// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// You can also run a script with `npx hardhat run <script>`. If you do that, Hardhat
// will compile your contracts, add the Hardhat Runtime Environment's members to the
// global scope, and execute the script.
const hre = require("hardhat");

async function main() {
  let betPlatform;
  let betFundPool;
  let myErc20;
  let BetPlatform = (await hre.ethers.getContractFactory("BetPlatform"));
  betPlatform = await BetPlatform.deploy();
  await betPlatform.deployed()
  const betFundPoolAddress = await betPlatform.betFundPool();

  let MyErc20 = (await hre.ethers.getContractFactory("MyErc20"));
  myErc20 = await MyErc20.deploy();
  await myErc20.deployed()

  console.log("id:",await betPlatform.getBetIds())

  console.log("betPlatform deploy address:",betPlatform.address);

  console.log("betFundPool deploy address:",betFundPoolAddress)

  console.log("myErc20 deploy address:",myErc20.address)
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
