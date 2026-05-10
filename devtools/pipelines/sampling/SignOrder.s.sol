// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script} from "forge-std/Script.sol";

// core libs
import {OrderModel} from "orderbook/libs/OrderModel.sol";
import {SignatureOps as SigOps} from "orderbook/libs/SignatureOps.sol";

/**
 * @notice Abstract base for EIP-712 order signing. Used by BuildEpoch to sign generated orders
 *         with the maker's private key before writing them to JSON.
 */
abstract contract SignOrder is Script {
    using OrderModel for OrderModel.Order;

    /**
     * @notice Signs an order using EIP-712 and returns the resulting signature.
     * @param domainSeparator  EIP-712 domain separator from the OrderEngine.
     * @param order            The order to sign.
     * @param signerPk         Private key of the order maker.
     */
    function signOrder(
        bytes32 domainSeparator,
        OrderModel.Order memory order,
        uint256 signerPk
    ) internal pure returns (SigOps.Signature memory) {
        bytes32 digest = SigOps.digest712(domainSeparator, order.hash());

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPk, digest);
        return SigOps.Signature(v, r, s);
    }
}
