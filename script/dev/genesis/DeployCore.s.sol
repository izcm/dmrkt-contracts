// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

// core contracts
import {OrderEngine} from "orderbook/OrderEngine.sol";

// periphery contracts
import {DMrktGremlin} from "nfts/DMrktGremlin.ERC721.sol";
import {DMrktSeal} from "nfts/DMrktSeal.ERC721.sol";

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
        uint256 funderPk = uint256(uint256(vm.envUint("PRIVATE_KEY")));

        // --------------------------------
        // PHASE 1: DEPLOY MARKETPLCE & NFTS
        // --------------------------------
        logSection("DEPLOY CORE CONTRACTS");

        // since the script uses the same private key its not necessary but I like to be explicit
        vm.startBroadcast(funderPk);

        // deploy core
        OrderEngine orderEngine = new OrderEngine(weth, msg.sender);

        // deploy periphery
        DMrktGremlin gremlin = new DMrktGremlin();
        DMrktSeal seal = new DMrktSeal();

        vm.stopBroadcast();

        // log deployments
        logDeployment("OrderEngine", address(orderEngine));

        logDeployment("DMrktGremlin", address(gremlin));
        logDeployment("DMrktSeal", address(seal));

        // --------------------------------
        // PHASE 2: WRITE TO .TOML
        // --------------------------------

        config.set("order_engine", address(orderEngine));

        // === DEPLOYED PERIPHERY NFTs ===

        config.set("nft_0", address(gremlin));
        config.set("nft_1", address(seal));

        config.set("nft_count", NFT_COUNT);
    }
}
