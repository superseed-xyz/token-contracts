// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { ERC721 } from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import { ERC721URIStorage } from "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

interface ICharacterToken {
    function mintToWithURI(address to, string calldata tokenURI_) external returns (uint256 tokenId);
}

contract CharacterToken is ERC721, ERC721URIStorage, Ownable {
    uint256 private _nextTokenId = 0;

    constructor(
        string memory name_,
        string memory symbol_,
        address initialOwner_
    )
        ERC721(name_, symbol_)
        Ownable(initialOwner_)
    { }

    function mintToWithURI(address to, string calldata tokenURI_) external onlyOwner returns (uint256 tokenId) {
        tokenId = _nextTokenId++;
        _safeMint(to, tokenId);
        _setTokenURI(tokenId, tokenURI_);
    }

    function tokenURI(uint256 tokenId) public view override(ERC721, ERC721URIStorage) returns (string memory) {
        return ERC721URIStorage.tokenURI(tokenId);
    }

    function supportsInterface(bytes4 interfaceId) public view override(ERC721, ERC721URIStorage) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
