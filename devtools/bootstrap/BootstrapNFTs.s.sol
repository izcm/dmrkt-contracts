// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

// scripts
import {BaseDevScript} from "dev/BaseDevScript.s.sol";
import {DevConfig} from "dev/DevConfig.s.sol";
import {console} from "forge-std/console.sol";

// interfaces
import {DNFT} from "dev/interfaces/DNFT.sol";

/**
 * @notice Mints all tokens from each deployed NFT collection to participants using a
 *         pseudo-random but deterministic distribution.
 */
contract BootstrapNFTs is BaseDevScript, DevConfig {
    function run() external {
        logBlockTimestamp();

        // --------------------------------
        // LOAD CONFIG
        // --------------------------------

        address[] memory collections = readCollections();
        uint256[] memory participantPks = generateKeys();
        uint256 participantCount = participantPks.length;

        // --------------------------------
        // MINT NFTs
        // --------------------------------

        logSection("MINT NFTs");

        for (uint256 i = 0; i < collections.length; i++) {
            DNFT collectionToken = DNFT(collections[i]);
            mintTokens(participantPks, collectionToken);

            logSection("DNFT FINAL BALANCES");

            for (uint256 j = 0; j < participantCount; j++) {
                address user = addrOf(participantPks[j]);
                uint256 bal = collectionToken.balanceOf(user);

                logTokenBalance("DNFT", user, bal);
            }
        }
    }

    /**
     * @notice Mints all tokens in `collection` to participants using a deterministic distribution
     *         (keccak256 of collection + tokenId). Buckets tokens per recipient first so we open
     *         one broadcast per participant instead of one per token — smaller broadcast log means foundry doesn't stall after this step.
     * @param pks  Participant private keys — mints go out from the recipient's own key.
     * @param collection  The NFT collection to mint from (needs MAX_SUPPLY and mint).
     */
    function mintTokens(uint256[] memory pks, DNFT collection) internal {
        uint256 limit = collection.MAX_SUPPLY();
        uint256 participantCount = pks.length;

        uint256[] memory assignments = new uint256[](limit);
        uint256[] memory tokenCounts = new uint256[](participantCount);

        for (uint256 i = 0; i < limit; i++) {
            uint256 j = uint256(keccak256(abi.encode(address(collection), i))) %
                participantCount;
            assignments[i] = j;
            tokenCounts[j]++;
        }

        for (uint256 j = 0; j < participantCount; j++) {
            if (tokenCounts[j] == 0) continue;

            address to = addrOf(pks[j]);

            vm.startBroadcast(pks[j]);
            for (uint256 i = 0; i < limit; i++) {
                if (assignments[i] != j) continue;
                collection.mint(to);
                console.log("MINT | tokenId: %s | to: %s", i, to);
            }
            vm.stopBroadcast();
        }
    }
}
