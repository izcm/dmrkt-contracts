// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {IERC1271} from "@openzeppelin/interfaces/IERC1271.sol";

library SignatureOps {
    error InvalidYParity();
    error InvalidSParameter();
    error InvalidSignature();

    struct Signature {
        uint8 v; // Y-parity - 27 or 28 always
        bytes32 r;
        bytes32 s;
    }

    /// @dev Semantic helper. Unpacks a Signature into its (v, r, s) components.
    function vrs(
        Signature calldata sig
    ) internal pure returns (uint8, bytes32, bytes32) {
        return (sig.v, sig.r, sig.s);
    }

    /// @notice Recovers signer from digest and signature
    function recover(
        bytes32 hash,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) internal pure returns (address) {
        return ecrecover(hash, v, r, s);
    }

    /**
     * @notice Verifies an EIP-712 signature against an expected signer
     * @dev Supports EOA signatures via ecrecover and contract signatures via EIP-1271.
     *      Reverts on any verification failure.
     * @param domainSeparator The EIP-712 domain separator
     * @param msgHash         The EIP-712 struct hash of the message
     * @param expectedSigner  Address that must have produced the signature
     */
    function verify(
        bytes32 domainSeparator,
        bytes32 msgHash,
        address expectedSigner,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) internal view {
        // check v (y-parity)
        if (v != 27 && v != 28) revert InvalidYParity();

        // check s <= n/2 https://eips.ethereum.org/EIPS/eip-2
        if (
            uint256(s) >
            0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A0
        ) {
            revert InvalidSParameter();
        }

        // build digest
        bytes32 digest = digest712(domainSeparator, msgHash);

        if ((expectedSigner.code.length > 0)) {
            // TODO: add tests for eip-1271 settlements
            bytes4 result = IERC1271(expectedSigner).isValidSignature(
                digest,
                abi.encodePacked(r, s, v)
            );

            if (result != IERC1271.isValidSignature.selector) {
                revert InvalidSignature();
            }
        } else {
            address actualSigner = ecrecover(digest, v, r, s);
            if (actualSigner == address(0) || actualSigner != expectedSigner) {
                revert InvalidSignature();
            }
        }
    }

    /**
     * @dev Constructs an EIP-712 typed data digest:
     * keccak256(0x19 0x01 || domainSeparator || hashStruct(message))
     * https://eips.ethereum.org/EIPS/eip-712#specification-of-the-eth_signtypeddata-json-rpc
     */
    function digest712(
        bytes32 domain,
        bytes32 msgHash
    ) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked("\x19\x01", domain, msgHash));
    }
}
