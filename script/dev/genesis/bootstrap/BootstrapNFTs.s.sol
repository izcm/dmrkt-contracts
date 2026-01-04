// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

// scripts
import {BaseDevScript} from "dev/BaseDevScript.s.sol";
import {DevConfig} from "dev/DevConfig.s.sol";

// interfaces
import {DNFT} from "periphery/interfaces/DNFT.sol";

contract BootstrapNFTs is BaseDevScript, DevConfig {
    function run() external {
        logBlockTimestamp();

        // --------------------------------
        // PHASE 0: LOAD CONFIG
        // --------------------------------
        address[] memory collections = readCollections();

        // --- PKs for broadcasting ---
        uint256[] memory participantPks = readKeys();
        uint256 participantCount = participantPks.length;

        // --------------------------------
        // PHASE 1: MINT NFTs
        // --------------------------------
        logSection("MINT NFTs");

        for (uint256 i = 0; i < collections.length; i++) {
            DNFT collectionToken = DNFT(collections[i]);
            mintTokens(participantPks, collectionToken);

            logSection("DNFT FINAL BALANCES");

            for (uint256 j = 0; j < participantCount; j++) {
                address user = addrOf(participantPks[i]);
                uint256 bal = collectionToken.balanceOf(user);

                logTokenBalance("DNFT", user, bal);
            }
        }
    }

    function mintTokens(uint256[] memory pks, DNFT ct) internal {
        uint256 limit = ct.MAX_SUPPLY();

        for (uint256 i = 0; i < limit; i++) {
            bytes32 h = keccak256(abi.encode(address(ct), i));
            uint256 j = uint256(h) % pks.length;

            uint256 pk = pks[j];
            address to = addrOf(pk);

            // Broadcast as the recipient — respect for history
            vm.startBroadcast(pk);

            ct.mint(to);

            vm.stopBroadcast();
        }
    }
}
