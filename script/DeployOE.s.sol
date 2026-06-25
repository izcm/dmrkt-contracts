// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "forge-std/Script.sol";
import { OrderEngine } from "orderbook/OrderEngine.sol";

contract DeployOrderEngine is Script {
    function run(address whitelistedCurrency) external returns (OrderEngine deployed) {
        vm.startBroadcast();

        deployed = new OrderEngine(
            whitelistedCurrency,
            msg.sender // msg.sender receives protocol fees
        );

        vm.stopBroadcast();

        console2.log("Engine deployed at: ", address(deployed));
    }
}
