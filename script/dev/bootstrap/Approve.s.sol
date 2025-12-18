// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Config} from "forge-std/Config.sol";
import {console} from "forge-std/console.sol";

// local
import {BaseDevScript} from "dev/BaseDevScript.s.sol";

// interfaces
import {IERC721} from "@openzeppelin/interfaces/IERC721.sol";
import {IWETH} from "shared/interfaces/IWETH.sol";

contract Approve is BaseDevScript, Config {
    function run() external {
        // --------------------------------
        // PHASE 0: LOAD CONFIG
        // --------------------------------
        _loadConfig("deployments.toml", true);

        logSection("LOAD CONFIG");

        uint256 chainId = block.chainid;
        console.log("ChainId: %s", chainId);

        address weth = config.get("weth").toAddress();
        address dNft = config.get("dnft_erc721").toAddress();
        address marketplace = config.get("marketplace").toAddress();

        logAddress("DNFT       ", dNft);
        logAddress("MARKETPLACE", marketplace);

        // --- PKs for broadcasting ---
        uint256[] memory participantPks = readKeys(chainId);
        uint256 participantCount = participantPks.length;

        // --------------------------------
        // PHASE 1: MARKETPLACE TRANSFER
        // --------------------------------
        logSection("APPROVE MARKETPLACE FOR NFTs");

        IERC721 nftToken = IERC721(address(dNft));

        for (uint256 i = 0; i < participantCount; i++) {
            vm.startBroadcast(participantPks[i]);
            nftToken.setApprovalForAll(marketplace, true);
            vm.stopBroadcast();

            address owner = addrOf(participantPks[i]);
            console.log(
                "%s HAS APPROVED DMRKT FOR ALL: ",
                owner,
                nftToken.isApprovedForAll(owner, marketplace)
            );
        }

        // --------------------------------
        // PHASE 2: WETH ALLOWANCE
        // --------------------------------
        logSection("APPROVE WETH ALLOWANCE FOR MARKETPLACE");

        // DEV-ONLY:
        // Infinite approval used ONLY for local fork / deterministic setup.
        // Production flow uses exact per-owner exposure-based allowances.
        IWETH wethToken = IWETH(weth);
        uint256 allowance = type(uint256).max;

        for (uint256 i = 0; i < participantCount; i++) {
            vm.startBroadcast(participantPks[i]);
            wethToken.approve(marketplace, allowance);
            vm.stopBroadcast();

            address owner = addrOf(participantPks[i]);
            console.log(
                "%s HAS APPROVED ALLOWANCE FOR MARKETPLACE: ",
                owner,
                wethToken.allowance(owner, marketplace)
            );
        }
    }
}
