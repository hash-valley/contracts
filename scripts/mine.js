const hre = require("hardhat");
const ethers = hre.ethers;

const day = 24 * 60 * 60;
async function start() {
  await ethers.provider.send("evm_increaseTime", [1 * day]);
  await ethers.provider.send("evm_mine", []);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
start()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
