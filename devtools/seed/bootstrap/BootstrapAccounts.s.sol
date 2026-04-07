// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {console} from "forge-std/console.sol";

// local
import {BaseDevScript} from "dev/BaseDevScript.s.sol";
import {DevConfig} from "dev/DevConfig.s.sol";

// interfaces
import {IWETH} from "periphery/interfaces/IWETH.sol";

contract BootstrapAccounts is BaseDevScript, DevConfig {
    function run() external {
        logBlockTimestamp();

        // --------------------------------
        // PHASE 0: LOAD CONFIG
        // --------------------------------

        // read pipeline.toml
        address weth = readWeth();

        // --- PKs for broadcasting ---

        uint256[] memory participantPks = generateKeys();
        uint256 participantCount = participantPks.length;

        // --------------------------------
        // PHASE 2: WRAP ETH
        // --------------------------------
        logSection("WRAP ETH => WETH");

        IWETH wethToken = IWETH(weth);

        for (uint256 i = 0; i < participantCount; i++) {
            address a = addrOf(participantPks[i]);
            logTokenBalance("PRE  WETH", a, wethToken.balanceOf(a));

            vm.startBroadcast(participantPks[i]);
            uint256 wethWrapAmount = a.balance / 2; // wraps half of eth balance to weth
            wethToken.deposit{value: wethWrapAmount}();
            vm.stopBroadcast();

            logTokenBalance("POST WETH", a, wethToken.balanceOf(a));

            logSeparator();
        }
    }
}
