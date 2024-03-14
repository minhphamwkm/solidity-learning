import {
  loadFixture,
  mine,
} from "@nomicfoundation/hardhat-toolbox/network-helpers";
import { expect } from "chai";
import { ethers } from "hardhat";

describe("Auction", function () {
  async function deploy() {
    const [owner, alice, bob, charlie, david, evan, ..._] =
      await ethers.getSigners();

    const NftToken = await ethers.getContractFactory("NFT");
    const nftToken = await NftToken.deploy(owner);

    await nftToken.mint(alice.address, 1);
    await nftToken.mint(bob.address, 2);

    const Auction = await ethers.getContractFactory("Auction");
    const auction = await Auction.deploy(owner);

    return { nftToken, auction, owner, alice, bob, charlie, david, evan };
  }

  it("Should start auction successful", async function () {
    const { nftToken, auction, owner, alice, bob, charlie, david, evan } =
      await loadFixture(deploy);

    await auction.connect(alice).addAuction(nftToken, 1, 100, 100, 500);
    await auction.connect(bob).addAuction(nftToken, 2, 100, 100, 500);

    const aliceAuction = await auction.getAuctionInfo(1);
    console.log("🚀 ~ aliceAuction:", aliceAuction);
  });
});
