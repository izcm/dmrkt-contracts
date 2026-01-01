// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

// oz
import {IERC721} from "@openzeppelin/interfaces/IERC721.sol";

// core libs
import {OrderModel} from "orderbook/libs/OrderModel.sol";

abstract contract SettlementValidation {
    using OrderModel for OrderModel.Order;

    function validTimestamps(
        OrderModel.Order memory o
    ) internal view returns (bool) {
        uint64 blockTs = uint64(block.timestamp);

        bool validStart = o.start <= blockTs;
        bool validEnd = o.end >= blockTs;

        return (validStart && validEnd);
    }

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
                return IERC721(o.collection).ownerOf(o.tokenId) == f.actor;
            } else {
                // order is regular bid => fill.actor must be owner of order.tokenId
                return IERC721(o.collection).ownerOf(f.tokenId) == f.actor;
            }
        }
    }
}
