// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

// core libraries
import {OrderModel} from "orderbook/libs/OrderModel.sol";
import {SignatureOps as SigOps} from "orderbook/libs/SignatureOps.sol";

// periphery libraries
import {OrderBuilder} from "periphery/builders/OrderBuilder.sol";

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
    uint256 constant MIN_OFFSET_DATES = 2;

    // ctx
    uint256 private epoch;
    uint256 private epochSize;

    // === ENTRYPOINTS ===

    function run(uint256 _epoch, uint256 _epochSize) external {
        // === LOAD CONFIG & SETUP ===

        address settlementContract = readSettlementContract();
        address weth = readWeth();

        bytes32 domainSeparator = ISettlementEngine(settlementContract)
            .DOMAIN_SEPARATOR();

        _loadParticipants();

        epoch = _epoch;
        epochSize = _epochSize;

        logSection("BUILD ORDERS");
        console.log("Epoch: %s", epoch);
        logSeparator();

        address[] memory collections = readCollections();
        console.log("Collections: %s", collections.length);

        // === BUILD ORDERS ===

        OrderModel.Order[] memory orders = _buildOrders(weth, collections);

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
        string memory fileName = string.concat(vm.toString(epoch), ".json");
        ordersToJson(signed, string.concat(ordersJsonDir(), fileName));

        logSeparator();
        console.log(
            "Epoch %s ready with %s signed orders!",
            epoch,
            signed.length
        );
        logSeparator();
    }

    function _buildOrders(
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
            weth
        );

        idx = _appendOrders(
            orders,
            idx,
            OrderModel.Side.Bid,
            false,
            selectionBids,
            weth
        );

        _appendOrders(
            orders,
            idx,
            OrderModel.Side.Bid,
            true,
            selectionCbs,
            weth
        );
    }

    function _appendOrders(
        OrderModel.Order[] memory orders,
        uint256 idx,
        OrderModel.Side side,
        bool isCollectionBid,
        Selection[] memory selections,
        address currency
    ) internal view returns (uint256) {
        for (uint256 i; i < selections.length; i++) {
            Selection memory sel = selections[i];
            for (uint256 j; j < sel.tokenIds.length; j++) {
                uint256 orderIdx = i + j;

                address collection = sel.collection;
                uint256 tokenId = !isCollectionBid ? sel.tokenIds[j] : 0;

                orders[idx++] = _buildOrder(
                    side,
                    isCollectionBid,
                    collection,
                    tokenId,
                    currency,
                    orderIdx
                );
            }
        }
        return idx;
    }

    function _buildOrder(
        OrderModel.Side side,
        bool isCollectionBid,
        address collection,
        uint256 tokenId,
        address currency,
        uint256 orderIdx
    ) internal view returns (OrderModel.Order memory order) {
        uint256 seed = orderSalt(side, isCollectionBid, collection, orderIdx);

        address actor = _resolveActor(
            side,
            isCollectionBid,
            collection,
            tokenId,
            seed
        );

        // annoying stack too deep...
        // (uint64 start, uint64 end) = _resolveDates(seed);

        order = OrderBuilder.build(
            side,
            isCollectionBid,
            collection,
            tokenId,
            currency,
            orderPrice(collection, tokenId, seed),
            actor,
            0,
            1,
            orderNonce(seed, orderIdx)
        );
    }

    function _resolveDates(
        uint256 seed
    ) internal view returns (uint64 start, uint64 end) {
        uint256 offset = (seed % epochSize) + MIN_OFFSET_DATES;
        uint256 epochAnchor = block.timestamp + (epoch * epochSize);

        // casting to 'uint64' is safe because start is a date
        // forge-lint: disable-next-line(unsafe-typecast)
        start = uint64(epochAnchor - offset);

        // forge-lint: disable-next-line(unsafe-typecast)
        end = uint64(epochAnchor + offset);
    }

    function _resolveActor(
        OrderModel.Side side,
        bool isCollectionBid,
        address collection,
        uint256 tokenId,
        uint256 seed
    ) internal view returns (address) {
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
}
