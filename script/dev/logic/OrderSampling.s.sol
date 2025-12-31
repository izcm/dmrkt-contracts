// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script} from "forge-std/Script.sol";

// core libs
import {OrderModel} from "orderbook/libs/OrderModel.sol";

// periphery libs
import {MarketSim} from "periphery/MarketSim.sol";

// interfaces
import {DNFT} from "periphery/interfaces/DNFT.sol";

// types
import {Selection} from "dev/state/Types.sol";

abstract contract OrderSampling is Script {
    function collect(
        OrderModel.Side side,
        bool isCollectionBid,
        address[] memory collections,
        uint256 epoch
    ) internal view returns (Selection[] memory selections) {
        selections = new Selection[](collections.length);

        for (uint256 i = 0; i < collections.length; i++) {
            address collection = collections[i];

            uint256[] memory tokens = _hydrateAndSelectTokens(
                side,
                isCollectionBid,
                collection,
                DNFT(collection).totalSupply(),
                epoch
            );

            selections[i] = Selection({
                collection: collection,
                tokenIds: tokens
            });
        }
    }

    function orderSalt(
        OrderModel.Side side,
        bool isCollectionBid,
        address collection,
        uint256 mixIn
    ) internal pure returns (uint256) {
        return
            uint256(
                keccak256(abi.encode(collection, side, isCollectionBid, mixIn))
            );
    }

    function orderPrice(
        address collection,
        uint256 tokenId,
        uint256 seed
    ) internal pure returns (uint256) {
        return MarketSim.priceOf(collection, tokenId, seed);
    }

    // eg. use orderSalt() to compute seed
    function orderNonce(
        uint256 seed,
        uint256 mixIn
    ) internal pure returns (uint256) {
        return uint256(keccak256(abi.encode(seed, mixIn)));
    }

    function _hydrateAndSelectTokens(
        OrderModel.Side side,
        bool isCollectionBid,
        address collection,
        uint256 scanLimit,
        uint256 mixIn
    ) internal pure returns (uint256[] memory) {
        uint256 seed = orderSalt(side, isCollectionBid, collection, mixIn);
        // Safe: uint8(seed) % 6 ∈ [0..5], +2 ⇒ [2..7]
        // forge-lint: disable-next-line(unsafe-typecast)
        uint8 density = (uint8(seed) % 6) + 2;

        return MarketSim.selectTokens(collection, scanLimit, density, seed);
    }
}
