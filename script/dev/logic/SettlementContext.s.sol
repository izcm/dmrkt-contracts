// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script} from "forge-std/Script.sol";

// core libraries
import {OrderModel} from "orderbook/libs/OrderModel.sol";

// interfaces
import {IERC721} from "@openzeppelin/interfaces/IERC721.sol";
import {ISettlementEngine} from "periphery/interfaces/ISettlementEngine.sol";

import {OrderBuilder} from "periphery/builders/OrderBuilder.sol";

abstract contract SettlementContext is Script {
    function makeOrder(
        OrderModel.Side side,
        bool isCollectionBid,
        address collection,
        uint256 tokenId,
        address currency,
        uint256 price,
        address settlementContract
    ) internal view returns (OrderModel.Order memory) {
        address owner = IERC721(collection).ownerOf(tokenId);

        uint256 j = 0;

        uint256 seed = uint256(
            keccak256(abi.encode(collection, owner, side, isCollectionBid, j))
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
            OrderBuilder.build(
                side,
                isCollectionBid,
                collection,
                tokenId,
                currency,
                price,
                owner,
                uint64(block.timestamp),
                uint64(block.timestamp + 7 days),
                _nonce(seed, j)
            );
    }

    function orderSalt(
        address collection,
        OrderModel.Side side,
        bool isCollectionBid,
        uint256 epoch
    ) internal pure returns (uint256) {
        return
            uint256(
                keccak256(abi.encode(collection, side, isCollectionBid, epoch))
            );
    }

    // === PRIVATE FUNCTIONS ===

    function _nonce(
        uint256 seed,
        uint256 attempt
    ) private pure returns (uint256) {
        return uint256(keccak256(abi.encode(seed, attempt)));
    }
}
