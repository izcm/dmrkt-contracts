// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

// core libraries
import {OrderModel} from "orderbook/libs/OrderModel.sol";

// interfaces
import {DNFT} from "dev/interfaces/DNFT.sol";

/**
 * @notice Resolves the fill recipient for bid orders. Handles both regular bids
 *         (fixed tokenId, look up current owner) and collection bids (find any eligible token).
 * @dev    Collection bid feature is currently paused.
 */
abstract contract FillBid {
    /**
     * @notice Routes to the correct fill strategy based on whether the bid is a collection bid.
     * @param bid         The bid order to fill.
     * @param excludedCb  Token IDs excluded from collection bid fills — typically tokens already
     *                    assigned to other orders in this epoch.
     */
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

    /**
     * @dev For a regular bid the tokenId is fixed — just resolve the current owner as the filler.
     */
    function _fillRegularBid(address collection, uint256 tokenId) internal view returns (OrderModel.Fill memory) {
        return OrderModel.Fill({tokenId: tokenId, actor: DNFT(collection).ownerOf(tokenId)});
    }

    /**
     * @dev For a collection bid, finds an eligible token starting at `seed % supply` and walking
     *      forward until a token is found whose owner is not the bidder and is not excluded.
     * @param collection   NFT collection address.
     * @param orderActor   The bidder — their own tokens are skipped.
     * @param seed         Used to derive the starting token ID.
     * @param excluded     Token IDs already committed to other orders in this epoch.
     */
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
