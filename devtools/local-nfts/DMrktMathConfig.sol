// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

library DMrktMathConfig {
    function lootMaxSupply() public pure returns (uint256) {
        return 500;
    }

    function itemTypeCount() public pure returns (uint256) {
        return 3;
    }

    function itemTypeSword() internal pure returns (uint256) {
        return 0;
    }

    function itemTypeElixir() internal pure returns (uint256) {
        return 1;
    }

    function itemTypeShield() internal pure returns (uint256) {
        return 2;
    }

    function rarityLegendaryMod() internal pure returns (uint256) {
        return 25;
    }

    function rarityEpicMod() internal pure returns (uint256) {
        return 10;
    }

    function rarityRareMod() internal pure returns (uint256) {
        return 5;
    }

    function elementThunderMod() internal pure returns (uint256) {
        return 11;
    }

    function elementFireMod() internal pure returns (uint256) {
        return 5;
    }

    function colorPaletteSize() internal pure returns (uint256) {
        return 12;
    }

    function damageBaseMin() internal pure returns (uint256) {
        return 10;
    }

    function damageBaseModulo() internal pure returns (uint256) {
        return 40;
    }

    function damageLegendaryBonus() internal pure returns (uint256) {
        return 50;
    }

    function damageEpicBonus() internal pure returns (uint256) {
        return 30;
    }

    function damageRareBonus() internal pure returns (uint256) {
        return 15;
    }

    function defenseBaseMin() internal pure returns (uint256) {
        return 5;
    }

    function defenseBaseModulo() internal pure returns (uint256) {
        return 25;
    }

    function defenseLegendaryBonus() internal pure returns (uint256) {
        return 40;
    }

    function defenseEpicBonus() internal pure returns (uint256) {
        return 20;
    }

    function defenseRareBonus() internal pure returns (uint256) {
        return 10;
    }

    function powerBaseMin() internal pure returns (uint256) {
        return 8;
    }

    function powerBaseModulo() internal pure returns (uint256) {
        return 30;
    }

    function powerLegendaryBonus() internal pure returns (uint256) {
        return 45;
    }

    function powerEpicBonus() internal pure returns (uint256) {
        return 25;
    }

    function powerRareBonus() internal pure returns (uint256) {
        return 12;
    }
}
