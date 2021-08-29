const hre = require("hardhat");
const ethers = hre.ethers;

const ADDRESS = "0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512";

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
