import {
  loadFixture,
  mine,
} from "@nomicfoundation/hardhat-toolbox/network-helpers";
import { expect } from "chai";
import { ethers } from "hardhat";

describe("StakeContract", function () {
  async function deploy() {
    const [owner, alice, bob, ..._] = await ethers.getSigners();

    const StakeContract = await ethers.getContractFactory("StakeContract");
    const stakeContract = await StakeContract.deploy();

    return { stakeContract, owner, alice, bob };
  }

  it("Should owner deposit successful", async function () {
    const { stakeContract, owner, alice, bob } = await loadFixture(deploy);

    await nftToken.connect(alice).bid({ value: 100 });

    const [highestBidder, highestBid] = await nftToken.getHighestBid();

    expect(highestBid).to.equal(100);
    expect(highestBidder).to.equal(alice.address);
  });
});
