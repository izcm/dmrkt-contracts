// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

// oz
import {IERC721} from "@openzeppelin/interfaces/IERC721.sol";

// core libs
import {OrderModel} from "orderbook/libs/OrderModel.sol";

/**
 * @notice Pre-settlement checks run by ExecuteOrder before calling settle().
 *         Guards against settling orders that have expired or whose NFT ownership has shifted.
 */
abstract contract SettlementValidation {
    using OrderModel for OrderModel.Order;

    /**
     * @notice Returns true if the current block timestamp falls within the order's validity window.
     */
    function validTimestamps(
        OrderModel.Order memory o
    ) internal view returns (bool) {
        uint64 blockTs = uint64(block.timestamp);

        bool validStart = o.start <= blockTs;
        bool validEnd = o.end >= blockTs;

        return (validStart && validEnd);
    }

    /**
     * @notice Returns true if the expected NFT owner matches for the given order side.
     * @dev    Three cases:
     *         - Ask:             order.actor must own order.tokenId.
     *         - Regular bid:     fill.actor must own order.tokenId.
     *         - Collection bid:  fill.actor must own fill.tokenId.
     */
    function validNftOwnership(
        OrderModel.Fill memory f,
        OrderModel.Order memory o
    ) internal view returns (bool) {
        if (o.isAsk()) {
            // order is ask => order.actor must be o.tokenId owner
            return IERC721(o.collection).ownerOf(o.tokenId) == o.actor;
        } else {
            if (o.isCollectionBid) {
                // order is collection bid => fill.actor must be owner of fill.tokenId
                return IERC721(o.collection).ownerOf(f.tokenId) == f.actor;
            } else {
                // order is regular bid => fill.actor must be owner of order.tokenId
                return IERC721(o.collection).ownerOf(o.tokenId) == f.actor;
            }
        }
    }
}
