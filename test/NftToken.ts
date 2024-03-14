import {
  loadFixture,
  mine,
} from "@nomicfoundation/hardhat-toolbox/network-helpers";
import { expect } from "chai";
import { ethers } from "hardhat";

describe("NftToken", function () {
  async function deploy() {
    const [owner, alice, bob, ..._] = await ethers.getSigners();

    const NftToken = await ethers.getContractFactory("NftToken");
    const nftToken = await NftToken.deploy(owner);

    return { nftToken, owner, alice, bob };
  }

  it("Should bid successful when biddable", async function () {
    const { nftToken, owner, alice, bob } = await loadFixture(deploy);

    await nftToken.connect(alice).bid({ value: 100 });

    const [highestBidder, highestBid] = await nftToken.getHighestBid();

    expect(highestBid).to.equal(100);
    expect(highestBidder).to.equal(alice.address);
  });

  it("Should raise error if bid when cannot biddable", async function () {
    const { nftToken, owner, alice, bob } = await loadFixture(deploy);
    await nftToken.connect(alice).bid({ value: 10 });
    await nftToken.connect(bob).bid({ value: 30 });

    mine(200);
    await expect(
      nftToken.connect(alice).bid({ value: 100 })
    ).to.be.revertedWith("Auction not open");
  });

  it("Should update highest bidder is bob when alice bid 10 then bob bid 30", async function () {
    const { nftToken, owner, alice, bob } = await loadFixture(deploy);
    await nftToken.connect(alice).bid({ value: 10 });
    await nftToken.connect(bob).bid({ value: 30 });

    const [highestBidder, highestBid] = await nftToken.getHighestBid();

    expect(highestBid).to.equal(30);
    expect(highestBidder).to.equal(bob.address);
  });

  it("Should raise error when bob bid lower than highest bid", async function () {
    const { nftToken, owner, alice, bob } = await loadFixture(deploy);
    await nftToken.connect(alice).bid({ value: 30 });
    await expect(nftToken.connect(bob).bid({ value: 10 })).to.be.revertedWith(
      "Bid must be higher than the highest bid"
    );
  });

  it("Should raise error when claim in bid time", async function () {
    const { nftToken, owner, alice, bob } = await loadFixture(deploy);
    await expect(nftToken.claim()).to.be.revertedWith("Auction not closed");
  });

  it("Should owner claim nft when no one bid and generate new nft", async function () {
    const { nftToken, owner, alice, bob } = await loadFixture(deploy);
    mine(200);
    await nftToken.claim();
    const ownerNft = await nftToken.ownerOf(0);
    expect(ownerNft).to.equal(owner.address);
    expect(await nftToken.getCurrentTokenId()).to.equal(1);
  });

  it("Should highest bidder claim nft when bid time end", async function () {
    const { nftToken, owner, alice, bob } = await loadFixture(deploy);
    await nftToken.connect(alice).bid({ value: 10 });

    mine(200);
    await nftToken.claim();
    const ownerNft = await nftToken.ownerOf(0);
    expect(ownerNft).to.equal(alice.address);
    expect(await nftToken.getCurrentTokenId()).to.equal(1);
  });

  it("Should highest bidder claim nft when bid time end", async function () {
    const { nftToken, owner, alice, bob } = await loadFixture(deploy);
    await nftToken.connect(alice).bid({ value: 10 });

    mine(200);
    await nftToken.claim();
    const ownerNft = await nftToken.ownerOf(0);
    expect(ownerNft).to.equal(alice.address);
    expect(await nftToken.getCurrentTokenId()).to.equal(1);
  });
});
