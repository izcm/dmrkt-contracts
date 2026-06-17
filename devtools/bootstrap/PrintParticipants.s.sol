// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {BaseDevScript} from "dev/BaseDevScript.s.sol";
import {console} from "forge-std/console.sol";

/**
 * @notice Prints pipeline participants. Run before bootstrapping.
 */
contract PrintParticipants is BaseDevScript {
    function run() external view {
        uint256[] memory pks = generateKeys();

        console.log("PIPELINE PARTICIPANTS");
        console.log("--------------------");
        for (uint256 i = 0; i < pks.length; i++) {
            console.log("P%s | %s", i + 1, addrOf(pks[i]));
        }
        console.log("--------------------");
    }
}
