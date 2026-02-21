// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/token/ERC721/ERC721.sol";
import "@openzeppelin/utils/Base64.sol";
import "@openzeppelin/utils/Strings.sol";

import {DNFT} from "periphery/interfaces/DNFT.sol";
import {DMrktNFTLib} from "./DMrktNFTLib.sol";

// free mint, used in DEV env setup
// see Script/dev-setup
contract DMrktNode is DNFT, ERC721 {
    uint256 public constant MAX_SUPPLY = 100;
    uint256 private _nextTokenId;

    constructor() ERC721("dmrktNode", "DNODE") {}

    function mint(address to) external {
        require(_nextTokenId < MAX_SUPPLY, "Sold out");
        _safeMint(to, _nextTokenId++);
    }

    function totalSupply() external view returns (uint256) {
        return _nextTokenId;
    }

    function tokenURI(
        uint256 tokenId
    ) public view override returns (string memory) {
        require(_ownerOf(tokenId) != address(0), "Not minted");
        return
            string.concat("data:application/json;base64,", _metadata(tokenId));
    }

    // ----------------------------
    // METADATA PIPELINE
    // ----------------------------

    function _metadata(uint256 tokenId) internal pure returns (string memory) {
        string memory svgBase64 = Base64.encode(bytes(_svg(tokenId)));
        return
            DMrktNFTLib.buildMetadata(
                string.concat("DmrktNode #", Strings.toString(tokenId)),
                "Fully on-chain dmrkt node",
                tokenId,
                svgBase64
            );
    }

    // ----------------------------
    // SVG GENERATION
    // ----------------------------

    function _svg(uint256 tokenId) internal pure returns (string memory) {
        string memory color = _getColorForToken(tokenId);

        return
            string(
                abi.encodePacked(
                    '<svg width="600" height="600" viewBox="0 0 600 600" xmlns="http://www.w3.org/2000/svg">',
                    "<defs>",
                    '<radialGradient id="dg2" cx="50%" cy="50%" r="50%">',
                    '<stop offset="0%" stop-color="',
                    color,
                    '" stop-opacity="0.25"/>',
                    '<stop offset="100%" stop-color="',
                    color,
                    '" stop-opacity="0"/>',
                    "</radialGradient>",
                    "</defs>",
                    '<rect width="600" height="600" rx="64" fill="#0b0b10"/>',
                    '<circle cx="300" cy="285" r="210" fill="url(#dg2)"/>',
                    '<polygon points="300,200 400,300 300,400 200,300" fill="',
                    color,
                    '"/>',
                    '<polygon points="300,240 360,300 300,360 240,300" fill="#0b0b10"/>',
                    '<circle cx="300" cy="300" r="10" fill="',
                    color,
                    '"/>',
                    '<text x="300" y="505" text-anchor="middle" fill="',
                    color,
                    '" font-family="monospace" font-size="34" letter-spacing="2">dmrkt</text>',
                    "</svg>"
                )
            );
    }

    // ----------------------------
    // TRAIT LOGIC
    // ----------------------------

    function _getColorForToken(
        uint256 tokenId
    ) private pure returns (string memory) {
        return DMrktNFTLib.getColorForToken(tokenId);
    }

    function getColor(uint256 tokenId) public pure returns (string memory) {
        return _getColorForToken(tokenId);
    }

    function getColorName(uint256 tokenId) public pure returns (string memory) {
        return DMrktNFTLib.getColorName(tokenId);
    }
}
