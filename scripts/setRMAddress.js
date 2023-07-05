const hre = require("hardhat");
const ethers = hre.ethers;

const CONTRACT = "address_storage_address";
const NEW_RM = "0x8b42d2A6FDd74eE31c28240dA144d5264106e83C";

async function start() {
  const { chainId } = await ethers.provider.getNetwork();
  let addresses;
  try {
    addresses = require(`../deployments/deployment_${chainId}.json`);
  } catch {
    throw "couldnt load addresses";
  }

  const signer = await ethers.getSigner();
  const contract = new ethers.Contract(
    addresses[CONTRACT],
    ["function newRoyaltyManager(address _royaltyManager) external"],
    signer
  );

  console.log(`Change royalty manager`);
  const approvalTx = await contract.newRoyaltyManager(NEW_RM);
  const approvalReceipt = await approvalTx.wait();
  console.log(`tx mined, gas used ${approvalReceipt.gasUsed.toString()}`);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
start()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
