// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "forge-std/Test.sol";

import {DMrktMathConfig} from "../DMrktMathConfig.sol";
import "../DMrktNFTLib.sol";

contract DMrktNFTLibTest is Test {
    // ----------------------------
    // RARITY
    // ----------------------------

    function testRarityLogic() public {
        string memory r1 = DMrktNFTLib.getRarity(
            DMrktMathConfig.rarityLegendaryMod()
        );
        string memory r2 = DMrktNFTLib.getRarity(
            DMrktMathConfig.rarityEpicMod()
        );
        string memory r3 = DMrktNFTLib.getRarity(
            DMrktMathConfig.rarityRareMod()
        );
        string memory r4 = DMrktNFTLib.getRarity(1);

        assertEq(r1, "Legendary");
        assertEq(r2, "Epic");
        assertEq(r3, "Rare");
        assertEq(r4, "Common");
    }

    // ----------------------------
    // METADATA BUILD
    // ----------------------------

    function testBuildItemName() public {
        // With element
        string memory nameWithElement = DMrktNFTLib.buildItemName("Sword", 11);
        assertTrue(bytes(nameWithElement).length > 0);

        // Without element
        string memory nameNoElement = DMrktNFTLib.buildItemName("Shield", 1);
        assertTrue(bytes(nameNoElement).length > 0);
    }

    function testBuildAttributesSword() public {
        string memory attrs = DMrktNFTLib.buildLootAttributes(
            0,
            DMrktMathConfig.itemTypeSword()
        );
        assertTrue(bytes(attrs).length > 50);
    }

    function testBuildAttributesShield() public {
        string memory attrs = DMrktNFTLib.buildLootAttributes(
            2,
            DMrktMathConfig.itemTypeShield()
        );
        assertTrue(bytes(attrs).length > 50);
    }

    function testBuildAttributesElixir() public {
        string memory attrs = DMrktNFTLib.buildLootAttributes(
            1,
            DMrktMathConfig.itemTypeElixir()
        );
        assertTrue(bytes(attrs).length > 50);
    }

    // ----------------------------
    // VISUAL DECORATORS
    // ----------------------------

    function testBuildRarityGlow() public {
        string memory glowLegend = DMrktNFTLib.buildRarityGlow(
            DMrktMathConfig.rarityLegendaryMod()
        );
        assertTrue(bytes(glowLegend).length > 0);

        string memory glowEpic = DMrktNFTLib.buildRarityGlow(
            DMrktMathConfig.rarityEpicMod()
        );
        assertTrue(bytes(glowEpic).length > 0);

        string memory glowCommon = DMrktNFTLib.buildRarityGlow(1);
        assertEq(bytes(glowCommon).length, 0);
    }

    function testBuildElementOverlay() public {
        string memory overlayThunder = DMrktNFTLib.buildElementOverlay(
            DMrktMathConfig.elementThunderMod()
        );
        assertTrue(bytes(overlayThunder).length > 0);

        string memory overlayFire = DMrktNFTLib.buildElementOverlay(
            DMrktMathConfig.elementFireMod()
        );
        assertTrue(bytes(overlayFire).length > 0);

        string memory overlayNone = DMrktNFTLib.buildElementOverlay(1);
        assertEq(bytes(overlayNone).length, 0);
    }

    function testGetItemTypeName() public {
        // Sword
        assertEq(
            DMrktNFTLib.getItemTypeName(DMrktMathConfig.itemTypeSword()),
            "Sword"
        );
        // Elixir
        assertEq(
            DMrktNFTLib.getItemTypeName(DMrktMathConfig.itemTypeElixir()),
            "Elixir"
        );
        // Shield (fallback)
        assertEq(
            DMrktNFTLib.getItemTypeName(DMrktMathConfig.itemTypeShield()),
            "Shield"
        );
    }
}
