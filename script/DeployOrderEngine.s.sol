// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import { OrderEngine } from "orderbook/OrderEngine.sol";

contract DeployOrderEngine is Script {
    function run() external returns (OrderEngine deployed) {
        vm.startBroadcast();
        deployed = new OrderEngine();
        vm.stopBroadcast();
    }
}