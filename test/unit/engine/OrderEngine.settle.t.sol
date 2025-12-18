// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.30;

// local
import {OrderEngine} from "orderbook/OrderEngine.sol";
import {OrderActs} from "orderbook/libs/OrderActs.sol";
import {SignatureOps as SigOps} from "orderbook/libs/SignatureOps.sol";

// helpers
import {OrderHelper} from "test-helpers/OrderHelper.sol";
import {AccountsHelper} from "test-helpers/AccountsHelper.sol";

/*
    // === REVERTS ===

    // invalid signature (wrong signer / wrong order fields)
    // reused nonce
    // order.actor == address(0)
    // currency != WETH
    // unsupported collection (not ERC721)
    // insufficient ERC20 allowance

    // === VALID ===

    // NFT transfers seller → fill.actor
    // WETH balances: buyer pays, seller receives (minus fee), protocol gets fee
    // nonce invalidated after settle
    // cannot settle same order twice

    // === SIGNATURE (INTEGRATION ONLY) ===

    // invalid signature causes settle to revert
    // valid signature allows settle to proceed
*/

contract OrderEngineSettleTest is OrderHelper, AccountsHelper {
    using OrderActs for OrderActs.Order;

    uint256 internal constant DEFAULT_TOKENID = 1;

    address immutable WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    OrderEngine orderEngine;
    address user = makeAddr("user");

    address[] actors;

    function setUp() public {
        orderEngine = new OrderEngine(WETH, address(this)); // fee receiver = this

        actors = allActors();
    }

    /*//////////////////////////////////////////////////////////////
                                REVERTS
    //////////////////////////////////////////////////////////////*/
    function test_Settle_InvalidSenderReverts() public {
        address orderActor = actors[0];

        address fillActor = actors[1];
        address txSender = actors[2];

        OrderActs.Order memory order = makeOrder(orderActor);
        OrderActs.Fill memory fill = makeFill(fillActor);
        SigOps.Signature memory sig = dummySig();

        vm.prank(txSender);
        vm.expectRevert(OrderEngine.UnauthorizedFillActor.selector);
        orderEngine.settle(fill, order, sig);
    }

    function test_Settle_ReusedNonceReverts() public {}

    function makeFill(
        address actor
    ) internal view returns (OrderActs.Fill memory fill) {
        return OrderActs.Fill({actor: actor, tokenId: DEFAULT_TOKENID});
    }

    function makeFill(
        address actor,
        uint256 tokenId
    ) internal view returns (OrderActs.Fill memory fill) {
        return OrderActs.Fill({actor: actor, tokenId: tokenId});
    }
}
