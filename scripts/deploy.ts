import { ethers } from "hardhat";

async function main() {
  const [owner, ...addresses]  = await ethers.getSigners();

  const myToken = await ethers.deployContract("MyToken");


  await myToken.waitForDeployment();
  await myToken.name(); // MyToken
  await myToken.symbol(); // MTK
  await myToken.balanceOf(owner.address); // 1,000,000

  // Viết script js/ts để mint token cho 1 address bất kì với số lượng bất kì
  await myToken.mint(addresses[18].address, 1000000);
  await myToken.balanceOf(addresses[18].address); // 1,000,000

  // Viết script js/ts để transfer token từ ví A sang ví B 100 Token
  await myToken.transferFrom(addresses[18].address, addresses[17].address, 50);

  // Viết scripts transferFrom từ ví A (addresses[18]) sang vì B (addresses[17]) 50 token
  await myToken.transferFrom(addresses[18].address, addresses[17].address, 50);
  await myToken.balanceOf(addresses[17].address); // 50

  // Viết script check allowance giữa ví A và ví B sau khi approve
  await myToken.allowance(addresses[18].address, addresses[17].address); // 50

  // Viết script transferFrom từ ví A sang ví B 50 token, nhưng sender là ví B  (*)

  // Ví A tự burn 10 token từ ví của chính mình
  await myToken.burn(addresses[17].address, 10);
  await myToken.balanceOf(addresses[17].address); // 40

  //
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
