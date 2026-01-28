// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {IERC1271} from "@openzeppelin/interfaces/IERC1271.sol";

library SignatureOps {
    // ===== ERRORS =====
    error InvalidYParity();
    error InvalidSParameter();
    error InvalidSignature();

    // ===== SIG OBJ & METHODS =====

    struct Signature {
        uint8 v; // Y-parity - 27 or 28 always
        bytes32 r;
        bytes32 s;
    }

    /**
     * @dev Simply a structural / semantic helper
     */
    function vrs(Signature calldata sig) internal pure returns (uint8, bytes32, bytes32) {
        return (sig.v, sig.r, sig.s);
    }

    // ===== SIG VERIFICATION =====

    function recover(bytes32 hash, uint8 v, bytes32 r, bytes32 s) internal pure returns (address) {
        return ecrecover(hash, v, r, s);
    }

    function verify(bytes32 domainSeparator, bytes32 msgHash, address expectedSigner, uint8 v, bytes32 r, bytes32 s)
        internal
        view
    {
        // Check v (Y-parity)
        if (v != 27 && v != 28) revert InvalidYParity();

        // Check s <= n/2 https://eips.ethereum.org/EIPS/eip-2
        if (uint256(s) > 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A0) {
            revert InvalidSParameter();
        }

        // Build digest
        bytes32 digest = digest712(domainSeparator, msgHash);

        if ((expectedSigner.code.length > 0)) {
            // TODO: add tests for eip-712 settlements
            bytes4 result = IERC1271(expectedSigner).isValidSignature(digest, abi.encodePacked(r, s, v));

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

    function digest712(bytes32 domain, bytes32 msgHash) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked("\x19\x01", domain, msgHash));
    }
}
