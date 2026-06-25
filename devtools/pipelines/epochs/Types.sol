// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

// core libraries
import { OrderModel } from "orderbook/libs/OrderModel.sol";
import { SignatureOps as SigOps } from "orderbook/libs/SignatureOps.sol";

/// @notice An order paired with its EIP-712 signature, as produced by BuildEpoch and consumed by ExecuteOrder.
struct SignedOrder {
    OrderModel.Order order;
    SigOps.Signature signature;
}

/// @notice Tracks the last used nonce per participant. Persisted to JSON between epochs
///         so nonces stay unique across script invocations.
struct ActorNonce {
    address actor;
    uint256 nonce;
}

/// @notice A set of token IDs sampled from a single collection for one epoch.
struct Selection {
    address collection;
    uint256[] tokenIds;
}
