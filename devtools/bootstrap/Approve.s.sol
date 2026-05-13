// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {console} from "forge-std/console.sol";

// scripts
import {BaseDevScript} from "dev/BaseDevScript.s.sol";
import {DevConfig} from "dev/DevConfig.s.sol";

// interfaces
import {IERC721} from "@openzeppelin/interfaces/IERC721.sol";
import {IERC20} from "@openzeppelin/interfaces/IERC20.sol";

/**
 * @notice Grants the OrderEngine the approvals it needs to settle trades:
 *         `setApprovalForAll` on every NFT collection and max WETH allowance for the allowance spender.
 */
contract Approve is BaseDevScript, DevConfig {
    function run() external {
        logBlockTimestamp();

        // --------------------------------
        // LOAD CONFIG
        // --------------------------------

        address weth = readWeth();

        address nftTransferAuth = readNftTransferAuth();
        address allowanceSpender = readAllowanceSpender();

        address[] memory collections = readCollections();

        uint256[] memory participantPks = generateKeys();
        uint256 participantCount = participantPks.length;

        // --------------------------------
        // NFT TRANSFER AUTH
        // --------------------------------

        logSection("APPROVE NFT TRANSFER AUTH");

        for (uint256 i = 0; i < collections.length; i++) {
            IERC721 collectionToken = IERC721(collections[i]);

            logSection(string.concat("APPROVE COLLECTION #", vm.toString(i)));

            for (uint256 j = 0; j < participantCount; j++) {
                address owner = addrOf(participantPks[j]);
                console.log("[nft-approve] participant %s/%s | %s", j + 1, participantCount, owner);

                vm.startBroadcast(participantPks[j]);
                collectionToken.setApprovalForAll(nftTransferAuth, true);
                vm.stopBroadcast();

                console.log("[nft-approve] done | approved: %s", collectionToken.isApprovedForAll(owner, nftTransferAuth));
            }
        }

        // --------------------------------
        // WETH ALLOWANCE
        // --------------------------------

        logSection("APPROVE WETH ALLOWANCE FOR NFT TRANSFER AUTH");

        IERC20 wethToken = IERC20(weth);
        uint256 allowance = type(uint256).max;

        for (uint256 i = 0; i < participantCount; i++) {
            address owner = addrOf(participantPks[i]);
            console.log("[weth-approve] participant %s/%s | %s", i + 1, participantCount, owner);

            vm.startBroadcast(participantPks[i]);
            wethToken.approve(allowanceSpender, allowance);
            vm.stopBroadcast();

            console.log("[weth-approve] done | allowance: %s", wethToken.allowance(owner, allowanceSpender));
        }
    }
}
