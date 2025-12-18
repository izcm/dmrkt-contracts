// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";

// local
import {OrderActs} from "orderbook/libs/OrderActs.sol";
import {SignatureOps as SigOps} from "orderbook/libs/SignatureOps.sol";

abstract contract OrderHelper is Test {
    using OrderActs for OrderActs.Order;

    uint256 internal constant DEFAULT_PRICE = 1 ether;

    // defaults (override in child tests if you want)
    address internal collection = makeAddr("collection");
    address internal defaultCurrency = makeAddr("currency");

    /*//////////////////////////////////////////////////////////////
                                SIGNING
    //////////////////////////////////////////////////////////////*/

    function makeOrderDigestAndSign(
        address actor,
        uint256 actorPk,
        bytes32 domainSeparator
    )
        internal
        view
        returns (OrderActs.Order memory order, SigOps.Signature memory sig)
    {
        order = makeOrder(actor);
        bytes32 digest = makeDigest(order, domainSeparator);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(actorPk, digest);
        sig = SigOps.Signature({v: v, r: r, s: s});
    }

    /*//////////////////////////////////////////////////////////////
                                ORDERS
    //////////////////////////////////////////////////////////////*/

    function makeOrder(
        address actor
    ) internal view returns (OrderActs.Order memory) {
        return makeOrder(actor, 0, defaultCurrency, DEFAULT_PRICE);
    }

    function makeOrder(
        address actor,
        uint256 nonce
    ) internal view returns (OrderActs.Order memory) {
        return makeOrder(actor, nonce, defaultCurrency, DEFAULT_PRICE);
    }

    function makeOrder(
        address actor,
        uint256 nonce,
        address currency
    ) internal view returns (OrderActs.Order memory) {
        return makeOrder(actor, nonce, currency, DEFAULT_PRICE);
    }

    function makeOrder(
        address actor,
        uint256 nonce,
        address currency,
        uint256 price
    ) internal view returns (OrderActs.Order memory) {
        return
            OrderActs.Order({
                side: OrderActs.Side.Ask,
                actor: actor,
                isCollectionBid: false,
                collection: collection,
                currency: currency,
                tokenId: 1,
                price: price,
                start: 0,
                end: uint64(block.timestamp + 1 days),
                nonce: nonce
            });
    }

    /*//////////////////////////////////////////////////////////////
                                DIGEST
    //////////////////////////////////////////////////////////////*/

    function makeDigest(
        OrderActs.Order memory o,
        bytes32 domainSeparator
    ) internal pure returns (bytes32) {
        return
            keccak256(abi.encodePacked("\x19\x01", domainSeparator, o.hash()));
    }

    /*//////////////////////////////////////////////////////////////
                                SIGNATURE
    //////////////////////////////////////////////////////////////*/
    function dummySig() internal pure returns (SigOps.Signature memory) {
        return SigOps.Signature({v: 0, r: bytes32(0), s: bytes32(0)});
    }
}
