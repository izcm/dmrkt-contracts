// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script} from "forge-std/Script.sol";

// core libs
import {OrderModel} from "orderbook/libs/OrderModel.sol";
import {SignatureOps as SigOps} from "orderbook/libs/SignatureOps.sol";

abstract contract SettlementSigner is Script {
    using OrderModel for OrderModel.Order;

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
