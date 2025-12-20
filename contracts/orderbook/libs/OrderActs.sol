// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

library OrderActs {
    enum Side {
        Ask, // 0
        Bid, // 1
        _COUNT
    }

    /// Maker's Intent
    struct Order {
        Side side;
        bool isCollectionBid; // if side = bid and order is for any item in collection
        address collection;
        uint256 tokenId; // specific token for bid / ask, ignored if isCollectionBid = true
        address currency;
        uint256 price;
        address actor;
        uint64 start;
        uint64 end;
        uint256 nonce;
    }

    function isAsk(Order memory o) internal pure returns (bool) {
        return o.side == Side.Ask;
    }

    function isBid(Order memory o) internal pure returns (bool) {
        return o.side == Side.Bid;
    }

    // bytes constraints; remember to keccak dynamic values in an inner keccak256 when hashing

    /// Taker's action to fulfill an `Order` whether that be:
    /// 1. Selling an NFT if order is `bid`
    /// 2. Buying an NFT if order is `ask`
    struct Fill {
        uint256 tokenId; // used only when order.isCollectionBid = true
        address actor; // must be msg.sender
    }

    // https://eips.ethereum.org/EIPS/eip-712#definition-of-hashstruct:
    // hashStruct(s : 𝕊) = keccak256(typeHash ‖ encodeData(s)) where typeHash = keccak256(encodeType(typeOf(s)))
    bytes32 constant ORDER_TYPE_HASH = keccak256("dmrkt.order.v.1.0"); // temporary until `Order` fields are decided

    // TODO: implement this in assembly and test gas savings
    function hash(Order memory o) internal pure returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    ORDER_TYPE_HASH,
                    o.side,
                    o.isCollectionBid,
                    o.collection,
                    o.tokenId,
                    o.currency,
                    o.price,
                    o.actor,
                    o.start,
                    o.end,
                    o.nonce
                )
            );
    }
}
