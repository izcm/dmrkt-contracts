// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

abstract contract BaseDevScript is Script {
    // DEV ONLY - anvil default funded accounts
    uint256[7] internal DEV_KEYS = [
        10000000,
        20000000,
        30000000,
        40000000,
        50000000,
        60000000,
        70000000
    ];

    function resolveAddr(uint256 pk) internal view returns (address) {
        return vm.addr(pk);
    }

    function countUntilZero(
        uint256[] memory arr
    ) internal pure returns (uint256) {
        uint256 i = 0;
        while (i < arr.length && arr[i] != 0) {
            i++;
        }
        return i;
    }

    // --- LOG HELPERS ---
    function logDeployment(
        string memory label,
        address deployed
    ) internal view {
        console.log(
            "DEPLOY | %s | %s | codeSize: %s",
            label,
            deployed,
            deployed.code.length
        );
    }

    function logSection(string memory title) internal pure {
        console.log("------------------------------------");
        console.log(title);
        console.log("------------------------------------");
    }

    function logBalance(string memory label, address a) internal view {
        console.log("%s | %s | balance: %s", label, a, a.balance);
    }

    function logTokenBalance(
        string memory label,
        address a,
        uint256 balance
    ) internal pure {
        console.log("%s | %s | balance: %s", label, a, balance);
    }

    function logSeperator() internal pure {
        console.log("------------------------------------");
    }
}
