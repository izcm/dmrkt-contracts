// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/token/ERC721/ERC721.sol";
import "@openzeppelin/utils/Base64.sol";

// free mint, used in DEV env setup
// see Script/dev-setup
contract DMrktGremlin is ERC721 {
    uint256 public constant MAX_SUPPLY = 100;
    uint256 private _nextTokenId;

    constructor() ERC721("DMrktGremlin", "DMRKT") {}

    function mint(address to) external {
        require(_nextTokenId < MAX_SUPPLY, "Sold out");
        _safeMint(to, _nextTokenId++);
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        require(_ownerOf(tokenId) != address(0), "Not minted");

        string memory svg = string(
            abi.encodePacked(
                '<svg width="600" height="600" viewBox="0 0 600 600" xmlns="http://www.w3.org/2000/svg">',
                '<rect width="600" height="600" rx="64" fill="#0b0b10"/>',
                '<circle cx="300" cy="280" r="180" fill="#7c5cff" opacity="0.12"/>',
                '<ellipse cx="300" cy="280" rx="140" ry="150" fill="#111827"/>',
                '<ellipse cx="255" cy="260" rx="18" ry="26" fill="#ffffff"/>',
                '<ellipse cx="345" cy="260" rx="18" ry="26" fill="#ffffff"/>',
                '<circle cx="258" cy="268" r="8" fill="#7c5cff"/>',
                '<circle cx="348" cy="268" r="8" fill="#7c5cff"/>',
                '<circle cx="262" cy="262" r="3" fill="#ffffff"/>',
                '<circle cx="352" cy="262" r="3" fill="#ffffff"/>',
                '<path d="M260 330 Q300 350 340 330" stroke="#7c5cff" stroke-width="6" fill="none" stroke-linecap="round"/>',
                '<circle cx="220" cy="310" r="10" fill="#ff7aa8" opacity="0.6"/>',
                '<circle cx="380" cy="310" r="10" fill="#ff7aa8" opacity="0.6"/>',
                '<path d="M190 170 Q140 110 160 80" stroke="#7c5cff" stroke-width="10" fill="none" stroke-linecap="round"/>',
                '<path d="M410 170 Q460 110 440 80" stroke="#7c5cff" stroke-width="10" fill="none" stroke-linecap="round"/>',
                '<rect x="200" y="420" rx="18" ry="18" width="200" height="48" fill="#111827" stroke="#7c5cff" stroke-width="2"/>',
                '<text x="300" y="452" text-anchor="middle" font-size="22" fill="#7c5cff" font-family="monospace" letter-spacing="1">dmrkt</text>',
                "</svg>"
            )
        );

        string memory json = Base64.encode(
            bytes(
                string(
                    abi.encodePacked(
                        '{"name":"DMrktGremlin #',
                        Strings.toString(tokenId),
                        '","description":"Fully on-chain dmrkt gremlin","image":"data:image/svg+xml;base64,',
                        Base64.encode(bytes(svg)),
                        '"}'
                    )
                )
            )
        );

        return string.concat("data:application/json;base64,", json);
    }

    function getColor(uint256 tokenId) public pure returns (string memory) {
        string[5] memory colors = ["#00FFFF", "#8A2BE2", "#39FF14", "#7c5cff", "#FF00FF"];
        return colors[tokenId % colors.length];
    }
}
