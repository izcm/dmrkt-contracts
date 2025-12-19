// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";

import {OrderActs} from "orderbook/libs/OrderActs.sol";

// interfaces
import {IERC20, SafeERC20} from "@openzeppelin/token/ERC20/utils/SafeERC20.sol";

import {IMintable721, IERC721} from "periphery/interfaces/IMintable.sol";
import {IWETH} from "periphery/interfaces/IWETH.sol";

abstract contract SettlementHelper is Test {
    using SafeERC20 for IERC20; // mirrors actual engine
    using OrderActs for OrderActs.Order;

    address erc721TransferAuthority;
    address erc20Spender;

    address private weth;

    function _initSettlementHelper(
        address _weth,
        address _erc721TransferAuthority,
        address _erc20Spender
    ) internal {
        weth = _weth;
        erc721TransferAuthority = _erc721TransferAuthority;
        erc20Spender = _erc20Spender;
    }

    /// @dev Expectation helper only.
    /// Does NOT check whether isBid purposefully so `settle` can revert `InvalidOrderSide`.
    function expectRolesAndAsset(
        OrderActs.Fill memory f,
        OrderActs.Order memory o
    )
        internal
        pure
        returns (address nftHolder, address spender, uint256 tokenId)
    {
        if (o.isAsk()) {
            return (o.actor, f.actor, o.tokenId);
        } else {
            return (
                f.actor,
                o.actor,
                o.isCollectionBid ? f.tokenId : o.tokenId
            );
        }
    }

    function legitimizeSettlement(
        OrderActs.Fill memory f,
        OrderActs.Order memory o
    ) internal {
        address collection = o.collection;
        uint256 price = o.price;
        address currency = o.currency;

        (
            address nftHolder,
            address spender,
            uint256 tokenId
        ) = expectRolesAndAsset(f, o);

        // future proofing in case future support for other currencies
        console.log("IS IT THE SAME????");
        console.logAddress(o.currency);
        console.logAddress(weth);
        if (currency == weth) {
            dealWETHViaDeposit(spender, price);
        }

        // NFT
        vm.startPrank(nftHolder);
        mintMockNft(collection, nftHolder, tokenId);
        approveNftTransfer(collection, erc721TransferAuthority, tokenId);
        vm.stopPrank();

        // ERC20
        vm.prank(spender);
        forceApproveAllowance(currency, erc20Spender, price);
    }

    function mintMockNft(
        address collection,
        address to,
        uint256 tokenId
    ) internal {
        IMintable721(collection).mint(to, tokenId);
    }

    function dealWETHViaDeposit(address to, uint256 amount) internal {
        vm.deal(to, amount);
        vm.prank(to);
        IWETH(weth).deposit{value: amount}();
    }

    function approveNftTransfer(
        address collection,
        address operator,
        uint256 tokenId
    ) internal {
        IERC721(collection).approve(operator, tokenId);
    }

    function forceApproveAllowance(
        address tokenContract,
        address spender,
        uint256 value
    ) internal {
        IERC20(tokenContract).forceApprove(spender, value);
    }
}
