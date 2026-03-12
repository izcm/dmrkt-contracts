// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

// core contracts
import {OrderEngine} from "orderbook/OrderEngine.sol";

// periphery contracts
import {DMrktLoot} from "nfts/DMrktLoot.sol";
import {DMrktDragonEggs} from "nfts/DMrktDragonEggs.sol";

// scripts
import {BaseDevScript} from "dev/BaseDevScript.s.sol";
import {DevConfig} from "dev/DevConfig.s.sol";

contract DeployCore is BaseDevScript, DevConfig {
    uint256 constant NFT_COUNT = 2;

    function run() external {
        // --------------------------------
        // PHASE 0: LOAD CONFIG
        // --------------------------------
        address weth = readWeth();
        uint256 funderPk = uint256(uint256(vm.envUint("FUNDER_PK")));

        // --------------------------------
        // PHASE 1: DEPLOY MARKETPLCE & NFTS
        // --------------------------------

        // TODO: make someone else than funder deploy these contracts
        // if we have our own random adress (not default anvil user) nonce stays same
        // => deterministic addresses
        logSection("DEPLOY CORE CONTRACTS");

        // since the script uses the same private key its not necessary but I like to be explicit
        vm.startBroadcast(funderPk);

        // deploy core
        OrderEngine orderEngine = new OrderEngine(weth, msg.sender);

        // deploy nfts
        DMrktLoot inventory = new DMrktLoot();
        DMrktDragonEggs eggs = new DMrktDragonEggs();

        vm.stopBroadcast();

        // log deployments
        logDeployment("OrderEngine", address(orderEngine));

        logDeployment("DMrktLoot", address(inventory));
        logDeployment("DMrktDragonEggs", address(eggs));

        // --------------------------------
        // PHASE 2: WRITE TO .TOML
        // --------------------------------

        config.set("order_engine", address(orderEngine));

        // === DEPLOYED PERIPHERY NFTs ===

        config.set("nft_c_0", address(inventory));
        config.set("nft_c_1", address(eggs));

        config.set("nft_c_count", NFT_COUNT);
    }
}
