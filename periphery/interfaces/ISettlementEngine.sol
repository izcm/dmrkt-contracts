// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

interface ISettlementEngine {
    function DOMAIN_SEPARATOR() external view returns (bytes32);

    function isUserOrderNonceInvalid(
        address user,
        uint256 nonce
    ) external view returns (bool);
}
