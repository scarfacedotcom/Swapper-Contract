import { ethers } from "hardhat";

const ConstructionArgs = {
  // DAI TOKEN
    token1: "0x6B175474E89094C44Da98b954EedeAC495271d0F",
    // ETH TOKEN
    token2: "0xFfb99f4A02712C909d8F7cC44e67C87Ea1E71E83",
    // DAI/USD PRICEFEED
    priceFeed1: "0x0d79df66BE487753B02D015Fb622DED7f0E9798d",
    priceFeed2: "0xD4a33860578De61DBAbDc8BFdb98FD742fA7028e"
}

async function main() {


  //const lockedAmount = ethers.utils.parseEther("1");

  const TokenSwap = await ethers.getContractFactory("TokenSwap");
  const tokenSwap = await TokenSwap.deploy(ConstructionArgs.token1, ConstructionArgs.token2, ConstructionArgs.priceFeed1, ConstructionArgs.priceFeed2);

  await tokenSwap.deployed();

  console.log(`Token swap contract has been deployed to ${tokenSwap.address}`);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});