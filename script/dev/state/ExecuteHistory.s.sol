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
import {SignedOrder} from "dev/state/Types.sol";

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
        // === TIME WARP ===

        _jumpToEpoch(_epoch, _epochSize);

        // === LOAD CONFIG & SETUP ===

        address orderSettler = readSettlementContract();

        _loadParticipants();

        // === PARSE JSON ORDERS ===

        SignedOrder[] memory signed = ordersFromJson(
            string.concat(
                ordersJsonDir(),
                string.concat(vm.toString(_epoch), ".json")
            )
        );

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

            bool isInvalidNonce = ISettlementEngine(orderSettler)
                .isUserOrderNonceInvalid(order.actor, order.nonce);

            if (isInvalidNonce) {
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

    function _isValidSettlement(
        OrderModel.Fill memory f,
        OrderModel.Order memory o
    ) internal view returns (bool) {
        return (validTimestamps(o) && validNftOwnership(f, o));
    }

    function _produceFill(
        OrderModel.Order memory order
    ) internal view returns (OrderModel.Fill memory) {
        if (order.isAsk()) {
            return _fillAsk(order.actor, order.nonce);
        } else if (order.isBid()) {
            return fillBid(order);
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

    // === TIME HELPERS ===

    function _jumpToEpoch(uint256 epoch, uint256 eSize) private {
        uint256 startTs = readStartTs();
        vm.warp(startTs + (epoch * eSize));
    }

    function _jumpToNow() private {
        vm.warp(readNowTs());
    }
}
