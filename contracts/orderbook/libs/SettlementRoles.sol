// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {OrderModel} from "./OrderModel.sol";

library SettlementRoles {
    using OrderModel for OrderModel.Order;

    error InvalidOrderSide();

    /**
     * @notice Derives settlement roles from an order/fill pair.
     * @dev Ask: the order creator holds the NFT and the fill actor is the buyer.
     *      The token ID is always taken from the order.
     *
     *      Bid: the fill actor supplies the NFT and the order creator is the buyer.
     *      Token ID selection depends on `isCollectionBid`:
     *        - collection bid  → any token in the collection is accepted; ID comes from the fill.
     *        - specific bid    → the fill's tokenId is ignored; ID comes from the order.
     * @param f The fill submitted against the order.
     * @param o The standing order being settled.
     * @return nftHolder Address currently holding the NFT to be transferred.
     * @return spender   Address that will pay for the NFT.
     * @return tokenId   Token ID to settle on.
     */
    function resolve(OrderModel.Fill memory f, OrderModel.Order memory o)
        internal
        pure
        returns (address nftHolder, address spender, uint256 tokenId)
    {
        if (o.isAsk()) {
            return (o.actor, f.actor, o.tokenId);
        } else if (o.isBid()) {
            return (f.actor, o.actor, o.isCollectionBid ? f.tokenId : o.tokenId);
        }

        revert InvalidOrderSide();
    }
}
