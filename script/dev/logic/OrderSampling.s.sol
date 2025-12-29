// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script} from "forge-std/Script.sol";

// core libs
import {OrderModel} from "orderbook/libs/OrderModel.sol";

// periphery libs
import {MarketSim} from "periphery/MarketSim.sol";

// interfaces
import {IERC721} from "@openzeppelin/interfaces/IERC721.sol";

import {DNFT} from "periphery/interfaces/DNFT.sol";
import {ISettlementEngine} from "periphery/interfaces/ISettlementEngine.sol";

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

    // TODO: this only works with `asks` since `owner` is always order.actor
    function makeOrder(
        OrderModel.Side side,
        bool isCollectionBid,
        address collection,
        uint256 tokenId,
        address currency,
        address settlementContract
    ) internal view returns (OrderModel.Order memory order) {
        address owner = IERC721(collection).ownerOf(tokenId);

        uint256 nonceIdx = 0;

        uint256 seed = uint256(
            orderSalt(collection, side, isCollectionBid, nonceIdx)
        );

        while (
            ISettlementEngine(settlementContract).isUserOrderNonceInvalid(
                owner,
                _nonce(seed, nonceIdx)
            )
        ) {
            nonceIdx++;
        }

        order = OrderModel.Order({
            side: side,
            isCollectionBid: isCollectionBid,
            collection: collection,
            tokenId: tokenId,
            currency: currency,
            price: MarketSim.priceOf(collection, tokenId, seed),
            actor: owner,
            start: uint64(block.timestamp),
            end: uint64(block.timestamp + 7 days),
            nonce: _nonce(seed, nonceIdx)
        });
    }

    function orderSalt(
        address collection,
        OrderModel.Side side,
        bool isCollectionBid,
        uint256 saltSeed
    ) internal pure returns (uint256) {
        return
            uint256(
                keccak256(
                    abi.encode(collection, side, isCollectionBid, saltSeed)
                )
            );
    }

    function _hydrateAndSelectTokens(
        OrderModel.Side side,
        bool isCollectionBid,
        address collection,
        uint256 scanLimit,
        uint256 seedSalt
    ) internal pure returns (uint256[] memory) {
        uint256 seed = orderSalt(collection, side, isCollectionBid, seedSalt);
        // Safe: uint8(seed) % 6 ∈ [0..5], +2 ⇒ [2..7]
        // forge-lint: disable-next-line(unsafe-typecast)
        uint8 density = (uint8(seed) % 6) + 2;

        return MarketSim.selectTokens(collection, scanLimit, density, seed);
    }

    // === PRIVATE FUNCTIONS ===

    function _nonce(
        uint256 seed,
        uint256 attempt
    ) private pure returns (uint256) {
        return uint256(keccak256(abi.encode(seed, attempt)));
    }
}
