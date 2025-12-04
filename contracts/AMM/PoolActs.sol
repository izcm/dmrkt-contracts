// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.30;

library PoolActs {
    enum Side {
        Ask,
        Bid
    }

    struct Intent {
        address actor;
        Side side;
        uint64 start;
        uint64 end;
        uint256 nonce;
        bytes constraints;
    }

    struct Call {
        address actor;
    }

    bytes32 internal constant INTENT_HASH = keccak256("todo");

    /*
    function hash(Intent memory intent) internal pure returns (bytes32) {
        return keccak256(
            abi.encode(
                INTENT_HASH,
                intent.actor,
                intent.side,
                intent.start,
                intent.end,
                intent.nonce,
                keccak256(intent.constraints)
            )
        );
    }
    */
}
