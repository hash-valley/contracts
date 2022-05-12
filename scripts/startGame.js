const hre = require("hardhat");
const ethers = hre.ethers;

const ADDRESS = "0x725Ebff6DD72F7eA9d82bbccEF552Df0fC682122";

async function start() {
  const signer = await ethers.getSigner();
  const vineyard = new ethers.Contract(
    ADDRESS,
    ["function start() public"],
    signer
  );

  console.log(`start gmae`);
  const approvalTx = await vineyard.start();
  const approvalReceipt = await approvalTx.wait();
  console.log(`tx mined, gas used ${approvalReceipt.gasUsed.toString()}`);
  console.log("game started");
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
start()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
