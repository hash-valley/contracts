const hre = require("hardhat");
const ethers = hre.ethers;

const ADDRESS = "0x01cD50Db1A148465dc2bCa30203429aEb4ea62e1";

async function start() {
  const signer = await ethers.getSigner();
  const vineyard = new ethers.Contract(
    ADDRESS,
    ["function newVineyards(uint16[] calldata) public payable"],
    signer
  );

  const approvalTx1 = await vineyard.newVineyards([1, 131, 0, 0]);
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
