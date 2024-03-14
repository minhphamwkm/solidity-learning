import { loadFixture } from "@nomicfoundation/hardhat-toolbox/network-helpers";
import { expect } from "chai";
import { ethers } from "hardhat";

describe("NftToken", function () {
  async function deploy() {
    const [owner, alice, bob, charlie, ..._] = await ethers.getSigners();

    const NftToken = await ethers.getContractFactory("NftToken");
    const nftToken = await NftToken.deploy(owner);

    return { nftToken, owner, alice, bob, charlie };
  }

  it("Should deploy contract successful, with blockStart is current block number", async function () {
    const { nftToken, owner, alice, bob, charlie } = await loadFixture(deploy);

    expect(await nftToken.getCurrentBlock()).to.equal(0);
  });
});
