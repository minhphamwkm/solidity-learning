// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "./interfaces/INFT.sol";

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
contract Auction is Ownable, IERC721Receiver {
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

    uint256 auctionId;

    mapping(uint256 => AuctionInfo) public auctions;

    event NewAuction(
        address indexed owner,
        uint256 indexed auctionId,
        uint256 tokenId,
        address tokenContract,
        uint256 startTime,
        uint256 endTime
    );

    event NewBid(
        address indexed bidder,
        uint256 indexed auctionId,
        uint256 amount
    );
    event AuctionEnded(
        uint256 indexed auctionId,
        address indexed winner,
        uint256 amount
    );
    event Claimed(address indexed bidder, uint256 indexed auctionId);

    modifier auctionExists(uint256 _auctionId) {
        require(
            auctions[_auctionId].owner != address(0),
            "Auction does not exist"
        );
        _;
    }

    modifier onlyTokenOwner(uint256 _auctionId) {
        require(
            auctions[_auctionId].owner == msg.sender,
            "Not the token owner"
        );
        _;
    }

    modifier bidable(uint256 _auctionId) {
        require(
            auctions[_auctionId].startTime < block.number &&
                auctions[_auctionId].endTime > block.number,
            "Auction not open"
        );
        _;
    }

    modifier claimable(uint256 _auctionId) {
        require(!auctions[_auctionId].isClaimed, "Auction already claimed");
        require(
            auctions[_auctionId].highestBidder == msg.sender,
            "Not the token highest bidder"
        );
        _;
    }

    modifier validTimeline(uint256 _startTime, uint256 _endTime) {
        require(
            _startTime > block.number,
            "Start time should be > block number"
        );
        require(_endTime > _startTime, "End time should be > start time");
        _;
    }

    constructor(address _owner) Ownable(_owner) {
        auctionId = 1;
    }

    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external pure override returns (bytes4) {
        return
            bytes4(
                keccak256("onERC721Received(address,address,uint256,bytes)")
            );
    }

    function addAuction(
        address _tokenContract,
        uint256 _tokenId,
        uint256 _amount,
        uint256 _startTime,
        uint256 _endTime
    ) external validTimeline(_startTime, _endTime) {
        INFT nft = INFT(_tokenContract);
        require(nft.ownerOf(_tokenId) == msg.sender, "Not token owner");
        nft.safeTransferFrom(msg.sender, address(this), _tokenId);
        auctions[auctionId] = AuctionInfo({
            owner: msg.sender,
            tokenId: _tokenId,
            tokenContract: _tokenContract,
            highestBid: _amount,
            highestBidder: payable(address(0)),
            startTime: _startTime,
            endTime: _endTime,
            isClaimed: false
        });
        emit NewAuction(
            msg.sender,
            auctionId,
            _tokenId,
            _tokenContract,
            _startTime,
            _endTime
        );
        auctionId += 1;
    }

    function getAuctionInfo(
        uint256 _auctionId
    ) external view returns (AuctionInfo memory) {
        return auctions[_auctionId];
    }

    function getAllAuctions() external view returns (AuctionInfo[] memory) {
        AuctionInfo[] memory result = new AuctionInfo[](auctionId - 1);
        for (uint256 i = 1; i < auctionId; i++) {
            result[i - 1] = auctions[i];
        }
        return result;
    }

    function bid(
        uint256 _auctionId
    ) external payable auctionExists(_auctionId) bidable(_auctionId) {
        AuctionInfo storage auction = auctions[_auctionId];

        require(msg.value > auction.highestBid, "Bid too low");

        if (auction.highestBidder != address(0)) {
            auction.highestBidder.transfer(auction.highestBid);
        }

        auction.highestBid = msg.value;
        auction.highestBidder = payable(msg.sender);

        emit NewBid(msg.sender, _auctionId, msg.value);
    }

    function endAuction(
        uint256 _auctionId
    )
        external
        auctionExists(_auctionId)
        bidable(_auctionId)
        onlyTokenOwner(_auctionId)
    {
        AuctionInfo storage auction = auctions[_auctionId];
        INFT nft = INFT(auction.tokenContract);
        require(auction.highestBidder == address(0), "Already have bidder");
        nft.safeTransferFrom(address(this), msg.sender, auction.tokenId);

        auction.endTime = block.number;
        auction.isClaimed = true;
        emit AuctionEnded(
            _auctionId,
            auction.highestBidder,
            auction.highestBid
        );
    }

    function claimNFT(
        uint256 _auctionId
    ) external auctionExists(_auctionId) claimable(_auctionId) {
        AuctionInfo storage auction = auctions[_auctionId];
        INFT nft = INFT(auction.tokenContract);

        nft.safeTransferFrom(
            address(this),
            auction.highestBidder,
            auction.tokenId
        );
        payable(auction.owner).transfer(auction.highestBid);

        auction.isClaimed = true;

        emit Claimed(msg.sender, auction.tokenId);
    }

    function forceEnded(
        uint256 _auctionId
    ) public auctionExists(_auctionId) onlyOwner {
        AuctionInfo storage auction = auctions[_auctionId];

        require(auction.isClaimed == false, "Auction already claimed");

        INFT nft = INFT(auction.tokenContract);

        nft.safeTransferFrom(address(this), auction.owner, auction.tokenId);

        if (auction.highestBidder != address(0)) {
            payable(auction.highestBidder).transfer(auction.highestBid);
        }
        auction.isClaimed = true;
        auction.endTime = block.number;
        auction.highestBid = 0;
        auction.highestBidder = payable(address(0));

        emit AuctionEnded(
            _auctionId,
            auction.highestBidder,
            auction.highestBid
        );
    }
}
