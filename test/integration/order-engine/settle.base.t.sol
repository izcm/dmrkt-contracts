// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

// local
import {OrderEngine} from "orderbook/OrderEngine.sol";
import {OrderModel} from "orderbook/libs/OrderModel.sol";

// helpers
import {OrderHelper} from "test-helpers/OrderHelper.sol";
import {AccountsHelper} from "test-helpers/AccountsHelper.sol";
import {SettlementHelper} from "test-helpers/SettlementHelper.sol";

// mocks
import {MockWETH} from "mocks/MockWETH.sol";
import {MockERC721} from "mocks/MockERC721.sol";

abstract contract OrderEngineSettleBase is
    AccountsHelper,
    OrderHelper,
    SettlementHelper
{
    using OrderModel for OrderModel.Order;

    uint256 internal constant DEFAULT_ACTOR_COUNT = 10;

    OrderEngine internal orderEngine;

    address internal protocolFeeRecipient;

    function setUp() public virtual {
        MockWETH wethToken = new MockWETH();
        MockERC721 erc721Token = new MockERC721();

        address weth = address(wethToken);
        address erc721 = address(erc721Token);

        protocolFeeRecipient = address(this);
        orderEngine = new OrderEngine(weth, protocolFeeRecipient);

        bytes32 domainSeparator = orderEngine.DOMAIN_SEPARATOR();

        _initSettlementHelper(
            weth,
            address(orderEngine), // ERC721 transfer operator
            address(orderEngine) // ERC20 spender
        );

        _initOrderHelper(domainSeparator, erc721, weth);
        _initActors(DEFAULT_ACTOR_COUNT);
    }
}
