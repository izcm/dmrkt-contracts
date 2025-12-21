// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "orderbook/libs/OrderActs.sol";

library OrderFactory {
    function ask(
        address actor,
        address collection,
        address currency,
        uint256 tokenId,
        uint256 price,
        uint256 nonce,
        uint64 start,
        uint64 end
    ) internal pure returns (OrderActs.Order memory) {
        return
            OrderActs.Order({
                side: OrderActs.Side.Ask,
                actor: actor,
                isCollectionBid: false,
                collection: collection,
                currency: currency,
                tokenId: tokenId,
                price: price,
                start: start,
                end: end,
                nonce: nonce
            });
    }

    function simpleAsk(
        address actor,
        address collection,
        address currency,
        uint256 tokenId,
        uint256 price,
        uint256 nonce
    ) internal view returns (OrderActs.Order memory) {
        return
            ask(
                actor,
                collection,
                currency,
                tokenId,
                price,
                nonce,
                0,
                uint64(block.timestamp + 7 days)
            );
    }
}
