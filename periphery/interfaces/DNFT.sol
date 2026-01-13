// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/// @dev dev-only interface for periphery NFTs used in similation scripts
/// @notice shorthand for DMrkt NFT

import {IERC721} from "@openzeppelin/interfaces/IERC721.sol";

interface DNFT is IERC721 {
    function MAX_SUPPLY() external view returns (uint256);

    function totalSupply() external view returns (uint256);

    function mint(address to) external;
}
