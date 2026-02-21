// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

// core libraries
import {OrderModel} from "orderbook/libs/OrderModel.sol";

// interfaces
import {DNFT} from "periphery/interfaces/DNFT.sol";

abstract contract FillBid {
    function fillBid(OrderModel.Order memory bid, uint256[] memory excludedCb)
        internal
        view
        returns (OrderModel.Fill memory)
    {
        if (bid.isCollectionBid) {
            return _fillCollectionBid(bid.collection, bid.actor, bid.nonce, excludedCb);
        } else {
            return _fillRegularBid(bid.collection, bid.tokenId);
        }
    }

    function _fillRegularBid(address collection, uint256 tokenId) internal view returns (OrderModel.Fill memory) {
        return OrderModel.Fill({tokenId: tokenId, actor: DNFT(collection).ownerOf(tokenId)});
    }

    function _fillCollectionBid(address collection, address orderActor, uint256 seed, uint256[] memory excluded)
        internal
        view
        returns (OrderModel.Fill memory)
    {
        uint256 supply = DNFT(collection).totalSupply();

        uint256 tokenId = seed % supply;
        address nftHolder = DNFT(collection).ownerOf(tokenId);

        while (nftHolder == orderActor || _isExcluded(tokenId, excluded)) {
            tokenId = (tokenId + 1) % supply;
            nftHolder = DNFT(collection).ownerOf(tokenId);
        }

        return OrderModel.Fill({tokenId: tokenId, actor: nftHolder});
    }

    function _isExcluded(uint256 tokenId, uint256[] memory excluded) private pure returns (bool) {
        for (uint256 i = 0; i < excluded.length; i++) {
            if (tokenId == excluded[i]) return true;
        }
        return false;
    }
}
