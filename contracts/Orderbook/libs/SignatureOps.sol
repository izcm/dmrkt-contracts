// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.30;

library SignatureOps {
    // --------------
    // ERRORS
    // --------------
    error InvalidYParity();
    error InvalidSParameter();
    error InvalidSignature();
    error ContractSignerUnsupported();

    // --------------
    // OBJ & METHODS
    // --------------
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

    // --------------
    // VERIFICATION
    // --------------
    function recover(bytes32 hash, uint8 v, bytes32 r, bytes32 s) internal pure returns (address) {
        return ecrecover(hash, v, r, s);
    }

    function verify(bytes32 domainSeparator, bytes32 msgHash, address signer, uint8 v, bytes32 r, bytes32 s)
        internal
        view
    {
        // TODO EIP-1271 not supported yet
        if (signer.code.length > 0) revert ContractSignerUnsupported();

        // Check v (Y-parity)
        if (v != 27 && v != 28) revert InvalidYParity();

        // Check s <= n/2 https://eips.ethereum.org/EIPS/eip-2
        if (uint256(s) > 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A0) {
            revert InvalidSParameter();
        }

        // Build digest
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", domainSeparator, msgHash));

        // Recover signer
        address recovered = recover(digest, v, r, s);
        if (recovered == address(0) || recovered != signer) revert InvalidSignature();
    }
}
