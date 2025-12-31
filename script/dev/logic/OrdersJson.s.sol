// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script} from "forge-std/Script.sol";

// core libraries
import {OrderModel} from "orderbook/libs/OrderModel.sol";
import {SignatureOps as SigOps} from "orderbook/libs/SignatureOps.sol";

// types
import {SignedOrder} from "dev/state/Types.sol";

abstract contract OrdersJson is Script {
    struct PersistedOrders {
        uint256 chainId;
        SignedOrdersJson[] signedOrders;
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
        SignatureJson signature;
        uint64 start;
        uint256 tokenId;
    }

    // `remove` comes from serializing signature terminal value
    struct SignatureJson {
        string _terminal;
        bytes32 r;
        bytes32 s;
        uint8 v;
    }

    function ordersJsonDir() internal view returns (string memory) {
        return
            string.concat(
                "./data/",
                vm.toString(block.chainid),
                "/orders-raw/"
            );
    }

    function ordersToJson(
        SignedOrder[] memory signedOrders,
        string memory path
    ) internal {
        uint256 signedOrderCount = signedOrders.length;
        string memory root = "root";

        // metadata
        vm.serializeUint(root, "chainId", block.chainid);

        // signedOrders array
        string[] memory entries = new string[](signedOrderCount);

        for (uint256 i = 0; i < signedOrderCount; i++) {
            SignedOrder memory signed = signedOrders[i];

            string memory oKey = string.concat(
                "order_",
                vm.toString(uint256(1))
            );

            entries[i] = _serializeOrdersJson(signed.order, oKey);

            // ---- signature ----
            SigOps.Signature memory sig = signed.sig;

            string memory sKey = string.concat(oKey, "sig");

            vm.serializeUint(sKey, "v", sig.v);
            vm.serializeBytes32(sKey, "r", sig.r);
            vm.serializeBytes32(sKey, "s", sig.s);

            // Foundry serialize API requires a terminal value?
            string memory sigOut = vm.serializeString(sKey, "_terminal", "0");

            string memory output = vm.serializeString(
                oKey,
                "signature",
                sigOut
            );
            entries[i] = output;
        }

        string memory finalJson = vm.serializeString(
            root,
            "signedOrders",
            entries
        );

        vm.writeJson(finalJson, path);
    }

    function ordersFromJson(
        string memory path
    ) internal view returns (SignedOrder[] memory signed) {
        string memory json = vm.readFile(path);
        bytes memory data = vm.parseJson(json);

        PersistedOrders memory parsed = abi.decode(data, (PersistedOrders));
        uint256 count = parsed.signedOrders.length;

        signed = new SignedOrder[](count);

        for (uint256 i = 0; i < count; i++) {
            signed[i] = _fromSignedOrdersJson(parsed.signedOrders[i]);
        }
    }

    function _serializeOrdersJson(
        OrderModel.Order memory o,
        string memory objKey
    ) internal returns (string memory) {
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
    ) internal pure returns (SignedOrder memory signed) {
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
            v: jso.signature.v,
            r: jso.signature.r,
            s: jso.signature.s
        });
    }
}
