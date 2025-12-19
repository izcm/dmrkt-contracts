// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {console} from "forge-std/console.sol";

// local
import {OrderEngine} from "orderbook/OrderEngine.sol";
import {OrderActs} from "orderbook/libs/OrderActs.sol";
import {SignatureOps as SigOps} from "orderbook/libs/SignatureOps.sol";

// helpers
import {OrderHelper} from "test-helpers/OrderHelper.sol";
import {AccountsHelper} from "test-helpers/AccountsHelper.sol";
import {SettlementHelper} from "test-helpers/SettlementHelper.sol";

// mocks
import {MockWETH} from "mocks/MockWETH.sol";
import {MockERC721} from "mocks/MockERC721.sol";
import {MockUnsupported} from "mocks/MockUnsupported.sol";

/*
    // === SIGNATURE (INTEGRATION ONLY) ===

    // invalid signature causes settle to revert
*/

/// NOTE:
/// When testing branches that revert before any `order.Side` logic,
/// the order defaults to `Ask` for simplicity.
///
/// When behavior depends on `Side`, dedicated tests are added
/// for `Ask`, `Bid`, and `CollectionBid`.
contract OrderEngineSettleRevertsTest is
    OrderHelper,
    AccountsHelper,
    SettlementHelper
{
    using OrderActs for OrderActs.Order;

    uint256 private constant DEFAULT_ACTOR_COUNT = 10; // adjust as you please

    OrderEngine orderEngine;
    address erc721;

    function setUp() public {
        MockWETH wethToken = new MockWETH();
        MockERC721 erc721Token = new MockERC721();

        address weth = address(wethToken);
        erc721 = address(erc721Token);

        orderEngine = new OrderEngine(weth, address(this)); // fee receiver = this
        bytes32 domainSeparator = orderEngine.DOMAIN_SEPARATOR();

        // future proofing in case auth decentralizes from orderEngine
        address erc721TransferOperator = address(orderEngine);
        address erc20AllowanceSpender = address(orderEngine);

        _initSettlementHelper(
            weth,
            erc721TransferOperator,
            erc20AllowanceSpender
        );
        _initOrderHelper(domainSeparator);

        _initActors(DEFAULT_ACTOR_COUNT);
    }

    /*//////////////////////////////////////////////////////////////
                    VALID SIGNATURE NOT REQUIRED
    //////////////////////////////////////////////////////////////*/

    function test_Settle_InvalidSenderReverts() public {
        Actors memory actors = someActors("invalid_sender");
        address txSender = vm.addr(actorCount() + 1); // private keys is [1, 2, 3... n]

        OrderActs.Order memory order = makeAsk(actors.order);
        OrderActs.Fill memory fill = makeFill(actors.fill);
        SigOps.Signature memory sig = dummySig();

        vm.prank(txSender);
        vm.expectRevert(OrderEngine.UnauthorizedFillActor.selector);
        orderEngine.settle(fill, order, sig);
    }

    function test_Settle_ZeroAsOrderActorReverts() public {
        Actors memory actors = Actors({
            order: address(0),
            fill: actor("not_important")
        });

        OrderActs.Order memory order = makeAsk(
            actors.order,
            erc721,
            wethAddr()
        );

        SigOps.Signature memory sig = dummySig();

        OrderActs.Fill memory fill = makeFill(actors.fill);

        vm.prank(actors.fill);
        vm.expectRevert(OrderEngine.ZeroActor.selector);
        orderEngine.settle(fill, order, sig);
    }

    function test_Settle_NonWhitelistedCurrencyReverts() public {
        string memory seed = "non_whitelisted_currency";

        // per today orderbook only supports WETH
        Actors memory actors = someActors(seed);

        address nonWhitelistedCurrency = makeAddr(seed);

        OrderActs.Order memory order = makeAsk(
            actors.order,
            erc721,
            nonWhitelistedCurrency
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

    function test_Settle_InvalidOrderSideReverts() public {
        Actors memory actors = someActors("invalid_side");
        uint256 signerPk = pkOf(actors.order);

        OrderActs.Order memory order = makeAsk(
            actors.order,
            erc721,
            wethAddr()
        );

        order.side = OrderActs.Side._COUNT; // invalid

        (, SigOps.Signature memory sig) = makeDigestAndSign(order, signerPk);

        OrderActs.Fill memory fill = makeFill(actors.fill);

        vm.prank(actors.fill);
        vm.expectRevert(OrderEngine.InvalidOrderSide.selector);
        orderEngine.settle(fill, order, sig);
    }

    function test_Settle_TamperedOrderReverts() public {
        Actors memory actors = someActors("sig_mismatch");
        uint256 signerPk = pkOf(actors.order);

        OrderActs.Order memory order = makeAsk(
            actors.order,
            erc721,
            wethAddr()
        );

        (, SigOps.Signature memory sig) = makeDigestAndSign(order, signerPk);

        OrderActs.Fill memory fill = makeFill(actors.fill);

        // decrease price
        order.price = 10;

        vm.prank(actors.fill);
        vm.expectRevert(SigOps.InvalidSignature.selector);
        orderEngine.settle(fill, order, sig);
    }

    /*//////////////////////////////////////////////////////////////
                VALID SIGNATURE + APPROVALS REQUIRED
    //////////////////////////////////////////////////////////////*/

    function test_Settle_ReusedNonceReverts() public {
        Actors memory actors = someActors("reuse_nonce");
        uint256 signerPk = pkOf(actors.order);

        OrderActs.Order memory order = makeAsk(
            actors.order,
            erc721,
            wethAddr()
        );

        (, SigOps.Signature memory sig) = makeDigestAndSign(order, signerPk);

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

    function test_Settle_UnsupportedCollectionReverts() public {
        Actors memory actors = someActors("unsupported_collection");
        uint256 signerPk = pkOf(actors.order);

        MockUnsupported unsupportedCollection = new MockUnsupported();

        OrderActs.Order memory order = makeAsk(
            actors.order,
            address(unsupportedCollection),
            wethAddr()
        );

        (, SigOps.Signature memory sig) = makeDigestAndSign(order, signerPk);

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
