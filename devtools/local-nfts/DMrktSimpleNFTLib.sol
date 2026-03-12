// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/utils/Base64.sol";

import {DMrktMathConfig} from "./DMrktMathConfig.sol";

/**
 * @title DMrktSimpleNFTLib
 * @dev Lightweight metadata + color library for non-inventory NFTs.
 */
library DMrktSimpleNFTLib {
    function getRarity(uint256 tokenId) internal pure returns (string memory) {
        if (tokenId % DMrktMathConfig.rarityLegendaryMod() == 0)
            return "Legendary";
        if (tokenId % DMrktMathConfig.rarityEpicMod() == 0) return "Epic";
        if (tokenId % DMrktMathConfig.rarityRareMod() == 0) return "Rare";
        return "Common";
    }

    function getColorForToken(
        uint256 tokenId
    ) internal pure returns (string memory) {
        uint256 c = tokenId % DMrktMathConfig.colorPaletteSize();

        if (c == 0) return "#7c5cff"; // Protocol Purple
        if (c == 1) return "#ff2bd6"; // Neon Pink
        if (c == 2) return "#39ff14"; // Neon Green
        if (c == 3) return "#00eaff"; // Cyber Blue
        if (c == 4) return "#ff7a00"; // Lava Orange
        if (c == 5) return "#ffd500"; // Solar Gold
        if (c == 6) return "#ff3b3b"; // Blood Red
        if (c == 7) return "#00ffcc"; // Aqua Mint
        if (c == 8) return "#9b5cff"; // Arcane Violet
        if (c == 9) return "#c4ff00"; // Toxic Lime
        if (c == 10) return "#ff00ff"; // Magenta
        return "#ffffff"; // Mythic White
    }

    function getColorName(
        uint256 tokenId
    ) internal pure returns (string memory) {
        uint256 c = tokenId % DMrktMathConfig.colorPaletteSize();

        if (c == 0) return "Protocol Purple";
        if (c == 1) return "Neon Pink";
        if (c == 2) return "Neon Green";
        if (c == 3) return "Cyber Blue";
        if (c == 4) return "Lava Orange";
        if (c == 5) return "Solar Gold";
        if (c == 6) return "Blood Red";
        if (c == 7) return "Aqua Mint";
        if (c == 8) return "Arcane Violet";
        if (c == 9) return "Toxic Lime";
        if (c == 10) return "Magenta";
        return "Mythic White";
    }

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
                    buildTrait("Rarity", getRarity(tokenId)),
                    ",",
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
