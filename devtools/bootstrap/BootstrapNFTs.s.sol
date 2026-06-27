// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

// oz
import { IERC721Metadata } from "@openzeppelin/token/ERC721/extensions/IERC721Metadata.sol";

// scripts
import { BaseDevScript } from "dev/BaseDevScript.s.sol";
import { DevConfig } from "dev/DevConfig.s.sol";
import { console } from "forge-std/console.sol";

// interfaces
import { DNFT } from "dev/interfaces/DNFT.sol";

/**
 * @notice Mints all tokens from each deployed NFT collection to participants using a
 *         pseudo-random but deterministic distribution.
 */
contract BootstrapNFTs is BaseDevScript, DevConfig {
    function run() external {
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
            IERC721Metadata collectionToken = IERC721Metadata(collections[i]);
            string memory name = collectionToken.name();
            mintTokens(participantPks, DNFT(collections[i]));

            for (uint256 j = 0; j < participantCount; j++) {
                address user = addrOf(participantPks[j]);
                uint256 bal = collectionToken.balanceOf(user);

                console.log("%s | P%s | balance: %s", name, j + 1, bal);
            }
        }
    }

    /**
     * @notice Mints every token in `collection` up to MAX_SUPPLY, distributing them
     *         deterministically across `pks`. Distribution is derived from
     *         keccak256(collection, tokenId) so the same setup always produces
     *         the same ownership layout.
     * @param pks  Participant private keys — each mint is broadcast from the recipient's key.
     * @param collection   NFT collection implementing the DNFT interface (must expose MAX_SUPPLY and mint).
     */
    function mintTokens(uint256[] memory pks, DNFT collection) internal {
        uint256 limit = collection.MAX_SUPPLY();

        for (uint256 i = 0; i < limit; i++) {
            bytes32 h = keccak256(abi.encode(address(collection), i));
            uint256 j = uint256(h) % pks.length;

            uint256 pk = pks[j];
            address to = addrOf(pk);

            // skip if already minted
            try collection.ownerOf(i) returns (address) {
                continue;
            } catch {}
            // Broadcast as the recipient
            vm.startBroadcast(pk);

            collection.mint(to);

            vm.stopBroadcast();
        }
    }
}
