// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script} from "forge-std/Script.sol";

// core libs
import {OrderModel} from "orderbook/libs/OrderModel.sol";

// periphery libs
import {MarketSim} from "periphery/MarketSim.sol";

// interfaces
import {IERC721} from "@openzeppelin/interfaces/IERC721.sol";
import {ISettlementEngine} from "periphery/interfaces/ISettlementEngine.sol";
import {DNFT} from "periphery/interfaces/DNFT.sol";

abstract contract OrderSampling is Script {
    address private weth;
    address private settlementContract;

    // any child contract must call this method
    function _initOrderSampling(
        address _settlementContract,
        address _weth
    ) internal {
        settlementContract = _settlementContract;
        weth = _weth;
    }

    function hydrateAndSelectTokens(
        uint256 epoch,
        OrderModel.Side side,
        bool isCollectionBid,
        address collection
    ) internal view returns (uint256[] memory) {
        uint256 max = DNFT(collection).totalSupply();

        uint256 seed = _orderSalt(collection, side, isCollectionBid, epoch);

        // Safe: uint8(seed) % 6 ∈ [0..5], +2 ⇒ [2..7]
        // forge-lint: disable-next-line(unsafe-typecast)
        uint8 density = (uint8(seed) % 6) + 2;

        return MarketSim.selectTokens(collection, max, density, seed);
    }

    function makeOrder(
        OrderModel.Side side,
        bool isCollectionBid,
        address collection,
        uint256 tokenId
    ) internal view returns (OrderModel.Order memory) {
        address owner = IERC721(collection).ownerOf(tokenId);

        uint256 j = 0;

        uint256 seed = uint256(
            keccak256(abi.encode(collection, tokenId, side, isCollectionBid, j))
        );

        while (
            ISettlementEngine(settlementContract).isUserOrderNonceInvalid(
                owner,
                _nonce(seed, j)
            )
        ) {
            j++;
        }

        return
            OrderModel.Order({
                side: side,
                isCollectionBid: isCollectionBid,
                collection: collection,
                tokenId: tokenId,
                currency: weth,
                price: MarketSim.priceOf(collection, tokenId, seed),
                actor: owner,
                start: uint64(block.timestamp),
                end: uint64(block.timestamp + 7 days),
                nonce: _nonce(seed, j)
            });
    }

    // === PRIVATE FUNCTIONS ===

    function _nonce(
        uint256 seed,
        uint256 attempt
    ) private pure returns (uint256) {
        return uint256(keccak256(abi.encode(seed, attempt)));
    }

    function _orderSalt(
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
}
