import "@openzeppelin/hardhat-upgrades";

import { ethers, upgrades } from "hardhat";

async function main() {
  const [owner, ...addresses] = await ethers.getSigners();

  // // ----- ex 1 ------
  // const MyToken = await ethers.getContractFactory("MyToken");
  // await MyToken.deploy(owner);

  // // ----- ex 2 ------
  // const NftToken = await ethers.getContractFactory("NftToken");
  // await NftToken.deploy(owner);

  // // ----- ex 3 ------
  // const Nft = await ethers.getContractFactory("NFT");
  // await Nft.deploy(owner);

  // const Auction = await ethers.getContractFactory("Auction");
  // await Auction.deploy(owner);

  // ----- ex 4 ------
  const RewardToken = await ethers.getContractFactory("RewardToken");
  await RewardToken.deploy();

  const Staking = await ethers.getContractFactory("StakeContract");
  const stakeContract = await upgrades.deployProxy(Staking, {
    initializer: "initialize",
    kind: "uups",
    initialOwner: owner.address,
  });
  await stakeContract.deployed();
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
