// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "@openzeppelin/token/ERC721/ERC721.sol";
import "@openzeppelin/utils/Base64.sol";

import {DNFT} from "periphery/interfaces/DNFT.sol";
import {DMrktNFTLib} from "./DMrktNFTLib.sol";

contract DMrktDragonEggs is DNFT, ERC721 {
    uint256 private _nextTokenId;

    constructor() ERC721("dmrktDragonEggs", "DEGG") {}

    function MAX_SUPPLY() public pure override returns (uint256) {
        return 120;
    }

    function mint(address to) external {
        require(_nextTokenId < MAX_SUPPLY(), "Max supply reached");

        uint256 tokenId = _nextTokenId++;
        _safeMint(to, tokenId);
    }

    function totalSupply() external view returns (uint256) {
        return _nextTokenId;
    }

    function tokenURI(
        uint256 tokenId
    ) public view override returns (string memory) {
        require(_ownerOf(tokenId) != address(0), "Not minted");

        string memory svg = _svg(tokenId);
        string memory svgBase64 = Base64.encode(bytes(svg));

        return
            string.concat(
                "data:application/json;base64,",
                DMrktNFTLib.buildEggMetadata(tokenId, svgBase64)
            );
    }

    // ----------------------------
    // SVG
    // ----------------------------

    function _svg(uint256 tokenId) internal pure returns (string memory) {
        string memory color = DMrktNFTLib.getColorForToken(tokenId);
        string memory glow = DMrktNFTLib.buildRarityGlow(tokenId);
        string memory overlay = DMrktNFTLib.buildElementOverlay(tokenId);

        return
            string(
                abi.encodePacked(
                    '<svg width="600" height="600" viewBox="0 0 600 600" xmlns="http://www.w3.org/2000/svg">',
                    '<rect width="600" height="600" rx="64" fill="#0b0b10"/>',
                    glow,
                    overlay,
                    // egg shell
                    '<ellipse cx="300" cy="310" rx="110" ry="140" fill="#111827"/>',
                    // glowing crack
                    '<polygon points="300,230 330,280 300,300 340,350 300,390" fill="',
                    color,
                    '"/>',
                    '<polygon points="300,260 270,300 300,330" fill="',
                    color,
                    '"/>',
                    // highlight
                    '<ellipse cx="260" cy="260" rx="30" ry="40" fill="#ffffff" opacity="0.15"/>',
                    '<text x="300" y="505" text-anchor="middle" fill="',
                    color,
                    '" font-family="monospace" font-size="34" letter-spacing="2">dmrkt</text>',
                    "</svg>"
                )
            );
    }
}
