// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

// core libraries
import {OrderModel} from "orderbook/libs/OrderModel.sol";
import {SignatureOps as SigOps} from "orderbook/libs/SignatureOps.sol";

// scripts
import {BaseDevScript} from "dev/BaseDevScript.s.sol";
import {DevConfig} from "dev/DevConfig.s.sol";

import {OrderSampling} from "dev/logic/OrderSampling.s.sol";
import {OrdersJson} from "dev/logic/OrdersJson.s.sol";
import {SettlementSigner} from "dev/logic/SettlementSigner.s.sol";

// types
import {SignedOrder, Selection} from "dev/state/Types.sol";

// interfaces
import {ISettlementEngine} from "periphery/interfaces/ISettlementEngine.sol";
import {IERC721} from "periphery/interfaces/DNFT.sol";

// logging
import {console} from "forge-std/console.sol";

contract BuildHistory is
    OrderSampling,
    SettlementSigner,
    OrdersJson,
    BaseDevScript,
    DevConfig
{
    // ctx
    uint256 private epoch;

    // === ENTRYPOINTS ===

    function runWeek(uint256 _epoch) external {
        // === LOAD CONFIG & SETUP ===

        address settlementContract = readSettlementContract();
        address weth = readWeth();

        bytes32 domainSeparator = ISettlementEngine(settlementContract)
            .DOMAIN_SEPARATOR();

        _loadParticipants();

        epoch = _epoch;

        logSection("BUILD ORDERS");
        console.log("Epoch: %s", epoch);
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

            signed[i] = SignedOrder({order: orders[i], sig: sig});
        }

        console.log("Orders signed: %s", signed.length);

        // === ORDER BY NONCE ===

        _sortByNonce(signed);

        console.log("Sorting by nonce completed");

        // === EXPORT AS JSON ===
        ordersToJson(signed, _jsonFilePath());

        logSeparator();
        console.log(
            "Epoch %s ready with %s signed orders!",
            epoch,
            signed.length
        );
        logSeparator();
    }

    function _buildOrders(
        address settlementContract,
        address weth,
        address[] memory collections
    ) internal view returns (OrderModel.Order[] memory orders) {
        Selection[] memory selectionAsks = collect(
            OrderModel.Side.Ask,
            false,
            collections,
            epoch
        );
        Selection[] memory selectionBids = collect(
            OrderModel.Side.Bid,
            false,
            collections,
            epoch
        );
        Selection[] memory selectionCbs = collect(
            OrderModel.Side.Bid,
            true,
            collections,
            epoch
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
                uint256 tokenId = !isCollectionBid ? sel.tokenIds[j] : 0;

                address actor = _resolveActor(
                    side,
                    isCollectionBid,
                    sel.collection,
                    tokenId
                );

                orders[idx++] = makeOrder(
                    side,
                    isCollectionBid,
                    sel.collection,
                    tokenId,
                    weth,
                    actor,
                    settlementContract,
                    j + i
                );
            }
        }
        return idx;
    }

    function _resolveActor(
        OrderModel.Side side,
        bool isCollectionBid,
        address collection,
        uint256 tokenId
    ) internal view returns (address) {
        uint256 seed = orderSalt(side, isCollectionBid, collection, epoch);

        if (isCollectionBid) {
            address[] memory ps = participants();
            return ps[seed % ps.length];
        } else {
            address nftHolder = IERC721(collection).ownerOf(tokenId);
            return
                side == OrderModel.Side.Ask
                    ? nftHolder
                    : otherParticipant(nftHolder, seed);
        }
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

    // === PRIVATE ===

    function _jsonFilePath() private view returns (string memory) {
        return
            string.concat(
                "./data/",
                vm.toString(block.chainid),
                "/orders-raw.",
                vm.toString(epoch),
                ".json"
            );
    }
}
