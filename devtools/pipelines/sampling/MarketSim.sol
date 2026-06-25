// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import { Script } from "forge-std/Script.sol";

// core libs
import { OrderModel } from "orderbook/libs/OrderModel.sol";

// interfaces
import { DNFT } from "dev/interfaces/DNFT.sol";

// types
import { Selection } from "../epochs/Types.sol";

/**
 * @notice Abstract base for order sampling and price generation. Selects a pseudo-random but
 *         deterministic subset of token IDs from each collection and assigns prices to them.
 * @dev    Determinism comes from mixing collection address, side, and other inputs into a hash —
 *         same inputs always produce the same selection.
 */
abstract contract MarketSim is Script {
    /**
     * @notice For each collection, selects a subset of token IDs to generate orders for.
     * @param side             Order side (bid or ask).
     * @param isCollectionBid  Whether the order is a collection-level bid (paused feature).
     * @param collections      Collection addresses to sample from.
     * @param mixIn            Mixed into the selection hash so different values produce different tokens.
     * @return selections      One Selection per collection, each containing the sampled token IDs.
     */
    function collect(
        OrderModel.Side side,
        bool isCollectionBid,
        address[] memory collections,
        uint256 mixIn
    ) internal view returns (Selection[] memory selections) {
        selections = new Selection[](collections.length);

        for (uint256 i = 0; i < collections.length; i++) {
            address collection = collections[i];

            uint256[] memory tokens = _selectTokens(
                side,
                isCollectionBid,
                collection,
                DNFT(collection).totalSupply(),
                mixIn
            );

            selections[i] = Selection({ collection: collection, tokenIds: tokens });
        }
    }

    /**
     * @notice Derives a deterministic seed for token selection from the given inputs.
     * @param side             Order side.
     * @param isCollectionBid  Collection bid flag.
     * @param collection       NFT collection address.
     * @param mixIn            Extra entropy — typically the epoch index.
     */
    function selectionSalt(
        OrderModel.Side side,
        bool isCollectionBid,
        address collection,
        uint256 mixIn
    ) internal pure returns (uint256) {
        return uint256(keccak256(abi.encode(collection, side, isCollectionBid, mixIn)));
    }

    /**
     * @notice Returns a deterministic price for a token in one of 11 buckets: 0.05 ETH to 0.55 ETH.
     *         Virtual — override to provide collection-aware pricing (e.g. rarity-based).
     * @param mixIn  Extra entropy mixed into the price hash — typically the selection salt.
     */
    function orderPrice(
        address collection,
        uint256 tokenId,
        uint256 mixIn
    ) internal pure virtual returns (uint256) {
        bytes32 h = keccak256(abi.encode("DMRKT_PRICE_V1", collection, mixIn, tokenId));
        uint256 bucket = uint256(h) % 11;
        return (bucket + 1) * 0.05 ether;
    }

    /**
     * @dev Derives a gap from the mixIn in range [25, 30], then scans token IDs 0..scanLimit
     *      including each with probability 1/gap. Returns roughly scanLimit/gap token IDs.
     *      Bigger gap = fewer tokens selected.
     */
    function _selectTokens(
        OrderModel.Side side,
        bool isCollectionBid,
        address collection,
        uint256 scanLimit,
        uint256 mixIn
    ) internal pure returns (uint256[] memory) {
        uint256 seed = selectionSalt(side, isCollectionBid, collection, mixIn);
        // forge-lint: disable-next-line(unsafe-typecast)
        uint8 gap = (uint8(seed) % 6) + 25; // pick 1 every 25..30 tokens

        uint256 count = 0;
        uint256 targetCount = scanLimit / gap;
        uint256[] memory ids = new uint256[](targetCount);

        for (uint256 i = 0; i < scanLimit && count < targetCount; i++) {
            bytes32 h = keccak256(abi.encode(collection, seed, i));
            if (uint256(h) % gap == 0) {
                ids[count++] = i;
            }
        }

        assembly {
            mstore(ids, count)
        }

        return ids;
    }
}
