// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

// local
import { BaseDevScript } from "dev/BaseDevScript.s.sol";
import { DevConfig } from "dev/DevConfig.s.sol";
import { console } from "forge-std/console.sol";

// interfaces
import { IWETH } from "periphery/interfaces/IWETH.sol";

contract BootstrapFunds is BaseDevScript, DevConfig {
    /**
     * @notice Wraps half of a single participant's ETH balance into WETH. Run one process
     *         per participant in parallel (each passing its own `participantIdx` via `--sig`)
     *         instead of looping over every participant sequentially in-process.
     * @param participantIdx Raw mnemonic index of the participant.
     */
    function run(uint256 participantIdx) external {
        // --------------------------------
        // LOAD CONFIG
        // --------------------------------

        address weth = readWeth();
        uint256 participantPk = pkAtMnemonicIndex(participantIdx);
        address a = addrOf(participantPk);

        // --------------------------------
        // WRAP ETH
        // --------------------------------

        IWETH wethToken = IWETH(weth);

        vm.startBroadcast(participantPk);
        uint256 wethWrapAmount = a.balance / 2; // wraps half of eth balance to weth
        wethToken.deposit{ value: wethWrapAmount }();
        vm.stopBroadcast();

        console.log("wrapped %s wei => weth balance: %s", wethWrapAmount, wethToken.balanceOf(a));
    }
}
