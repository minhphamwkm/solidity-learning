// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 *
 * Bài 2: Viết contract mua NFT
 * Contract NFT 721
 * Trong vòng 10 block, người dùng có quyền đấu giá mua NFT
 * Người dùng đấu giá bằng ETH
 * Ở block thứ 10, người dùng có giá trị đấu giá cao nhất sẽ được quyền claim NFT về ví mình
 * Nếu không có người dùng nào đấu giá, NFT sẽ được trả về cho owner.
 * Vòng tiếp theo sẽ được bắt đầu sau khi người trước claim NFT hoặc NFT được trả về cho owner.
 * Thời hạn bắt đầu tính từ block thứ 0 cho đấu giá là lúc contract được deploy.
 */

contract NftToken is ERC721, Ownable {
    address nftOwner;

    address payable highestBidder;
    uint256 highestBidAmount;

    uint256 blockStart;
    uint256 constant TIMELINE = 100;

    uint256 currentTokenId;

    constructor(address owner) Ownable(owner) ERC721("NftToken", "NFT") {
        nftOwner = owner;
        blockStart = block.number;
    }

    event NewBid(
        address indexed bidder,
        uint256 indexed tokenId,
        uint256 amount
    );
    event NewNft(uint256 indexed tokenId);

    modifier bidable() {
        require(
            blockStart < block.number && blockStart + TIMELINE > block.number,
            "Auction not open"
        );
        _;
    }

    modifier claimable() {
        require(blockStart + TIMELINE < block.number, "Auction not closed");
        _;
    }

    function getHighestBid() external view returns (address, uint256) {
        return (highestBidder, highestBidAmount);
    }

    function getCurrentTokenId() external view returns (uint256) {
        return currentTokenId;
    }

    function bid() external payable bidable {
        require(
            highestBidAmount < msg.value,
            "Bid must be higher than the highest bid"
        );

        if (highestBidder != address(0)) {
            highestBidder.transfer(highestBidAmount);
        }
        highestBidder = payable(msg.sender);
        highestBidAmount = msg.value;

        emit NewBid(highestBidder, currentTokenId, highestBidAmount);
    }

    function claim() external claimable {
        if (highestBidder == address(0)) {
            _mint(nftOwner, currentTokenId);
        } else {
            _mint(highestBidder, currentTokenId);
            payable(nftOwner).transfer(highestBidAmount);
        }

        highestBidder = payable(address(0));
        highestBidAmount = 0;
        currentTokenId += 1;

        emit NewNft(currentTokenId);
    }
}
