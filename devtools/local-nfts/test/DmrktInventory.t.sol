// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "forge-std/Test.sol";

import {DMrktInventory} from "../DMrktInventory.sol";
import {DMrktMathConfig} from "../DMrktMathConfig.sol";
import "../DMrktNFTLib.sol";

/**
 * nb: tests are made by AI (this is only demo-periphery stuff)
 */

contract DMrktInventoryTest is Test {
    DMrktInventory inventory;

    address alice = address(0x1);
    address bob = address(0x2);

    function setUp() public {
        inventory = new DMrktInventory();
    }

    // ----------------------------
    // BASIC MINT
    // ----------------------------

    function testMintSword() public {
        inventory.mint(alice);
        // Token 0: 0 % 3 = 0 = Sword
        assertEq(inventory.totalSupply(), 1);
        assertEq(inventory.ownerOf(0), alice);
        assertEq(
            uint256(inventory.itemTypeOf(0)),
            DMrktMathConfig.itemTypeSword()
        );
    }

    function testMintElixir() public {
        inventory.mint(alice);
        // Token 0: 0 % 3 = 0 = Sword
        inventory.mint(alice);
        // Token 1: 1 % 3 = 1 = Elixir
        assertEq(inventory.totalSupply(), 2);
        assertEq(
            uint256(inventory.itemTypeOf(1)),
            DMrktMathConfig.itemTypeElixir()
        );
    }

    function testMintShield() public {
        inventory.mint(alice);
        // Token 0
        inventory.mint(alice);
        // Token 1
        inventory.mint(alice);
        // Token 2: 2 % 3 = 2 = Shield
        assertEq(inventory.totalSupply(), 3);
        assertEq(
            uint256(inventory.itemTypeOf(2)),
            DMrktMathConfig.itemTypeShield()
        );
    }

    // ----------------------------
    // SUPPLY TRACKING
    // ----------------------------

    function testTypeSupply() public {
        // Mint 6 tokens: 0(Sword), 1(Elixir), 2(Shield), 3(Sword), 4(Elixir), 5(Shield)
        for (uint256 i = 0; i < 6; i++) {
            inventory.mint(alice);
        }
        inventory.mint(bob);
        // Token 6: 6 % 3 = 0 = Sword

        // Should have 3 Swords (tokens 0, 3, 6)
        assertEq(inventory.supplyOf(DMrktInventory.ItemType.Sword), 3);
        assertEq(inventory.totalSupply(), 7);
    }

    function testDifferentTypesSupply() public {
        // Mint 3 tokens to cover one of each type
        inventory.mint(alice); // Token 0: Sword
        inventory.mint(alice); // Token 1: Elixir
        inventory.mint(alice); // Token 2: Shield

        assertEq(inventory.supplyOf(DMrktInventory.ItemType.Sword), 1);
        assertEq(inventory.supplyOf(DMrktInventory.ItemType.Elixir), 1);
        assertEq(inventory.supplyOf(DMrktInventory.ItemType.Shield), 1);
    }

    // ----------------------------
    // MAX SUPPLY PER TYPE
    // ----------------------------

    function testMaxSupplyPerType() public {
        // Fill all 300 slots
        for (uint256 i = 0; i < inventory.MAX_SUPPLY(); i++) {
            inventory.mint(alice);
        }
        // Should have exactly 100 of each type
        assertEq(
            inventory.supplyOf(DMrktInventory.ItemType.Sword),
            DMrktMathConfig.inventorySupplyPerType()
        );
        assertEq(
            inventory.supplyOf(DMrktInventory.ItemType.Elixir),
            DMrktMathConfig.inventorySupplyPerType()
        );
        assertEq(
            inventory.supplyOf(DMrktInventory.ItemType.Shield),
            DMrktMathConfig.inventorySupplyPerType()
        );
    }

    // ----------------------------
    // MAX GLOBAL SUPPLY
    // ----------------------------

    function testMaxTotalSupply() public {
        // Fill to MAX_SUPPLY
        for (uint256 i = 0; i < inventory.MAX_SUPPLY(); i++) {
            inventory.mint(alice);
        }
        assertEq(inventory.totalSupply(), inventory.MAX_SUPPLY());
        // Next mint should fail
        vm.expectRevert("Max supply reached");
        inventory.mint(alice);
    }

    // ----------------------------
    // TOKEN URI
    // ----------------------------

    function testTokenURI() public {
        inventory.mint(alice);

        string memory uri = inventory.tokenURI(0);

        assertTrue(bytes(uri).length > 0);
    }

    // ----------------------------
    // ITEM TYPE CHECK
    // ----------------------------

    function testItemType() public {
        inventory.mint(alice); // Token 0: Sword
        inventory.mint(alice); // Token 1: Elixir
        inventory.mint(alice); // Token 2: Shield

        DMrktInventory.ItemType t = inventory.itemTypeOf(2);

        assertEq(uint256(t), DMrktMathConfig.itemTypeShield());
    }

    // ----------------------------
    // LIBRARY TESTS
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

    function testTraitGetters() public {
        inventory.mint(alice); // Token 0 (0 % 3 = 0 = Sword)

        assertEq(inventory.getRarity(0), "Legendary");
        assertEq(inventory.getColorName(0), "Protocol Purple");
        assertEq(inventory.getElementName(0), "Thunder");
    }

    // ----------------------------
    // METADATA BUILD TESTS
    // ----------------------------

    function testBuildItemName() public {
        // With element
        string memory name_with_element = DMrktNFTLib.buildItemName(
            "Sword",
            11
        );
        // Token 11: Legendary, Cyan Blue color, Thunder element
        assertTrue(bytes(name_with_element).length > 0);
        // Should contain "Legendary" or "Epic" etc

        // Without element
        string memory name_no_element = DMrktNFTLib.buildItemName("Shield", 1);
        assertTrue(bytes(name_no_element).length > 0);
    }

    function testBuildAttributesSword() public {
        // Token 0: Sword (itemType 0)
        string memory attrs = DMrktNFTLib.buildAttributes(
            0,
            DMrktMathConfig.itemTypeSword()
        );
        assertTrue(bytes(attrs).length > 0);
        // Should contain "attributes" and "Damage"
        assertTrue(bytes(attrs).length > 50);
    }

    function testBuildAttributesShield() public {
        // Token 2: Shield (itemType 2)
        string memory attrs = DMrktNFTLib.buildAttributes(
            2,
            DMrktMathConfig.itemTypeShield()
        );
        assertTrue(bytes(attrs).length > 0);
        // Should contain "attributes" and "Defense"
        assertTrue(bytes(attrs).length > 50);
    }

    function testBuildAttributesElixir() public {
        // Token 1: Elixir (itemType 1)
        string memory attrs = DMrktNFTLib.buildAttributes(
            1,
            DMrktMathConfig.itemTypeElixir()
        );
        assertTrue(bytes(attrs).length > 0);
        // Should contain "attributes" and "Power"
        assertTrue(bytes(attrs).length > 50);
    }

    function testBuildRarityGlow() public {
        // Legendary glow
        string memory glow_legend = DMrktNFTLib.buildRarityGlow(
            DMrktMathConfig.rarityLegendaryMod()
        );
        assertTrue(bytes(glow_legend).length > 0);
        assertTrue(keccak256(bytes(glow_legend)) != keccak256(bytes("")));

        // Epic glow
        string memory glow_epic = DMrktNFTLib.buildRarityGlow(
            DMrktMathConfig.rarityEpicMod()
        );
        assertTrue(bytes(glow_epic).length > 0);

        // Common (no glow)
        string memory glow_common = DMrktNFTLib.buildRarityGlow(1);
        assertEq(bytes(glow_common).length, 0);
    }

    function testBuildElementOverlay() public {
        // Thunder (11 % 11 == 0)
        string memory overlay_thunder = DMrktNFTLib.buildElementOverlay(
            DMrktMathConfig.elementThunderMod()
        );
        assertTrue(bytes(overlay_thunder).length > 0);
        // Should be SVG polygon

        // Fire (5 % 5 == 0, not % 11)
        string memory overlay_fire = DMrktNFTLib.buildElementOverlay(
            DMrktMathConfig.elementFireMod()
        );
        assertTrue(bytes(overlay_fire).length > 0);

        // None
        string memory overlay_none = DMrktNFTLib.buildElementOverlay(1);
        assertEq(bytes(overlay_none).length, 0);
    }
}
