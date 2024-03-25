import { loadFixture, time } from "@nomicfoundation/hardhat-toolbox/network-helpers";
import { expect } from "chai";
import { ZeroAddress } from "ethers";
import { ethers, upgrades } from "hardhat";

describe("StakeV1", function () {
  async function deploy() {
    const [owner, alice, bob, charlie, ..._] = await ethers.getSigners();

    const RewardToken = await ethers.getContractFactory("RewardToken");
    const rc = await RewardToken.deploy();

    const StakeContract = await ethers.getContractFactory("StakeContract");
    const stakeContract = await upgrades.deployProxy(StakeContract, {
      initializer: "initialize",
    });
    const sc = await ethers.getContractAt("StakeContract", await stakeContract.getAddress());

    await rc.grantMinterRole(await sc.getAddress());
    await sc.setRewardToken(await rc.getAddress());

    return { sc, rc, owner, alice, bob, charlie };
  }

  it("Should return all packages", async function () {
    const { sc, rc, owner, alice, bob, charlie } = await loadFixture(deploy);

    const packages = await sc.getAllPackages();

    expect(packages.length).to.equal(3);
    expect(packages[0][0]).to.equal(30n);
    expect(packages[0][1]).to.equal(10n);
    expect(packages[1][0]).to.equal(60n);
    expect(packages[1][1]).to.equal(20n);
    expect(packages[2][0]).to.equal(90n);
    expect(packages[2][1]).to.equal(30n);
  });

  it("Should alice stake 100 in 30 day successful", async function () {
    const { sc, rc, owner, alice, bob, charlie } = await loadFixture(deploy);

    const aliceStakeTx = sc.connect(alice).stake(0, { value: 100 });

    await expect(aliceStakeTx).to.changeEtherBalance(alice, -100);
    expect((await sc.connect(alice).getStake(0)).amount).to.equal(100);
  });

  it("Should alice stake twice successful", async function () {
    const { sc, rc, owner, alice, bob, charlie } = await loadFixture(deploy);

    const aliceStakeTx = sc.connect(alice).stake(0, { value: 100 });
    const aliceStakeTx2 = sc.connect(alice).stake(0, { value: 500 });

    await expect(aliceStakeTx).to.changeEtherBalance(alice, -100);
    await expect(aliceStakeTx2).to.changeEtherBalance(alice, -500);

    expect((await sc.connect(alice).getAllStakes()).length).to.equal(2);
  });

  it("Should alice stake fail cause duration not valid", async function () {
    const { sc, rc, owner, alice, bob, charlie } = await loadFixture(deploy);

    const aliceStakeTx = sc.connect(alice).stake(3, { value: 100 });

    expect(aliceStakeTx).to.be.revertedWith("Invalid duration");
  });

  it("Should alice stake fail cause amount not valid", async function () {
    const { sc, rc, owner, alice, bob, charlie } = await loadFixture(deploy);

    const aliceStakeTx = sc.connect(alice).stake(0, { value: 0 });

    expect(aliceStakeTx).to.be.revertedWith("Invalid amount");
  });

  it("Should alice un stake fail cause stake not completed yet", async function () {
    const { sc, rc, owner, alice, bob, charlie } = await loadFixture(deploy);

    await sc.connect(alice).stake(0, { value: 100 });
    const aliceUnstakeTx = sc.connect(alice).unstake(0);

    await expect(aliceUnstakeTx).to.be.revertedWith("Stake not completed yet");
  });

  it("Should alice un stake fail cause balance not enough", async function () {
    const { sc, rc, owner, alice, bob, charlie } = await loadFixture(deploy);

    await sc.connect(alice).stake(0, { value: 100 });

    await time.increase(400 * 24 * 60 * 60);

    const aliceUnstakeTx = sc.connect(alice).unstake(0);

    await expect(aliceUnstakeTx).to.be.revertedWith("Insufficient balance, contact admin to unstake");
  });

  it("Should alice un stake fail cause stake not valid", async function () {
    const { sc, rc, owner, alice, bob, charlie } = await loadFixture(deploy);

    await expect(sc.connect(alice).unstake(0)).to.revertedWith("Invalid stake index");
  });

  it("Should alice un stake fail cause already un stake", async function () {
    const { sc, rc, owner, alice, bob, charlie } = await loadFixture(deploy);

    await owner.sendTransaction({ to: await sc.getAddress(), value: 100 });
    await sc.connect(alice).stake(0, { value: 100 });
    await time.increase(400 * 24 * 60 * 60);

    await sc.connect(alice).unstake(0);
    const aliceUnstakeTx = sc.connect(alice).unstake(0);

    await expect(aliceUnstakeTx).to.revertedWith("Already unstaked");
  });

  it("Should alice un stake successful", async function () {
    const { sc, rc, owner, alice, bob, charlie } = await loadFixture(deploy);

    await owner.sendTransaction({ to: await sc.getAddress(), value: 100 });
    await sc.connect(alice).stake(0, { value: 100 });
    await time.increase(400 * 24 * 60 * 60);

    const aliceUnstakeTx = sc.connect(alice).unstake(0);

    await expect(aliceUnstakeTx).to.changeEtherBalance(alice, 110);
  });

  it("Should alice claim all reward failed cause invalid stake index", async function () {
    const { sc, rc, owner, alice, bob, charlie } = await loadFixture(deploy);

    const aliceClaimTx = sc.connect(alice).claimReward(0);

    await expect(aliceClaimTx).to.revertedWith("Invalid stake index");
  });

  it("Should alice claim all reward successful", async function () {
    const { sc, rc, owner, alice, bob, charlie } = await loadFixture(deploy);

    await sc.connect(alice).stake(0, { value: 100 });

    await time.increase(400 * 24 * 60 * 60);

    const aliceClaimTx = sc.connect(alice).claimReward(0);

    const aliceRewardAmount = (1 * 100 * 30 * 60 * 60 * 24) / 100_000;

    await expect(aliceClaimTx).to.changeTokenBalance(rc, alice, aliceRewardAmount);
  });

  it("Should owner set token reward successful", async function () {
    const { sc, rc, owner, alice, bob, charlie } = await loadFixture(deploy);

    await sc.setRewardToken(ZeroAddress);

    expect(await sc.rewardToken()).to.equal(ZeroAddress);
  });

  it("Should alice set token reward failed cause not contract owner", async function () {
    const { sc, rc, owner, alice, bob, charlie } = await loadFixture(deploy);

    await expect(sc.connect(alice).setRewardToken(ZeroAddress)).to.revertedWithCustomError(
      sc,
      "OwnableUnauthorizedAccount"
    );
  });
});
