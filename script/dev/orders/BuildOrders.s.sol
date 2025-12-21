// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

// foundry
import {Config} from "forge-std/Config.sol";
import {console} from "forge-std/console.sol";

// interfaces
import {IERC721} from "@openzeppelin/interfaces/IERC721.sol";

// local scripts
import {BaseDevScript} from "dev/BaseDevScript.s.sol";

// local contracts
import {OrderEngine} from "orderbook/OrderEngine.sol";

// local libs
import {OrderActs} from "orderbook/libs/OrderActs.sol";
import {SignatureOps as SigOps} from "orderbook/libs/SignatureOps.sol";
import {OrderFactory} from "periphery/factories/OrderFactory.sol";
import {MarketSim} from "periphery/MarketSim.sol";

interface DNFT {
    function MAX_SUPPLY() external view returns (uint256);
}

struct SignedOrder {
    OrderActs.Order order;
    SigOps.Signature sig;
}

contract BuildOrders is BaseDevScript, Config {
    mapping(address => uint256) internal ownerPk;
    mapping(address => uint256) internal nonceOf;

    function run() external {
        // --------------------------------
        // PHASE 0: LOAD CONFIG
        // --------------------------------
        _loadConfig("deployments.toml", true);

        logSection("CONFIG");

        uint256 chainId = block.chainid;

        console.log("ChainId: %s", chainId);

        // currencies
        address weth = config.get("weth").toAddress();

        // deployed contracts
        address dNft = config.get("dnft_erc721").toAddress();
        address verifyingContract = config
            .get("verifying_contract")
            .toAddress();

        logAddress("DNFT    ", dNft);
        logAddress("VERIFIER", verifyingContract);

        // --------------------------------
        // PHASE 1: MAKE ORDERS
        // --------------------------------
        logSection("MAKE ORDERS: ASK");

        OrderActs.Order[] memory orders = _makeOrders(address(dNft), weth);
        uint256 orderCount = orders.length;

        // --- PKs for signing ---
        uint256[] memory participantPks = readKeys(chainId);
        uint256 participantCount = participantPks.length;

        for (uint256 i = 0; i < participantCount; i++) {
            uint256 pk = participantPks[i];

            address addr = addrOf(pk);
            ownerPk[addr] = pk;
        }

        bytes32 domainSeparator = OrderEngine(verifyingContract)
            .DOMAIN_SEPARATOR();

        SignedOrder[] memory signed = new SignedOrder[](orderCount);

        for (uint256 i = 0; i < orderCount; i++) {
            OrderActs.Order memory order = orders[i];

            uint256 pk = ownerPk[order.actor];
            require(pk != 0, "NO PK FOR ACTOR");

            (SigOps.Signature memory sig) = _makeOrderDigestAndSign(
                order,
                pk,
                domainSeparator
            );

            signed[i] = SignedOrder({order: order, sig: sig});
        }

        // --------------------------------
        // PHASE 2: WRITE AS JSON
        // --------------------------------
        logSection("WRITING ORDERS AS JSON");

        string memory path = string.concat(
            "./data/",
            vm.toString(chainId),
            "/orders-raw.json"
        );

        _persistSignedOrders(
            signed,
            path,
            chainId,
            verifyingContract,
            domainSeparator
        );

        logSeparator();
        console.log("ORDERS SAVED TO: %s", path);
        logSeparator();
    }

    function _makeOrders(
        address collection,
        address currency
    ) internal returns (OrderActs.Order[] memory) {
        IERC721 token = IERC721(collection);

        uint256[] memory selected = MarketSim.selectTokens(
            collection,
            DNFT(collection).MAX_SUPPLY() / 2,
            3
        );

        uint256 selectedCount = selected.length;
        OrderActs.Order[] memory orders = new OrderActs.Order[](selectedCount);

        for (uint256 i = 0; i < selectedCount; i++) {
            uint256 tokenId = selected[i];
            address owner = token.ownerOf(tokenId);
            uint256 price = MarketSim.priceOf(collection, tokenId);
            uint256 nonce = ++nonceOf[owner];

            orders[i] = OrderFactory.simpleAsk(
                owner,
                collection,
                currency,
                tokenId,
                price,
                nonce
            );
        }

        return orders;
    }

    function _makeOrderDigestAndSign(
        OrderActs.Order memory order,
        uint256 actorPrivateKey,
        bytes32 domainSeparator
    ) internal pure returns (SigOps.Signature memory) {
        bytes32 digest = keccak256(
            abi.encodePacked("\x19\x01", domainSeparator, OrderActs.hash(order))
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(actorPrivateKey, digest);

        SigOps.Signature memory sig = SigOps.Signature({v: v, r: r, s: s});

        return sig;
    }

    function _persistSignedOrders(
        SignedOrder[] memory signedOrders,
        string memory path,
        uint256 chainId,
        address verifyingContract,
        bytes32 domainSeparator
    ) internal {
        uint256 signedOrderCount = signedOrders.length;
        string memory root = "root";

        // metadata
        vm.serializeUint(root, "chainId", chainId);
        vm.serializeAddress(root, "verifyingContract", verifyingContract);
        vm.serializeBytes32(root, "domainSeparator", domainSeparator);

        // signedOrders array
        string[] memory entries = new string[](signedOrderCount);

        for (uint256 i = 0; i < signedOrderCount; i++) {
            SignedOrder memory signed = signedOrders[i];

            string memory oKey = string.concat(
                "order_",
                vm.toString(uint256(1))
            );

            entries[i] = _serializeOrder(signed.order, oKey);

            // ---- signature ----
            SigOps.Signature memory sig = signed.sig;

            string memory sKey = string.concat(oKey, "sig");

            vm.serializeUint(sKey, "v", sig.v);
            vm.serializeBytes32(sKey, "r", sig.r);
            vm.serializeBytes32(sKey, "s", sig.s);

            // tried to avoid printing this value, but cannot avoid this!?
            string memory sigOut = vm.serializeString(sKey, "_", "0");

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

    function _serializeOrder(
        OrderActs.Order memory o,
        string memory objKey
    ) internal returns (string memory) {
        string memory key = objKey;

        // ---- order ----
        vm.serializeUint(key, "side", uint256(o.side));
        vm.serializeAddress(key, "actor", o.actor);
        vm.serializeBool(key, "isCollectionBid", o.isCollectionBid);
        vm.serializeAddress(key, "collection", o.collection);
        vm.serializeString(key, "tokenId", vm.toString(o.tokenId));
        vm.serializeString(key, "price", vm.toString(o.price));
        vm.serializeAddress(key, "currency", o.currency);
        vm.serializeUint(key, "start", o.start);
        vm.serializeUint(key, "end", o.end);
        vm.serializeString(key, "nonce", vm.toString(o.nonce));

        return key;
    }
}
