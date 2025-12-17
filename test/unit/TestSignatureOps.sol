// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";

// local
import {OrderActs} from "orderbook/libs/OrderActs.sol";
import {SignatureOps as SigOps} from "orderbook/libs/SignatureOps.sol";

// mocks
import {MockVerifyingContract} from "../mocks/MockVerifyingContract.sol";

contract TestSignatureOps is Test {
    using OrderActs for OrderActs.Order;

    MockVerifyingContract verifier;

    uint256 userPrivateKey;
    uint256 signerPrivateKey;

    address user;
    address signer;

    address collection = makeAddr("collection");
    address currency = makeAddr("currency");

    function setUp() public {
        verifier = new MockVerifyingContract(keccak256("TEST_DOMAIN"));

        userPrivateKey = 0xabc123;
        signerPrivateKey = 0x123abc;

        user = vm.addr(userPrivateKey);
        signer = vm.addr(signerPrivateKey);
    }

    function test_Verify_ValidSignature_Succeeds() public {
        (
            OrderActs.Order memory order,
            SigOps.Signature memory sig
        ) = makeOrderDigestAndSign(signer, signerPrivateKey);

        vm.prank(user);
        verifier.verify(order, sig);
    }

    function test_Verify_CorruptedS_Reverts() public {
        (
            OrderActs.Order memory order,
            SigOps.Signature memory sig
        ) = makeOrderDigestAndSign(signer, signerPrivateKey);

        // simulate corrupt s <= n/2 https://eips.ethereum.org/EIPS/eip-2
        sig.s = bytes32(
            uint256(
                0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A0
            ) + 1
        );

        vm.prank(user);
        vm.expectRevert(SigOps.InvalidSParameter.selector);
        verifier.verify(order, sig);
    }

    function test_Verify_WrongSigner_Reverts() public {
        (
            OrderActs.Order memory order,
            SigOps.Signature memory sig
        ) = makeOrderDigestAndSign(signer, signerPrivateKey);

        order.actor = makeAddr("imposter");

        vm.expectRevert(SigOps.InvalidSignature.selector);
        verifier.verify(order, sig);
    }

    // ===== HELPERS =====

    function makeOrderDigestAndSign(
        address actor,
        uint256 actorPrivateKey
    ) internal view returns (OrderActs.Order memory, SigOps.Signature memory) {
        OrderActs.Order memory order = makeOrder(actor);
        bytes32 digest = makeDigest(order);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(actorPrivateKey, digest);
        SigOps.Signature memory sig = SigOps.Signature({v: v, r: r, s: s});

        return (order, sig);
    }

    function makeOrder(
        address actor
    ) internal view returns (OrderActs.Order memory) {
        return makeOrder(actor, 0);
    }

    function makeOrder(
        address actor,
        uint256 nonce
    ) internal view returns (OrderActs.Order memory) {
        return makeOrder(actor, nonce, 1 ether);
    }

    // TODO: make this accept some seed or make helper seedGenerator to pseudo-randomize fields
    function makeOrder(
        address actor,
        uint256 nonce,
        uint256 price
    ) internal view returns (OrderActs.Order memory) {
        return
            OrderActs.Order({
                side: OrderActs.Side.Ask,
                actor: actor,
                isCollectionBid: false,
                collection: collection,
                currency: currency,
                tokenId: 1,
                price: price,
                start: 0,
                end: uint64(block.timestamp + 1 days),
                nonce: nonce
            });
    }

    function makeDigest(
        OrderActs.Order memory o
    ) internal view returns (bytes32) {
        bytes32 msgHash = o.hash();

        return
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    verifier.DOMAIN_SEPARATOR(),
                    msgHash
                )
            );
    }
}
