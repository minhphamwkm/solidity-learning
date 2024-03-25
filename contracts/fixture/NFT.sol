// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract NFT is ERC721, Ownable {
    constructor(address owner) Ownable(owner) ERC721("NFT", "NFT") {}

    function mint(address to, uint256 tokenId) external onlyOwner {
        _mint(to, tokenId);
    }
}
