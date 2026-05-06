// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

library MarketSim {
    function selectTokens(
        address collection,
        uint256 scanLimit,
        uint8 density,
        uint256 seed
    ) internal pure returns (uint256[] memory) {
        uint256 count = 0;
        uint256 targetCount = scanLimit / density;
        uint256[] memory ids = new uint256[](targetCount);

        for (uint256 i = 0; i < scanLimit && count < targetCount; i++) {
            bytes32 h = keccak256(abi.encode(collection, seed, i));
            if (uint256(h) % density == 0) {
                ids[count++] = i;
            }
        }

        assembly {
            mstore(ids, count)
        }

        return ids;
    }

    function priceOf(
        address collection,
        uint256 tokenId,
        uint256 seed
    ) internal pure returns (uint256) {
        bytes32 h = keccak256(
            abi.encode("DMRKT_PRICE_V1", collection, seed, tokenId)
        );

        uint256 bucket = uint256(h) % 11;
        return (bucket + 1) * 0.05 ether;
    }
}
