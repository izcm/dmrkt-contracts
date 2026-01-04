// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {console} from "forge-std/console.sol";

// scripts
import {BaseDevScript} from "dev/BaseDevScript.s.sol";
import {DevConfig} from "dev/DevConfig.s.sol";

// interfaces
import {IERC721} from "@openzeppelin/interfaces/IERC721.sol";
import {IERC20} from "@openzeppelin/interfaces/IERC20.sol";

contract Approve is BaseDevScript, DevConfig {
    function run() external {
        logBlockTimestamp();

        // --------------------------------
        // PHASE 0: LOAD CONFIG
        // --------------------------------
        address weth = readWeth();

        address nftTransferAuth = readNftTransferAuth();
        address allowanceSpender = readAllowanceSpender();

        address[] memory collections = readCollections();

        // --- PKs for broadcasting ---
        uint256[] memory participantPks = readKeys();
        uint256 participantCount = participantPks.length;

        // --------------------------------
        // PHASE 1: NFT TRANSFER AUTH
        // --------------------------------
        logSection("APPROVE NFT TRANSFER AUTH");

        for (uint256 i = 0; i < collections.length; i++) {
            IERC721 collectionToken = IERC721(collections[i]);

            logSection(string.concat("APPROVE COLLECTION #", vm.toString(i)));

            for (uint256 j = 0; j < participantCount; j++) {
                vm.startBroadcast(participantPks[j]);
                collectionToken.setApprovalForAll(nftTransferAuth, true);
                vm.stopBroadcast();

                address owner = addrOf(participantPks[j]);
                console.log(
                    "%s HAS APPROVED DMRKT FOR ALL: ",
                    owner,
                    collectionToken.isApprovedForAll(owner, nftTransferAuth)
                );
            }
        }

        // --------------------------------
        // PHASE 2: WETH ALLOWANCE
        // --------------------------------
        logSection("APPROVE WETH ALLOWANCE FOR NFT TRANSFER AUTH");

        // DEV-ONLY:
        // Infinite approval used ONLY for local fork / deterministic setup.
        // Production flow uses exact per-owner exposure-based allowances.
        IERC20 wethToken = IERC20(weth);
        uint256 allowance = type(uint256).max;

        for (uint256 i = 0; i < participantCount; i++) {
            vm.startBroadcast(participantPks[i]);
            wethToken.approve(allowanceSpender, allowance);
            vm.stopBroadcast();

            address owner = addrOf(participantPks[i]);
            console.log(
                "%s HAS APPROVED ALLOWANCE FOR SPENDER: ",
                owner,
                wethToken.allowance(owner, allowanceSpender)
            );
        }
    }
}
