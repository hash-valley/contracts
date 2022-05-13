const hre = require("hardhat");
const ethers = hre.ethers;

const ADDRESS = "0x5011dD64319B8766F26479E86217E5AC48200F19";

async function start() {
  const signer = await ethers.getSigner();
  const vineyard = new ethers.Contract(
    ADDRESS,
    ["function newVineyards(uint16[] calldata) public payable"],
    signer
  );

  const approvalTx1 = await vineyard.newVineyards([12, 130, 0, 3]);
  await approvalTx1.wait();
  console.log("vine minted")
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
start()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
