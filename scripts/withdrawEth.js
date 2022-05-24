const hre = require("hardhat");
const ethers = hre.ethers;

async function start() {
  const { chainId } = await ethers.provider.getNetwork();
  let addresses;
  try {
    addresses = require(`../deployments/deployment_${chainId}.json`);
  } catch {
    console.error("couldnt load addresses");
  }

  const signer = await ethers.getSigner();
  const vineyard = new ethers.Contract(
    addresses.vine_address,
    ["function withdrawAll() public payable"],
    signer
  );

  console.log(`withdrawing eth`);
  const approvalTx = await vineyard.withdrawAll();
  const approvalReceipt = await approvalTx.wait();
  console.log(`tx mined, gas used ${approvalReceipt.gasUsed.toString()}`);
  console.log(approvalTx.hash)
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
start()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
