// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.30;

// local
import {OrderModel} from "orderbook/libs/OrderModel.sol";
import {SignatureOps as SigOps} from "orderbook/libs/SignatureOps.sol";
import {OrderHelper} from "test-helpers/OrderHelper.sol";

// mocks
import {MockVerifyingContract} from "../mocks/MockVerifyingContract.sol";

contract SignatureOpsTest is OrderHelper {
    MockVerifyingContract verifier;

    uint256 userPrivateKey;
    uint256 signerPk;

    address user;
    address signer;

    function setUp() public {
        verifier = new MockVerifyingContract(keccak256("TEST_DOMAIN"));
        bytes32 domainSeparator = verifier.DOMAIN_SEPARATOR();

        userPrivateKey = 0xabc123;
        signerPk = 0x123abc;

        user = vm.addr(userPrivateKey);
        signer = vm.addr(signerPk);

        _initOrderHelper(domainSeparator, makeAddr("dummy_collection"), makeAddr("dummy_currency"));
    }

    /*//////////////////////////////////////////////////////////////
                                SUCCESS
    //////////////////////////////////////////////////////////////*/

    function test_verify_valid_signature_succeeds() public {
        (OrderModel.Order memory order, SigOps.Signature memory sig) = makeSignedAsk(signer, signerPk);

        vm.prank(user);
        verifier.verify(order, sig);
    }

    /*//////////////////////////////////////////////////////////////
                                REVERTS
    //////////////////////////////////////////////////////////////*/

    function test_verify_mutated_order_reverts() public {
        (OrderModel.Order memory order, SigOps.Signature memory sig) = makeSignedAsk(signer, signerPk);

        // mutate ANY field (pick one, doesn't matter)
        order.price += 1;

        vm.expectRevert(SigOps.InvalidSignature.selector);
        verifier.verify(order, sig);
    }

    function test_verify_corrupted_s_reverts() public {
        (OrderModel.Order memory order, SigOps.Signature memory sig) = makeSignedAsk(signer, signerPk);

        // simulate corrupt s <= n/2 https://eips.ethereum.org/EIPS/eip-2
        sig.s = bytes32(uint256(0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A0) + 1);

        vm.prank(user);
        vm.expectRevert(SigOps.InvalidSParameter.selector);
        verifier.verify(order, sig);
    }

    function test_verify_corrupted_v_reverts() public {
        (OrderModel.Order memory order, SigOps.Signature memory sig) = makeSignedAsk(signer, signerPk);

        assertTrue(sig.v == 27 || sig.v == 28);

        sig.v = 29;

        vm.prank(user);
        vm.expectRevert(SigOps.InvalidYParity.selector);
        verifier.verify(order, sig);
    }

    function test_verify_wrong_signer_reverts() public {
        (OrderModel.Order memory order, SigOps.Signature memory sig) = makeSignedAsk(signer, signerPk);

        order.actor = makeAddr("imposter");

        vm.expectRevert(SigOps.InvalidSignature.selector);
        verifier.verify(order, sig);
    }
}
