const hre = require("hardhat");
const ethers = hre.ethers;

async function start() {
  const { chainId } = await ethers.provider.getNetwork();
  let addresses;
  try {
    addresses = require(`../deployments/deployment_${chainId}.json`);
  } catch {
    throw "couldnt load addresses";
  }

  const signer = await ethers.getSigner();
  const vineyard = new ethers.Contract(
    addresses.vine_address,
    ["function newVineyards(uint16[] calldata) public payable"],
    signer
  );

  const approvalTx1 = await vineyard.newVineyards([1, 131, 0, 0]);
  await approvalTx1.wait();
  console.log("vine minted");
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
start()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
