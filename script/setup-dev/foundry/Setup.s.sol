// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script} from "forge-std/Script.sol";
import {Config} from "forge-std/Config.sol";
import {console} from "forge-std/console.sol";

// local
import {BaseDevScript} from "dev-script/BaseDevScript.s.sol";
import {OrderEngine} from "orderbook/OrderEngine.sol";
import {DMrktGremlin as DNFT} from "nfts/DMrktGremlin.ERC721.sol";

// TODO: import IERC721 + IERC20 from OZ libs
// interfaces
interface IERC721 {
    function setApprovalForAll(address operator, bool approved) external;
    function isApprovedForAll(
        address owner,
        address operator
    ) external returns (bool);
    function ownerOf(uint256 tokenId) external view returns (address);
    function transferFrom(address from, address to, uint256 tokenId) external;
    function balanceOf(address who) external view returns (uint256);
}

interface IMintable721 {
    function mint(address to) external;
}

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function balanceOf(address who) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function allowance(
        address owner,
        address spender
    ) external returns (uint256);
}

interface IWETH is IERC20 {
    function deposit() external payable;
    function withdraw(uint256) external;
}

// NOTE:
// This script is typically executed using the funder private key.
// Explicit vm.startBroadcast(funderPK) calls are used for clarity
// and to guarantee correct sender behavior even if the script
// is invoked from a different context.
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
        // deploy orderEngine nft and marketplace
        vm.startBroadcast(funderPK);
        orderEngine = new OrderEngine();
        DNFT dNft = new DNFT();
        vm.stopBroadcast();

        logDeployment("OrderEngine", address(orderEngine));
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
        uint256 participantLen;

        if (chainId == 1337) {
            participantLen = DEV_KEYS.length;
        } else {
            revert("account bootstrap not configured for this chain");
        }

        uint256[] memory participantPKs = new uint256[](participantLen);

        if (chainId == 1337) {
            for (uint256 i = 0; i < participantLen; i++) {
                participantPKs[i] = DEV_KEYS[i];
            }
        } else {
            revert("account bootstrap not configured for this chain");
        }

        // amount to fund each account
        uint256 bootstrapEth = distributableEth / participantLen;

        vm.startBroadcast(funderPK);

        for (uint256 i = 0; i < participantLen; i++) {
            address a = resolveAddr(participantPKs[i]);

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

        // --------------------------------
        // PHASE 3: WRAP ETH
        // --------------------------------
        logSection("WRAP ETH => WETH");

        uint256 wethWrapAmount = bootstrapEth / 2;
        IWETH wethToken = IWETH(weth);

        for (uint256 i = 1; i < participantLen; i++) {
            address a = resolveAddr(participantPKs[i]);
            logTokenBalance("PRE  WETH", a, wethToken.balanceOf(a));

            vm.startBroadcast(participantPKs[i]);
            wethToken.deposit{value: wethWrapAmount}();
            vm.stopBroadcast();

            logTokenBalance("POST WETH", a, wethToken.balanceOf(a));

            logSeperator();
        }

        // --------------------------------
        // PHASE 3: MINT NFTs
        // --------------------------------
        logSection("MINT NFTs");

        IERC721 nftToken = IERC721(address(dNft));
        uint256 supply = dNft.MAX_SUPPLY();

        // script mints all tokens => limit = MAX_SUPPLY()
        mintTokens(participantPKs, IMintable721(address(nftToken)), supply);

        logSection("DNFT FINAL BALANCES");

        for (uint256 i = 0; i < participantLen; i++) {
            address user = resolveAddr(participantPKs[i]);
            uint256 bal = nftToken.balanceOf(user);

            logTokenBalance("DNFT", user, bal);
        }

        // --------------------------------
        // PHASE 4: SELECT TOKENS FOR ORDERS
        // --------------------------------
        logSection("SELECT TOKENS");

        uint256 scanLimit = supply / 2; // scan only N first tokenIds
        uint8 density = 3;

        uint256[] memory selectedTokens = selectTokens(
            address(nftToken),
            scanLimit,
            density
        );

        // --------------------------------
        // PHASE 5: APPROVALS
        // --------------------------------
        logSection("APPROVE MARKETPLACE FOR NFTs");

        address marketplace = address(orderEngine);

        for (uint256 i = 0; i < participantLen; i++) {
            vm.startBroadcast(participantPKs[i]);
            nftToken.setApprovalForAll(marketplace, true);
            vm.stopBroadcast();

            address owner = resolveAddr(participantPKs[i]);
            console.log(
                "%s HAS APPROVED DMRKT FOR ALL: ",
                owner,
                nftToken.isApprovedForAll(owner, marketplace)
            );
        }

        logSection("APPROVE WETH ALLOWANCE FOR MARKETPLACE");

        /*
            DEV ORDERBOOK SETUP — INTENDED FLOW (CAN MIRROR PROD)

            1) Mint NFTs
            2) selectTokens() → choose tokenIds to list
            3) Compute prices (pure + deterministic from tokenId)
            4) Group by owner → sum prices per owner
            = orderExposureByOwner / requiredWethAllowanceByOwner
            5) Approve WETH = exact exposure per owner (NOT max)
            6) Sign orders (off-chain)
            7) Persist orders (JSON / Mongo)
            8) Engine consumes orders

            Notes:
            - Allowance represents *economic exposure*, not convenience
            - Deterministic pricing → reproducible forks & simulations
            - Dev scripts intentionally mirror production flows

            PROPER ALLOWANCE: 
            exposure[owner] += priceOf(tokenId);
            weth.approve(marketplace, exposure[owner]);
        */

        // DEV-ONLY:
        // Infinite approval used ONLY for local fork / deterministic setup.
        // Production flow uses exact per-owner exposure-based allowances.
        uint256 allowance = type(uint256).max;

        for (uint256 i = 0; i < participantLen; i++) {
            vm.startBroadcast(participantPKs[i]);
            wethToken.approve(marketplace, allowance);
            vm.stopBroadcast();

            address owner = resolveAddr(participantPKs[i]);
            console.log(
                "%s HAS APPROVED ALLOWANCE FOR MARKETPLACE: ",
                owner,
                wethToken.allowance(owner, marketplace)
            );
        }
    }

    // for dnft limit = maxSupply
    function mintTokens(
        uint256[] memory pks,
        IMintable721 nft,
        uint256 limit
    ) internal {
        // in this script we know i = tokenid for token minted (no previous mints)
        for (uint256 i = 0; i < limit; i++) {
            bytes32 h = keccak256(abi.encode(address(nft), i));
            uint256 j = uint256(h) % pks.length;

            address to = resolveAddr(pks[j]);
            nft.mint(to);
        }
    }

    function selectTokens(
        address tokenContract,
        uint256 scanLimit,
        uint8 density
    ) internal pure returns (uint256[] memory) {
        uint256 count = 0;
        uint targetCount = scanLimit / density;

        uint256[] memory ids = new uint256[](targetCount);

        for (uint256 i = 0; i < scanLimit && count < targetCount; i++) {
            bytes32 h = keccak256(abi.encode(tokenContract, i));
            if (uint256(h) % density == 0) {
                ids[count++] = i;
            }
        }

        assembly {
            mstore(ids, count)
        }

        return ids;
    }

    function priceOf(
        address nft,
        uint256 tokenId
    ) internal pure returns (uint256) {
        bytes32 h = keccak256(abi.encode("DMRKT_PRICE_V1", nft, tokenId));

        // map to range: 0.05 → 0.55 ETH
        uint256 bucket = uint256(h) % 11; // 0..10

        return (bucket + 1) * 0.05 ether;
    }
}
