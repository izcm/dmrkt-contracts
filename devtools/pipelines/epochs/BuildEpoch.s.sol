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

import {OrderSampling} from "../sampling/OrderSampling.s.sol";
import {EpochsJson} from "./EpochsJson.s.sol";
import {SettlementSigner} from "../execution/SettlementSigner.s.sol";

// types
import {SignedOrder, Selection, ActorNonce} from "./Types.sol";

// interfaces
import {ISettlementEngine} from "periphery/interfaces/ISettlementEngine.sol";
import {IERC721} from "periphery/interfaces/DNFT.sol";

// logging
import {console} from "forge-std/console.sol";

contract BuildEpoch is
    OrderSampling,
    SettlementSigner,
    EpochsJson,
    BaseDevScript,
    DevConfig
{
    // ctx
    uint256 private epoch;
    uint256 private epochSpan;

    mapping(address => uint256) private actorNonceIdx;
    mapping(address => uint256[]) private selected; // selected tokenIds per collection

    // selection of tokens decided by run-epochs bash script to not be executed
    // build script ensures no new orders are made on these tokens
    // mapping(address => uint256[]) private exclude; // feature paused

    // === ENTRYPOINTS ===

    function run(uint256 _epoch, uint256 _epochSpan) external {
        // === LOAD CONFIG & SETUP ===

        address settlementContract = readSettlementContract();
        address weth = readWeth();

        bytes32 domainSeparator = ISettlementEngine(settlementContract)
            .DOMAIN_SEPARATOR();

        try vm.envString("DATA_DIR") returns (string memory dir) {
            _setDataDir(dir);
            console.log(
                "DATA_DIR config exists => out dir set to %s",
                _dataDir()
            );
        } catch {
            console.log("DATA_DIR not set => default out dir %s", _dataDir());
        }
        _loadParticipants();
        _createDefaultDirs(_epoch);

        if (_epoch != 0) {
            // read prev epoch actors' last order nonce
            ActorNonce[] memory startNonces = noncesFromJson(_epoch - 1);
            _importNonces(startNonces);
        }

        epoch = _epoch;
        epochSpan = _epochSpan;

        logSection("BUILD ORDERS");
        console.log("Block timestamp: %s", block.timestamp);
        console.log("Epoch: %s", epoch);
        logSeparator();

        address[] memory collections = readCollections();
        console.log("Collections: %s", collections.length);

        // feature paused
        // if (_epoch != 0) {
        //     for (uint256 i; i < collections.length; i++) {
        //         address collection = collections[i];

        //         Selection memory selection = ensureLingerFromJson(collection);
        //         exclude[collection] = selection.tokenIds;
        //     }
        // }

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

            signed[i] = SignedOrder({order: orders[i], signature: sig});
        }

        console.log("Orders signed: %s", signed.length);

        // === ORDER BY NONCE ===

        console.log("Sorting by 'end' timestamp...");

        _sortByEndDate(signed);

        // === EXPORT AS JSON ===

        for (uint256 i = 0; i < collections.length; i++) {
            address c = collections[i];
            selectionToJson(
                Selection({collection: c, tokenIds: selected[c]}),
                _epoch
            );
        }

        for (uint256 i = 0; i < signed.length; i++) {
            SignedOrder memory s = signed[i];
            orderToJson(s, i, _epoch);
        }

        noncesToJson(_exportNonces(), _epoch); // saved in epoch root as singular nonces.json file

        // === WRITE EPOCH METADATA ===

        vm.writeFile(
            string.concat(_epochDir(_epoch), "order-count.txt"),
            vm.toString(signed.length)
        );

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
        Selection[] memory selectionsAsk = collect(
            OrderModel.Side.Ask,
            false,
            collections,
            epoch
        );
        Selection[] memory selectionsBid = collect(
            OrderModel.Side.Bid,
            false,
            collections,
            epoch
        );
        Selection[] memory selectionsCb = collect(
            OrderModel.Side.Bid,
            true,
            collections,
            epoch
        );

        uint256 count;

        // count asks & bids + push tokenids to storage for later json write
        count += _mergeSelections(selectionsAsk);
        count += _mergeSelections(selectionsBid);

        // collectionbids don't have tokenIds like ask / regular bid => only get count
        for (uint256 i = 0; i < selectionsCb.length; i++) {
            Selection memory s = selectionsCb[i];
            for (uint256 j = 0; j < s.tokenIds.length; j++) {
                count++;
            }
        }

        orders = new OrderModel.Order[](count);
        uint256 idx;

        idx = _appendOrders(
            orders,
            idx,
            OrderModel.Side.Ask,
            false,
            selectionsAsk,
            weth
        );

        idx = _appendOrders(
            orders,
            idx,
            OrderModel.Side.Bid,
            false,
            selectionsBid,
            weth
        );

        _appendOrders(
            orders,
            idx,
            OrderModel.Side.Bid,
            true,
            selectionsCb,
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
        uint256 actorSeed = (epoch << 160) | orderIdx;

        address actor = _resolveActor(
            side,
            isCollectionBid,
            collection,
            tokenId,
            actorSeed
        );

        uint256 orderSeed = selectionSalt(
            side,
            isCollectionBid,
            collection,
            actorSeed
        );

        order = OrderBuilder.build(
            side,
            isCollectionBid,
            collection,
            tokenId,
            currency,
            orderPrice(collection, tokenId, orderSeed),
            actor,
            _resolveStartDate(orderSeed),
            _resolveEndDate(orderSeed),
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

    // preps data for json write
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

    // === PRIVATE FUNCTIONS ===

    // --- storage mutators ---

    // preps data read from json for use in script
    function _importNonces(ActorNonce[] memory nonces) private {
        for (uint256 i = 0; i < nonces.length; i++) {
            address actor = nonces[i].actor;
            uint256 nonce = nonces[i].nonce;

            actorNonceIdx[actor] = nonce;
        }
    }

    function _mergeSelections(
        Selection[] memory sels
    ) private returns (uint256 added) {
        for (uint256 i = 0; i < sels.length; i++) {
            Selection memory s = sels[i];
            address c = s.collection;

            for (uint256 j = 0; j < s.tokenIds.length; j++) {
                selected[c].push(s.tokenIds[j]);
                added++;
            }
        }
    }

    // --- resolvers ---

    // Not in use per now
    function _epochAnchor() private view returns (uint64) {
        // forge-lint: disable-next-line(unsafe-typecast)
        return uint64(readStartTs() + (epoch * epochSpan)); // safe because date
    }

    function _resolveTimeOffset(uint256 seed) private view returns (uint64) {
        // forge-lint: disable-next-line(unsafe-typecast)
        return uint64((seed % epochSpan) + epochSpan); // safe because date
    }

    function _resolveDate(
        uint256 seed,
        bool isStart
    ) private view returns (uint64) {
        // uint64 anchor = _epochAnchor();
        uint64 anchor = uint64(readStartTs());
        uint64 offset = _resolveTimeOffset(seed);

        return isStart ? anchor - offset : anchor + offset;
    }
}
