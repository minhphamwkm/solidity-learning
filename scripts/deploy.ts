import { ethers } from "hardhat";

async function main() {
  const [owner, ...addresses]  = await ethers.getSigners();

  const myToken = await ethers.deployContract("MyToken", [owner.address], owner);

  const alice = addresses[0];
  const bob = addresses[1];

  await myToken.waitForDeployment();
  await myToken.name(); // MyToken
  await myToken.symbol(); // MTK
  await myToken.balanceOf(owner.address); // 1,000,000

  // Viết script js/ts để mint token cho 1 address bất kì với số lượng bất kì
  let parsedMintAmount = ethers.parseUnits('1000000', 18);
  await myToken.mint(alice, parsedMintAmount);
  await myToken.balanceOf(alice); // 1,000,000

  // Viết script js/ts để transfer token từ ví A sang ví B 100 Token
  let parsedTransferAmount = ethers.parseUnits('100', 18);
  await myToken.connect(alice).transfer(bob, parsedTransferAmount);
  await myToken.balanceOf(alice); //999,900
  await myToken.balanceOf(bob); // 100

  // Viết script approve từ ví A cho ví B 50 Token
  let parsedApproveAmount = ethers.parseUnits('50', 18);
  await myToken.connect(alice).approve(bob, parsedApproveAmount);
  // Viết script check allowance giữa ví A và ví B sau khi approve
  await myToken.allowance(alice, bob); // 50

  // Viết scripts transferFrom từ ví A sang vì B 50 token
  let parsedTransferFromAmount = ethers.parseUnits('50', 18);
  await myToken.connect(alice).approve(owner, parsedTransferFromAmount);
  await myToken.transferFrom(alice, bob, parsedTransferFromAmount);
  await myToken.balanceOf(alice); // 999,850
  await myToken.balanceOf(bob); // 150

  // Viết script transferFrom từ ví A sang ví B 50 token, nhưng sender là ví B (*)
  await myToken.connect(alice).approve(bob, parsedTransferFromAmount);
  await myToken.connect(bob).transferFrom(alice, bob, parsedTransferFromAmount);
  await myToken.balanceOf(alice); // 999,800
  await myToken.balanceOf(bob); // 200

  // Ví A tự burn 10 token từ ví của chính mình
  let parsedBurnAmount = ethers.parseUnits('10', 18);
  await myToken.transferOwnership(alice);
  await myToken.connect(alice).burn(alice, parsedBurnAmount);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
