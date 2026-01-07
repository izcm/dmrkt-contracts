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
import {OrdersJson} from "dev/logic/OrdersJson.s.sol";
import {FillBid} from "dev/logic/FillBid.s.sol";
import {SettlementValidation} from "dev/logic/SettlementValidation.s.sol";

// interfaces
import {IERC20, SafeERC20} from "@openzeppelin/token/ERC20/utils/SafeERC20.sol";
import {ISettlementEngine} from "periphery/interfaces/ISettlementEngine.sol";

// types
import {SignedOrder, Selection} from "dev/state/Types.sol";

// TODO: have a seperate bash script that sets nowts() after all scripts finish
contract ExecuteHistory is
    OrdersJson,
    FillBid,
    SettlementValidation,
    BaseDevScript,
    DevConfig
{
    using SafeERC20 for IERC20;
    using OrderModel for OrderModel.Order;

    function run(uint256 _epoch, uint256 _epochSize) external {
        // === LOAD CONFIG & SETUP ===

        address orderSettler = readSettlementContract();

        _loadParticipants();

        logSection("EXECUTING ORDERS");
        console.log("Block timestamp: %s", block.timestamp);
        console.log("Epoch: %s", _epoch);
        logSeparator();

        // === PARSE JSON ORDERS ===

        SignedOrder[] memory signed = ordersFromJson(_epoch);

        uint256 count = signed.length;

        // === MATCH FILL AND EXECUTE ===

        uint256 executedCount;

        uint256 invalidTimestamps;
        uint256 invalidOwnership;
        uint256 invalidNonce;

        for (uint256 i; i < count; i++) {
            OrderModel.Order memory order = signed[i].order;
            SigOps.Signature memory sig = signed[i].sig;

            OrderModel.Fill memory fill = _produceFill(order);

            if (!validTimestamps(order)) {
                invalidTimestamps++;
                continue;
            }

            if (!validNftOwnership(fill, order)) {
                invalidOwnership++;
                continue;
            }

            if (
                ISettlementEngine(orderSettler).isUserOrderNonceInvalid(
                    order.actor,
                    order.nonce
                )
            ) {
                invalidNonce++;
                continue;
            }

            vm.startBroadcast(pkOf(fill.actor));
            ISettlementEngine(orderSettler).settle(fill, order, sig);
            vm.stopBroadcast();

            executedCount++;
        }

        console.log("=== EXECUTION SUMMARY ===");
        console.log("Total Orders: %s", count);
        console.log("Executed: %s", executedCount);
        console.log("Invalid Timestamps: %s", invalidTimestamps);
        console.log("Invalid Ownership: %s", invalidOwnership);
        console.log("Invalid Nonce: %s", invalidNonce);
        console.log("Total Skipped: %s", count - executedCount);

        logSeparator();
    }

    function _produceFill(
        OrderModel.Order memory o
    ) internal view returns (OrderModel.Fill memory) {
        if (o.isAsk()) {
            return
                _fillAsk(o.actor, uint256((uint160(o.actor) << 160) | o.nonce));
        } else if (o.isBid()) {
            return fillBid(o);
        } else {
            revert("Invalid Order Side");
        }
    }

    function _fillAsk(
        address orderActor,
        uint256 seed
    ) internal view returns (OrderModel.Fill memory) {
        return
            OrderModel.Fill({
                tokenId: 0,
                actor: otherParticipant(orderActor, seed)
            });
    }

    // === PRIVATE FUNCTIONS ===

    // to exclude selected tokens to be sold beforehand by `_fillCollectionBid`
    // function _importExcluded() private returns (uint256[] memory) {}
}
