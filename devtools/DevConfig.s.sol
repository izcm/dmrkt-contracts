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
// These are intentionally split into separate accessors to allow role separation later.

/**
 * @title DevConfig
 * @notice Centralizes all reads of pipeline.toml.
 *
 * @dev Reads from pipeline.toml via forge-std Config.
 *
 * Expected keys in pipeline.toml:
 *   - `order_engine`        — address implementing `settle` entrypoint
 *   - `weth`                — address of weth
 *   - `pipeline_start_ts`   — timestamp of fork start block
 *   - `pipeline_end_ts`     — end of pipeline window (start_ts + (epoch * epoch_size))
 *   - `nft_c_count`         — the count of deployed nft-collections, needed for iteration
 *   - `nft_c_{i}`           — address of the ith nft-collection where i < nft_c_count
 *
 * Extend this contract in any script that needs values from pipeline.toml.
 */

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
            nfts[i] = config
                .get(string.concat("nft_c_", vm.toString(i)))
                .toAddress();
        }
        return nfts;
    }

    function _orderEngine() private view returns (address) {
        return config.get("order_engine").toAddress();
    }
}
