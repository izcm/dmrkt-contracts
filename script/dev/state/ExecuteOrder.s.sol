// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

// foundry
import {console} from "forge-std/console.sol";

// core libraries
import {OrderModel} from "orderbook/libs/OrderModel.sol";
import {SignatureOps as SigOps} from "orderbook/libs/SignatureOps.sol";

// scripts base
import {BaseDevScript} from "dev/BaseDevScript.s.sol";
import {DevConfig} from "dev/DevConfig.s.sol";

// scripts order logic
import {EpochsJson} from "dev/logic/EpochsJson.s.sol";
import {FillBid} from "dev/logic/FillBid.s.sol";
import {SettlementValidation} from "dev/logic/SettlementValidation.s.sol";

// interfaces
import {IERC20, SafeERC20} from "@openzeppelin/token/ERC20/utils/SafeERC20.sol";
import {ISettlementEngine} from "periphery/interfaces/ISettlementEngine.sol";

// types
import {SignedOrder, Selection} from "dev/state/Types.sol";

contract ExecuteOrder is EpochsJson, FillBid, SettlementValidation, BaseDevScript, DevConfig {
    using SafeERC20 for IERC20;
    using OrderModel for OrderModel.Order;

    uint256[] excludedFromCb;

    function run(uint256 epoch, uint256 idx) external {
        // === LOAD CONFIG & SETUP ===

        address orderSettler = readSettlementContract();

        _loadParticipants();

        logSection("EXECUTING ORDER");
        console.log("Epoch: %s", epoch);
        console.log("Index: %s", idx);
        logSeparator();

        // === PARSE JSON ===

        SignedOrder memory signed = orderFromJson(epoch, idx);

        if (signed.order.isCollectionBid) {
            // selection.tokenIds are excluded when producing fill for collectionBids
            // this is because they are linked to some other order in this epoch
            Selection memory selection = selectionFromJson(epoch, signed.order.collection);

            uint256[] memory exclude = selection.tokenIds;

            for (uint256 i = 0; i < exclude.length; i++) {
                excludedFromCb.push(exclude[i]);
            }
        }

        // === VALIDATE AND EXECUTE ===

        OrderModel.Order memory order = signed.order;
        SigOps.Signature memory sig = signed.sig;

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

    function _produceFill(OrderModel.Order memory o) internal view returns (OrderModel.Fill memory) {
        if (o.isAsk()) {
            return _fillAsk(o.actor, uint256((uint160(o.actor) << 160) | o.nonce));
        } else if (o.isBid()) {
            return fillBid(o, excludedFromCb);
        } else {
            revert("Invalid Order Side");
        }
    }

    function _fillAsk(address orderActor, uint256 seed) internal view returns (OrderModel.Fill memory) {
        return OrderModel.Fill({tokenId: 0, actor: otherParticipant(orderActor, seed)});
    }
}
