// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "orderbook/libs/OrderActs.sol";

library FillFactory {
    uint256 internal constant DEFAULT_TOKEN_ID = 0;

    function make(address actor) internal pure returns (OrderActs.Fill memory) {
        return OrderActs.Fill({actor: actor, tokenId: DEFAULT_TOKEN_ID});
    }

    function make(
        address actor,
        uint256 tokenId
    ) internal pure returns (OrderActs.Fill memory) {
        return OrderActs.Fill({actor: actor, tokenId: tokenId});
    }
}
