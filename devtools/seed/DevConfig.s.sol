// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Config} from "forge-std/Config.sol";

// TODO: https://getfoundry.sh/reference/cheatcodes/write-toml/
// learn about json nesting in .toml

// NOTE:
// order_engine currently fulfills multiple roles:
// - settlement engine
// - signature verifier
// - nft transfer authority
// - allowance spender
// These are intentionally split into separate accessors
// to allow role separation later without refactoring scripts.
contract DevConfig is Config {
    constructor() {
        _loadConfig("pipeline.toml", true);
    }

    function readWeth() internal view returns (address) {
        return config.get("weth").toAddress();
    }

    // contract implementing methods `settle` `DOMAIN_SEPARATOR()` and `isUserNonceInvalid()`
    function readSettlementContract() internal view returns (address) {
        return _orderEngine();
    }

    // contract implementing signature verification
    function readSignatureVerifier() internal view returns (address) {
        return _orderEngine();
    }

    // contract working as the nft transferer
    // if multiple strategies: readNftTransferAuth(strategyId)
    function readNftTransferAuth() internal view returns (address) {
        return _orderEngine();
    }

    // if multiple strategies: readAllowanceSpender(strategyId)
    function readAllowanceSpender() internal view returns (address) {
        return _orderEngine();
    }

    function readStartTs() internal view returns (uint256) {
        return config.get("pipeline_start_ts").toUint256();
    }

    function readEndTs() internal view returns (uint256) {
        return config.get("pipeline_end_ts").toUint256();
    }

    function readCollections() internal view returns (address[] memory) {
        uint256 count = config.get("nft_c_count").toUint256();
        address[] memory nfts = new address[](count);
        for (uint256 i; i < count; i++) {
            nfts[i] = config.get(string.concat("nft_c_", vm.toString(i))).toAddress();
        }
        return nfts;
    }

    function _orderEngine() private view returns (address) {
        return config.get("order_engine").toAddress();
    }
}
