// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

// core libraries
import { OrderModel } from "orderbook/libs/OrderModel.sol";
import { SignatureOps as SigOps } from "orderbook/libs/SignatureOps.sol";

// periphery libraries
import { OrderBuilder } from "periphery/builders/OrderBuilder.sol";

// scripts
import { BaseDevScript } from "dev/BaseDevScript.s.sol";
import { DevConfig } from "dev/DevConfig.s.sol";

import { EpochsJson } from "./EpochsJson.s.sol";
import { MarketSim } from "../sampling/MarketSim.sol";
import { SignOrder } from "../sampling/SignOrder.s.sol";

// types
import { SignedOrder, Selection, ActorNonce } from "./Types.sol";

// interfaces
import { ISettlementEngine } from "dev/interfaces/ISettlementEngine.sol";
import { IERC721 } from "@openzeppelin/interfaces/IERC721.sol";
import { DMrktNFTLib } from "../../local-nfts/DMrktNFTLib.sol";
import { DMrktMathConfig } from "../../local-nfts/DMrktMathConfig.sol";

// logging
import { console } from "forge-std/console.sol";

/**
 * @notice Generates and signs all orders for a single epoch. Called once per epoch by run-epochs.sh.
 *         Samples ask and bid token selections across all collections, builds orders with
 *         deterministic actors and timestamps, signs them EIP-712, sorts by end date, and
 *         writes everything to the epoch's JSON output directory.
 */
contract BuildEpoch is MarketSim, SignOrder, EpochsJson, BaseDevScript, DevConfig {
    // ctx
    uint256 private epoch;
    uint256 private timeWindow;
    uint256 private gapBase;
    uint256 private nonceSeed;

    mapping(address => uint256) private actorNonceIdx; // per-actor nonce counter, carried over between epochs via nonces.json
    mapping(address => uint256[]) private selected; // selected tokenIds per collection

    // === ENTRYPOINTS ===

    /**
     * @notice  Entry point. Loads config, imports the previous epoch's nonces, builds and signs
     *          all orders, sorts them by end date, and exports them to JSON.
     * @param _epoch        Current epoch index.
     * @param _timeWindow   Full pipeline delta in seconds. Passed as the full delta (not epoch slice)
     *                      so every order's end timestamp is guaranteed >= pipeline_end_ts,
     *                      keeping unsettled orders valid for demo users to settle manually.
     * @param _gap          Base token-selection gap passed to MarketSim's sampler (density knob).
     * @param _nonceSeed    Added when extending to repeated builds without tracking nonce
     *                      Probably going to move away from the sequential nonce system all together.
     *                      Very little value for lot the added  complexity.
     */
    function run(
        uint256 _epoch,
        uint256 _timeWindow,
        uint256 _gap,
        uint256 _nonceSeed
    ) external {
        // --------------------------------
        // LOAD CONFIG & SETUP
        // --------------------------------

        address settlementContract = readSettlementContract();
        address weth = readWeth();

        bytes32 domainSeparator = ISettlementEngine(settlementContract).DOMAIN_SEPARATOR();

        // checks if another output dir is defined
        try vm.envString("DATA_DIR") returns (string memory dir) {
            _setDataDir(dir);
            console.log("DATA_DIR config exists => out dir set to %s", _dataDir());
        } catch {}
        loadParticipants();
        _createDefaultDirs(_epoch);

        if (_epoch != 0) {
            // read prev epoch actors' last order nonce
            ActorNonce[] memory startNonces = noncesFromJson(_epoch - 1);
            _importNonces(startNonces);
        }

        epoch = _epoch;
        timeWindow = _timeWindow;
        gapBase = _gap;
        nonceSeed = _nonceSeed;

        address[] memory collections = readCollections();

        // --------------------------------
        // BUILD ORDERS
        // --------------------------------

        logSection("BUILD ORDERS");
        console.log("Epoch: %s | Collections: %s", epoch, collections.length);

        OrderModel.Order[] memory orders = _buildOrders(weth, collections);

        // --------------------------------
        // SIGN ORDERS
        // --------------------------------

        logSection("SIGNING");

        SignedOrder[] memory signed = new SignedOrder[](orders.length);

        for (uint256 i = 0; i < orders.length; i++) {
            SigOps.Signature memory sig = signOrder(
                domainSeparator,
                orders[i],
                pkOf(orders[i].actor)
            );

            signed[i] = SignedOrder({ order: orders[i], signature: sig });
        }

        console.log("Orders signed: %s", signed.length);

        // --------------------------------
        // SORT ORDERS
        // --------------------------------

        console.log("Sorting by token ID...");
        _sortByTokenId(signed);

        // --------------------------------
        // WRITE OUTPUTS
        // --------------------------------

        // order-count.txt is read by run-epochs.sh to know how many orders to loop over
        // better to do this than counting with `find` to make sure the count is correct
        vm.writeFile(
            string.concat(_epochDir(_epoch), "order-count.txt"),
            vm.toString(signed.length)
        );

        for (uint256 i = 0; i < collections.length; i++) {
            address c = collections[i];
            selectionToJson(Selection({ collection: c, tokenIds: selected[c] }), _epoch);
        }

        for (uint256 i = 0; i < signed.length; i++) {
            orderToJson(signed[i], i, _epoch);
        }

        noncesToJson(_exportNonces(), _epoch);

        console.log("Epoch %s ready with %s signed orders!", _epoch, signed.length);
    }

    // === BUILD ===

    /**
     * @dev Samples ask and bid selections across all collections, then flattens them into
     *      a single order array. Collection bids are paused and commented out.
     */
    function _buildOrders(
        address weth,
        address[] memory collections
    ) internal returns (OrderModel.Order[] memory orders) {
        // ASK – participant is the SELLER; limit selected tokens to be owned by participants
        Selection[] memory selectionsAsk = collect(
            collections,
            participants(),
            gapBase,
            uint256(keccak256(abi.encode(OrderModel.Side.Ask, false, epoch, nonceSeed)))
        );
        // BID – participant is the BUYER; no need to scope by ownership
        Selection[] memory selectionsBid = collect(
            collections,
            new address[](0),
            gapBase,
            uint256(keccak256(abi.encode(OrderModel.Side.Bid, false, epoch, nonceSeed)))
        );

        uint256 count;

        count += _mergeSelections(selectionsAsk);
        count += _mergeSelections(selectionsBid);

        orders = new OrderModel.Order[](count);
        uint256 idx;

        idx = _appendOrders(orders, idx, OrderModel.Side.Ask, false, selectionsAsk, weth);

        idx = _appendOrders(orders, idx, OrderModel.Side.Bid, false, selectionsBid, weth);
    }

    /**
     * @dev Iterates selections and appends one order per token ID into `orders` starting at `idx`.
     *      Returns the updated index after all orders are appended.
     */
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

    /**
     * @dev Builds a single order. Resolves the actor, price, start/end timestamps, and nonce
     *      deterministically from the epoch index and order position.
     */
    function _buildOrder(
        OrderModel.Side side,
        bool isCollectionBid,
        address collection,
        uint256 tokenId,
        address currency,
        uint256 orderIdx
    ) internal returns (OrderModel.Order memory order) {
        uint256 actorSeed = (epoch << 160) | orderIdx;

        address actor = _resolveActor(side, isCollectionBid, collection, tokenId, actorSeed);

        uint256 orderSeed = selectionSalt(
            collection,
            uint256(keccak256(abi.encode(side, isCollectionBid, collection, actorSeed)))
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
            uint256(keccak256(abi.encode(orderSeed, nonceSeed)))
            // actorNonceIdx[actor]++
        );

        OrderBuilder.validate(order);
    }

    // === PRICING ===

    /**
     * @notice DMrktLoot-aware price override. Derives price from the token's rarity tier,
     *         item type stat, element bonus, and a small noise factor.
     * @dev    Tier multiplier:  Legendary 8x | Epic 4x | Rare 2x | Common 1x
     *         Element bonus:    Thunder or Fire adds tier * 0.05 ETH
     *         Base:             tier * stat * 0.001 ETH, rounded up to nearest 0.001 ETH
     */
    function orderPrice(
        address,
        uint256 tokenId,
        uint256 seed
    ) internal pure override returns (uint256) {
        uint256 tier = tokenId % DMrktMathConfig.rarityLegendaryMod() == 0
            ? 8
            : tokenId % DMrktMathConfig.rarityEpicMod() == 0
                ? 4
                : tokenId % DMrktMathConfig.rarityRareMod() == 0
                    ? 2
                    : 1;

        uint256 itemType = tokenId % DMrktMathConfig.itemTypeCount();
        uint256 stat = itemType == DMrktMathConfig.itemTypeSword()
            ? DMrktNFTLib.getDamage(tokenId)
            : itemType == DMrktMathConfig.itemTypeShield()
                ? DMrktNFTLib.getDefense(tokenId)
                : DMrktNFTLib.getPower(tokenId);

        bool hasElement = tokenId % DMrktMathConfig.elementThunderMod() == 0 ||
            tokenId % DMrktMathConfig.elementFireMod() == 0;

        uint256 base = tier * stat * 0.001 ether;
        uint256 bonus = hasElement ? tier * 0.05 ether : 0;
        uint256 noise = uint256(keccak256(abi.encode(seed, tokenId))) % 20;

        uint256 raw = base + bonus + ((base * noise) / 100);
        uint256 unit = 0.001 ether;
        uint256 remainder = raw % unit;
        return remainder == 0 ? raw : raw + (unit - remainder);
    }

    // === PRIVATE FUNCTIONS ===

    /**
     * @dev For asks: the NFT holder is the actor (they're selling).
     *      For regular bids: a random participant who is not the NFT holder (they're buying).
     *      For collection bids: any random participant.
     */
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
            return side == OrderModel.Side.Ask ? nftHolder : otherParticipant(nftHolder, seed);
        }
    }

    function _resolveStartDate(uint256 seed) internal view returns (uint64) {
        return _resolveDate(seed, true);
    }

    function _resolveEndDate(uint256 seed) internal view returns (uint64) {
        return _resolveDate(seed, false);
    }

    /**
     * @dev Derives start/end timestamps relative to the pipeline start anchor.
     *      Start = anchor - offset, end = anchor + offset, giving each order a window
     *      that straddles the pipeline start and extends into the future.
     */
    function _resolveDate(uint256 seed, bool isStart) private view returns (uint64) {
        uint64 anchor = uint64(readStartTs());
        uint64 offset = _resolveTimeOffset(seed);

        return isStart ? anchor - offset : anchor + offset;
    }

    /**
     * @dev Returns an offset in [timeWindow, 2*timeWindow]. Since timeWindow is the full pipeline
     *      delta, end = anchor + offset >= pipeline_end_ts for every order.
     */
    function _resolveTimeOffset(uint256 seed) private view returns (uint64) {
        // forge-lint: disable-next-line(unsafe-typecast)
        return uint64((seed % timeWindow) + timeWindow);
    }

    function _exportNonces() internal view returns (ActorNonce[] memory nonces) {
        address[] memory ps = participants();

        nonces = new ActorNonce[](ps.length);

        for (uint256 i = 0; i < ps.length; i++) {
            address a = ps[i];
            nonces[i] = ActorNonce({ actor: a, nonce: actorNonceIdx[a] });
        }
    }

    function _importNonces(ActorNonce[] memory nonces) private {
        for (uint256 i = 0; i < nonces.length; i++) {
            address actor = nonces[i].actor;
            uint256 nonce = nonces[i].nonce;

            actorNonceIdx[actor] = nonce;
        }
    }

    /**
     * @dev Insertion sort by token ID for a stable, delta-independent order index mapping.
     */
    function _sortByTokenId(SignedOrder[] memory arr) internal pure {
        uint256 n = arr.length;

        for (uint256 i = 1; i < n; i++) {
            SignedOrder memory key = arr[i];
            uint256 keyToken = key.order.tokenId;

            uint256 j = i;
            while (j > 0 && arr[j - 1].order.tokenId > keyToken) {
                arr[j] = arr[j - 1];
                j--;
            }

            arr[j] = key;
        }
    }

    /**
     * @dev Flattens a selections array into the `selected` storage map and returns the total token count.
     *      The stored token IDs are later written to selections JSON for ExecuteOrder to consume.
     */
    function _mergeSelections(Selection[] memory sels) private returns (uint256 added) {
        for (uint256 i = 0; i < sels.length; i++) {
            Selection memory s = sels[i];
            address c = s.collection;

            for (uint256 j = 0; j < s.tokenIds.length; j++) {
                selected[c].push(s.tokenIds[j]);
                added++;
            }
        }
    }
}
