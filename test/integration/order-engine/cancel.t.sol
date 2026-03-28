// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";

// local
import {OrderEngine} from "orderbook/OrderEngine.sol";
import {SignatureOps as SigOps} from "orderbook/libs/SignatureOps.sol";
import {OrderModel} from "orderbook/libs/OrderModel.sol";

contract OrderEngineCancelTest is Test {
    OrderEngine internal engine = new OrderEngine(address(0), address(0));

    address user = vm.addr(123);
    uint256 nonce = uint256(keccak256("invalid_nonce"));

    event OrderCancelled(address indexed user, uint256 indexed nonce);

    function test_cancel_emits_event() public {
        vm.expectEmit(true, true, false, false);
        emit OrderCancelled(user, nonce);

        vm.prank(user);
        engine.cancelOrder(nonce);
    }

    function test_cancel_sets_nonce_invalid() public {
        vm.prank(user);
        engine.cancelOrder(nonce);

        bool isInvalidNonce = engine.isUserOrderNonceInvalid(user, nonce);
        assertTrue(isInvalidNonce);
    }

    function test_settle_reverts_when_nonce_cancelled() public {
        OrderModel.Order memory order = OrderModel.Order({
            side: OrderModel.Side.Ask,
            isCollectionBid: false,
            collection: address(0),
            tokenId: 0,
            currency: address(0),
            price: 0,
            actor: user,
            start: 0,
            end: 1,
            nonce: nonce
        });

        SigOps.Signature memory sig = SigOps.Signature({
            v: 0,
            r: bytes32(0),
            s: bytes32(0)
        });

        vm.prank(user);
        engine.cancelOrder(nonce);

        vm.expectRevert(OrderEngine.InvalidNonce.selector);
        engine.settle(
            OrderModel.Fill({tokenId: order.tokenId, actor: address(this)}),
            order,
            sig
        );
    }
}
