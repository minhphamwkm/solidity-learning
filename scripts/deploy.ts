import { ethers } from "hardhat";

async function main() {
  const [owner, ...addresses] = await ethers.getSigners();
  const MyToken = await ethers.getContractFactory("MyToken");
  const NftToken = await ethers.getContractFactory("NftToken");

  await MyToken.deploy(owner);
  await NftToken.deploy();
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
