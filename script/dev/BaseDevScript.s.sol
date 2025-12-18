// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

abstract contract BaseDevScript is Script {
    function readKeys(
        uint256 chainId
    ) internal view returns (uint256[] memory) {
        string memory path = string.concat(
            "./data/",
            vm.toString(chainId),
            "/keys.json"
        );

        string memory json = vm.readFile(path);
        uint256[] memory keys = vm.parseJsonUintArray(json, ".privateKeys");

        return keys;
    }

    function addrOf(uint256 pk) internal pure returns (address) {
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

    function logSection(string memory title) internal pure {
        console.log("------------------------------------");
        console.log(title);
        console.log("------------------------------------");
    }

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

    function logAddress(string memory label, address a) internal pure {
        console.log("%s | %s", label, a);
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

    function logSeparator() internal pure {
        console.log("------------------------------------");
    }

    function logNFTMint(
        address nft,
        uint256 tokenId,
        address to
    ) internal pure {
        console.log("MINT | nft: %s | tokenId: %s | to: %s", nft, tokenId, to);
    }
}
