const hre = require("hardhat");
const ethers = hre.ethers;

const CONTRACT = "vine_address";

async function start() {
  const { chainId } = await ethers.provider.getNetwork();
  let addresses;
  try {
    addresses = require(`../deployments/deployment_${chainId}.json`);
  } catch {
    throw("couldnt load addresses");
  }

  const signer = await ethers.getSigner();
  const vineyard = new ethers.Contract(
    addresses[CONTRACT],
    ["function setBaseURI(string memory _baseUri) public"],
    signer
  );

  console.log(`change base uri`);
  const approvalTx = await vineyard.setBaseURI("https://kovan.hashvalley.xyz");
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
