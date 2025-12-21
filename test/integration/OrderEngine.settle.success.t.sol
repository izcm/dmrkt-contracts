// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

// oz
import {IERC20} from "@openzeppelin/interfaces/IERC20.sol";
import {IERC721} from "@openzeppelin/interfaces/IERC721.sol";

// local
import {OrderEngineSettleBase} from "./OrderEngine.settle.base.t.sol";

// libraries
import {OrderActs} from "orderbook/libs/OrderActs.sol";
import {SignatureOps as SigOps} from "orderbook/libs/SignatureOps.sol";

// periphery
import {SettlementRoles} from "periphery/SettlementRoles.sol";

struct Balances {
    uint256 spender;
    uint256 nftHolder;
    uint256 protocol;
}

contract OrderEngineSettleSuccessTest is OrderEngineSettleBase {
    using OrderActs for OrderActs.Order;

    function test_Settle_Ask_Succeeds() public {
        _assertSettleSucceeds(OrderActs.Side.Ask, false, someActors("ask"));
    }

    function test_Settle_Bid_SpecificToken_Succeeds() public {
        _assertSettleSucceeds(
            OrderActs.Side.Bid,
            false,
            someActors("bid_specific")
        );
    }

    function test_Settle_Bid_CollectionBid_Succeeds() public {
        _assertSettleSucceeds(
            OrderActs.Side.Bid,
            true,
            someActors("bid_collection")
        );
    }

    function _assertSettleSucceeds(
        OrderActs.Side side,
        bool isCollectionBid,
        Actors memory actors
    ) internal {
        uint256 signerPk = pkOf(actors.order);

        // defaults to mockEERC721 + WETH
        OrderActs.Order memory order = makeOrder(
            side,
            isCollectionBid,
            actors.order
        );

        (, SigOps.Signature memory sig) = signOrder(order, signerPk);

        uint256 tokenIdFill = order.isBid() ? order.tokenId : 0;

        OrderActs.Fill memory fill = makeFill(actors.fill, tokenIdFill);

        legitimizeSettlement(fill, order);

        (address nftHolder, address spender, uint256 tokenId) = SettlementRoles
            .resolve(fill, order);

        // check balance of parties before settlement
        IERC20 token = IERC20(order.currency);

        Balances memory beforeSuccess = _balanceOfParties(
            token,
            spender,
            nftHolder
        );

        vm.prank(actors.fill);
        orderEngine.settle(fill, order, sig);

        // check balance of parties after_ settlement
        Balances memory afterSuccess = _balanceOfParties(
            token,
            spender,
            nftHolder
        );

        _assertPayoutMatchesExpectations(
            beforeSuccess,
            afterSuccess,
            order.price
        );

        // check new ownership
        assertEq(IERC721(order.collection).ownerOf(tokenId), spender);

        assertTrue(
            orderEngine.isUserOrderNonceInvalid(order.actor, order.nonce)
        );
    }

    function _assertPayoutMatchesExpectations(
        Balances memory before,
        Balances memory after_, // _ suffix since `after` is a reserved keyword
        uint256 orderPrice
    ) internal view {
        uint256 fee = _protocolFee(orderPrice);
        uint256 payout = orderPrice - fee;

        uint256 spenderDiff = before.spender - after_.spender; // should decrease
        uint256 nftHolderDiff = after_.nftHolder - before.nftHolder; // should increase
        uint256 protocolDiff = after_.protocol - before.protocol; // should increase

        assertEq(spenderDiff, orderPrice);
        assertEq(nftHolderDiff, payout);
        assertEq(protocolDiff, fee);
    }

    function _protocolFee(uint256 price) internal view returns (uint256) {
        return (price * orderEngine.PROTOCOL_FEE_BPS()) / 10000;
    }

    function _balanceOfParties(
        IERC20 token,
        address spender,
        address nftHolder
    ) internal view returns (Balances memory b) {
        b.spender = token.balanceOf(spender);
        b.nftHolder = token.balanceOf(nftHolder);
        b.protocol = token.balanceOf(protocolFeeRecipient);
    }
}
