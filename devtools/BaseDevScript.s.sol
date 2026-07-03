// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";

/**
 * @notice Abstract base for all dev pipeline scripts. Derives participant accounts from a
 *         generation, address lookup, and console logging.
 */
abstract contract BaseDevScript is Script {
    mapping(address => uint256) private _participantPk;
    address[] private _participants;

    /**
     * @notice Populates the internal participants list and pk lookup map.
     *         Call this before using `participant()` or `pkOf()`. Scripts that only
     *         need to broadcast can skip this and call `generateKeys()` directly.
     * @dev    Reads `PARTICIPANT_SIZE` (default 5) and `PARTICIPANT_IDX_START` (default 0)
     *         from env so the participant range can be changed between pipeline runs
     *         without threading params through every script's `run()`.
     */
    function loadParticipants() internal {
        uint256 keyCount = vm.envOr("PARTICIPANT_SIZE", defaultParticipantSize());
        uint256 startIndex = vm.envOr("PARTICIPANT_IDX_START", uint256(0));

        loadParticipants(keyCount, startIndex);
    }

    function loadParticipants(uint256 keyCount, uint256 startIndex) internal {
        uint256[] memory pks = _generateKeys(keyCount, startIndex);

        for (uint256 i = 0; i < pks.length; i++) {
            uint256 pk = pks[i];
            address addr = addrOf(pk);

            _participantPk[addr] = pk;
            _participants.push(addr);
        }
    }

    // when you don't need to load participant key => address into storage
    function generateKeys(
        uint256 keyCount,
        uint256 startIndex
    ) internal view returns (uint256[] memory) {
        return _generateKeys(keyCount, startIndex);
    }

    function generateKeys() internal view returns (uint256[] memory) {
        uint256 keyCount = vm.envOr("PARTICIPANT_SIZE", defaultParticipantSize());
        uint256 startIndex = vm.envOr("PARTICIPANT_IDX_START", uint256(0));

        return _generateKeys(keyCount, startIndex);
    }

    function defaultParticipantSize() internal pure returns (uint256) {
        return 5;
    }

    /**
     * @notice Returns N private keys derived from the chain-specific mnemonic file.
     *         Use this when the script only needs to broadcast — no participant map needed.
     *         NB: if changing the count, remember to update the --accounts flag in start-fork.sh
     */
    function _generateKeys(
        uint256 keyCount,
        uint256 startIndex
    ) private view returns (uint256[] memory) {
        // use the standard eth dev mnemonic if not found
        string memory mnemonic = vm.envOr(
            "PARTICIPANT_MNEMONIC",
            string("test test test test test test test test test test test junk")
        );
        uint256[] memory keys = new uint256[](keyCount);

        for (uint32 i = 0; i < keyCount; i++) {
            keys[i] = vm.deriveKey(mnemonic, i + uint32(startIndex));
        }

        return keys;
    }

    function participant(uint256 idx) internal view returns (address) {
        return _participants[idx];
    }

    function participants() internal view returns (address[] memory) {
        return _participants;
    }

    /**
     * @notice Returns a deterministic participant that is not `excluded`, selected using `seed`.
     *         Useful for pairing a maker with a distinct taker without repeating the same address.
     * @param excluded  Address to skip.
     * @param seed      Arbitrary value — same seed always picks the same counterparty.
     */
    function otherParticipant(address excluded, uint256 seed) internal view returns (address) {
        address[] memory ps = participants();
        require(ps.length > 1, "Need at least 2 participants");

        uint256 idx = uint256(keccak256(abi.encode(seed))) % ps.length;
        if (ps[idx] == excluded) {
            idx = (idx + 1) % ps.length;
        }

        return ps[idx];
    }

    function pkOf(address a) internal view returns (uint256) {
        require(_participantPk[a] != 0, "unknown participant");
        return _participantPk[a];
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

    function printSpace() internal pure {
        console.log("");
    }

    function logSection(string memory title) internal pure {
        logSeparator();
        console.log(title);
        logSeparator();
    }

    function logDeployment(string memory label, address deployed) internal view {
        console.log("DEPLOY | %s | %s | codeSize: %s", label, deployed, deployed.code.length);
    }

    function logAddress(string memory label, address a) internal pure {
        console.log("%s | %s", label, a);
    }

    function logBalance(string memory label, address a) internal view {
        console.log("%s | %s | balance: %s", label, a, a.balance);
    }

    function logTokenBalance(string memory label, address a, uint256 balance) internal pure {
        console.log("%s | %s | balance: %s", label, a, balance);
    }

    function logSeparator() internal pure {
        console.log("--------------------");
    }

    function logNFTMint(address collection, uint256 tokenId, address to) internal pure {
        console.log("MINT | collection: %s | tokenId: %s | to: %s", collection, tokenId, to);
    }

    function logBlockTimestamp() internal view {
        console.log("TIMESTAMP | unix: %s", vm.getBlockTimestamp());
    }
}
