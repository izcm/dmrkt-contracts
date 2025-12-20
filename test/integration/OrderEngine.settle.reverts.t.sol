// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

// local
import {OrderEngineSettleBase} from "./OrderEngine.settle.base.t.sol";

import {OrderEngine} from "orderbook/OrderEngine.sol";
import {OrderActs} from "orderbook/libs/OrderActs.sol";
import {SignatureOps as SigOps} from "orderbook/libs/SignatureOps.sol";

// mocks
import {MockUnsupported} from "mocks/MockUnsupported.sol";
import {MockERC721} from "mocks/MockERC721.sol";

// function test_Settle_OrderNotStarted_Reverts()
// function test_Settle_OrderExpired_Reverts()
/// NOTE:
/// When testing branches that revert before any `order.Side` logic,
/// the order defaults to `Ask` for simplicity.
///
/// When behavior depends on `Side`, dedicated tests are added
/// for `Ask`, `Bid`, and `CollectionBid`.
contract OrderEngineSettleRevertsTest is OrderEngineSettleBase {
    /*//////////////////////////////////////////////////////////////
                    VALID SIGNATURE NOT REQUIRED
    //////////////////////////////////////////////////////////////*/

    function test_Settle_InvalidSender_Reverts() public {
        Actors memory actors = someActors("invalid_sender");
        address txSender = vm.addr(actorCount() + 1); // private keys are [1, 2, 3... n]

        OrderActs.Order memory order = makeAsk(actors.order);
        OrderActs.Fill memory fill = makeFill(actors.fill);
        SigOps.Signature memory sig = dummySig();

        vm.prank(txSender);
        vm.expectRevert(OrderEngine.UnauthorizedFillActor.selector);
        orderEngine.settle(fill, order, sig);
    }

    function test_Settle_ZeroAsOrderActor_Reverts() public {
        Actors memory actors = Actors({
            order: address(0),
            fill: actor("not_important")
        });

        OrderActs.Order memory order = makeAsk(actors.order);

        SigOps.Signature memory sig = dummySig();

        OrderActs.Fill memory fill = makeFill(actors.fill);

        vm.prank(actors.fill);
        vm.expectRevert(OrderEngine.ZeroActor.selector);
        orderEngine.settle(fill, order, sig);
    }

    function test_Settle_NonWhitelistedCurrency_Reverts() public {
        string memory seed = "non_whitelisted_currency";
        MockERC721 supportedCollection = new MockERC721();

        // per today orderbook only supports WETH
        Actors memory actors = someActors(seed);

        address nonWhitelistedCurrency = makeAddr(seed);

        OrderActs.Order memory order = makeAsk(
            address(supportedCollection),
            nonWhitelistedCurrency,
            actors.order
        );

        SigOps.Signature memory sig = dummySig();

        OrderActs.Fill memory fill = makeFill(actors.fill);

        vm.prank(actors.fill);
        vm.expectRevert(OrderEngine.CurrencyNotWhitelisted.selector);
        orderEngine.settle(fill, order, sig);
    }

    /*//////////////////////////////////////////////////////////////
                    VALID SIGNATURE REQUIRED
    //////////////////////////////////////////////////////////////*/

    function test_Settle_InvalidOrderSide_Reverts() public {
        Actors memory actors = someActors("invalid_side");
        uint256 signerPk = pkOf(actors.order);

        OrderActs.Order memory order = makeAsk(actors.order);

        order.side = OrderActs.Side._COUNT; // invalid

        (, SigOps.Signature memory sig) = signOrder(order, signerPk);

        OrderActs.Fill memory fill = makeFill(actors.fill);

        vm.prank(actors.fill);
        vm.expectRevert(OrderEngine.InvalidOrderSide.selector);
        orderEngine.settle(fill, order, sig);
    }

    function test_Settle_TamperedOrder_Reverts() public {
        Actors memory actors = someActors("sig_mismatch");
        uint256 signerPk = pkOf(actors.order);

        OrderActs.Order memory order = makeAsk(actors.order);

        (, SigOps.Signature memory sig) = signOrder(order, signerPk);

        OrderActs.Fill memory fill = makeFill(actors.fill);

        // tamper price
        order.price = 10;

        vm.prank(actors.fill);
        vm.expectRevert(SigOps.InvalidSignature.selector);
        orderEngine.settle(fill, order, sig);
    }

    /*//////////////////////////////////////////////////////////////
                VALID SIGNATURE + APPROVALS REQUIRED
    //////////////////////////////////////////////////////////////*/

    function test_Settle_ReusedNonce_Reverts() public {
        Actors memory actors = someActors("reuse_nonce");
        uint256 signerPk = pkOf(actors.order);

        OrderActs.Order memory order = makeAsk(actors.order);

        (, SigOps.Signature memory sig) = signOrder(order, signerPk);

        OrderActs.Fill memory fill = makeFill(actors.fill);

        legitimizeSettlement(fill, order);

        // valid nonce
        vm.prank(actors.fill);
        orderEngine.settle(fill, order, sig);

        // replay nonce - should revert
        vm.prank(actors.fill);
        vm.expectRevert(OrderEngine.InvalidNonce.selector);
        orderEngine.settle(fill, order, sig);
    }

    function test_Settle_UnsupportedCollection_Reverts() public {
        Actors memory actors = someActors("unsupported_collection");
        uint256 signerPk = pkOf(actors.order);

        MockUnsupported unsupportedCollection = new MockUnsupported();

        OrderActs.Order memory order = makeAsk(
            address(unsupportedCollection),
            wethAddr(),
            actors.order
        );

        (, SigOps.Signature memory sig) = signOrder(order, signerPk);

        OrderActs.Fill memory fill = makeFill(actors.fill);

        // `legitimizeSettlement` mints nft while MockUnsupported does not mint implement `mint`
        // => explicitly do erc20 approvals
        uint256 price = order.price;
        address spender = actors.fill; // since order is `Ask`

        wethDealAndApproveSpenderAllowance(spender, price);

        vm.prank(actors.fill);
        vm.expectRevert(OrderEngine.UnsupportedCollection.selector);
        orderEngine.settle(fill, order, sig);
    }
}
