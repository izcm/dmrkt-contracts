// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

// core libraries
import {OrderModel} from "orderbook/libs/OrderModel.sol";
import {SignatureOps as SigOps} from "orderbook/libs/SignatureOps.sol";

struct SignedOrder {
    OrderModel.Order order;
    SigOps.Signature signature;
}

struct ActorNonce {
    address actor;
    uint256 nonce;
}

struct Selection {
    address collection;
    uint256[] tokenIds;
}
