import { loadFixture } from "@nomicfoundation/hardhat-toolbox/network-helpers";
import { expect } from "chai";
import { ethers } from "hardhat";

describe("MyToken", function () {
  async function deploy() {
    const [owner, alice, bob, ...addresses] = await ethers.getSigners();

    const MyToken = await ethers.getContractFactory("MyToken");
    const myToken = await MyToken.deploy(owner);

    return { myToken, owner, alice, bob, addresses };
  }

  it("Should correct contract name, symbol & mint to owner 1M", async function () {
    const { myToken, owner, alice, bob, addresses } = await loadFixture(deploy);

    expect(await myToken.name()).to.equal("MyToken");
    expect(await myToken.symbol()).to.equal("MTK");
    const parsedMint = ethers.parseUnits("1000000", 18);
    expect(await myToken.balanceOf(owner.address)).to.equal(parsedMint);
  });

  it("Should mint to alice 1M", async function () {
    const { myToken, owner, alice, bob } = await loadFixture(deploy);

    const parsedMint = ethers.parseUnits("1000000", 18);
    await myToken.mint(alice, parsedMint);
    expect(await myToken.balanceOf(alice)).to.equal(parsedMint);
  });

  it("Should alice self mint 1M failed", async function () {
    const { myToken, owner, alice, bob } = await loadFixture(deploy);

    const parsedMint = ethers.parseUnits("1000000", 18);
    await expect(myToken.connect(alice).mint(alice, parsedMint)).to.be.revertedWithCustomError(
      myToken,
      "OwnableUnauthorizedAccount"
    );
  });

  it("Should transfer from alice to bob 100", async function () {
    const { myToken, owner, alice, bob } = await loadFixture(deploy);

    const parsedMint = ethers.parseUnits("1000000", 18);
    const parsedTransferAmount = ethers.parseUnits("100", 18);

    await myToken.mint(alice, parsedMint);
    await myToken.connect(alice).transfer(bob, parsedTransferAmount);

    const aliceBalance = ethers.formatEther(await myToken.balanceOf(alice));
    const bobBalance = ethers.formatEther(await myToken.balanceOf(bob));
    expect(aliceBalance).to.equal("999900.0");
    expect(bobBalance).to.equal("100.0");
  });

  it("Should approve from alice to bob 50", async function () {
    const { myToken, owner, alice, bob } = await loadFixture(deploy);

    const parsedMint = ethers.parseUnits("1000000", 18);

    await myToken.mint(alice, parsedMint);
    let parsedApproveAmount = ethers.parseUnits("50", 18);
    await myToken.connect(alice).approve(bob, parsedApproveAmount);

    let allowanceAmount = ethers.formatEther(await myToken.allowance(alice, bob));
    expect(allowanceAmount).to.equal("50.0");
  });

  it("Should transferFrom alice to bob 50", async function () {
    const { myToken, owner, alice, bob } = await loadFixture(deploy);

    const parsedMint = ethers.parseUnits("1000000", 18);
    await myToken.mint(alice, parsedMint);

    let parsedApproveAmount = ethers.parseUnits("50", 18);
    await myToken.connect(alice).approve(owner, parsedApproveAmount);
    await myToken.transferFrom(alice, bob, parsedApproveAmount);

    const aliceBalance = ethers.formatEther(await myToken.balanceOf(alice));
    const bobBalance = ethers.formatEther(await myToken.balanceOf(bob));
    expect(aliceBalance).to.equal("999950.0");
    expect(bobBalance).to.equal("50.0");
  });

  it("Should transferFrom alice to bob 50, but sender is bob", async function () {
    const { myToken, owner, alice, bob } = await loadFixture(deploy);

    const parsedMint = ethers.parseUnits("1000000", 18);
    await myToken.mint(alice, parsedMint);

    let parsedApproveAmount = ethers.parseUnits("50", 18);
    await myToken.connect(alice).approve(bob, parsedApproveAmount);
    await myToken.connect(bob).transferFrom(alice, bob, parsedApproveAmount);

    const aliceBalance = ethers.formatEther(await myToken.balanceOf(alice));
    const bobBalance = ethers.formatEther(await myToken.balanceOf(bob));
    expect(aliceBalance).to.equal("999950.0");
    expect(bobBalance).to.equal("50.0");
  });

  it("Should admin burn alice 10", async function () {
    const { myToken, owner, alice, bob } = await loadFixture(deploy);

    const parsedMint = ethers.parseUnits("1000000", 18);
    await myToken.mint(alice, parsedMint);
    await myToken.burn(alice, ethers.parseUnits("10", 18));
    const aliceBalance = ethers.formatEther(await myToken.balanceOf(alice));
    expect(aliceBalance).to.equal("999990.0");
  });

  it("Should admin burn alice 10 fail cause Insufficient Balance", async function () {
    const { myToken, owner, alice, bob } = await loadFixture(deploy);

    await myToken.mint(alice, 1);
    await expect(myToken.burn(alice, 10)).to.be.revertedWithCustomError(myToken, "ERC20InsufficientBalance");
  });

  it("Should alice use admin burn 10 fail", async function () {
    const { myToken, owner, alice, bob } = await loadFixture(deploy);

    const parsedMint = ethers.parseUnits("1000000", 18);
    await myToken.mint(alice, parsedMint);
    await expect(myToken.connect(alice).burn(alice, ethers.parseUnits("10", 18))).to.be.revertedWithCustomError(
      myToken,
      "OwnableUnauthorizedAccount"
    );
  });

  it("Should alice burn 10 itself", async function () {
    const { myToken, owner, alice, bob } = await loadFixture(deploy);

    const parsedMint = ethers.parseUnits("1000000", 18);
    await myToken.mint(alice, parsedMint);

    let parsedBurnAmount = ethers.parseUnits("10", 18);
    await myToken.connect(alice).selfBurn(parsedBurnAmount);

    const aliceBalance = ethers.formatEther(await myToken.balanceOf(alice));
    expect(aliceBalance).to.equal("999990.0");
  });

  it("Should alice burn self 10 fail cause Insufficient Balance", async function () {
    const { myToken, owner, alice, bob } = await loadFixture(deploy);

    await myToken.mint(alice, 1);
    await expect(myToken.connect(alice).selfBurn(10)).to.be.revertedWithCustomError(
      myToken,
      "ERC20InsufficientBalance"
    );
  });
});
