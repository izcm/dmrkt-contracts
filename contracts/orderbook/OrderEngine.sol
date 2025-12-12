// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.30;

import {ReentrancyGuard} from "@openzeppelin/utils/ReentrancyGuard.sol";

// local
import "./libs/OrderActs.sol";
import {SignatureOps as SigOps} from "./libs/SignatureOps.sol";
import {console} from "forge-std/console.sol";

// ===== ERRORS =====
error UnauthorizedFillActor();
error InvalidNonce();
error ZeroActor();
error CurrencyNotWhitelisted();

contract OrderEngine is ReentrancyGuard {
    using OrderActs for OrderActs.Order;
    using SigOps for SigOps.Signature;

    bytes32 public immutable DOMAIN_SEPARATOR;
    address public immutable WETH;

    mapping(address => mapping(uint256 => bool)) private _isUserOrderNonceInvalid;

    constructor() {
        DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                // EIP-712 domain type hash
                0x8b73c3c69bb8fe3d512ecc4cf759cc79239f7b179b0ffacaa9a75d522b39400f,
                // nameHash
                0x997dc85543e54e3a10f066eed263ff8d0cbf9f87e862f32fce17b110cadc23f2, // "dmrkt"
                // versionHash
                0x044852b2a670ade5407e78fb2863c51de9fcb96542a07186fe3aeda6bb8a116d, // "0"
                // static types => fed directly
                block.chainid,
                address(this)
            )
        );

        WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    }

    // ===== EXTERNAL FUNCTIONS =====

    /**
     * @notice Matches a `Fill` request to an existing `Order`
     */
    function settle(OrderActs.Fill calldata fill, OrderActs.Order calldata order, SigOps.Signature calldata sig)
        external
        payable
        nonReentrant
    {
        // Fill request actor must be msg.sender
        require(msg.sender == fill.actor, UnauthorizedFillActor());

        // Verify
        (uint8 v, bytes32 r, bytes32 s) = sig.vrs();
        _validateOrder(order, v, r, s);

        // uint256 tokenId = order.isCollectionBid ? fill.tokenId : order.tokenId;
    }

    // ===== INTERNAL FUNCTIONS =====

    /**
     * @notice Validates order.
     */
    function _validateOrder(OrderActs.Order calldata order, uint8 v, bytes32 r, bytes32 s) internal view {
        // Signer != addr(0)
        require(order.actor != address(0), ZeroActor());

        // Valid order nonce
        require(!_isUserOrderNonceInvalid[order.actor][order.nonce], InvalidNonce());

        // Whitelisted currency
        require(order.currency == WETH, CurrencyNotWhitelisted());

        // Verify Signature
        SigOps.verify(DOMAIN_SEPARATOR, order.hash(), order.actor, v, r, s);
    }
}
