// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.30;

import {OrderModel} from "orderbook/libs/OrderModel.sol";
import {OrderHelper} from "test-helpers/OrderHelper.sol";

contract OrderHelperTest is OrderHelper {
    using OrderModel for OrderModel.Order;

    address defaultCollection;
    address defaultCurrency;
    bytes32 domainSeparator;

    function setUp() public {
        domainSeparator = keccak256(abi.encode("dummy_domain"));
        defaultCollection = makeAddr("default_collection");
        defaultCurrency = makeAddr("default_currency");

        _initOrderHelper(domainSeparator, defaultCollection, defaultCurrency);
    }

    function test_make_ask_sets_side_ask() public {
        address actor = makeAddr("ask_actor");

        OrderModel.Order memory order = makeAsk(actor);

        assertEq(uint256(order.side), uint256(OrderModel.Side.Ask));
        assertEq(order.actor, actor);
    }

    function test_make_order_sets_collection_bid_flag() public {
        address actor = makeAddr("bid_actor");

        OrderModel.Order memory order = makeOrder(OrderModel.Side.Bid, true, actor);

        assertTrue(order.isBid());
        assertTrue(order.isCollectionBid);
        assertEq(order.actor, actor);
    }

    function test_make_order_uses_defaults() public {
        address actor = makeAddr("default_actor");

        OrderModel.Order memory order = makeOrder(OrderModel.Side.Ask, false, actor);

        assertEq(order.collection, defaultCollection);
        assertEq(order.currency, defaultCurrency);
        assertEq(order.price, 1 ether);
        assertEq(order.tokenId, 1);
        assertEq(order.start, 0);
        assertEq(order.end, uint64(block.timestamp + 1 days));
        assertEq(order.nonce, 0);
        assertFalse(order.isCollectionBid);
    }

    function test_make_ask_custom_collection_currency_uses_provided_values() public {
        address actor = makeAddr("custom_actor");
        address customCollection = makeAddr("custom_collection");
        address customCurrency = makeAddr("custom_currency");

        OrderModel.Order memory order = makeAsk(customCollection, customCurrency, actor);

        assertEq(order.collection, customCollection);
        assertEq(order.currency, customCurrency);
        assertEq(order.price, 1 ether);
        assertEq(order.tokenId, 1);
        assertEq(order.actor, actor);
        assertFalse(order.isCollectionBid);
    }
}
