// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

// oz
import { IERC721 } from "@openzeppelin/interfaces/IERC721.sol";
import { IERC165 } from "@openzeppelin/interfaces/IERC165.sol";
import { IERC20, SafeERC20 } from "@openzeppelin/token/ERC20/utils/SafeERC20.sol";
import { ReentrancyGuard } from "@openzeppelin/utils/ReentrancyGuard.sol";

// local
import { OrderModel } from "./libs/OrderModel.sol";
import { SettlementRoles } from "./libs/SettlementRoles.sol";
import { SignatureOps as SigOps } from "./libs/SignatureOps.sol";

bytes4 constant INTERFACE_ID_ERC721 = 0x80ac58cd;

contract OrderEngine is ReentrancyGuard {
    using SafeERC20 for IERC20;
    using OrderModel for OrderModel.Order;
    using SigOps for SigOps.Signature;

    // === ERRORS ===

    // invalid order fields
    error UnauthorizedFillActor();
    error ZeroActor();
    error InvalidNonce();
    error InvalidTimestamp();

    // not supported behaviour
    error CurrencyNotWhitelisted();
    error UnsupportedCollection();

    // === IMMUTABLES ===

    bytes32 public immutable DOMAIN_SEPARATOR;
    address public immutable WHITELISTED_CURRENCY;
    uint256 public immutable PROTOCOL_FEE_BPS = 100; // immutable for simplicity

    // === MUTABLES ===

    address public protocolFeeRecipient;

    // TODO: make nonce bitmap instead 1x uint256 holding 256 nonces
    mapping(address => mapping(uint256 => bool)) private _isUserOrderNonceInvalid;

    // === EVENTS ===

    event OrderCancelled(address indexed user, uint256 indexed nonce);

    event Settlement(
        bytes32 indexed orderHash,
        address indexed collection,
        uint256 indexed tokenId,
        address seller,
        address buyer,
        address currency,
        uint256 price
    );

    /**
     * @notice Constructor
     * @param _whitelistedCurrency Whitelisted ERC20 currency for order settlement
     * @param _protocolFeeRecipient Address receiving protocol fees
     */
    constructor(address _whitelistedCurrency, address _protocolFeeRecipient) {
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

        WHITELISTED_CURRENCY = _whitelistedCurrency;
        protocolFeeRecipient = _protocolFeeRecipient;
    }

    // ===== EXTERNAL FUNCTIONS =====

    /**
     * @notice Invalidates a specific nonce for a sender
     */
    function cancelOrder(uint256 nonce) external {
        _isUserOrderNonceInvalid[msg.sender][nonce] = true;

        emit OrderCancelled(msg.sender, nonce);
    }

    /**
     * @notice Checks if user nonce is invalid
     */
    function isUserOrderNonceInvalid(address user, uint256 nonce) external view returns (bool) {
        return _isUserOrderNonceInvalid[user][nonce];
    }

    /**
     * @notice Settles a matching order and fill pair
     * @dev Validates order fields, verifies signature, invalidates nonce, transfers payment, and transfers NFT
     * @param fill Taker fill request
     * @param order Signed maker order
     * @param sig Maker EIP-712 signature
     */
    function settle(
        OrderModel.Fill calldata fill,
        OrderModel.Order calldata order,
        SigOps.Signature calldata sig
    ) external payable nonReentrant {
        // Fill request actor must be msg.sender
        require(msg.sender == fill.actor, UnauthorizedFillActor());

        // sig and hash
        bytes32 orderHash = order.hash();
        (uint8 v, bytes32 r, bytes32 s) = sig.vrs();

        // verify
        _validateOrder(order, orderHash, v, r, s);

        // prevent replay
        _isUserOrderNonceInvalid[order.actor][order.nonce] = true;

        // decide roles and asset
        (address nftHolder, address spender, uint256 tokenId) = SettlementRoles.resolve(
            fill,
            order
        );

        _settlePayment(order.currency, spender, nftHolder, order.price);

        _transferNft(order.collection, nftHolder, spender, tokenId);

        emit Settlement(
            orderHash,
            order.collection,
            tokenId,
            nftHolder, // **the nftHolder PRE transfer**
            spender,
            order.currency,
            order.price
        );
    }

    // ===== INTERNAL FUNCTIONS =====

    /**
     * @notice Transfers currency between accounts
     * @dev Royalty fee distribution is currently paused
     */
    function _settlePayment(address currency, address from, address to, uint256 amount) internal {
        uint256 sellerCompensation = amount;

        // calculate protocol fee
        {
            uint256 feeAmount = (amount * PROTOCOL_FEE_BPS) / 10000;

            // using SafeERC20 to future proof
            IERC20(currency).safeTransferFrom(from, protocolFeeRecipient, feeAmount);

            sellerCompensation -= feeAmount;
        }

        // compensate seller
        {
            IERC20(currency).safeTransferFrom(from, to, sellerCompensation);
        }
    }

    /**
     * @notice Transfers an ERC721 token between accounts
     * @dev Reverts if collection does not implement ERC721 via ERC165
     */
    function _transferNft(address collection, address from, address to, uint256 tokenId) internal {
        if (!IERC165(collection).supportsInterface(INTERFACE_ID_ERC721)) {
            revert UnsupportedCollection();
        }

        IERC721(collection).safeTransferFrom(from, to, tokenId);
    }

    /**
     * @notice Validates order fields and signature
     * @dev Checks actor, nonce, timestamps, currency, and signature validity
     */
    function _validateOrder(
        OrderModel.Order calldata order,
        bytes32 orderHash,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) internal view {
        require(order.actor != address(0), ZeroActor());

        require(!_isUserOrderNonceInvalid[order.actor][order.nonce], InvalidNonce());

        require(order.start <= block.timestamp && order.end >= block.timestamp, InvalidTimestamp());

        require(order.currency == WHITELISTED_CURRENCY, CurrencyNotWhitelisted());

        SigOps.verify(DOMAIN_SEPARATOR, orderHash, order.actor, v, r, s);
    }
}
