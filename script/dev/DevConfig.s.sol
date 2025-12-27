// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Config} from "forge-std/Config.sol";

// TODO: https://getfoundry.sh/reference/cheatcodes/write-toml/
// learn about json nesting in .toml

contract DevConfig is Config {
    constructor() {
        _loadConfig("deployments.toml", true);
    }

    function readWeth() internal view returns (address) {
        return config.get("weth").toAddress();
    }

    function readFunder() internal view returns (address) {
        return config.get("funder").toAddress();
    }

    // contract implementing methods `DOMAIN_SEPARATOR()` and `isUserNonceInvalid()`
    function readSettlementContract() internal view returns (address) {
        return config.get("order_engine").toAddress();
    }

    // contract implementing signature verification
    function readSignatureVerifier() internal view returns (address) {
        return config.get("order_engine").toAddress();
    }

    // contract working as the nft transferer
    function readNftTransferAuth() internal view returns (address) {
        return config.get("order_engine").toAddress();
    }

    function readAllowanceSpender() internal view returns (address) {
        return config.get("order_engine").toAddress();
    }

    function readStartTs() internal view returns (uint256) {
        return config.get("history_start_ts").toUint256();
    }

    function readNowTs() internal view returns (uint256) {
        return config.get("now_ts").toUint256();
    }

    function readCollections() internal view returns (address[] memory) {
        uint256 count = config.get("nft_count").toUint256();
        address[] memory nfts = new address[](count);
        for (uint256 i; i < count; i++) {
            nfts[i] = config
                .get(string.concat("nft_", vm.toString(i)))
                .toAddress();
        }
        return nfts;
    }
}
