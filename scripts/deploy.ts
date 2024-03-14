import { ethers } from "hardhat";

async function main() {
  const [owner, ...addresses] = await ethers.getSigners();

  // ----- ex 1 ------
  const MyToken = await ethers.getContractFactory("MyToken");
  await MyToken.deploy(owner);

  // ----- ex 2 ------

  const NftToken = await ethers.getContractFactory("NftToken");
  await NftToken.deploy();

  // ----- ex 3 ------

  const Nft = await ethers.getContractFactory("Auction");
  await Nft.deploy(owner);

  const Auction = await ethers.getContractFactory("Auction");
  await Auction.deploy(owner);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
