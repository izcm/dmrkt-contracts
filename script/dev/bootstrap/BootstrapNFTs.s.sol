// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Config} from "forge-std/Config.sol";
import {console} from "forge-std/console.sol";

// local
import {BaseDevScript} from "dev/BaseDevScript.s.sol";

// interfaces
import {IERC721} from "@openzeppelin/interfaces/IERC721.sol";

interface IMintable721 is IERC721 {
    function mint(address to) external;
    function MAX_SUPPLY() external view returns (uint256);
}

contract BootstrapNFTs is BaseDevScript, Config {
    function run() external {
        // --------------------------------
        // PHASE 0: LOAD CONFIG
        // --------------------------------
        _loadConfig("deployments.toml", true);

        logSection("LOAD CONFIG");

        uint256 chainId = block.chainid;
        console.log("ChainId: %s", chainId);

        address dNft = config.get("dnft_erc721").toAddress();
        logAddress("DNFT    ", dNft);

        // --- PKs for broadcasting ---
        uint256[] memory participantPks = readKeys(chainId);
        uint256 participantCount = participantPks.length;

        // --------------------------------
        // PHASE 1: MINT NFTs
        // --------------------------------
        logSection("MINT NFTs");

        IMintable721 nftToken = IMintable721(address(dNft));
        uint256 supply = nftToken.MAX_SUPPLY();

        // script mints all tokens => limit = MAX_SUPPLY()
        mintTokens(participantPks, nftToken, supply);

        logSection("DNFT FINAL BALANCES");

        for (uint256 i = 0; i < participantCount; i++) {
            address user = addrOf(participantPks[i]);
            uint256 bal = nftToken.balanceOf(user);

            logTokenBalance("DNFT", user, bal);
        }
    }

    function mintTokens(
        uint256[] memory pks,
        IMintable721 nft,
        uint256 limit
    ) internal {
        // in this script we know i = tokenid for token minted (no previous mints)
        for (uint256 i = 0; i < limit; i++) {
            bytes32 h = keccak256(abi.encode(address(nft), i));
            uint256 j = uint256(h) % pks.length;

            uint256 pk = pks[j];
            address to = addrOf(pk);

            // Broadcast as the recipient — respect for history
            vm.startBroadcast(pk);

            nft.mint(to);

            vm.stopBroadcast();
        }
    }
}
