// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script} from "forge-std/Script.sol";
import {Config} from "forge-std/Config.sol";
import {console} from "forge-std/console.sol";

// local
import {BaseDevScript} from "dev-script/BaseDevScript.s.sol";
import {OrderEngine} from "orderbook/OrderEngine.sol";
import {DMrktGremlin as DNFT} from "nfts/DMrktGremlin.sol";

// TODO: cryptopunks is not erc721 compatible, custom wrapper l8r?
// https://docs.openzeppelin.com/contracts/4.x/api/token/erc721
interface IERC721 {
    function setApprovalForAll(address operator, bool approved) external;
    function ownerOf(uint256 tokenId) external view returns (address);
    function transferFrom(address from, address to, uint256 tokenId) external;
}

interface IWETH {
    function deposit() external payable;
    function transfer(address to, uint256 amount) external returns (bool);
    function balanceOf(address who) external view returns (uint256);
}

contract Setup is BaseDevScript, Config {
    uint256 immutable DEV_BOOTSTRAP_ETH = 10000 ether;

    OrderEngine public orderEngine;

    function run() external {
        // --------------------------------
        // PHASE 0: LOAD CONFIG
        // --------------------------------
        _loadConfig("deployments.toml", true);

        logSection("CONFIG & CONTRACT DEPLOYMENT");

        uint256 chainId = block.chainid;

        console.log("ChainId: %s", chainId);

        address funder = config.get("funder").toAddress();
        address weth = config.get("weth").toAddress();

        // --------------------------------
        // PHASE 1: SETUP CONTRACTS
        // --------------------------------
        uint256 funderPK = uint256(uint256(vm.envUint("PRIVATE_KEY")));

        // since the script uses the same private key its not necessary but I like to be explicit
        // deploy dmrkt nft and marketplace
        vm.startBroadcast(funderPK);
        OrderEngine oe = new OrderEngine();
        DNFT dNft = new DNFT();
        vm.stopBroadcast();

        logDeployment("OrderEngine", address(oe));
        logDeployment("DNFT", address(dNft));

        // --------------------------------
        // PHASE 2: FUND ETH
        // --------------------------------
        logSection("BOOTSTRAP DEV ACCOUNTS");
        console.log("------------------------------------");
        console.log("FUNDER");
        console.log("ADDR  | %s", funder);
        console.log("BAL   | %s", funder.balance);
        console.log("------------------------------------");

        uint256 distributableEth = (funder.balance * 4) / 5;
        uint256 recipientLen;

        if (chainId == 1337) {
            recipientLen = DEV_KEYS.length;
        } else {
            revert("account bootstrap not configured for this chain");
        }

        uint256[] memory recipientPKs = new uint256[](recipientLen);

        if (chainId == 1337) {
            for (uint256 i = 0; i < recipientLen; i++) {
                recipientPKs[i] = DEV_KEYS[i];
            }
        } else {
            revert("account bootstrap not configured for this chain");
        }

        // amount to fund each account
        uint256 bootstrapEth = distributableEth / recipientLen;

        vm.startBroadcast(funderPK);

        for (uint256 i = 0; i < recipientLen; i++) {
            address a = resolveAddr(recipientPKs[i]);
            console.log("ADDRESS A: %s", a);

            logBalance("PRE ", a);

            (bool ok, ) = payable(a).call{value: bootstrapEth}("");

            if (!ok) {
                console.log("TRANSFER FAILED -> %s", a);
            } else {
                logBalance("POST", a);
            }

            logSeperator();
        }

        vm.stopBroadcast();

        logSection("WRAP ETH => WETH");

        uint256 wethWrapAmount = bootstrapEth / 2;

        for (uint256 i = 1; i < recipientLen; i++) {
            address a = resolveAddr(recipientPKs[i]);
            logTokenBalance("PRE WETH ", a, IWETH(weth).balanceOf(a));

            vm.startBroadcast(recipientPKs[i]);
            IWETH(weth).deposit{value: wethWrapAmount}();
            vm.stopBroadcast();

            logTokenBalance("POST WETH", a, IWETH(weth).balanceOf(a));

            logSeperator();
        }
    }

    function selectTokens(
        address tokenContract,
        uint256 scanLimit,
        uint256 targetCount,
        uint8 mod
    ) internal pure returns (uint256[] memory) {
        uint256 count = 0;
        uint256[] memory ids = new uint256[](targetCount);

        for (uint256 i = 0; i < scanLimit && count < targetCount; i++) {
            bytes32 h = keccak256(abi.encode(tokenContract, i));
            if (uint256(h) % mod == 0) {
                ids[count] = i;
                count++;
            }
        }

        assembly {
            mstore(ids, count)
        }

        return ids;
    }

    function readOwnerOf(
        address tokenContract,
        uint256 tokenId
    ) internal view returns (address) {
        return IERC721(tokenContract).ownerOf(tokenId);
    }
}
