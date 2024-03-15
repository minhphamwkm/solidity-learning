import {
  loadFixture,
  mine,
} from "@nomicfoundation/hardhat-toolbox/network-helpers";
import { expect } from "chai";
import { ethers } from "hardhat";

describe("Auction", function () {
  const ZERO_ADDRESS = "0x0000000000000000000000000000000000000000";

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

  it("Should alice and bob add auction successful", async function () {
    const { nftToken, auction, owner, alice, bob, charlie, david, evan } =
      await loadFixture(deploy);

    await nftToken.connect(alice).approve(auction.getAddress(), 1);
    const aliceAddAuctionTx = auction
      .connect(alice)
      .addAuction(nftToken, 1, 100, 100, 500);

    await expect(aliceAddAuctionTx).to.changeTokenBalance(nftToken, alice, -1);
    await expect(aliceAddAuctionTx)
      .to.emit(auction, "NewAuction")
      .withArgs(alice.address, 1, 1, nftToken.getAddress(), 100, 500);

    // auction id start at 1
    const aliceAuction = await auction.getAuctionInfo(1);

    expect(aliceAuction.tokenId).to.equal(1);
    expect(aliceAuction.tokenContract).to.equal(await nftToken.getAddress());
    expect(aliceAuction.highestBid).to.equal(100);
    expect(aliceAuction.startTime).to.equal(100);
    expect(aliceAuction.endTime).to.equal(500);

    await nftToken.connect(bob).approve(auction, 2);
    const bobAddAuctionTx = auction
      .connect(bob)
      .addAuction(nftToken, 2, 100, 400, 1000);

    await expect(bobAddAuctionTx).to.changeTokenBalance(nftToken, bob, -1);
    await expect(bobAddAuctionTx)
      .to.emit(auction, "NewAuction")
      .withArgs(bob.address, 2, 2, nftToken.getAddress(), 400, 1000);

    const bobAuction = await auction.getAuctionInfo(2);

    expect(bobAuction.tokenId).to.equal(2);
    expect(bobAuction.tokenContract).to.equal(await nftToken.getAddress());
    expect(bobAuction.highestBid).to.equal(100);
    expect(bobAuction.startTime).to.equal(400);
    expect(bobAuction.endTime).to.equal(1000);
  });

  it("Should charlie bid alice auction successful", async function () {
    const { nftToken, auction, owner, alice, bob, charlie, david, evan } =
      await loadFixture(deploy);

    await nftToken.connect(alice).approve(auction, 1);
    await auction.connect(alice).addAuction(nftToken, 1, 100, 100, 500);
    mine(200);

    const charlieBidTx = auction.connect(charlie).bid(1, { value: 200 });
    await expect(charlieBidTx).to.changeEtherBalance(charlie, -200);
    await expect(charlieBidTx)
      .to.emit(auction, "NewBid")
      .withArgs(charlie.address, 1, 200);

    const aliceAuction = await auction.getAuctionInfo(1);

    expect(aliceAuction.highestBid).to.equal(200);
    expect(aliceAuction.highestBidder).to.equal(charlie.address);
  });

  it("Should david bid alice auction successful when bid more than charlie bid before", async function () {
    const { nftToken, auction, owner, alice, bob, charlie, david, evan } =
      await loadFixture(deploy);

    await nftToken.connect(alice).approve(auction, 1);
    await auction.connect(alice).addAuction(nftToken, 1, 100, 100, 500);
    mine(200);

    await auction.connect(charlie).bid(1, { value: 200 });
    const davidBidHigherTx = auction.connect(david).bid(1, { value: 300 });

    await expect(davidBidHigherTx).to.changeEtherBalance(charlie, 200);
    await expect(davidBidHigherTx).to.changeEtherBalance(david, -300);

    await expect(davidBidHigherTx)
      .to.emit(auction, "NewBid")
      .withArgs(david.address, 1, 300);

    const aliceAuction = await auction.getAuctionInfo(1);
    expect(aliceAuction.highestBid).to.equal(300);
    expect(aliceAuction.highestBidder).to.equal(david.address);
  });

  it("Should charlie bid bob auction fail cause auction not exist", async function () {
    const { nftToken, auction, owner, alice, bob, charlie, david, evan } =
      await loadFixture(deploy);

    await expect(
      auction.connect(charlie).bid(1, { value: 200 })
    ).to.be.revertedWith("Auction does not exist");
  });

  it("Should charlie bid bob auction fail cause not biddable time", async function () {
    const { nftToken, auction, owner, alice, bob, charlie, david, evan } =
      await loadFixture(deploy);

    await nftToken.connect(alice).approve(auction, 1);
    await auction.connect(alice).addAuction(nftToken, 1, 100, 100, 500);
    await expect(
      auction.connect(charlie).bid(1, { value: 200 })
    ).to.be.revertedWith("Auction not open");
  });

  it("Should charlie bid bob auction fail cause not bid too low", async function () {
    const { nftToken, auction, owner, alice, bob, charlie, david, evan } =
      await loadFixture(deploy);

    await nftToken.connect(alice).approve(auction, 1);
    await auction.connect(alice).addAuction(nftToken, 1, 100, 100, 500);
    mine(200);
    await expect(
      auction.connect(charlie).bid(1, { value: 2 })
    ).to.be.revertedWith("Bid too low");
  });

  it("Should alice end auction soon successful when no bidder", async function () {
    const { nftToken, auction, owner, alice, bob, charlie, david, evan } =
      await loadFixture(deploy);

    await nftToken.connect(alice).approve(auction, 1);
    await auction.connect(alice).addAuction(nftToken, 1, 100, 100, 500);
    mine(200);

    const aliceEndAuctionTx = auction.connect(alice).endAuction(1);
    await expect(aliceEndAuctionTx).to.changeTokenBalance(nftToken, alice, 1);
    await expect(aliceEndAuctionTx)
      .to.emit(auction, "AuctionEnded")
      .withArgs(1, ZERO_ADDRESS, 100);
    expect(await nftToken.ownerOf(1)).to.equal(alice.address);

    const aliceAuction = await auction.getAuctionInfo(1);
    expect(aliceAuction.isClaimed).to.equal(true);
  });

  it("Should alice end auction soon fail cause already have bidder", async function () {
    const { nftToken, auction, owner, alice, bob, charlie, david, evan } =
      await loadFixture(deploy);

    await nftToken.connect(alice).approve(auction, 1);
    await auction.connect(alice).addAuction(nftToken, 1, 100, 100, 500);
    mine(200);
    await auction.connect(charlie).bid(1, { value: 200 });

    await expect(auction.connect(alice).endAuction(1)).to.be.revertedWith(
      "Already have bidder"
    );
  });

  it("Should claim alice auction successful", async function () {
    const { nftToken, auction, owner, alice, bob, charlie, david, evan } =
      await loadFixture(deploy);

    await nftToken.connect(alice).approve(auction, 1);
    await auction.connect(alice).addAuction(nftToken, 1, 100, 100, 500);
    mine(200);

    await auction.connect(charlie).bid(1, { value: 200 });

    mine(500);

    const charlieClaimTokenTx = auction.connect(charlie).claimNFT(1);
    await expect(charlieClaimTokenTx).to.changeTokenBalance(
      nftToken,
      charlie,
      1
    );
    await expect(charlieClaimTokenTx)
      .to.emit(auction, "Claimed")
      .withArgs(charlie.address, 1);
    await expect(charlieClaimTokenTx).to.changeEtherBalance(alice, 200);
    const aliceAuction = await auction.getAuctionInfo(1);
    expect(aliceAuction.isClaimed).to.equal(true);
    expect(await nftToken.ownerOf(aliceAuction[1])).to.equal(charlie.address);
  });

  it("Should claim alice auction fail cause claimer not highest bidder", async function () {
    const { nftToken, auction, owner, alice, bob, charlie, david, evan } =
      await loadFixture(deploy);

    await nftToken.connect(alice).approve(auction, 1);
    await auction.connect(alice).addAuction(nftToken, 1, 100, 100, 500);
    mine(200);

    await auction.connect(charlie).bid(1, { value: 200 });

    mine(500);
    await expect(auction.connect(alice).claimNFT(1)).to.be.revertedWith(
      "Not the token highest bidder"
    );
  });

  it("Should force end auction by admin during bid time successful", async function () {
    const { nftToken, auction, owner, alice, bob, charlie, david, evan } =
      await loadFixture(deploy);

    await nftToken.connect(alice).approve(auction, 1);
    await auction.connect(alice).addAuction(nftToken, 1, 100, 100, 500);
    mine(200);

    await auction.connect(charlie).bid(1, { value: 200 });
    const adminForceEndTx = auction.connect(owner).forceEnded(1);

    await expect(adminForceEndTx).to.changeTokenBalance(nftToken, alice, 1);
    await expect(adminForceEndTx).to.changeEtherBalance(charlie, 200);
    await expect(adminForceEndTx)
      .to.emit(auction, "AuctionEnded")
      .withArgs(1, ZERO_ADDRESS, 0);

    const aliceAuction = await auction.getAuctionInfo(1);
    expect(aliceAuction.isClaimed).to.equal(true);
    expect(await nftToken.ownerOf(1)).to.equal(alice.address);
  });

  it("Should force end auction by admin during bid time fail cause auction already claimed", async function () {
    const { nftToken, auction, owner, alice, bob, charlie, david, evan } =
      await loadFixture(deploy);

    await nftToken.connect(alice).approve(auction, 1);
    await auction.connect(alice).addAuction(nftToken, 1, 100, 100, 500);
    mine(200);

    await auction.connect(charlie).bid(1, { value: 200 });
    mine(500);
    await auction.connect(charlie).claimNFT(1);

    await expect(auction.connect(owner).forceEnded(1)).to.be.revertedWith(
      "Auction already claimed"
    );
  });
});
