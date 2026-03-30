// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/utils/Base64.sol";
import "@openzeppelin/utils/Strings.sol";

import {DMrktMathConfig} from "./DMrktMathConfig.sol";

/**
 * @title DMrktNFTLib
 * @dev Shared library for dmrkt NFT contracts
 */

// NOTE: Demo-only contract. Generated with AI and lightly modified.
// NB: Contract is not part of production code nor coupled to the architecture

library DMrktNFTLib {
    // ----------------------------
    // ELEMENT LOGIC
    // ----------------------------

    function getElementForToken(
        uint256 tokenId
    ) internal pure returns (string memory) {
        if (tokenId % DMrktMathConfig.elementThunderMod() == 0) {
            return "Thunder";
        } else if (tokenId % DMrktMathConfig.elementFireMod() == 0) {
            return "Fire";
        } else {
            return "None";
        }
    }

    function getElementName(
        uint256 tokenId
    ) internal pure returns (string memory) {
        if (tokenId % DMrktMathConfig.elementThunderMod() == 0)
            return "Thunder";
        if (tokenId % DMrktMathConfig.elementFireMod() == 0) return "Fire";
        return "None";
    }

    function buildElementOverlay(
        uint256 tokenId
    ) internal pure returns (string memory) {
        if (tokenId % DMrktMathConfig.elementThunderMod() == 0) {
            return
                '<polygon points="250,150 310,150 270,260 330,260 260,380" fill="#fde047"/>';
        }

        if (tokenId % DMrktMathConfig.elementFireMod() == 0) {
            return
                '<polygon points="300,120 270,180 330,180" fill="#f97316"/>'
                '<polygon points="300,150 260,230 340,230" fill="#fb923c"/>';
        }

        return "";
    }

    // ----------------------------
    // COLOR LOGIC
    // ----------------------------

    function getRarity(uint256 tokenId) internal pure returns (string memory) {
        if (tokenId % DMrktMathConfig.rarityLegendaryMod() == 0)
            return "Legendary";
        if (tokenId % DMrktMathConfig.rarityEpicMod() == 0) return "Epic";
        if (tokenId % DMrktMathConfig.rarityRareMod() == 0) return "Rare";
        return "Common";
    }

    function getItemTypeName(
        uint256 itemType
    ) internal pure returns (string memory) {
        if (itemType == DMrktMathConfig.itemTypeSword()) return "Sword";
        if (itemType == DMrktMathConfig.itemTypeElixir()) return "Elixir";
        return "Shield";
    }

    function getDamage(uint256 tokenId) internal pure returns (uint256) {
        uint256 base = DMrktMathConfig.damageBaseMin() +
            (tokenId % DMrktMathConfig.damageBaseModulo());

        if (tokenId % DMrktMathConfig.rarityLegendaryMod() == 0)
            return base + DMrktMathConfig.damageLegendaryBonus();
        if (tokenId % DMrktMathConfig.rarityEpicMod() == 0)
            return base + DMrktMathConfig.damageEpicBonus();
        if (tokenId % DMrktMathConfig.rarityRareMod() == 0)
            return base + DMrktMathConfig.damageRareBonus();

        return base;
    }

    function getDefense(uint256 tokenId) internal pure returns (uint256) {
        uint256 base = DMrktMathConfig.defenseBaseMin() +
            (tokenId % DMrktMathConfig.defenseBaseModulo());

        if (tokenId % DMrktMathConfig.rarityLegendaryMod() == 0)
            return base + DMrktMathConfig.defenseLegendaryBonus();
        if (tokenId % DMrktMathConfig.rarityEpicMod() == 0)
            return base + DMrktMathConfig.defenseEpicBonus();
        if (tokenId % DMrktMathConfig.rarityRareMod() == 0)
            return base + DMrktMathConfig.defenseRareBonus();

        return base;
    }

    function getPower(uint256 tokenId) internal pure returns (uint256) {
        uint256 base = DMrktMathConfig.powerBaseMin() +
            (tokenId % DMrktMathConfig.powerBaseModulo());

        if (tokenId % DMrktMathConfig.rarityLegendaryMod() == 0)
            return base + DMrktMathConfig.powerLegendaryBonus();
        if (tokenId % DMrktMathConfig.rarityEpicMod() == 0)
            return base + DMrktMathConfig.powerEpicBonus();
        if (tokenId % DMrktMathConfig.rarityRareMod() == 0)
            return base + DMrktMathConfig.powerRareBonus();

        return base;
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

    function buildItemName(
        string memory base,
        uint256 tokenId
    ) internal pure returns (string memory) {
        string memory rarity = getRarity(tokenId);
        string memory element = getElementName(tokenId);
        string memory color = getColorName(tokenId);

        if (keccak256(bytes(element)) == keccak256(bytes("None"))) {
            return string.concat(rarity, " ", color, " ", base);
        }

        return string.concat(rarity, " ", color, " ", element, " ", base);
    }

    function buildRarityGlow(
        uint256 tokenId
    ) internal pure returns (string memory) {
        if (tokenId % DMrktMathConfig.rarityLegendaryMod() == 0) {
            return
                '<circle cx="300" cy="300" r="240" fill="#ffd700" opacity="0.15"/>';
        }

        if (tokenId % DMrktMathConfig.rarityEpicMod() == 0) {
            return
                '<circle cx="300" cy="300" r="240" fill="#a855f7" opacity="0.12"/>';
        }

        return "";
    }

    function buildLootAttributes(
        uint256 tokenId,
        uint256 itemType
    ) internal pure returns (string memory) {
        string memory common = string(
            abi.encodePacked(
                buildTrait("Type", getItemTypeName(itemType)),
                ",",
                buildTrait("Rarity", getRarity(tokenId)),
                ",",
                buildTrait("Color", getColorName(tokenId)),
                ",",
                buildTrait("Element", getElementName(tokenId))
            )
        );

        string memory stat;

        if (itemType == DMrktMathConfig.itemTypeSword()) {
            stat = buildTrait("Damage", Strings.toString(getDamage(tokenId)));
        } else if (itemType == DMrktMathConfig.itemTypeShield()) {
            stat = buildTrait("Defense", Strings.toString(getDefense(tokenId)));
        } else {
            stat = buildTrait("Power", Strings.toString(getPower(tokenId)));
        }

        return
            string(abi.encodePacked('"attributes":[', common, ",", stat, "]"));
    }

    function buildLootMetadata(
        string memory name,
        string memory description,
        uint256 tokenId,
        uint256 itemType,
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
                            buildLootAttributes(tokenId, itemType),
                            ',"image":"data:image/svg+xml;base64,',
                            svgBase64,
                            '"}'
                        )
                    )
                )
            );
    }

    function buildEggAttributes(
        uint256 tokenId
    ) internal pure returns (string memory) {
        return
            string(
                abi.encodePacked(
                    '"attributes":[',
                    buildTrait("Rarity", getRarity(tokenId)),
                    ",",
                    buildTrait("Color", getColorName(tokenId)),
                    ",",
                    buildTrait("Element", getElementName(tokenId)),
                    "]"
                )
            );
    }
}
