// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {Test} from "forge-std/Test.sol";
import {Config} from "forge-std/Config.sol";
import {console} from "forge-std/console.sol";

// local contracts
import {OrderEngine} from "orderbook/OrderEngine.sol";

interface IERC721 {
    function setApprovalForAll(address operator, bool approved) external;
}

contract Setup is Script, Config, Test {
    OrderEngine public orderEngine;

    function run() external {
        string memory path = "myfile.txt";
        assertTrue(vm.exists(path));
        /*
        _loadConfig("../../deployments.toml", true);

        uint chainId = block.chainid;
        console.log("Deploying to chain: ", chainId);

        // config addresses
        address bayc = config.get("bayc").toAddress();
        console.log(bayc);

        vm.startBroadcast();
        orderEngine = new OrderEngine();
        vm.stopBroadcast();

        console.log("\nEngine Deployed: ");
        console.logAddress(address(orderEngine));

        console.log(
            "\nDeployment complete! Addresses saved to deployments.toml"
        );
        */
    }
}
