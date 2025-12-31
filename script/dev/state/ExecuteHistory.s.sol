// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

// core libraries
import {OrderModel} from "orderbook/libs/OrderModel.sol";
import {SignatureOps as SigOps} from "orderbook/libs/SignatureOps.sol";

// scripts
import {BaseDevScript} from "dev/BaseDevScript.s.sol";
import {DevConfig} from "dev/DevConfig.s.sol";

import {OrdersJson} from "dev/logic/OrdersJson.s.sol";
import {FillBid} from "dev/logic/FillBid.s.sol";

// interfaces
import {IERC20, SafeERC20} from "@openzeppelin/token/ERC20/utils/SafeERC20.sol";

// types
import {SignedOrder} from "dev/state/Types.sol";

contract ExecuteHistory is OrdersJson, FillBid, BaseDevScript, DevConfig {
    using SafeERC20 for IERC20;
    using OrderModel for OrderModel.Order;

    // ctx
    uint256 epoch;

    function run() external {
        _loadParticipants();

        // read signed orders from .json
        SignedOrder[] memory signed = ordersFromJson(
            string.concat(ordersJsonDir(), ".4.json")
        );
    }

    function _produceFills(
        OrderModel.Order[] memory orders
    ) internal view returns (OrderModel.Fill[] memory fills) {
        fills = new OrderModel.Fill[](orders.length);

        address allowanceSpender = readAllowanceSpender();

        for (uint256 i = 0; i < orders.length; i++) {
            OrderModel.Order memory order = orders[i];

            fills[i] = _produceFill(order);

            uint256 allowance = IERC20(order.currency).allowance(
                fills[i].actor,
                allowanceSpender
            );

            require(allowance > order.price, "Allowance too low");
        }
    }

    // TODO: seperate fillOrder** functionality to own abstract contracts
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

    function _jumpToWeek() internal {
        uint256 startTs = readStartTs();
        vm.warp(startTs + (epoch * 7 days));
    }

    function _jumpToNow() internal {
        vm.warp(readNowTs());
    }
}
