// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";

abstract contract AccountsHelper is Test {
    struct Actors {
        address order;
        address fill;
    }

    uint256[] private testKeys;

    function _initActors(uint256 count) internal {
        testKeys = new uint256[](count);
        for (uint256 i = 0; i < count; i++) {
            testKeys[i] = i + 1;
        }
    }

    function actorCount() internal view returns (uint256) {
        return testKeys.length;
    }

    function addrOf(uint256 pk) internal pure returns (address) {
        return vm.addr(pk);
    }

    function pkOf(address target) internal view returns (uint256) {
        for (uint256 i = 0; i < testKeys.length; i++) {
            uint256 pk = testKeys[i];
            if (vm.addr(pk) == target) {
                return pk;
            }
        }
        revert("Address not in testKeys");
    }

    function actor(string memory seed) internal view returns (address) {
        uint256 idx = uint256(keccak256(abi.encode(seed))) % testKeys.length;
        return addrOf(testKeys[idx]);
    }

    function someActors(string memory seed) internal view returns (Actors memory a) {
        a.order = actor(string.concat(seed, "_order"));
        a.fill = actor(string.concat(seed, "_fill"));

        uint256 i = 0;
        while (a.order == a.fill) {
            a.fill = actor(string.concat(seed, "_fill_", vm.toString(i)));
            i++;
        }
    }

    function allActors() internal view returns (address[] memory) {
        uint256 count = testKeys.length;
        address[] memory actors = new address[](count);

        for (uint256 i = 0; i < count; i++) {
            actors[i] = addrOf(testKeys[i]);
        }

        return actors;
    }
}
