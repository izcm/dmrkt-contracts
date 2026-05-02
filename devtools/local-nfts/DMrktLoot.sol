// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "@openzeppelin/token/ERC721/ERC721.sol";
import "@openzeppelin/utils/Base64.sol";
import "@openzeppelin/utils/Strings.sol";

import {DNFT} from "periphery/interfaces/DNFT.sol";
import {DMrktMathConfig} from "./DMrktMathConfig.sol";
import {DMrktNFTLib} from "./DMrktNFTLib.sol";

// NOTE: Demo-only contract. Generated with AI and lightly modified.
// NB: Contract is not part of production code nor coupled to the architecture

contract DMrktLoot is DNFT, ERC721 {
    enum ItemType {
        Sword,
        Elixir,
        Shield
    }

    uint256 private _nextTokenId;

    mapping(uint256 => ItemType) private _tokenType;

    constructor() ERC721("dmrktLoot", "dloot") {}

    function MAX_SUPPLY() public pure override returns (uint256) {
        return DMrktMathConfig.lootMaxSupply();
    }

    // DNFT interface — auto-derives item type from tokenId
    function mint(address to) external {
        require(_nextTokenId < MAX_SUPPLY(), "Max supply reached");
        uint256 tokenId = _nextTokenId++;
        ItemType itemType = ItemType(tokenId % DMrktMathConfig.itemTypeCount());
        _tokenType[tokenId] = itemType;
        _safeMint(to, tokenId);
    }

    function totalSupply() external view returns (uint256) {
        return _nextTokenId;
    }

    function itemTypeOf(uint256 tokenId) external view returns (ItemType) {
        require(_ownerOf(tokenId) != address(0), "Not minted");
        return _tokenType[tokenId];
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

    function _metadata(uint256 tokenId) internal view returns (string memory) {
        ItemType itemType = _tokenType[tokenId];
        string memory svgBase64 = Base64.encode(bytes(_svg(tokenId, itemType)));
        (string memory name, string memory desc) = _itemMeta(tokenId, itemType);
        return
            DMrktNFTLib.buildLootMetadata(
                name,
                desc,
                tokenId,
                uint256(itemType),
                svgBase64
            );
    }

    function _itemMeta(
        uint256 tokenId,
        ItemType itemType
    ) internal pure returns (string memory name, string memory desc) {
        if (itemType == ItemType.Sword) {
            return (
                DMrktNFTLib.buildItemName("Sword", tokenId),
                "Fully on-chain dmrkt sword"
            );
        } else if (itemType == ItemType.Elixir) {
            return (
                DMrktNFTLib.buildItemName("Elixir", tokenId),
                "Fully on-chain dmrkt elixir"
            );
        } else {
            return (
                DMrktNFTLib.buildItemName("Shield", tokenId),
                "Fully on-chain dmrkt shield"
            );
        }
    }

    // ----------------------------
    // SVG GENERATION
    // ----------------------------

    function _svg(
        uint256 tokenId,
        ItemType itemType
    ) internal pure returns (string memory) {
        string memory color = DMrktNFTLib.getColorForToken(tokenId);
        string memory element = DMrktNFTLib.buildElementOverlay(tokenId);
        string memory glow = DMrktNFTLib.buildRarityGlow(tokenId);

        if (itemType == ItemType.Sword) {
            return _svgSword(color, element, glow);
        } else if (itemType == ItemType.Elixir) {
            return _svgElixir(color, element, glow);
        } else {
            return _svgShield(color, element, glow);
        }
    }

    function _svgSword(
        string memory color,
        string memory element,
        string memory glow
    ) internal pure returns (string memory) {
        return
            string(
                abi.encodePacked(
                    '<svg width="600" height="600" viewBox="0 0 600 600" xmlns="http://www.w3.org/2000/svg">',
                    '<rect width="600" height="600" rx="64" fill="#0b0b10"/>',
                    glow,
                    element,
                    '<rect x="290" y="120" width="20" height="260" fill="#d1d5db"/>',
                    '<rect x="240" y="300" width="120" height="20" fill="',
                    color,
                    '"/>',
                    '<rect x="295" y="320" width="10" height="100" fill="#78350f"/>',
                    '<rect x="285" y="420" width="30" height="30" fill="',
                    color,
                    '"/>',
                    '<text x="300" y="505" text-anchor="middle" fill="',
                    color,
                    '" font-family="monospace" font-size="34" letter-spacing="2">dmrkt</text>',
                    "</svg>"
                )
            );
    }

    function _svgElixir(
        string memory color,
        string memory element,
        string memory glow
    ) internal pure returns (string memory) {
        return
            string(
                abi.encodePacked(
                    '<svg width="600" height="600" viewBox="0 0 600 600" xmlns="http://www.w3.org/2000/svg">',
                    '<rect width="600" height="600" rx="64" fill="#0b0b10"/>',
                    glow,
                    '<rect x="280" y="150" width="40" height="60" fill="#9ca3af"/>',
                    '<rect x="270" y="120" width="60" height="30" fill="#a16207"/>',
                    '<rect x="220" y="210" width="160" height="180" fill="#111827"/>',
                    '<rect x="240" y="260" width="120" height="120" fill="',
                    color,
                    '"/>',
                    element,
                    '<rect x="260" y="240" width="20" height="120" fill="#ffffff" opacity="0.2"/>',
                    '<text x="300" y="505" text-anchor="middle" fill="',
                    color,
                    '" font-family="monospace" font-size="34" letter-spacing="2">dmrkt</text>',
                    "</svg>"
                )
            );
    }

    function _svgShield(
        string memory color,
        string memory element,
        string memory glow
    ) internal pure returns (string memory) {
        return
            string(
                abi.encodePacked(
                    '<svg width="600" height="600" viewBox="0 0 600 600" xmlns="http://www.w3.org/2000/svg">',
                    '<rect width="600" height="600" rx="64" fill="#0b0b10"/>',
                    glow,
                    '<rect x="240" y="180" width="120" height="160" fill="#111827"/>',
                    '<polygon points="240,340 360,340 300,420" fill="#111827"/>',
                    '<rect x="230" y="170" width="140" height="180" fill="none" stroke="',
                    color,
                    '" stroke-width="10"/>',
                    '<rect x="285" y="240" width="30" height="80" fill="',
                    color,
                    '"/>',
                    element,
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

    function getRarity(uint256 tokenId) public pure returns (string memory) {
        return DMrktNFTLib.getRarity(tokenId);
    }

    function getElement(uint256 tokenId) public pure returns (string memory) {
        return DMrktNFTLib.getElementForToken(tokenId);
    }

    function getElementName(
        uint256 tokenId
    ) public pure returns (string memory) {
        return DMrktNFTLib.getElementName(tokenId);
    }

    function getItemTypeName(
        uint256 tokenId
    ) external view returns (string memory) {
        require(_ownerOf(tokenId) != address(0), "Not minted");
        return DMrktNFTLib.getItemTypeName(uint256(_tokenType[tokenId]));
    }

    // === erc165 override ===

    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override(ERC721, IERC165) returns (bool) {
        return
            interfaceId == type(DNFT).interfaceId ||
            super.supportsInterface(interfaceId);
    }
}
