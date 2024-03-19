import {
  loadFixture,
  mine,
  time,
} from "@nomicfoundation/hardhat-toolbox/network-helpers";
import { expect } from "chai";
import { ethers, upgrades } from "hardhat";

describe("StakeV1", function () {
  async function deploy() {
    const [owner, alice, bob, charlie, ..._] = await ethers.getSigners();

    const RewardToken = await ethers.getContractFactory("RewardToken");
    const rc = await RewardToken.deploy();

    const StakeContract = await ethers.getContractFactory("StakeContract");
    const sc = await StakeContract.deploy();

    return { sc, rc, owner, alice, bob, charlie };
  }

  it("Should alice stake 100 in 30 day successful", async function () {
    const { sc, rc, owner, alice, bob, charlie } = await loadFixture(deploy);

    const aliceStakeTx = sc.connect(alice).stake(30, { value: 100 });

    await expect(aliceStakeTx).to.changeEtherBalance(alice, -100);
    expect((await sc.connect(alice).getStake(0)).amount).to.equal(100);
  });

  it("Should alice stake twice successful", async function () {
    const { sc, rc, owner, alice, bob, charlie } = await loadFixture(deploy);

    const aliceStakeTx = sc.connect(alice).stake(30, { value: 100 });
    const aliceStakeTx2 = sc.connect(alice).stake(30, { value: 500 });

    await expect(aliceStakeTx).to.changeEtherBalance(alice, -100);
    await expect(aliceStakeTx2).to.changeEtherBalance(alice, -500);

    expect((await sc.connect(alice).getAllStakes()).length).to.equal(2);
  });

  it("Should alice stake fail cause duration not valid", async function () {
    const { sc, rc, owner, alice, bob, charlie } = await loadFixture(deploy);

    const aliceStakeTx = sc.connect(alice).stake(20, { value: 100 });

    expect(aliceStakeTx).to.be.revertedWith("Invalid duration");
  });

  it("Should alice stake fail cause amount not valid", async function () {
    const { sc, rc, owner, alice, bob, charlie } = await loadFixture(deploy);

    const aliceStakeTx = sc.connect(alice).stake(30, { value: 0 });

    expect(aliceStakeTx).to.be.revertedWith("Invalid amount");
  });

  it("Should alice un stake fail cause stake not completed yet", async function () {
    const { sc, rc, owner, alice, bob, charlie } = await loadFixture(deploy);

    await sc.connect(alice).stake(30, { value: 100 });
    const aliceUnstakeTx = sc.connect(alice).unstake(0);

    await expect(aliceUnstakeTx).to.be.revertedWith("Stake not completed yet");
  });

  it("Should alice un stake fail cause balance not enough", async function () {
    const { sc, rc, owner, alice, bob, charlie } = await loadFixture(deploy);

    await sc.connect(alice).stake(30, { value: 100 });

    await time.increase(400 * 24 * 60 * 60);

    const aliceUnstakeTx = sc.connect(alice).unstake(0);

    await expect(aliceUnstakeTx).to.be.revertedWith(
      "Insufficient balance, contact admin to unstake"
    );
  });

  it.only("Should alice un stake successful", async function () {
    const { sc, rc, owner, alice, bob, charlie } = await loadFixture(deploy);

    await sc.connect(owner).deposit({ value: 100 });
    await sc.connect(alice).stake(30, { value: 100 });

    await time.increase(400 * 24 * 60 * 60);

    const aliceUnstakeTx = sc.connect(alice).unstake(0);

    await expect(aliceUnstakeTx).to.changeEtherBalance(alice, 110);
  });
});
