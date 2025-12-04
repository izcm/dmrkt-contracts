// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.30;

// Explicit namespace imports to avoid any ambiguity in maintenance / audits
import "./libs/OrderActs.sol";
import {SignatureOps as SigOps} from "./libs/SignatureOps.sol";

contract OrderEngine {
    using OrderActs for OrderActs.Order;
    using SigOps for SigOps.Signature;

    bytes32 public immutable DOMAIN_SEPERATOR;
    mapping(address => mapping(uint256 => bool)) private _isUserOrderNonceValid;

    constructor() {
        // load to memory => compute hash
        DOMAIN_SEPERATOR = keccak256(
            abi.encode(
                // EIP-712 domain type hash
                0x8b73c3c69bb8fe3d512ecc4cf759cc79239f7b179b0ffacaa9a75d522b39400f,
                // nameHash
                0x997dc85543e54e3a10f066eed263ff8d0cbf9f87e862f32fce17b110cadc23f2, // "dmrkt"
                // versionHash
                0x044852b2a670ade5407e78fb2863c51de9fcb96542a07186fe3aeda6bb8a116d, // "0"
                // static types => fed directly
                block.chainid,
                address(this)
            )
        );
    }

    /// Matches a `Fill` request to an existing `Order`
    // TODO: add nonreentrant
    function settle(OrderActs.Fill calldata fill, OrderActs.Order calldata order, SigOps.Signature calldata sig)
        external
    {
        // Verify
        (uint8 v, bytes32 r, bytes32 s) = sig.vrs();
        _verifyOrder(order, v, r, s);
    }

    // --------------
    // INTERNAL
    // --------------

    /**
     * @notice Verify order is valid
     */
    function _verifyOrder(OrderActs.Order calldata order, uint8 v, bytes32 r, bytes32 s) internal {
        // Require:
        // 1. Order nonce is valid
        // 2. Signer != addr(0)

        // Verify signature
        //(uint8 v, bytes32 r, bytes32 s) = SigOps.vrs(sig);
        SigOps.verify(DOMAIN_SEPERATOR, order.hash(), order.actor, v, r, s);
    }
}
