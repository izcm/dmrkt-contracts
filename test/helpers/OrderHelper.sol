// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";

// core libraries
import {OrderModel} from "orderbook/libs/OrderModel.sol";
import {SignatureOps as SigOps} from "orderbook/libs/SignatureOps.sol";

abstract contract OrderHelper is Test {
    using OrderModel for OrderModel.Order;

    uint256 private constant DEFAULT_PRICE = 1 ether;
    uint256 private constant DEFAULT_TOKEN_ID = 1;

    bytes32 private domainSeparator;
    address private defaultCurrency; // WETH
    address private defaultCollection; // some erc721

    function _initOrderHelper(
        bytes32 _domainSeparator,
        address _defaultCollection,
        address _defaultCurrency
    ) internal {
        domainSeparator = _domainSeparator;
        defaultCollection = _defaultCollection;
        defaultCurrency = _defaultCurrency;
    }

    // === MAKE ORDERS ===

    // === ASK ===
    function makeAsk(
        address actor
    ) internal view returns (OrderModel.Order memory order) {
        return makeOrder(OrderModel.Side.Ask, false, actor);
    }

    function makeAsk(
        address collection,
        address currency,
        address actor
    ) internal view returns (OrderModel.Order memory) {
        return
            _order(
                OrderModel.Side.Ask,
                false,
                collection,
                currency,
                DEFAULT_PRICE,
                actor,
                0
            );
    }

    // === BID / ASK ===

    function makeOrder(
        OrderModel.Side side,
        bool isCollectionBid,
        address actor
    ) internal view returns (OrderModel.Order memory) {
        return
            _order(
                side,
                isCollectionBid,
                defaultCollection,
                defaultCurrency,
                DEFAULT_PRICE,
                actor,
                0
            );
    }

    function _order(
        OrderModel.Side side,
        bool isCollectionBid,
        address collection,
        address currency,
        uint256 price,
        address actor,
        uint256 nonce
    ) internal view returns (OrderModel.Order memory) {
        return
            OrderModel.Order({
                side: side,
                isCollectionBid: isCollectionBid,
                collection: collection,
                tokenId: DEFAULT_TOKEN_ID,
                currency: currency,
                price: price,
                actor: actor,
                start: 0,
                end: uint64(block.timestamp + 1 days),
                nonce: nonce
            });
    }

    // === DIGEST / SIGNING ===

    function makeSignedAsk(
        address signer,
        uint256 signerPk
    )
        internal
        view
        returns (OrderModel.Order memory order, SigOps.Signature memory sig)
    {
        order = makeAsk(signer);
        (, sig) = signOrder(order, signerPk);
    }

    function signOrder(
        OrderModel.Order memory order,
        uint256 signerPk
    ) internal view returns (bytes32 digest, SigOps.Signature memory sig) {
        digest = SigOps.digest712(domainSeparator, order.hash());

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPk, digest);
        sig = SigOps.Signature(v, r, s);
    }

    function dummySig() internal pure returns (SigOps.Signature memory) {
        return SigOps.Signature({v: 0, r: bytes32(0), s: bytes32(0)});
    }
}
