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
import {SignedOrder, Selection, ActorNonce} from "dev/state/Types.sol";

// interfaces
import {ISettlementEngine} from "periphery/interfaces/ISettlementEngine.sol";
import {IERC721} from "periphery/interfaces/DNFT.sol";

// logging
import {console} from "forge-std/console.sol";

// TODO: freexe timestamps in bootstrap scripts
// warp time properly

contract BuildHistory is
    OrderSampling,
    SettlementSigner,
    OrdersJson,
    BaseDevScript,
    DevConfig
{
    // ctx
    uint256 private epoch;
    uint256 private epochSize;

    mapping(address => uint256) private actorNonceIdx;

    // === ENTRYPOINTS ===

    function run(uint256 _epoch, uint256 _epochSize) external {
        // === LOAD CONFIG & SETUP ===

        address settlementContract = readSettlementContract();
        address weth = readWeth();

        bytes32 domainSeparator = ISettlementEngine(settlementContract)
            .DOMAIN_SEPARATOR();

        _loadParticipants();

        // track userNonces if epoch != 0
        if (_epoch != 0) {
            // read prev epoch userNonces
            ActorNonce[] memory startNonces = noncesFromJson(
                epochNoncesPath(_epoch - 1)
            );
            _importNonces(startNonces);
        }

        epoch = _epoch;
        epochSize = _epochSize;

        logSection("BUILD ORDERS");
        console.log("Block timestamp: %s", block.timestamp);
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

        _sortByEndDate(signed); // TODO: change this when nonces become incremental

        console.log("Sorting by nonce completed");

        // === EXPORT AS JSON ===

        ordersToJson(signed, epochOrdersPath(_epoch));
        noncesToJson(_exportNonces(), epochNoncesPath(_epoch));

        logSeparator();
        console.log(
            "Epoch %s ready with %s signed orders!",
            _epoch,
            signed.length
        );
        logSeparator();
    }

    function _buildOrders(
        address weth,
        address[] memory collections
    ) internal returns (OrderModel.Order[] memory orders) {
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
    ) internal returns (uint256) {
        for (uint256 i; i < selections.length; i++) {
            Selection memory sel = selections[i];
            for (uint256 j; j < sel.tokenIds.length; j++) {
                uint256 orderIdx = idx;
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
    ) internal returns (OrderModel.Order memory order) {
        uint256 seed = (orderIdx << 160) | epoch;

        address actor = _resolveActor(
            side,
            isCollectionBid,
            collection,
            tokenId,
            seed
        );

        order = OrderBuilder.build(
            side,
            isCollectionBid,
            collection,
            tokenId,
            currency,
            orderPrice(collection, tokenId, seed),
            actor,
            _resolveStartDate(seed),
            _resolveEndDate(seed),
            actorNonceIdx[actor]++
        );

        OrderBuilder.validate(order);
    }

    function _resolveStartDate(uint256 seed) internal view returns (uint64) {
        return _resolveDate(seed, true);
    }

    function _resolveEndDate(uint256 seed) internal view returns (uint64) {
        return _resolveDate(seed, false);
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

    function _sortByEndDate(SignedOrder[] memory arr) internal pure {
        uint256 n = arr.length;

        for (uint256 i = 1; i < n; i++) {
            SignedOrder memory key = arr[i];
            uint256 keyEnd = key.order.end;

            uint256 j = i;
            while (j > 0 && arr[j - 1].order.end > keyEnd) {
                arr[j] = arr[j - 1];
                j--;
            }

            arr[j] = key;
        }
    }

    function _exportNonces()
        internal
        view
        returns (ActorNonce[] memory nonces)
    {
        address[] memory ps = participants();

        nonces = new ActorNonce[](ps.length);

        for (uint256 i = 0; i < ps.length; i++) {
            address a = ps[i];
            nonces[i] = ActorNonce({actor: a, nonce: actorNonceIdx[a]});
        }
    }

    function _importNonces(ActorNonce[] memory nonces) internal {
        for (uint256 i = 0; i < nonces.length; i++) {
            address actor = nonces[i].actor;
            uint256 nonce = nonces[i].nonce;

            actorNonceIdx[actor] = nonce;
        }
    }

    // === PRIVATE FUNCTIONS ===

    function _resolveTimeOffset(uint256 seed) private view returns (uint64) {
        // forge-lint: disable-next-line(unsafe-typecast)
        return uint64((seed % epochSize) + epochSize); // safe because date
    }
    function _epochAnchor() private view returns (uint64) {
        // forge-lint: disable-next-line(unsafe-typecast)
        return uint64(readStartTs() + (epoch * epochSize)); // safe because date
    }

    function _resolveDate(
        uint256 seed,
        bool isStart
    ) private view returns (uint64) {
        uint64 anchor = _epochAnchor();
        uint64 offset = _resolveTimeOffset(seed);

        return isStart ? anchor - offset : anchor + offset;
    }
}
