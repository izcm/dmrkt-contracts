// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/token/ERC721/ERC721.sol";
import "@openzeppelin/utils/Base64.sol";
import "@openzeppelin/utils/Strings.sol";

import {DNFT} from "periphery/interfaces/DNFT.sol";
import {DMrktNFTLib} from "./DMrktNFTLib.sol";

// free mint, used in DEV env setup
// see Script/dev-setup
contract DMrktGremlin is DNFT, ERC721 {
    uint256 public constant MAX_SUPPLY = 100;
    uint256 private _nextTokenId;

    constructor() ERC721("dmrktGremlin", "DGREM") {}

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
                string.concat("DMrktGremlin #", Strings.toString(tokenId)),
                "Fully on-chain dmrkt gremlin",
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
                    '<rect width="600" height="600" rx="64" fill="#0b0b10"/>',
                    '<circle cx="300" cy="280" r="200" fill="',
                    color,
                    '" opacity="0.08"/>',
                    '<path d="M180 260 Q300 170 420 260 Q400 420 300 430 Q200 420 180 260Z" fill="#111827" stroke="',
                    color,
                    '" stroke-width="2"/>',
                    '<path d="M230 210 Q190 130 210 95" stroke="',
                    color,
                    '" stroke-width="6" fill="none" stroke-linecap="round"/>',
                    '<path d="M370 210 Q410 130 390 95" stroke="',
                    color,
                    '" stroke-width="6" fill="none" stroke-linecap="round"/>',
                    '<ellipse cx="255" cy="285" rx="20" ry="24" fill="#ffffff"/>',
                    '<ellipse cx="345" cy="285" rx="20" ry="24" fill="#ffffff"/>',
                    '<circle cx="258" cy="290" r="9" fill="',
                    color,
                    '"/>',
                    '<circle cx="348" cy="290" r="9" fill="',
                    color,
                    '"/>',
                    '<circle cx="262" cy="285" r="3" fill="#ffffff"/>',
                    '<circle cx="352" cy="285" r="3" fill="#ffffff"/>',
                    '<path d="M255 350 Q300 375 345 350" stroke="',
                    color,
                    '" stroke-width="5" fill="none" stroke-linecap="round"/>',
                    '<circle cx="215" cy="325" r="8" fill="',
                    color,
                    '" opacity="0.18"/>',
                    '<circle cx="385" cy="325" r="8" fill="',
                    color,
                    '" opacity="0.18"/>',
                    '<text x="300" y="505" text-anchor="middle" fill="',
                    color,
                    '" font-family="monospace" font-size="30" letter-spacing="2">dmrkt</text>',
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
