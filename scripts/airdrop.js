const hre = require("hardhat");
const ethers = hre.ethers;

const CONTRACT = "giveaway_address";

const recipients = [];

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
    ["function transfer(address to, uint256 amount) public returns (bool)"],
    signer
  );

  console.log(`sending tokens`);
  for (let i = 0; i < recipients.length; i++) {
    const tx = await contract.transfer(recipients[i], 3);
    const receipt = await tx.wait();
    console.log(`${recipients[i]}`);
  }
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
start()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
