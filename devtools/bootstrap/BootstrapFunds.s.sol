// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

// local
import {BaseDevScript} from "dev/BaseDevScript.s.sol";
import {DevConfig} from "dev/DevConfig.s.sol";
import {console} from "forge-std/console.sol";

// interfaces
import {IWETH} from "periphery/interfaces/IWETH.sol";

/**
 * @notice Wraps half of each participant's ETH balance into WETH so they have
 *         liquid bid collateral for the pipeline.
 * @dev    Participants are funded with ETH at fork startup via Anvil's `--mnemonic` flag.
 *         This script runs after fork start and before `Approve`.
 */
contract BootstrapFunds is BaseDevScript, DevConfig {
    function run() external {
        // --------------------------------
        // LOAD CONFIG
        // --------------------------------

        address weth = readWeth();
        uint256[] memory participantPks = generateKeys();
        uint256 participantCount = participantPks.length;

        // --------------------------------
        // WRAP ETH
        // --------------------------------

        logSection("WRAP ETH => WETH");

        IWETH wethToken = IWETH(weth);

        for (uint256 i = 0; i < participantCount; i++) {
            address a = addrOf(participantPks[i]);
            console.log(
                "PRE  WETH | P%s | balance: %s",
                i + 1,
                wethToken.balanceOf(a)
            );

            vm.startBroadcast(participantPks[i]);
            uint256 wethWrapAmount = a.balance / 2; // wraps half of eth balance to weth
            wethToken.deposit{value: wethWrapAmount}();
            vm.stopBroadcast();

            console.log(
                "POST WETH | P%s | balance: %s",
                i + 1,
                wethToken.balanceOf(a)
            );
        }
    }
}
