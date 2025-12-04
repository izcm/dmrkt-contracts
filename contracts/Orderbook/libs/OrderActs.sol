// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.30;

library OrderActs {
    enum Side {
        Ask,
        Bid
    }

    /// For clarity, `Signature` is a struct seperate from `Order`
    /*
        Off-chain mongo-db document will be in denormalized form:
        {
        "_id": "<orderId>",
        "order": {
            "side": "ask",
            "actor": "0x1234",
            "collection": "0xNFT",
            "tokenId": 1337,
            "price": "420000000000000000",
            "start": 12345,
            "end": 20000,
            "nonce": 69
        },
        "signature": {
            "r": "0xabc...",
            "s": "0xdef...",
            "v": 27
            }
        }
    */
    /// Maket's Intent
    struct Order {
        Side side;
        address actor;
        address collection;
        uint256 tokenId;
        uint256 price;
        uint64 start;
        uint64 end;
        uint256 nonce;
        // bytes constraints; remember to keccak dynamic values in an inner keccak256 when hashing
    }

    /// Taker's action to fulfill an `Order` whether that be:
    /// 1. Selling an NFT if order is `bid`
    /// 2. Buying an NFT if order is `ask`
    struct Fill {
        address actor;
    }

    // https://eips.ethereum.org/EIPS/eip-712#definition-of-hashstruct:
    // hashStruct(s : 𝕊) = keccak256(typeHash ‖ encodeData(s)) where typeHash = keccak256(encodeType(typeOf(s)))
    bytes32 constant ORDER_TYPE_HASH = keccak256("dmrkt.order.v.1.0"); // temporary until `Order` fields are decided

    // ❗ TODO: implement this in assembly and test gas savings
    function hash(Order memory o) internal pure returns (bytes32) {
        return keccak256(abi.encode(ORDER_TYPE_HASH, o.actor, o.price, o.side, o.start, o.end, o.nonce));
    }
}

