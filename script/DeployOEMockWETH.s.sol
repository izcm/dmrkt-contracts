// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "forge-std/Script.sol";
import {OrderEngine} from "orderbook/OrderEngine.sol";
import {MockWETH} from "mocks/MockWETH.sol";

contract DeployOrderEngineMockWETH is Script {
    function run() external returns (OrderEngine deployed) {
        vm.startBroadcast();

        MockWETH mockWeth = new MockWETH();

        deployed = new OrderEngine(
            address(mockWeth),
            msg.sender // msg.sender receives protocol fees
        );

        vm.stopBroadcast();

        console2.log("MockWETH deployed at: ", address(mockWeth));
        console2.log("Engine deployed at:   ", address(deployed));
    }
}
