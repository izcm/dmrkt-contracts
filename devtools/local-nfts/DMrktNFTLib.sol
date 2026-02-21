// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/utils/Base64.sol";
import "@openzeppelin/utils/Strings.sol";

/**
 * @title DMrktNFTLib
 * @dev Shared library for dmrkt NFT contracts
 */
library DMrktNFTLib {
    // ----------------------------
    // COLOR LOGIC
    // ----------------------------

    function getColorForToken(
        uint256 tokenId
    ) internal pure returns (string memory) {
        if (tokenId % 10 == 0) {
            return "#FFFF00"; // bright yellow
        } else if (tokenId % 7 == 0) {
            return "#39FF14"; // neon green
        } else if (tokenId % 3 == 0) {
            return "#FF00FF"; // magenta
        } else {
            return "#7c5cff"; // purple
        }
    }

    function getColorName(
        uint256 tokenId
    ) internal pure returns (string memory) {
        if (tokenId % 10 == 0) return "Solar Yellow";
        if (tokenId % 7 == 0) return "Neon Green";
        if (tokenId % 3 == 0) return "Magenta";
        return "Protocol Purple";
    }

    // ----------------------------
    // METADATA BUILDING
    // ----------------------------

    function buildTrait(
        string memory traitType,
        string memory value
    ) internal pure returns (string memory) {
        return
            string(
                abi.encodePacked(
                    '{"trait_type":"',
                    traitType,
                    '","value":"',
                    value,
                    '"}'
                )
            );
    }

    function buildAttributes(
        uint256 tokenId
    ) internal pure returns (string memory) {
        return
            string(
                abi.encodePacked(
                    '"attributes":[',
                    buildTrait("Color", getColorName(tokenId)),
                    "]"
                )
            );
    }

    function buildMetadata(
        string memory name,
        string memory description,
        uint256 tokenId,
        string memory svgBase64
    ) internal pure returns (string memory) {
        return
            Base64.encode(
                bytes(
                    string(
                        abi.encodePacked(
                            '{"name":"',
                            name,
                            '","description":"',
                            description,
                            '",',
                            buildAttributes(tokenId),
                            ',"image":"data:image/svg+xml;base64,',
                            svgBase64,
                            '"}'
                        )
                    )
                )
            );
    }
}
