// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

abstract contract BaseDevScript is Script {
    mapping(address => uint256) private _ownerPk;
    address[] private _participants;

    // Call this if the script needs easy access to pk => addr
    function _loadParticipants() internal {
        uint256[] memory pks = generateKeys();

        for (uint256 i = 0; i < pks.length; i++) {
            uint256 pk = pks[i];
            address addr = addrOf(pk);

            _ownerPk[addr] = pk;
            _participants.push(addr);
        }
    }

    // If a script only needs private keys use this, no need to call loadParticipants
    function generateKeys() internal view returns (uint256[] memory) {
        return generateKeys(7);
    }

    function generateKeys(
        uint32 keyCount
    ) private view returns (uint256[] memory) {
        string memory path = string.concat(
            "./data/",
            vm.toString(block.chainid),
            "/mnemonic.json"
        );

        string memory json = vm.readFile(path);
        string memory mnemonic = vm.parseJsonString(json, ".mnemonic");

        uint256[] memory keys = new uint256[](keyCount);

        for (uint32 i = 0; i < keyCount; i++) {
            keys[i] = vm.deriveKey(mnemonic, i);
        }

        return keys;
    }

    function participant(uint256 idx) internal view returns (address) {
        return _participants[idx];
    }

    function participants() internal view returns (address[] memory) {
        return _participants;
    }

    function otherParticipant(
        address excluded,
        uint256 seed
    ) internal view returns (address) {
        address[] memory ps = participants();
        require(ps.length > 1, "Need at least 2 participants");

        uint256 excludedIdx = _indexOfParticipant(excluded);
        uint256 idx = uint256(keccak256(abi.encode(seed))) % (ps.length - 1);

        if (idx >= excludedIdx) idx++;
        return ps[idx];
    }

    function pkOf(address a) internal view returns (uint256) {
        return _ownerPk[a];
    }

    function addrOf(uint256 pk) internal pure returns (address) {
        return vm.addr(pk);
    }

    // === PRIVATE FUNCTIONS ===

    function _indexOfParticipant(address a) internal view returns (uint256) {
        address[] memory parts = participants();
        for (uint256 i = 0; i < parts.length; i++) {
            if (parts[i] == a) return i;
        }
        revert("Address not found in participants");
    }

    // === LOG HELPERS ===

    function logSection(string memory title) internal pure {
        logSeparator();
        console.log(title);
        logSeparator();
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
        console.log("--------------------");
    }

    function logNFTMint(
        address collection,
        uint256 tokenId,
        address to
    ) internal pure {
        console.log(
            "MINT | collection: %s | tokenId: %s | to: %s",
            collection,
            tokenId,
            to
        );
    }

    function logBlockTimestamp() internal view {
        console.log("TIMESTAMP | unix: %s", vm.getBlockTimestamp());
    }
}
