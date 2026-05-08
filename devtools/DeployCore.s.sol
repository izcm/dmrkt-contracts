// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

// core contracts
import {OrderEngine} from "orderbook/OrderEngine.sol";

// periphery contracts
import {DMrktLoot} from "nfts/DMrktLoot.sol";

// scripts
import {BaseDevScript} from "dev/BaseDevScript.s.sol";
import {DevConfig} from "dev/DevConfig.s.sol";

/**
 * @notice Deploys `OrderEngine` and `DMrktLoot` to the local fork, then writes their
 *         addresses to `pipeline.toml` so downstream bootstrap and pipeline scripts can read them.
 * @dev    To add a new collection: deploy it inside the broadcast block, log it with
 *         `logDeployment`, and write it with `config.set("nft_c_N", address(...))` incrementing N.
 *         Bump `NFT_COUNT` to match.
 *
 *         Writes to pipeline.toml:
 *           - `order_engine`  — deployed OrderEngine address
 *           - `nft_c_0`       — deployed DMrktLoot address
 *           - `nft_c_count`   — number of deployed nft collections
 */
contract DeployCore is BaseDevScript, DevConfig {
    uint256 constant NFT_COUNT = 1;

    function run() external {
        // --------------------------------
        // LOAD CONFIG
        // --------------------------------

        address weth = readWeth();
        uint256 funderPk = generateKeys()[0];

        // --------------------------------
        // DEPLOY MARKETPLACE & NFTS
        // --------------------------------

        logSection("DEPLOY CORE CONTRACTS");

        // since the script uses the same private key its not necessary but I like to be explicit
        vm.startBroadcast(funderPk);

        // deploy core
        OrderEngine orderEngine = new OrderEngine(weth, msg.sender);

        // deploy nfts
        DMrktLoot inventory = new DMrktLoot();

        vm.stopBroadcast();

        // log deployments
        logDeployment("OrderEngine", address(orderEngine));

        logDeployment("DMrktLoot", address(inventory));
        // logDeployment("DMrktDragonEggs", address(eggs));

        // --------------------------------
        // WRITE TO .TOML
        // --------------------------------

        config.set("order_engine", address(orderEngine));
        config.set("nft_c_0", address(inventory));

        config.set("nft_c_count", NFT_COUNT);
    }
}
