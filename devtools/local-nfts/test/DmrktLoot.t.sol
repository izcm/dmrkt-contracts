// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "forge-std/Test.sol";

import {DMrktLoot} from "../DMrktLoot.sol";
import {DMrktMathConfig} from "../DMrktMathConfig.sol";

/**
 * nb: tests are made by AI (this is only demo-periphery stuff)
 */

contract DMrktLootTest is Test {
    DMrktLoot inventory;

    address alice = address(0x1);
    address bob = address(0x2);

    function setUp() public {
        inventory = new DMrktLoot();
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
        assertEq(inventory.supplyOf(DMrktLoot.ItemType.Sword), 3);
        assertEq(inventory.totalSupply(), 7);
    }

    function testDifferentTypesSupply() public {
        // Mint 3 tokens to cover one of each type
        inventory.mint(alice); // Token 0: Sword
        inventory.mint(alice); // Token 1: Elixir
        inventory.mint(alice); // Token 2: Shield

        assertEq(inventory.supplyOf(DMrktLoot.ItemType.Sword), 1);
        assertEq(inventory.supplyOf(DMrktLoot.ItemType.Elixir), 1);
        assertEq(inventory.supplyOf(DMrktLoot.ItemType.Shield), 1);
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

        DMrktLoot.ItemType t = inventory.itemTypeOf(2);

        assertEq(uint256(t), DMrktMathConfig.itemTypeShield());
    }

    function testTraitGetters() public {
        inventory.mint(alice); // Token 0 (0 % 3 = 0 = Sword)

        assertEq(inventory.getRarity(0), "Legendary");
        assertEq(inventory.getColorName(0), "Protocol Purple");
        assertEq(inventory.getElementName(0), "Thunder");
    }
}
