const hre = require("hardhat");
const ethers = hre.ethers;

const CONTRACT = "address_storage_address";

// deployer address, return to contract when done
const NEW_RM = "0x00000023F6B4ED7185E7B8928072a8bfEC660ff3";

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
