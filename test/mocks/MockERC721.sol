// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import { ERC721 } from "@openzeppelin/token/ERC721/ERC721.sol";
import { IMintable721 } from "periphery/interfaces/IMintable.sol";

contract MockERC721 is ERC721, IMintable721 {
    constructor() ERC721("Mock", "MOCK") {}

    function mint(address to, uint256 tokenId) external {
        _mint(to, tokenId);
    }
}
