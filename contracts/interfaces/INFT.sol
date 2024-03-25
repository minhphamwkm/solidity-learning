// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.24;

interface INFT {
    function ownerOf(uint256 tokenId) external view returns (address);

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external;
}
