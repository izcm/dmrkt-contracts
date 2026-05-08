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
     * @notice Mints every token in `ct` up to MAX_SUPPLY, distributing them
     *         deterministically across `pks`. Distribution is derived from
     *         keccak256(collection, tokenId) so the same setup always produces
     *         the same ownership layout.
     * @param pks  Participant private keys — each mint is broadcast from the recipient's key.
     * @param ct   NFT collection implementing the DNFT interface (must expose MAX_SUPPLY and mint).
     */
    function mintTokens(uint256[] memory pks, DNFT ct) internal {
        uint256 limit = ct.MAX_SUPPLY();

        for (uint256 i = 0; i < limit; i++) {
            bytes32 h = keccak256(abi.encode(address(ct), i));
            uint256 j = uint256(h) % pks.length;

            uint256 pk = pks[j];
            address to = addrOf(pk);

            // Broadcast as the recipient
            vm.startBroadcast(pk);

            ct.mint(to);

            vm.stopBroadcast();

            console.log("MINT | tokenId: %s | block: %s", i, block.number);
        }
    }
}
