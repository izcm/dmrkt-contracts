// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

// core contracts
import { OrderEngine } from "orderbook/OrderEngine.sol";

// periphery contracts
import { DMrktLoot } from "nfts/DMrktLoot.sol";

// scripts
import { BaseDevScript } from "dev/BaseDevScript.s.sol";
import { DevConfig } from "dev/DevConfig.s.sol";

/**
 * @notice Deploys `OrderEngine` and `DMrktLoot` to the local fork, then writes their
 *         addresses to `pipeline.toml` (for Solidity scripts) and `data/{chainId}/state/pipeline.env`
 *         (for bash scripts — a flat `KEY=value` file, source-able without a TOML parser).
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

        uint256 deployerPk = vm.envOr("DEPLOYER_PK", generateKeys()[0]);

        // --------------------------------
        // DEPLOY MARKETPLACE & NFTS
        // --------------------------------

        logSection("DEPLOY CORE CONTRACTS");

        logAddress("Deployer", addrOf(deployerPk));

        vm.startBroadcast(deployerPk);

        // deploy core
        OrderEngine orderEngine = new OrderEngine(weth, msg.sender);

        // deploy nfts
        DMrktLoot inventory = new DMrktLoot();

        vm.stopBroadcast();

        // log deployments
        logDeployment("OrderEngine", address(orderEngine));

        logDeployment("DMrktLoot  ", address(inventory));
        // logDeployment("DMrktDragonEggs", address(eggs));

        // --------------------------------
        // WRITE TO .TOML
        // --------------------------------

        config.set("order_engine", address(orderEngine));
        config.set("nft_c_0", address(inventory));

        config.set("nft_c_count", NFT_COUNT);

        // --------------------------------
        // WRITE FLAT ENV FILE (for bash scripts — avoids needing a TOML parser there)
        // --------------------------------

        string memory envDir = string.concat("./data/", vm.toString(block.chainid), "/state/");
        vm.createDir(envDir, true);

        string memory envContent = string.concat(
            "WETH=",
            vm.toString(weth),
            "\n",
            "ORDER_ENGINE=",
            vm.toString(address(orderEngine)),
            "\n",
            "NFT_C_0=",
            vm.toString(address(inventory)),
            "\n",
            "NFT_C_COUNT=",
            vm.toString(NFT_COUNT),
            "\n"
        );

        vm.writeFile(string.concat(envDir, "pipeline.env"), envContent);
    }
}
