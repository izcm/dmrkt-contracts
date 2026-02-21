// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "forge-std/Script.sol";
import {OrderEngine} from "orderbook/OrderEngine.sol";

contract DeployOrderEngine is Script {
    function run() external returns (OrderEngine deployed) {
        vm.startBroadcast();

        // TODO: fix args
        deployed = new OrderEngine(
            0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2,
            msg.sender
        );

        vm.stopBroadcast();

        console2.log("Engine created at address: ", address(deployed));
    }
}
