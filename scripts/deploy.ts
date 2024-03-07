import { ethers } from "hardhat";

async function main() {
  const [owner, ...addresses]  = await ethers.getSigners();

  const myToken = await ethers.deployContract("MyToken");


  await myToken.waitForDeployment();
  await myToken.name(); // MyToken
  await myToken.symbol(); // MTK
  await myToken.balanceOf(owner.address); // 1,000,000

  await myToken.mint(addresses[18].address, 1000000);
  await myToken.balanceOf(addresses[18].address); // 1,000,000

  await myToken.transfer(addresses[18].address, 100);
  await myToken.balanceOf(addresses[18].address); // 100
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
