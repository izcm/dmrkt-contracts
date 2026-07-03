// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

// foundry
import { console } from "forge-std/console.sol";

// core libraries
import { OrderModel } from "orderbook/libs/OrderModel.sol";
import { SignatureOps as SigOps } from "orderbook/libs/SignatureOps.sol";

// scripts base
import { BaseDevScript } from "dev/BaseDevScript.s.sol";
import { DevConfig } from "dev/DevConfig.s.sol";

// scripts order logic
import { EpochsJson } from "../epochs/EpochsJson.s.sol";
import { FillBid } from "./FillBid.s.sol";
import { SettlementValidation } from "./SettlementValidation.s.sol";

// interfaces
import { IERC20, SafeERC20 } from "@openzeppelin/token/ERC20/utils/SafeERC20.sol";
import { ISettlementEngine } from "dev/interfaces/ISettlementEngine.sol";

// types
import { SignedOrder, Selection } from "../epochs/Types.sol";

/**
 * @notice Settles a single order on-chain via OrderEngine.settle(). Called by run-epochs.sh
 *         once per chosen order after BuildEpoch has generated and signed them.
 * @dev    Reads the signed order from the epoch's JSON output, runs pre-settlement checks
 *         (timestamps, NFT ownership, nonce), produces a fill, then broadcasts settle().
 */
contract ExecuteOrder is EpochsJson, FillBid, SettlementValidation, BaseDevScript, DevConfig {
    using SafeERC20 for IERC20;
    using OrderModel for OrderModel.Order;

    uint256[] excludedFromCb;

    /**
     * @notice Entry point. Reads order at `idx` from epoch `epoch`, validates it, and settles it.
     * @param epoch  Epoch index — determines which state directory to read from.
     * @param idx    Order index within the epoch.
     */
    function run(uint256 epoch, uint256 idx) external {
        // --------------------------------
        // LOAD CONFIG & SETUP
        // --------------------------------

        address orderSettler = readSettlementContract();

        uint256 maxParticipantSize = vm.envOr("MAX_PARTICIPANT_SIZE", defaultParticipantSize());
        loadParticipants(maxParticipantSize, 0);

        logSection("EXECUTING ORDER");
        console.log("Epoch: %s", epoch);
        console.log("Index: %s", idx);
        logSeparator();

        // --------------------------------
        // READ JSON
        // --------------------------------

        SignedOrder memory signed = orderFromJson(epoch, idx);

        if (signed.order.isCollectionBid) {
            // selection.tokenIds are excluded when producing fill for collectionBids
            // this is because they are linked to some other order in this epoch

            Selection memory selection = selectionFromJson(epoch, signed.order.collection);

            // selection across epochs that are **not** to be executed in any epoch!

            uint256[] memory exclude = selection.tokenIds;

            for (uint256 i = 0; i < exclude.length; i++) {
                excludedFromCb.push(exclude[i]);
            }
        }

        // --------------------------------
        // VALIDATE AND EXECUTE
        // --------------------------------

        OrderModel.Order memory order = signed.order;
        SigOps.Signature memory sig = signed.signature;

        if (!validTimestamps(order)) {
            revert("INVALID_TIMESTAMPS");
        }

        OrderModel.Fill memory fill = _produceFill(order);

        if (!validNftOwnership(fill, order)) {
            revert("INVALID_NFT_OWNERSHIP");
        }

        if (ISettlementEngine(orderSettler).isUserOrderNonceInvalid(order.actor, order.nonce)) {
            revert("INVALID_NONCE");
        }

        vm.startBroadcast(pkOf(fill.actor));
        ISettlementEngine(orderSettler).settle(fill, order, sig);
        vm.stopBroadcast();

        console.log("Status: EXECUTED");
        logSeparator();
    }

    /**
     * @dev Routes fill production by order side. Asks pick a random counterparty;
     *      bids delegate to FillBid which handles both regular and collection bids.
     */
    function _produceFill(
        OrderModel.Order memory o
    ) internal view returns (OrderModel.Fill memory) {
        if (o.isAsk()) {
            return _fillAsk(o.actor, uint256((uint160(o.actor) << 160) | o.nonce));
        } else if (o.isBid()) {
            return fillBid(o, excludedFromCb);
        } else {
            revert("Invalid Order Side");
        }
    }

    /**
     * @dev Returns a fill for an ask order — picks a deterministic counterparty that is
     *      not the order actor, derived from the actor address and nonce as seed.
     */
    function _fillAsk(
        address orderActor,
        uint256 seed
    ) internal view returns (OrderModel.Fill memory) {
        return OrderModel.Fill({ tokenId: 0, actor: otherParticipant(orderActor, seed) });
    }
}
