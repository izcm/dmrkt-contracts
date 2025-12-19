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

/*
    // === REVERTS ===

    // order.actor == address(0)
    // currency != WETH
    // unsupported collection (not ERC721)
    // test reverts on invalid `Side`
    // reverts if isBid & !isCollectionBid and order.tokenid != fill.tokenId

    // === SIGNATURE (INTEGRATION ONLY) ===

    // invalid signature causes settle to revert
*/

contract OrderEngineSettleRevertsTest is
    OrderHelper,
    AccountsHelper,
    SettlementHelper
{
    using OrderActs for OrderActs.Order;

    uint256 constant DEFAULT_TOKEN_ID_FILL = 1;

    OrderEngine orderEngine;
    bytes32 domainSeparator;

    address erc721;

    function setUp() public {
        MockWETH wethToken = new MockWETH();
        MockERC721 erc721Token = new MockERC721();

        address weth = address(wethToken);
        erc721 = address(erc721Token);

        orderEngine = new OrderEngine(weth, address(this)); // fee receiver = this
        domainSeparator = orderEngine.DOMAIN_SEPARATOR();

        // future proofing in case auth decentralizes from orderEngine
        address erc721Transferer = address(orderEngine);
        address erc20Spender = address(orderEngine);

        _initSettlementHelper(weth, erc721Transferer, erc20Spender);
    }

    function test_Settle_InvalidSenderReverts() public {
        Actors memory actors = someActors("invalid_sender");
        address txSender = vm.addr(actorCount() + 1); // private keys is [1, 2, 3... n]

        OrderActs.Order memory order = makeAsk(actors.order); // should fail before currency revert
        OrderActs.Fill memory fill = makeFill(actors.fill);
        SigOps.Signature memory sig = dummySig();

        vm.prank(txSender);
        vm.expectRevert(OrderEngine.UnauthorizedFillActor.selector);
        orderEngine.settle(fill, order, sig);
    }

    function test_Settle_ReusedNonceReverts() public {
        Actors memory actors = someActors("reuse_nonce");
        uint256 signerPk = pkOf(actors.order);

        OrderActs.Order memory order = makeAsk(
            actors.order,
            erc721,
            wethAddr()
        );

        (, SigOps.Signature memory sig) = makeDigestAndSign(
            order,
            domainSeparator,
            signerPk
        );

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

    function test_Settle_ZeroAsOrderActorReverts() public {}

    // === INTERNAL HELPERS ===

    function makeFill(
        address actor
    ) internal view returns (OrderActs.Fill memory fill) {
        return OrderActs.Fill({actor: actor, tokenId: DEFAULT_TOKEN_ID_FILL});
    }

    function makeFill(
        address actor,
        uint256 tokenId
    ) internal pure returns (OrderActs.Fill memory fill) {
        return OrderActs.Fill({actor: actor, tokenId: tokenId});
    }
}
