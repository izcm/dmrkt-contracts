// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script} from "forge-std/Script.sol";

abstract contract BaseDevScript is Script {
    // DEV ONLY - anvil default funded accounts
    uint256[4] internal DEV_KEYS = [1, 2, 3, 4];

    function selectTokens(
        address tokenContract,
        uint256 roof,
        uint8 mod
    ) internal returns (uint256[] memory, uint256) {
        uint256 count = 0;
        uint256[] memory ids = new uint256[](roof);

        // start at 1 cuz we don't care enough to check if contract skips #0 / no
        for (uint256 i = 1; i <= roof; i++) {
            bytes32 h = keccak256(abi.encode(tokenContract, i));
            if (uint256(h) % mod == 0) {
                ids[count] = i;
                count++;
            }
        }
        return (ids, count);
    }

    function devKey(uint256 i) internal view returns (address) {
        return vm.addr(DEV_KEYS[i]);
    }
}
