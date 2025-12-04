// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.30;

library SignatureOps {
    // TODO read:
    // https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/cryptography/SignatureChecker.sol

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

    function recover() internal pure returns (address) {}

    function verify(bytes32 domainSeperator, bytes32 msgHash, address signer, uint8 v, bytes32 r, bytes32 s)
        internal
        view
        returns (bool)
    {
        // Recreate digest
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01", // version bytes eip-191 & eip-714
                domainSeperator,
                msgHash
            )
        );

        bool isContract = signer.code.length > 0;

        // will implement eip-1271 compliance later in dev
        if (isContract) {
            revert("Market not EIP-1271 compliant"); // TMP!
        }
    }
}
