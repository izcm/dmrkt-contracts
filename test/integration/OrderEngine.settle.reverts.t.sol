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
        address txSender = vm.addr(actorCount() + 1); // private keys are [1, 2, 3... n]
        (
            ,
            OrderActs.Order memory order,
            OrderActs.Fill memory fill,
            SigOps.Signature memory sig
        ) = _setupBasicRevertTest("invalid_sender");

        _expectSettleRevert(
            fill,
            order,
            sig,
            txSender,
            OrderEngine.UnauthorizedFillActor.selector
        );
    }

    function test_Settle_ZeroAsOrderActor_Reverts() public {
        Actors memory actors = Actors({
            order: address(0),
            fill: actor("not_important")
        });
        OrderActs.Order memory order = makeAsk(actors.order);
        OrderActs.Fill memory fill = makeFill(actors.fill);
        SigOps.Signature memory sig = dummySig();

        _expectSettleRevert(
            fill,
            order,
            sig,
            actors.fill,
            OrderEngine.ZeroActor.selector
        );
    }

    function test_Settle_NonWhitelistedCurrency_Reverts() public {
        MockERC721 supportedCollection = new MockERC721();
        Actors memory actors = someActors("non_whitelisted_currency");
        address nonWhitelistedCurrency = makeAddr("non_whitelisted_currency");

        OrderActs.Order memory order = makeAsk(
            address(supportedCollection),
            nonWhitelistedCurrency,
            actors.order
        );
        OrderActs.Fill memory fill = makeFill(actors.fill);
        SigOps.Signature memory sig = dummySig();

        _expectSettleRevert(
            fill,
            order,
            sig,
            actors.fill,
            OrderEngine.CurrencyNotWhitelisted.selector
        );
    }

    function test_Settle_OrderNotStarted_Reverts() public {
        (
            Actors memory actors,
            OrderActs.Order memory order,
            OrderActs.Fill memory fill,
            SigOps.Signature memory sig
        ) = _setupBasicRevertTest("not_started_order");

        order.start = uint64(block.timestamp + 1 days);

        _expectSettleRevert(
            fill,
            order,
            sig,
            fill.actor,
            OrderEngine.InvalidTimestamp.selector
        );
    }

    function test_Settle_OrderExpired_Reverts() public {
        (
            Actors memory actors,
            OrderActs.Order memory order,
            OrderActs.Fill memory fill,
            SigOps.Signature memory sig
        ) = _setupBasicRevertTest("expired_order");

        order.start = 1;
        order.end = 2;

        vm.warp(3);

        _expectSettleRevert(
            fill,
            order,
            sig,
            fill.actor,
            OrderEngine.InvalidTimestamp.selector
        );
    }

    /*//////////////////////////////////////////////////////////////
                    VALID SIGNATURE REQUIRED
    //////////////////////////////////////////////////////////////*/

    function test_Settle_InvalidOrderSide_Reverts() public {
        (
            Actors memory actors,
            OrderActs.Order memory order,
            OrderActs.Fill memory fill,
            SigOps.Signature memory sig,
            uint256 signerPk
        ) = _setupSignedRevertTest("invalid_side");

        order.side = OrderActs.Side._COUNT; // invalid
        (, sig) = signOrder(order, signerPk);

        _expectSettleRevert(
            fill,
            order,
            sig,
            actors.fill,
            OrderEngine.InvalidOrderSide.selector
        );
    }

    function test_Settle_SignatureMismatch_Reverts() public {
        (
            Actors memory actors,
            OrderActs.Order memory order,
            OrderActs.Fill memory fill,
            SigOps.Signature memory sig,

        ) = _setupSignedRevertTest("sig_mismatch");

        // tamper price
        order.price = 10;

        _expectSettleRevert(
            fill,
            order,
            sig,
            actors.fill,
            SigOps.InvalidSignature.selector
        );
    }

    /*//////////////////////////////////////////////////////////////
                VALID SIGNATURE + APPROVALS REQUIRED
    //////////////////////////////////////////////////////////////*/

    function test_Settle_ReusedNonce_Reverts() public {
        (
            Actors memory actors,
            OrderActs.Order memory order,
            OrderActs.Fill memory fill,
            SigOps.Signature memory sig,

        ) = _setupSignedRevertTest("reuse_nonce");

        legitimizeSettlement(fill, order);

        // valid nonce
        vm.prank(actors.fill);
        orderEngine.settle(fill, order, sig);

        // replay nonce - should revert
        _expectSettleRevert(
            fill,
            order,
            sig,
            actors.fill,
            OrderEngine.InvalidNonce.selector
        );
    }

    function test_Settle_UnsupportedCollection_Reverts() public {
        MockUnsupported unsupportedCollection = new MockUnsupported();
        Actors memory actors = someActors("unsupported_collection");
        uint256 signerPk = pkOf(actors.order);

        OrderActs.Order memory order = makeAsk(
            address(unsupportedCollection),
            wethAddr(),
            actors.order
        );
        (, SigOps.Signature memory sig) = signOrder(order, signerPk);
        OrderActs.Fill memory fill = makeFill(actors.fill);

        // `legitimizeSettlement` mints nft while MockUnsupported does not mint implement `mint`
        // => explicitly do erc20 approvals
        wethDealAndApproveSpenderAllowance(actors.fill, order.price);

        _expectSettleRevert(
            fill,
            order,
            sig,
            actors.fill,
            OrderEngine.UnsupportedCollection.selector
        );
    }

    /*//////////////////////////////////////////////////////////////
                                HELPERS
    //////////////////////////////////////////////////////////////*/

    function _expectSettleRevert(
        OrderActs.Fill memory fill,
        OrderActs.Order memory order,
        SigOps.Signature memory sig,
        address caller,
        bytes4 errorSelector
    ) internal {
        vm.prank(caller);
        vm.expectRevert(errorSelector);
        orderEngine.settle(fill, order, sig);
    }

    function _setupBasicRevertTest(
        string memory seed
    )
        internal
        returns (
            Actors memory actors,
            OrderActs.Order memory order,
            OrderActs.Fill memory fill,
            SigOps.Signature memory sig
        )
    {
        actors = someActors(seed);
        order = makeAsk(actors.order);
        fill = makeFill(actors.fill);
        sig = dummySig();
    }

    function _setupSignedRevertTest(
        string memory seed
    )
        internal
        returns (
            Actors memory actors,
            OrderActs.Order memory order,
            OrderActs.Fill memory fill,
            SigOps.Signature memory sig,
            uint256 signerPk
        )
    {
        actors = someActors(seed);
        signerPk = pkOf(actors.order);
        order = makeAsk(actors.order);
        (, sig) = signOrder(order, signerPk);
        fill = makeFill(actors.fill);
    }
}
