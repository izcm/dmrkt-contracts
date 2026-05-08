// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

// local
import {OrderModel} from "orderbook/libs/OrderModel.sol";
import {SignatureOps as SigOps} from "orderbook/libs/SignatureOps.sol";

interface ISettlementEngine {
    function DOMAIN_SEPARATOR() external view returns (bytes32);

    function isUserOrderNonceInvalid(
        address user,
        uint256 nonce
    ) external view returns (bool);

    function settle(
        OrderModel.Fill calldata fill,
        OrderModel.Order calldata order,
        SigOps.Signature calldata sig
    ) external payable;
}
