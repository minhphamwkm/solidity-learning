// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./NftToken.sol";


contract NftAuction is ERC721 {
    struct AuctionInfo {
        address owner;
        uint256 highestBid;
        address payable highestBidder;
        uint256 auctionStartBlock;
        uint256 auctionEndBlock;
        bool isEnded;
        bool isClaimed;
    }

    mapping(address => AuctionInfo) auctions;

    constructor() ERC721("NftAuction", "NFTA") {}

    modifier duringAuction(address _nftId) {
        require(auctions[_nftId].auctionStartBlock < block.number && block.number < auctions[_nftId].auctionEndBlock, "Auction not open");
        _;
    }

    modifier notDuringAution(address _nftId) {
        require(auctions[_nftId].auctionStartBlock > block.number || block.number > auctions[_nftId].auctionEndBlock, "Auction not closed");
        _;
    }

    modifier isValidNft(address _nftId) {
        require(abi.encodePacked(auctions[_nftId]).length > 0, "Not owner");
        _;
    }

    modifier isOwner(address _nftId) {
        require(msg.sender == auctions[_nftId].owner, "Not owner");
        _;
    }

    modifier isClaimed(address _nftId) {
        require(auctions[_nftId].isClaimed, "NFT not claimed");
        _;
    }

    //
    function addNft(address _nftId, address _owner, uint256 _amount) external {
        auctions[_nftId] = AuctionInfo(_owner, _amount, payable(address(0)), block.number, block.number + 10, false, false);
    }

    function bid(address _nftId, uint _amount) payable external duringAuction(_nftId) {
        require(msg.value > _amount, "Insufficient balance");
        require(auctions[_nftId].highestBid < _amount, "Bid must be higher than the highest bid");

        auctions[_nftId].highestBid = _amount;
        auctions[_nftId].highestBidder = payable msg.sender;
    }

    function claim(address _nftId) external notDuringAution(_nftId) {
    }

    function withdraw(address _nftId) external notDuringAution(_nftId) isOwner(_nftId) {
    }
}
