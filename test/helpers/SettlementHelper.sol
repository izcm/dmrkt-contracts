// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";

import {OrderModel} from "orderbook/libs/OrderModel.sol";

// interfaces
import {IERC20, SafeERC20} from "@openzeppelin/token/ERC20/utils/SafeERC20.sol";

// periphery
import {IMintable721, IERC721} from "periphery/interfaces/IMintable.sol";
import {IWETH} from "periphery/interfaces/IWETH.sol";

import {SettlementRoles} from "orderbook/libs/SettlementRoles.sol";

abstract contract SettlementHelper is Test {
    using SafeERC20 for IERC20; // mirrors actual engine
    using OrderModel for OrderModel.Order;

    // default tokenId for fill
    uint256 private constant DEFAULT_TOKEN_ID = 0;

    address private nftTransferOperator;
    address private erc20AllowanceSpender;

    address private weth;

    function _initSettlementHelper(address _weth, address _nftTransferOperator, address _erc20AllowanceSpender)
        internal
    {
        weth = _weth;
        nftTransferOperator = _nftTransferOperator;
        erc20AllowanceSpender = _erc20AllowanceSpender;
    }

    function wethDealAndApproveSpenderAllowance(address wethReceiver, uint256 amount) internal {
        vm.deal(wethReceiver, amount);

        vm.startPrank(wethReceiver);
        IWETH(weth).deposit{value: amount}();

        _forceApproveAllowance(weth, erc20AllowanceSpender, amount);
        vm.stopPrank();
    }

    function nftMintAndApproveTransferOperator(address collection, address nftReceiver, uint256 tokenId) internal {
        // group setup actions under a single actor context
        vm.startPrank(nftReceiver);

        _mintMockNft(collection, nftReceiver, tokenId);
        _approveNftTransferOperator(collection, tokenId);

        vm.stopPrank();
    }

    function legitimizeSettlement(OrderModel.Fill memory f, OrderModel.Order memory o) internal {
        address collection = o.collection;
        uint256 price = o.price;
        address currency = o.currency;

        (address nftHolder, address spender, uint256 tokenId) = SettlementRoles.resolve(f, o);

        // future proofing in case future support for other currencies
        if (currency == weth) {
            wethDealAndApproveSpenderAllowance(spender, price);
        }

        nftMintAndApproveTransferOperator(collection, nftHolder, tokenId);
    }

    function wethAddr() internal view returns (address) {
        return weth;
    }

    // === MAKE FILL ====

    function makeFill(address actor) internal pure returns (OrderModel.Fill memory fill) {
        return OrderModel.Fill({actor: actor, tokenId: DEFAULT_TOKEN_ID});
    }

    function makeFill(address actor, uint256 tokenId) internal pure returns (OrderModel.Fill memory fill) {
        return OrderModel.Fill({actor: actor, tokenId: tokenId});
    }

    // === PRIVATE FUNCTIONS ===

    function _forceApproveAllowance(address tokenContract, address spender, uint256 value) private {
        IERC20(tokenContract).forceApprove(spender, value);
    }

    function _mintMockNft(address collection, address to, uint256 tokenId) private {
        IMintable721(collection).mint(to, tokenId);
    }

    function _approveNftTransferOperator(address collection, uint256 tokenId) private {
        IERC721(collection).approve(nftTransferOperator, tokenId);
    }
}
