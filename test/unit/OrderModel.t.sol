// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";

// local
import {OrderModel} from "orderbook/libs/OrderModel.sol";

contract OrderModelTest is Test {
    using OrderModel for OrderModel.Order;

    /*//////////////////////////////////////////////////////////////
                                IsAsk
    //////////////////////////////////////////////////////////////*/

    function test_is_ask_returns_true_for_ask() public pure {
        OrderModel.Order memory order = OrderModel.Order({
            side: OrderModel.Side.Ask,
            isCollectionBid: false,
            collection: address(0),
            tokenId: 0,
            currency: address(0),
            price: 0,
            actor: address(0),
            start: 0,
            end: 0,
            nonce: 0
        });

        assertTrue(order.isAsk());
    }

    function test_is_ask_returns_false_for_bid() public pure {
        OrderModel.Order memory order = OrderModel.Order({
            side: OrderModel.Side.Bid,
            isCollectionBid: false,
            collection: address(0),
            tokenId: 0,
            currency: address(0),
            price: 0,
            actor: address(0),
            start: 0,
            end: 0,
            nonce: 0
        });

        assertFalse(order.isAsk());
    }

    /*//////////////////////////////////////////////////////////////
                                IsBid
    //////////////////////////////////////////////////////////////*/

    function test_is_bid_returns_true_for_bid() public pure {
        OrderModel.Order memory order = OrderModel.Order({
            side: OrderModel.Side.Bid,
            isCollectionBid: false,
            collection: address(0),
            tokenId: 0,
            currency: address(0),
            price: 0,
            actor: address(0),
            start: 0,
            end: 0,
            nonce: 0
        });

        assertTrue(order.isBid());
    }

    function test_is_bid_returns_false_for_ask() public pure {
        OrderModel.Order memory order = OrderModel.Order({
            side: OrderModel.Side.Ask,
            isCollectionBid: false,
            collection: address(0),
            tokenId: 0,
            currency: address(0),
            price: 0,
            actor: address(0),
            start: 0,
            end: 0,
            nonce: 0
        });

        assertFalse(order.isBid());
    }
}
