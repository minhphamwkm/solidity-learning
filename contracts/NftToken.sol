// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract NftToken is ERC721, Ownable {
    address owner;
    string name;
    string symbol;
    constructor(
        address _owner,
        string memory _name,
        string memory _symbol
    ) ERC721(_name, _symbol) Ownable(_owner) {
        owner = _owner;
        name = _name;
        symbol = _symbol;
    }
}
