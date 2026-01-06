// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script} from "forge-std/Script.sol";

// core libraries
import {OrderModel} from "orderbook/libs/OrderModel.sol";
import {SignatureOps as SigOps} from "orderbook/libs/SignatureOps.sol";

// types
import {SignedOrder, ActorNonce, Selection} from "dev/state/Types.sol";

abstract contract OrdersJson is Script {
    // === JSON SPECIFIC SCHEMAS ===

    struct PersistedOrdersJson {
        uint256 chainId;
        SignedOrdersJson[] signed;
    }

    struct PersistedNoncesJson {
        ActorNonce[] nonces;
    }

    struct SignedOrdersJson {
        address actor;
        address collection;
        address currency;
        uint64 end;
        bool isCollectionBid;
        uint256 nonce;
        uint256 price;
        OrderModel.Side side;
        SignatureJson sig;
        uint64 start;
        uint256 tokenId;
    }

    // struct has to match json alphabetical order => cannot use SigOps.Signature
    struct SignatureJson {
        bytes32 r;
        bytes32 s;
        uint8 v;
    }

    struct IdsJson {
        uint256[] ids;
    }

    // === INITIALIZERS ===

    function _createDefaultDirs(uint256 epoch) internal {
        vm.createDir(_stateDir(), true);
        vm.createDir(epochDir(epoch), true);
        vm.createDir(epochOrdersDir(epoch), true);
        vm.createDir(epochSelectionsDir(epoch), true);
    }

    // === OUT DIR / FILE ===

    function epochDir(uint256 epoch) internal view returns (string memory) {
        return string.concat(_stateDir(), "epoch_", vm.toString(epoch), "/");
    }

    function epochOrdersDir(
        uint256 epoch
    ) internal view returns (string memory) {
        return string.concat(epochDir(epoch), "orders/");
    }

    function epochSelectionsDir(
        uint256 epoch
    ) internal view returns (string memory) {
        return string.concat(epochDir(epoch), "selections/");
    }

    function epochNoncesPath(
        uint256 epoch
    ) internal view returns (string memory) {
        string memory dir = epochDir(epoch);
        string memory out = "/nonces.json";

        return string.concat(dir, out);
    }

    // === TO JSON ===

    function ordersToJson(
        SignedOrder[] memory signed,
        string memory path
    ) internal {
        string memory root = "orders";

        // metadata
        vm.serializeUint(root, "chainId", block.chainid);

        string[] memory entries = new string[](signed.length);

        for (uint256 i = 0; i < signed.length; i++) {
            SignedOrder memory item = signed[i];

            string memory oKey = string.concat("order_", vm.toString(i));

            entries[i] = _serializeOrdersJson(item.order, oKey);

            // ---- signature ----
            SigOps.Signature memory sig = item.sig;

            string memory sKey = string.concat(oKey, "_sig");

            vm.serializeUint(sKey, "v", sig.v);
            vm.serializeBytes32(sKey, "r", sig.r);
            string memory sigOut = vm.serializeBytes32(sKey, "s", sig.s);

            string memory out = vm.serializeString(oKey, "sig", sigOut);

            entries[i] = out;
        }

        string memory finalJson = vm.serializeString(root, "signed", entries);

        vm.writeJson(finalJson, string.concat(path, "orders.json"));
    }

    // Enables BuildHistory.s.sol keeping track of nonces between epochs
    function noncesToJson(
        ActorNonce[] memory nonces,
        string memory path
    ) internal {
        string memory root = "nonces";

        string[] memory entries = new string[](nonces.length);

        for (uint256 i = 0; i < nonces.length; i++) {
            string memory k = string.concat("nonce_", vm.toString(i));

            vm.serializeAddress(k, "actor", nonces[i].actor);
            string memory out = vm.serializeUint(k, "nonce", nonces[i].nonce);

            entries[i] = out;
        }

        string memory finalJson = vm.serializeString(root, "nonces", entries);

        vm.writeJson(finalJson, path);
    }

    // tracks selected tokens to avoid when executing collecitonbid
    function selectionToJson(
        Selection memory sel,
        string memory path
    ) internal {
        string memory colStr = vm.toString(sel.collection);
        string memory root = string.concat("selected_", colStr);

        vm.serializeUint(root, "tokenIds", sel.tokenIds);

        string memory finalJson = vm.serializeAddress(
            root,
            "col",
            sel.collection
        );

        vm.writeJson(
            finalJson,
            string.concat(path, string.concat(colStr, ".json"))
        );
    }

    // == FROM JSON ===

    // NOTE: orders are parsed in full each run (Foundry limitation).
    // Acceptable for dev tooling / demo scale.
    // TODO: when time split per-order JSON eg.
    // epoch_3/orders/order_0.json
    // epoch_3/orders/order_1.json
    // epoch_3/orders/order_2.json
    function orderFromJson(
        string memory filePath,
        uint256 orderIdx
    ) internal view returns (SignedOrder[] memory signed) {
        return ordersFromJson(filePath);
        // validate
        // produce fill
        // settle
    }

    function ordersFromJson(
        string memory filePath
    ) internal view returns (SignedOrder[] memory signed) {
        string memory json = vm.readFile(filePath);
        bytes memory data = vm.parseJson(json);

        PersistedOrdersJson memory parsed = abi.decode(
            data,
            (PersistedOrdersJson)
        );
        uint256 count = parsed.signed.length;

        signed = new SignedOrder[](count);

        for (uint256 i = 0; i < count; i++) {
            signed[i] = _fromSignedOrdersJson(parsed.signed[i]);
        }
    }

    function noncesFromJson(
        string memory path
    ) internal view returns (ActorNonce[] memory nonces) {
        string memory json = vm.readFile(path);
        bytes memory data = vm.parseJson(json);

        PersistedNoncesJson memory parsed = abi.decode(
            data,
            (PersistedNoncesJson)
        );

        uint256 count = parsed.nonces.length;

        nonces = new ActorNonce[](count);

        for (uint256 i = 0; i < count; i++) {
            nonces[i] = parsed.nonces[i];
        }
    }

    function selectionFromJson(
        string memory path
    ) internal view returns (Selection memory) {
        string memory json = vm.readFile(path);
        bytes memory data = vm.parseJson(json);

        return abi.decode(data, (Selection));
    }

    // === PRIVATE FUNCTIONS ===

    // --- filePath builders ---

    function _stateDir() private view returns (string memory) {
        return string.concat("./data/", vm.toString(block.chainid), "/state/");
    }

    // --- serializers ---

    function _serializeOrdersJson(
        OrderModel.Order memory o,
        string memory objKey
    ) private returns (string memory) {
        string memory key = objKey;

        // ---- order ----
        vm.serializeUint(key, "side", uint256(o.side));
        vm.serializeAddress(key, "actor", o.actor);
        vm.serializeBool(key, "isCollectionBid", o.isCollectionBid);
        vm.serializeAddress(key, "collection", o.collection);
        vm.serializeUint(key, "tokenId", o.tokenId);
        vm.serializeUint(key, "price", o.price);
        vm.serializeAddress(key, "currency", o.currency);
        vm.serializeUint(key, "start", o.start);
        vm.serializeUint(key, "end", o.end);
        vm.serializeUint(key, "nonce", o.nonce);

        return key;
    }

    function _fromSignedOrdersJson(
        SignedOrdersJson memory jso
    ) private pure returns (SignedOrder memory signed) {
        signed.order = OrderModel.Order({
            side: jso.side,
            isCollectionBid: jso.isCollectionBid,
            collection: jso.collection,
            tokenId: jso.tokenId,
            currency: jso.currency,
            price: jso.price,
            actor: jso.actor,
            start: jso.start,
            end: jso.end,
            nonce: jso.nonce
        });

        signed.sig = SigOps.Signature({
            v: jso.sig.v,
            r: jso.sig.r,
            s: jso.sig.s
        });
    }
}
