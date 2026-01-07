// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script} from "forge-std/Script.sol";

// core libraries
import {OrderModel} from "orderbook/libs/OrderModel.sol";
import {SignatureOps as SigOps} from "orderbook/libs/SignatureOps.sol";

// types
import {
    SignedOrder,
    ActorNonce,
    Selection,
    EpochMeta
} from "dev/state/Types.sol";

abstract contract OrdersJson is Script {
    // === JSON SPECIFIC SCHEMAS ===

    struct Path {
        string dir;
        string filename;
    }

    struct PersistedOrdersJson {
        uint256 chainId;
        SignedOrderJson[] signed;
    }

    struct PersistedNoncesJson {
        ActorNonce[] nonces;
    }

    struct SignedOrderJson {
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
        vm.createDir(_epochDir(epoch), true);
        vm.createDir(_epochOrdersDir(epoch), true);
        vm.createDir(_epochSelectionsDir(epoch), true);
    }

    // === DEFAULT DIRS ===

    function _stateDir() internal view returns (string memory) {
        return string.concat("./data/", vm.toString(block.chainid), "/state/");
    }

    function _epochDir(uint256 epoch) internal view returns (string memory) {
        return string.concat(_stateDir(), "epoch_", vm.toString(epoch), "/");
    }

    function _epochOrdersDir(
        uint256 epoch
    ) internal view returns (string memory) {
        return string.concat(_epochDir(epoch), "orders/");
    }

    function _epochSelectionsDir(
        uint256 epoch
    ) internal view returns (string memory) {
        return string.concat(_epochDir(epoch), "selections/");
    }

    // === DEFAULT PATHS ===

    function epochNoncesPath(
        uint256 epoch
    ) internal view returns (Path memory path) {
        path.dir = _epochDir(epoch);
        path.filename = "nonces.json";
    }

    function epochOrderPath(
        uint256 idx,
        uint256 epoch
    ) internal view returns (Path memory path) {
        path.dir = _epochOrdersDir(epoch);
        path.filename = string.concat("order_", vm.toString(idx), ".json");
    }

    function epochOrdersPath(
        uint256 epoch
    ) internal view returns (Path memory path) {
        path.dir = _epochOrdersDir(epoch);
        path.filename = "orders.json";
    }

    function epochSelectionPath(
        address collection,
        uint256 epoch
    ) internal view returns (Path memory path) {
        path.dir = _epochSelectionsDir(epoch);
        path.filename = string.concat(vm.toString(collection), ".json");
    }

    // === DEFAULT TO JSON PATHS ===

    function noncesToJson(ActorNonce[] memory nonces, uint256 epoch) internal {
        Path memory p = epochNoncesPath(epoch);
        noncesToJson(nonces, p.dir, p.filename);
    }

    function orderToJson(
        SignedOrder memory signed,
        uint256 idx,
        uint256 epoch
    ) internal {
        Path memory p = epochOrderPath(idx, epoch);
        orderToJson(signed, p.dir, p.filename, idx);
    }

    function selectionToJson(Selection memory sel, uint256 epoch) internal {
        Path memory p = epochSelectionPath(sel.collection, epoch);
        selectionToJson(sel, p.dir, p.filename);
    }

    // === DEFAULT FROM JSON PATHS ===

    function noncesFromJson(
        uint256 epoch
    ) internal view returns (ActorNonce[] memory) {
        Path memory p = epochNoncesPath(epoch);
        return noncesFromJson(string.concat(p.dir, p.filename));
    }

    function ordersFromJson(
        uint256 epoch
    ) internal view returns (SignedOrder[] memory) {
        Path memory p = epochOrdersPath(epoch);
        return ordersFromJson(string.concat(p.dir, p.filename));
    }

    function selectionFromJson(
        address collection,
        uint256 epoch
    ) internal view returns (Selection memory) {
        Path memory p = epochSelectionPath(collection, epoch);
        return selectionFromJson(string.concat(p.dir, p.filename));
    }

    // === TO JSON ===

    function orderToJson(
        SignedOrder memory signed,
        string memory dir,
        string memory filename,
        uint256 idx
    ) internal {
        string memory idxStr = string.concat("order_", vm.toString(idx));
        string memory root = idxStr;

        _serializeOrderJson(signed.order, root);

        // ---- signature ----
        SigOps.Signature memory sig = signed.sig;

        string memory sKey = string.concat(root, "_sig");

        vm.serializeUint(sKey, "v", sig.v);
        vm.serializeBytes32(sKey, "r", sig.r);
        string memory sigOut = vm.serializeBytes32(sKey, "s", sig.s);

        string memory finalJson = vm.serializeString(root, "sig", sigOut);

        vm.writeJson(finalJson, string.concat(dir, filename));
    }

    function ordersToJson(
        SignedOrder[] memory signed,
        string memory dir
    ) internal {
        string memory root = "orders";

        // metadata
        vm.serializeUint(root, "chainId", block.chainid);

        string[] memory entries = new string[](signed.length);

        for (uint256 i = 0; i < signed.length; i++) {
            SignedOrder memory item = signed[i];

            string memory oKey = string.concat("order_", vm.toString(i));

            entries[i] = _serializeOrderJson(item.order, oKey);

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

        vm.writeJson(finalJson, string.concat(dir, "orders.json"));
    }

    // Enables BuildHistory.s.sol keeping track of nonces between epochs
    function noncesToJson(
        ActorNonce[] memory nonces,
        string memory dir,
        string memory filename
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

        vm.writeJson(finalJson, string.concat(dir, filename));
    }

    // tracks selected tokens to avoid when executing collecitonbid
    function selectionToJson(
        Selection memory sel,
        string memory dir,
        string memory filename
    ) internal {
        string memory colStr = vm.toString(sel.collection);
        string memory root = string.concat("selected_", colStr);

        vm.serializeUint(root, "tokenIds", sel.tokenIds);

        string memory finalJson = vm.serializeAddress(
            root,
            "col",
            sel.collection
        );

        vm.writeJson(finalJson, string.concat(dir, filename));
    }

    // == FROM JSON ===

    function orderFromJson(
        string memory path
    ) internal view returns (SignedOrder memory signed) {
        bytes memory data = vm.parseJson(vm.readFile(path));

        SignedOrderJson memory parsed = abi.decode(data, (SignedOrderJson));

        signed = _fromSignedOrderJson(parsed);
    }

    function ordersFromJson(
        string memory path
    ) internal view returns (SignedOrder[] memory signed) {
        bytes memory data = vm.parseJson(vm.readFile(path));

        PersistedOrdersJson memory parsed = abi.decode(
            data,
            (PersistedOrdersJson)
        );
        uint256 count = parsed.signed.length;

        signed = new SignedOrder[](count);

        for (uint256 i = 0; i < count; i++) {
            signed[i] = _fromSignedOrderJson(parsed.signed[i]);
        }
    }

    function noncesFromJson(
        string memory path
    ) internal view returns (ActorNonce[] memory nonces) {
        bytes memory data = vm.parseJson(vm.readFile(path));

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
        bytes memory data = vm.parseJson(vm.readFile(path));
        return abi.decode(data, (Selection));
    }

    // === PRIVATE FUNCTIONS ===

    // --- serializers ---

    function _serializeOrderJson(
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

    function _fromSignedOrderJson(
        SignedOrderJson memory jso
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
