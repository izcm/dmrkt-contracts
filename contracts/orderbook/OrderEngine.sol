// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

// open zeppelin
import {IERC721} from "@openzeppelin/interfaces/IERC721.sol";
import {IERC165} from "@openzeppelin/interfaces/IERC165.sol";
import {IERC20, SafeERC20} from "@openzeppelin/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/utils/ReentrancyGuard.sol";

// local
import "./libs/OrderActs.sol";
import {SignatureOps as SigOps} from "./libs/SignatureOps.sol";

bytes4 constant INTERFACE_ID_ERC721 = 0x80ac58cd;

// TODO: when implementing support for other currency than WETH:
// lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol

contract OrderEngine is ReentrancyGuard {
    using SafeERC20 for IERC20;
    using OrderActs for OrderActs.Order;
    using SigOps for SigOps.Signature;

    // === ERRORS ===
    error UnauthorizedFillActor();
    error InvalidNonce();
    error ZeroActor();
    error CurrencyNotWhitelisted();
    error UnsupportedCollection();
    error InvalidOrderSide();

    // === IMMUTABLES ===
    bytes32 public immutable DOMAIN_SEPARATOR;
    address public immutable WETH;
    uint256 public immutable PROTOCOL_FEE_BPS = 1; // immutable for simplicity

    address public protocolFeeReceiver;

    // TODO: mapping(address => mapping(uint256 => uint256)) nonceBitmap;
    // ====> each uint256 packs 256 nonces
    mapping(address => mapping(uint256 => bool))
        private _isUserOrderNonceInvalid;

    constructor(address weth, address feeReceiver) {
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

        WETH = weth;
        protocolFeeReceiver = feeReceiver;
    }

    // ===== EXTERNAL FUNCTIONS =====

    /**
     * @notice Matches a `Fill` request to an existing `Order`
     */
    function settle(
        OrderActs.Fill calldata fill,
        OrderActs.Order calldata order,
        SigOps.Signature calldata sig
    ) external payable nonReentrant {
        // Fill request actor must be msg.sender
        require(msg.sender == fill.actor, UnauthorizedFillActor());

        // Verify
        (uint8 v, bytes32 r, bytes32 s) = sig.vrs();
        _validateOrder(order, v, r, s);

        // prevents replay
        _isUserOrderNonceInvalid[order.actor][order.nonce] = true;

        // decide roles and asset
        address nftHolder;
        address spender;
        uint256 tokenId;

        if (order.isAsk()) {
            nftHolder = order.actor;
            spender = fill.actor;
            tokenId = order.tokenId;
        } else if (order.isBid()) {
            nftHolder = fill.actor;
            spender = order.actor;

            tokenId = order.isCollectionBid ? fill.tokenId : order.tokenId;
        } else {
            revert InvalidOrderSide();
        }

        _settlePayment(order.currency, spender, nftHolder, order.price);

        _transferNFT(order.collection, nftHolder, spender, tokenId);
    }

    function isUserOrderNonceInvalid(
        address user,
        uint256 nonce
    ) external view returns (bool) {
        return _isUserOrderNonceInvalid[user][nonce];
    }

    // ===== INTERNAL FUNCTIONS =====

    /**
     * @notice Validates order.
     */
    function _validateOrder(
        OrderActs.Order calldata order,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) internal view {
        // Signer != addr(0)
        require(order.actor != address(0), ZeroActor());

        // Valid order nonce
        require(
            !_isUserOrderNonceInvalid[order.actor][order.nonce],
            InvalidNonce()
        );

        // Whitelisted currency
        require(order.currency == WETH, CurrencyNotWhitelisted());

        // Verify Signature
        SigOps.verify(DOMAIN_SEPARATOR, order.hash(), order.actor, v, r, s);
    }

    /**
     * @param currency: per today always WETH.
     */
    function _settlePayment(
        address currency,
        address from,
        address to,
        uint256 amount
    ) internal {
        uint256 sellerCompensation = amount;

        // stage 1: calculate protocol fee
        {
            uint256 feeAmount = (amount * PROTOCOL_FEE_BPS) / 100;

            // using SafeERC20 for future proofing
            IERC20(currency).safeTransferFrom(
                from,
                protocolFeeReceiver,
                feeAmount
            );

            sellerCompensation -= feeAmount;
        }

        // stage 2:  calculate royalty fee
        {
            // IERC20(WETH).safeTransferFrom
        }

        // stage 3: compensate seller
        {
            IERC20(currency).safeTransferFrom(from, to, sellerCompensation);
        }
    }

    function _transferNFT(
        address collection,
        address from,
        address to,
        uint256 tokenId
    ) internal {
        if (IERC165(collection).supportsInterface(INTERFACE_ID_ERC721)) {
            // nft supports erc721
            IERC721(collection).safeTransferFrom(from, to, tokenId);
        } else {
            revert UnsupportedCollection();
        }
    }
}
