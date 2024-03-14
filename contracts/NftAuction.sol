// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * Bài 3:
    - Viết contract bán NFT theo giá bid:
        + Sẽ có nhiều người được bán cùng lúc
        + userA có NFT, muốn bán NFT theo cách đấu giá
        + userA nạp NFT vào sàn đấu giá
        + Có thời gian bắt đầu, kết thúc
        + Sau thời gian kết thúc:
            - Nếu có người đấu giá, NFT sẽ được chuyển cho người đấu giá có giá cao nhất
            - Tiền sẽ được chuyển về người bán
            - Nếu không có người đấu giá, NFT sẽ được trả về cho người bán
        + Có thể hủy đấu giá trước thời gian kết thúc nếu không có người đấu giá, NFT sẽ đc trả về người bán
        + Admin có quyền hủy đấu giá bất kì lúc nào, NFT sẽ đc trả về người bán, người đã đấu giá sẽ được nhận lại tiền
    - Vẽ diagram cho flow của contract
    - Viết contract theo logic được vẽ từ diagram + unit test
 */

contract NFT is ERC721, Ownable {
    constructor(address _owner) ERC721("NFT", "NFT") Ownable(_owner) {}

    function mint(address to, uint256 tokenId) public onlyOwner {
        _safeMint(to, tokenId);
    }
}

contract Auction is Ownable {
    struct AuctionInfo {
        address owner;
        uint256 tokenId;
        address tokenContract;
        uint256 highestBid;
        address payable highestBidder;
        uint256 startTime;
        uint256 endTime;
        bool isClaimed;
    }

    mapping(uint256 => AuctionInfo) public auctions;

    event NewBid(
        address indexed bidder,
        uint256 indexed tokenId,
        uint256 amount
    );
    event AuctionEnded(
        uint256 indexed tokenId,
        address indexed winner,
        uint256 amount
    );
    event Claimed(address indexed bidder, uint256 indexed tokenID);

    modifier auctionExists(uint256 tokenId) {
        require(
            auctions[tokenId].owner != address(0),
            "Auction does not exist"
        );
        _;
    }

    modifier onlyTokenOwner(uint256 tokenId) {
        require(auctions[tokenId].owner == msg.sender, "Not the token owner");
        _;
    }

    modifier bidable(uint256 tokenId) {
        require(
            auctions[tokenId].startTime < block.timestamp &&
                auctions[tokenId].endTime > block.timestamp,
            "Auction not open"
        );
        _;
    }

    modifier claimable(uint256 tokenId) {
        require(!auctions[tokenId].isClaimed, "Auction already claimed");
        require(auctions[tokenId].endTime < block.number, "Auction not closed");
        require(
            auctions[tokenId].highestBidder == msg.sender,
            "Not the token highest bidder"
        );
        _;
    }

    constructor(address owner) Ownable(owner) {}

    function startAuction(
        address tokenContract,
        uint256 tokenId,
        uint256 amount,
        uint256 startTime,
        uint256 endTime
    ) external {
        NFT nft = NFT(tokenContract);
        require(nft.ownerOf(tokenId) == msg.sender, "Not token owner");
        require(
            startTime > block.timestamp,
            "start time should be > block timestamp"
        );
        require(endTime > startTime, "end time should be > start time");

        nft.transferFrom(msg.sender, address(this), tokenId);

        auctions[tokenId] = AuctionInfo({
            owner: msg.sender,
            tokenId: tokenId,
            tokenContract: tokenContract,
            highestBid: amount,
            highestBidder: payable(address(0)),
            startTime: startTime,
            endTime: endTime,
            isClaimed: false
        });
    }

    function bid(
        uint256 tokenId
    ) external payable auctionExists(tokenId) bidable(tokenId) {
        AuctionInfo memory auction = auctions[tokenId];

        require(msg.value > auction.highestBid, "Bid too low");

        if (auction.highestBidder != address(0)) {
            auction.highestBidder.transfer(auction.highestBid);
        }

        auction.highestBid = msg.value;
        auction.highestBidder = payable(msg.sender);

        emit NewBid(msg.sender, tokenId, msg.value);
    }

    function endAuction(
        uint256 tokenId
    ) external auctionExists(tokenId) bidable(tokenId) onlyTokenOwner(tokenId) {
        AuctionInfo storage auction = auctions[tokenId];
        NFT nft = NFT(auction.tokenContract);
        if (auction.highestBidder == address(0)) {
            nft.transferFrom(address(this), msg.sender, tokenId);
        } else {
            nft.transferFrom(address(this), auction.highestBidder, tokenId);
            payable(auction.owner).transfer(auction.highestBid);
        }

        auction.endTime = block.timestamp;
        auction.isClaimed = true;
        emit AuctionEnded(tokenId, auction.highestBidder, auction.highestBid);
    }

    function claimNFT(
        uint256 tokenId
    ) external auctionExists(tokenId) claimable(tokenId) {
        AuctionInfo storage auction = auctions[tokenId];
        NFT nft = NFT(auction.tokenContract);

        nft.transferFrom(address(this), msg.sender, tokenId);
        auction.isClaimed = true;

        payable(auction.owner).transfer(auction.highestBid);

        emit Claimed(msg.sender, tokenId);
    }

    function forceEnded(
        uint256 tokenId
    ) public auctionExists(tokenId) onlyOwner {
        AuctionInfo storage auction = auctions[tokenId];
        NFT nft = NFT(auction.tokenContract);
        nft.transferFrom(address(this), auction.owner, tokenId);
        payable(auction.highestBidder).transfer(auction.highestBid);
        auction.isClaimed = true;
        auction.endTime = block.timestamp;
    }
}
