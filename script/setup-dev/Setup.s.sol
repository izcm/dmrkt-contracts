// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script} from "forge-std/Script.sol";
import {Config} from "forge-std/Config.sol";
import {console} from "forge-std/console.sol";

// local
import {BaseDevScript} from "dev-script/BaseDevScript.s.sol";
import {OrderEngine} from "orderbook/OrderEngine.sol";

// TODO: cryptopunks is not erc721 compatible, custom wrapper l8r?
interface IERC721 {
    function setApprovalForAll(address operator, bool approved) external;
    function ownerOf(uint256 tokenId) external;
}

contract Setup is BaseDevScript, Config {
    OrderEngine public orderEngine;

    function run() external {
        _loadConfig("deployments.toml", true);

        uint256 chainId = block.chainid;
        console.log("Deploying to chain: %s", chainId);

        address baycAddr = config.get("bayc_addr").toAddress();
        console.log(baycAddr);

        (uint256[] memory ids, uint256 count) = selectTokens(baycAddr, 10, 2);

        vm.startBroadcast();
        orderEngine = new OrderEngine();
        vm.stopBroadcast();

        // TODO: write the addr back to development.toml
        console.log("\nEngine Deployed: %s", address(orderEngine));

        console.log(
            "\nDeployment complete! Addresses saved to deployments.toml"
        );
    }

    function readOwnerOf(address tokenContract, uint256 tokenId) internal {
        IERC721(tokenContract).ownerOf(tokenId);
        console.log("Owner of token %s", tokenId);
    }
}
