// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "forge-std/Test.sol";

import {DMrktLoot} from "../DMrktLoot.sol";
import {DMrktMathConfig} from "../DMrktMathConfig.sol";

/**
 * nb: tests are made by AI (this is only demo-periphery stuff)
 */

contract DMrktLootTest is Test {
    DMrktLoot loot;

    address alice = address(0x1);
    address bob = address(0x2);

    function setUp() public {
        loot = new DMrktLoot();
    }

    // ----------------------------
    // BASIC MINT
    // ----------------------------

    function testMintSword() public {
        loot.mint(alice);
        // Token 0: 0 % 3 = 0 = Sword
        assertEq(loot.totalSupply(), 1);
        assertEq(loot.ownerOf(0), alice);
        assertEq(uint256(loot.itemTypeOf(0)), DMrktMathConfig.itemTypeSword());
    }

    function testMintElixir() public {
        loot.mint(alice);
        // Token 0: 0 % 3 = 0 = Sword
        loot.mint(alice);
        // Token 1: 1 % 3 = 1 = Elixir
        assertEq(loot.totalSupply(), 2);
        assertEq(uint256(loot.itemTypeOf(1)), DMrktMathConfig.itemTypeElixir());
    }

    function testMintShield() public {
        loot.mint(alice);
        // Token 0
        loot.mint(alice);
        // Token 1
        loot.mint(alice);
        // Token 2: 2 % 3 = 2 = Shield
        assertEq(loot.totalSupply(), 3);
        assertEq(uint256(loot.itemTypeOf(2)), DMrktMathConfig.itemTypeShield());
    }

    // ----------------------------
    // SUPPLY TRACKING
    // ----------------------------

    function testTypeSupply() public {
        // Mint 6 tokens: 0(Sword), 1(Elixir), 2(Shield), 3(Sword), 4(Elixir), 5(Shield)
        for (uint256 i = 0; i < 6; i++) {
            loot.mint(alice);
        }
        loot.mint(bob);
        // Token 6: 6 % 3 = 0 = Sword

        // Should have 3 Swords (tokens 0, 3, 6)
        assertEq(loot.supplyOf(DMrktLoot.ItemType.Sword), 3);
        assertEq(loot.totalSupply(), 7);
    }

    function testDifferentTypesSupply() public {
        // Mint 3 tokens to cover one of each type
        loot.mint(alice); // Token 0: Sword
        loot.mint(alice); // Token 1: Elixir
        loot.mint(alice); // Token 2: Shield

        assertEq(loot.supplyOf(DMrktLoot.ItemType.Sword), 1);
        assertEq(loot.supplyOf(DMrktLoot.ItemType.Elixir), 1);
        assertEq(loot.supplyOf(DMrktLoot.ItemType.Shield), 1);
    }

    // ----------------------------
    // MAX GLOBAL SUPPLY
    // ----------------------------

    function testMaxTotalSupply() public {
        // Fill to MAX_SUPPLY
        for (uint256 i = 0; i < loot.MAX_SUPPLY(); i++) {
            loot.mint(alice);
        }
        assertEq(loot.totalSupply(), loot.MAX_SUPPLY());
        // Next mint should fail
        vm.expectRevert("Max supply reached");
        loot.mint(alice);
    }

    // ----------------------------
    // TOKEN URI
    // ----------------------------

    function testTokenURI() public {
        loot.mint(alice);

        string memory uri = loot.tokenURI(0);

        assertTrue(bytes(uri).length > 0);
    }

    // ----------------------------
    // ITEM TYPE CHECK
    // ----------------------------

    function testItemType() public {
        loot.mint(alice); // Token 0: Sword
        loot.mint(alice); // Token 1: Elixir
        loot.mint(alice); // Token 2: Shield

        DMrktLoot.ItemType t = loot.itemTypeOf(2);

        assertEq(uint256(t), DMrktMathConfig.itemTypeShield());
    }

    function testTraitGetters() public {
        loot.mint(alice); // Token 0 (0 % 3 = 0 = Sword)

        assertEq(loot.getRarity(0), "Legendary");
        assertEq(loot.getColorName(0), "Protocol Purple");
        assertEq(loot.getElementName(0), "Thunder");
    }
}
