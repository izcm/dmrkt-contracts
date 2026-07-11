// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

// scripts
import { BaseDevScript } from "dev/BaseDevScript.s.sol";
import { DevConfig } from "dev/DevConfig.s.sol";

// interfaces
import { DNFT } from "dev/interfaces/DNFT.sol";

/**
 * @notice Computes a deterministic token-to-participant assignment for each deployed NFT
 *         collection and writes the selection to JSON. Minting itself happens separately,
 *         in bash (see ops/bootstrap/bootstrap-nfts.sh), reading this JSON.
 */
contract SelectNFTs is BaseDevScript, DevConfig {
    function run() external {
        // --------------------------------
        // LOAD CONFIG
        // --------------------------------

        address[] memory collections = readCollections();
        uint256 startIndex = vm.envOr("P_IDX_START", uint256(0));
        uint256 participantCount = vm.envOr("P_SIZE", defaultParticipantSize());

        uint256[] memory participantIdxs = new uint256[](participantCount);
        for (uint256 j = 0; j < participantCount; j++) {
            participantIdxs[j] = startIndex + j;
        }

        // --------------------------------
        // SELECT NFTs
        // --------------------------------

        for (uint256 i = 0; i < collections.length; i++) {
            uint256[][] memory tokenIdsByParticipant = _selectTokens(
                collections[i],
                participantCount
            );

            _writeMintSelection(collections[i], participantIdxs, tokenIdsByParticipant);
        }
    }

    /**
     * @notice Computes the deterministic token distribution for `collection`, up to MAX_SUPPLY.
     *         Distribution is derived from keccak256(collection, tokenId) so the same setup
     *         always produces the same ownership layout.
     * @param collection       NFT collection implementing the DNFT interface (must expose MAX_SUPPLY).
     * @param participantCount Number of participants to distribute tokens across.
     * @return tokenIdsByParticipant tokenIdsByParticipant[j] is the list of token IDs assigned to participant j.
     */
    function _selectTokens(
        address collection,
        uint256 participantCount
    ) internal view returns (uint256[][] memory tokenIdsByParticipant) {
        uint256 limit = DNFT(collection).MAX_SUPPLY();
        tokenIdsByParticipant = new uint256[][](participantCount);

        uint256[] memory owner = new uint256[](limit); // tracks each tokenId's owner (participant idx); one slot for each tokenId
        uint256[] memory counts = new uint256[](participantCount); // tracks token count per participant idx for memory allocation in loop under; one slot for each participant

        // do deterministic selection
        for (uint256 i = 0; i < limit; i++) {
            uint256 j = uint256(keccak256(abi.encode(collection, i))) % participantCount;
            owner[i] = j;
            counts[j]++;
        }

        // allocate memory for inner arrays
        for (uint256 j = 0; j < participantCount; j++) {
            tokenIdsByParticipant[j] = new uint256[](counts[j]);
        }

        uint256[] memory cursor = new uint256[](participantCount);
        for (uint256 i = 0; i < limit; i++) {
            uint256 j = owner[i];
            tokenIdsByParticipant[j][cursor[j]++] = i;
        }
    }

    /**
     * @notice Writes the deterministic token selection for a collection to
     *         `data/{chainId}/state/bootstrap/{collection}.json`, shaped as:
     *         { "1": [95, 127, 175], "2": [42, 69, 76], ... } — keyed by participantIdx.
     * @dev    The selections will never be read from file in foudnry, it will be read in bash.
     *         This approach enables parallell minting instead of broadcasting TOKEN_SUPPLY times.
     */
    function _writeMintSelection(
        address collection,
        uint256[] memory participantIdxs,
        uint256[][] memory tokenIdsByParticipant
    ) internal {
        string memory root = "root";
        string memory finalJson;

        for (uint256 i = 0; i < participantIdxs.length; i++) {
            string memory key = vm.toString(participantIdxs[i]);
            finalJson = vm.serializeUint(root, key, tokenIdsByParticipant[i]);
        }

        string memory dir = string.concat(
            "./data/",
            vm.toString(block.chainid),
            "/state/cols-mint-per-idx/"
        );
        vm.createDir(dir, true);

        string memory filename = string.concat(vm.toString(collection), ".json");
        vm.writeJson(finalJson, string.concat(dir, filename));
    }
}
