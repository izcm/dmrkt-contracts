// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

// core libraries
import {OrderModel} from "orderbook/libs/OrderModel.sol";
import {SignatureOps as SigOps} from "orderbook/libs/SignatureOps.sol";

// scripts
import {BaseDevScript} from "dev/BaseDevScript.s.sol";
import {DevConfig} from "dev/DevConfig.s.sol";
import {OrderSampling} from "dev/logic/OrderSampling.s.sol";

import {SettlementSigner} from "dev/logic/SettlementSigner.s.sol";

// types
import {SignedOrder, SampleMode} from "dev/state/Types.sol";

// interfaces
import {ISettlementEngine} from "periphery/interfaces/ISettlementEngine.sol";

contract SettleHistory is
    OrderSampling,
    SettlementSigner,
    BaseDevScript,
    DevConfig
{
    // ctx
    uint256 private weekIdx;

    address weth;

    address settlementContract;
    bytes32 domainSeparator;

    SignedOrder[] signed;

    // === ENTRYPOINTS ===

    function runWeek(uint256 _weekIdx) external {
        weekIdx = _weekIdx;
        _bootstrap();
        _jumpToWeek();

        _collect();
        _handleSigned();
    }

    function finalize() external {
        _bootstrap();
        _jumpToNow();
    }

    // === SETUP / ENVIRONMENT ===

    function _bootstrap() internal {
        settlementContract = readSettlementContract();
        weth = readWeth();

        address[] memory collections = readCollections();

        domainSeparator = ISettlementEngine(settlementContract)
            .DOMAIN_SEPARATOR();

        _initOrderSampling(0, settlementContract, weth, 0, collections);
    }

    function _handleSigned() internal {
        if (!_isFinalWeek()) {
            // order by nonce and fulfill
        } else {
            // persistSignedOrders(signed, _jsonFilePath());
            // logSeparator();
            // console.log("ORDERS SAVED TO: %s", path);
            // logSeparator();
        }
    }

    function _collect() internal {
        for (uint256 i = 0; i < uint256(SampleMode.COUNT_); i++) {
            SampleMode mode = SampleMode(i);

            collect(mode);
            _buildAndSignOrders(mode);
        }
    }

    function _buildAndSignOrders(SampleMode mode) internal {
        if (mode == SampleMode.Ask) {
            _buildAndSignOrders(OrderModel.Side.Ask, false);
        } else if (mode == SampleMode.Bid) {
            _buildAndSignOrders(OrderModel.Side.Bid, false);
        } else if (mode == SampleMode.CollectionBid) {
            _buildAndSignOrders(OrderModel.Side.Bid, true);
        } else {
            revert("INVALID MODE");
        }
    }

    function _buildAndSignOrders(
        OrderModel.Side side,
        bool isCollectionBid
    ) internal {
        OrderModel.Order[] memory orders = buildOrders(side, isCollectionBid); // builds the orders stored in `OrderSampling.collectionSelected`

        uint256 count = orders.length;

        // SignedOrder[] memory signed = new SignedOrder[](count);

        for (uint256 i = 0; i < count; i++) {
            OrderModel.Order memory order = orders[i];

            uint256 pk = pkOf(order.actor);
            require(pk != 0, "NO PK FOR ACTOR");

            (SigOps.Signature memory sig) = signOrder(
                domainSeparator,
                order,
                pk
            );

            signed.push(SignedOrder({order: order, sig: sig}));
        }
    }

    // === TIME HELPERS ===

    function _jumpToWeek() internal {
        uint256 startTs = _readStartTS();
        vm.warp(startTs + (weekIdx * 7 days));
    }

    function _jumpToNow() internal {
        vm.warp(config.get("now_ts").toUint256());
    }

    // === PRIVATE ===

    // only this script uses reads timestamp so readers are moved here
    function _readStartTS() private view returns (uint256) {
        return config.get("history_start_ts").toUint256();
    }

    function _isFinalWeek() private view returns (bool) {
        return config.get("final_week_idx").toUint256() == weekIdx;
    }

    function _jsonFilePath() private view returns (string memory) {
        return
            string.concat(
                "./data/",
                vm.toString(block.chainid),
                "/orders-raw.json"
            );
    }
}
