// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/token/ERC721/ERC721.sol";
import "@openzeppelin/utils/Base64.sol";
import "@openzeppelin/utils/Strings.sol";

import {DNFT} from "periphery/interfaces/DNFT.sol";

// free mint, used in DEV env setup
// see Script/dev-setup
contract DMrktSeal is DNFT, ERC721 {
    uint256 public constant MAX_SUPPLY = 100;
    uint256 private _nextTokenId;

    constructor() ERC721("DMrktSeal", "DSEAL") {}

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

        string memory svg = string(
            abi.encodePacked(
                '<svg width="600" height="600" viewBox="0 0 600 600" xmlns="http://www.w3.org/2000/svg">',
                '<rect width="600" height="600" rx="64" fill="#0b0b10"/>',
                '<rect x="240" y="240" width="120" height="120" fill="#7c5cff"/>',
                '<rect x="270" y="270" width="60" height="60" fill="#0b0b10"/>',
                '<text x="300" y="500" text-anchor="middle" fill="#7c5cff" font-family="monospace">dmrkt</text>',
                "</svg>"
            )
        );

        string memory json = Base64.encode(
            bytes(
                string(
                    abi.encodePacked(
                        '{"name":"DmrktSeal #',
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
        string[5] memory colors = [
            "#00FFFF",
            "#8A2BE2",
            "#39FF14",
            "#7c5cff",
            "#FF00FF"
        ];
        return colors[tokenId % colors.length];
    }
}
