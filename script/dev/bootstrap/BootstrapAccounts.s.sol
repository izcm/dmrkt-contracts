// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Config} from "forge-std/Config.sol";
import {console} from "forge-std/console.sol";

// local
import {BaseDevScript} from "dev/BaseDevScript.s.sol";

// interfaces
import {IWETH} from "shared/interfaces/IWETH.sol";

contract BootstrapAccounts is BaseDevScript, Config {
    function run() external {
        // --------------------------------
        // PHASE 0: LOAD CONFIG
        // --------------------------------
        _loadConfig("deployments.toml", true);

        logSection("LOAD CONFIG");

        uint256 chainId = block.chainid;

        console.log("ChainId: %s", chainId);

        // read deployments.toml
        address funder = config.get("funder").toAddress();
        address weth = config.get("weth").toAddress();

        // read .env
        uint256 funderPk = uint256(uint256(vm.envUint("PRIVATE_KEY")));

        // --------------------------------
        // PHASE 1: FUND ETH
        // --------------------------------
        logSection("BOOTSTRAP DEV ACCOUNTS");
        console.log("------------------------------------");
        console.log("FUNDER");
        console.log("ADDR  | %s", funder);
        console.log("BAL   | %s", funder.balance);
        console.log("------------------------------------");

        uint256 distributableEth = (funder.balance * 4) / 5;

        // --- PKs for broadcasting ---

        // TODO: replace dev PKs with mnemonic-derived keys
        // https://getfoundry.sh/reference/cheatcodes/derive-key
        uint256[] memory participantPks = readKeys(chainId);
        uint256 participantCount = participantPks.length;

        // amount to fund each account
        uint256 bootstrapEth = distributableEth / participantCount;

        vm.startBroadcast(funderPk);

        for (uint256 i = 0; i < participantCount; i++) {
            address a = addrOf(participantPks[i]);

            logBalance("PRE ", a);

            (bool ok, ) = payable(a).call{value: bootstrapEth}("");

            if (!ok) {
                console.log("TRANSFER FAILED -> %s", a);
            } else {
                logBalance("POST", a);
            }

            logSeparator();
        }

        vm.stopBroadcast();

        // --------------------------------
        // PHASE 2: WRAP ETH
        // --------------------------------
        logSection("WRAP ETH => WETH");

        uint256 wethWrapAmount = bootstrapEth / 2;
        IWETH wethToken = IWETH(weth);

        for (uint256 i = 1; i < participantCount; i++) {
            address a = addrOf(participantPks[i]);
            logTokenBalance("PRE  WETH", a, wethToken.balanceOf(a));

            vm.startBroadcast(participantPks[i]);
            wethToken.deposit{value: wethWrapAmount}();
            vm.stopBroadcast();

            logTokenBalance("POST WETH", a, wethToken.balanceOf(a));

            logSeparator();
        }
    }
}
