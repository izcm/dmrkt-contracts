// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

// core libraries
import {OrderModel} from "orderbook/libs/OrderModel.sol";
import {SignatureOps as SigOps} from "orderbook/libs/SignatureOps.sol";

// scripts
import {BaseDevScript} from "dev/BaseDevScript.s.sol";
import {DevConfig} from "dev/DevConfig.s.sol";

import {OrderSampling} from "dev/logic/OrderSampling.s.sol";
import {OrderSnapshot} from "dev/logic/OrderSnapshot.s.sol";
import {SettlementSigner} from "dev/logic/SettlementSigner.s.sol";

// types
import {SignedOrder, Selection} from "dev/state/Types.sol";

// interfaces
import {ISettlementEngine} from "periphery/interfaces/ISettlementEngine.sol";
import {IERC20, SafeERC20} from "@openzeppelin/token/ERC20/utils/SafeERC20.sol";

// logging
import {console} from "forge-std/console.sol";

contract SettleHistory is
    OrderSampling,
    OrderSnapshot,
    SettlementSigner,
    BaseDevScript,
    DevConfig
{
    using SafeERC20 for IERC20;
    using OrderModel for OrderModel.Order;

    // ctx
    uint256 private weekIdx;

    // contract addresses (TODO: move this in init OrderFill.s.sol)

    // === ENTRYPOINTS ===

    function runWeek(uint256 _weekIdx) external {
        // === LOAD CONFIG & SETUP ===

        address settlementContract = readSettlementContract();
        address weth = readWeth();

        bytes32 domainSeparator = ISettlementEngine(settlementContract)
            .DOMAIN_SEPARATOR();

        _loadParticipants();

        weekIdx = _weekIdx;
        _jumpToWeek();

        logSection("SETTLE HISTORY");
        console.log("Week: %s", weekIdx);
        logSeparator();

        address[] memory collections = readCollections();
        console.log("Collections: %s", collections.length);

        // === BUILD ORDERS ===

        OrderModel.Order[] memory orders = _buildOrders(
            settlementContract,
            weth,
            collections
        );

        // === SIGN ORDERS ===

        logSection("SIGNING");

        SignedOrder[] memory signed = new SignedOrder[](orders.length);

        for (uint256 i = 0; i < orders.length; i++) {
            SigOps.Signature memory sig = signOrder(
                domainSeparator,
                orders[i],
                pkOf(orders[i].actor)
            );

            signed[i] = SignedOrder(orders[i], sig);
        }

        console.log("Orders signed: %s", signed.length);

        // === ORDER BY NONCE ===

        _sortByNonce(signed);

        console.log("Sorting by nonce completed");

        logSeparator();
        console.log(
            "Week %s ready with %s signed orders!",
            weekIdx,
            signed.length
        );
        logSeparator();

        // === FULFILL OR EXPORT ===

        if (_isFinalWeek()) {
            // export as JSON
            persistSignedOrders(signed, _jsonFilePath());
        } else {
            // match each mode with a fill
            _produceFills(orders);
            // broadcast as fill.actor
            // call settle
        }
    }

    function finalize() external {
        _jumpToNow();
    }

    function _produceFills(OrderModel.Order[] memory orders) internal view {
        OrderModel.Fill[] memory fills = new OrderModel.Fill[](orders.length);

        address allowanceSpender = readAllowanceSpender();

        for (uint256 i = 0; i < orders.length; i++) {
            OrderModel.Order memory order = orders[i];

            fills[i] = _produceFill(order);

            uint256 allowance = IERC20(order.currency).allowance(
                fills[i].actor,
                allowanceSpender
            );

            require(allowance > order.price, "Allowance too low");
        }
    }

    // TODO: seperate fillOrder** functionality to own abstract contracts
    function _produceFill(
        OrderModel.Order memory order
    ) internal view returns (OrderModel.Fill memory) {
        if (order.isAsk()) {
            return _fillAsk(order.actor, order.nonce);
        } else if (order.isBid()) {
            return _fillBid(order);
        } else {
            revert("Invalid Order Side");
        }
    }

    function _fillBid(
        OrderModel.Order memory order
    ) internal view returns (OrderModel.Fill memory) {
        if (order.isCollectionBid) {
            return _fillCollectionBid(order.collection, order.nonce);
        } else {
            return
                _fillRegularBid(order.collection, order.tokenId, order.nonce);
        }
    }

    function _fillAsk(
        address orderActor,
        uint256 seed
    ) internal view returns (OrderModel.Fill memory) {
        return
            OrderModel.Fill({
                tokenId: 0,
                actor: otherParticipant(orderActor, seed)
            });
    }

    function _fillRegularBid(
        address collection,
        uint256 tokenId,
        uint256 seed
    ) internal view returns (OrderModel.Fill memory) {}

    function _fillCollectionBid(
        address collection,
        uint256 seed
    ) internal view returns (OrderModel.Fill memory) {}

    function _buildOrders(
        address settlementContract,
        address weth,
        address[] memory collections
    ) internal view returns (OrderModel.Order[] memory orders) {
        Selection[] memory selectionAsks = collect(
            OrderModel.Side.Ask,
            false,
            collections,
            weekIdx
        );
        Selection[] memory selectionBids = collect(
            OrderModel.Side.Bid,
            false,
            collections,
            weekIdx
        );
        Selection[] memory selectionCbs = collect(
            OrderModel.Side.Bid,
            true,
            collections,
            weekIdx
        );

        uint256 count;
        for (uint256 i; i < selectionAsks.length; i++) {
            count += selectionAsks[i].tokenIds.length;
        }
        for (uint256 i; i < selectionBids.length; i++) {
            count += selectionBids[i].tokenIds.length;
        }
        for (uint256 i; i < selectionCbs.length; i++) {
            count += selectionCbs[i].tokenIds.length;
        }

        orders = new OrderModel.Order[](count);
        uint256 idx;

        idx = _appendOrders(
            orders,
            idx,
            OrderModel.Side.Ask,
            false,
            selectionAsks,
            weth,
            settlementContract
        );

        idx = _appendOrders(
            orders,
            idx,
            OrderModel.Side.Bid,
            false,
            selectionBids,
            weth,
            settlementContract
        );

        _appendOrders(
            orders,
            idx,
            OrderModel.Side.Bid,
            true,
            selectionCbs,
            weth,
            settlementContract
        );
    }

    function _appendOrders(
        OrderModel.Order[] memory orders,
        uint256 idx,
        OrderModel.Side side,
        bool isCollectionBid,
        Selection[] memory selections,
        address weth,
        address settlementContract
    ) internal view returns (uint256) {
        for (uint256 i; i < selections.length; i++) {
            Selection memory sel = selections[i];
            for (uint256 j; j < sel.tokenIds.length; j++) {
                orders[idx++] = makeOrder(
                    side,
                    isCollectionBid,
                    sel.collection,
                    sel.tokenIds[j],
                    weth,
                    settlementContract
                );
            }
        }
        return idx;
    }

    function _sortByNonce(SignedOrder[] memory arr) internal pure {
        uint256 n = arr.length;

        for (uint256 i = 1; i < n; i++) {
            SignedOrder memory key = arr[i];
            uint256 keyNonce = key.order.nonce;

            uint256 j = i;
            while (j > 0 && arr[j - 1].order.nonce > keyNonce) {
                arr[j] = arr[j - 1];
                j--;
            }

            arr[j] = key;
        }
    }

    // === TIME HELPERS ===

    function _jumpToWeek() internal {
        uint256 startTs = readStartTs();
        vm.warp(startTs + (weekIdx * 7 days));
    }

    function _jumpToNow() internal {
        vm.warp(readNowTs());
    }

    // === PRIVATE ===

    function _isFinalWeek() private view returns (bool) {
        return weekIdx == 4;
        // config.get("final_week_idx").toUint256();
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
