// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import { console } from "forge-std/console.sol";

// scripts
import { BaseDevScript } from "dev/BaseDevScript.s.sol";
import { DevConfig } from "dev/DevConfig.s.sol";

// interfaces
import { IERC721 } from "@openzeppelin/interfaces/IERC721.sol";
import { IERC721Metadata } from "@openzeppelin/token/ERC721/extensions/IERC721Metadata.sol";
import { IERC20 } from "@openzeppelin/interfaces/IERC20.sol";

/**
 * @notice Grants the OrderEngine the approvals it needs to settle trades:
 *         `setApprovalForAll` on every NFT collection and max WETH allowance for the allowance spender.
 */
contract Approve is BaseDevScript, DevConfig {
    /**
     * @notice Approves NFT transfer auth + WETH allowance spender for a single participant.
     *         Run one process per participant in parallel (each passing its own `participantIdx`
     *         via `--sig`) instead of looping over every participant sequentially in-process.
     * @param participantIdx Raw mnemonic index of the participant.
     */
    function run(uint256 participantIdx) external {
        // --------------------------------
        // LOAD CONFIG
        // --------------------------------

        address weth = readWeth();

        address nftTransferAuth = readNftTransferAuth();
        address allowanceSpender = readAllowanceSpender();

        address[] memory collections = readCollections();

        uint256 participantPk = pkAtMnemonicIndex(participantIdx);
        address owner = addrOf(participantPk);

        // --------------------------------
        // BROADCAST
        // --------------------------------

        vm.startBroadcast(participantPk);

        for (uint256 i = 0; i < collections.length; i++) {
            IERC721(collections[i]).setApprovalForAll(nftTransferAuth, true);
        }

        IERC20(weth).approve(allowanceSpender, type(uint256).max);

        vm.stopBroadcast();

        console.log(
            "owner %s | approved %s collections | weth allowance: unlimited",
            owner,
            collections.length
        );
    }
}
