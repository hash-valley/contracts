const hre = require("hardhat");
const ethers = hre.ethers;

const ADDRESS = "0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512";
const NEW_URI = "ghjdfkshglkas";

async function start() {
  const signer = await ethers.getSigner();
  const contract = new ethers.Contract(
    ADDRESS,
    [
      "function setBaseURI(string memory baseURI) public onlyOwner",
      "function updateImg(string memory imgUri, address artist) public",
    ],
    signer
  );

  console.log(`set uri`);
  const approvalTx = await contract.updateImg(
    NEW_URI,
    "0x495f947276749Ce646f68AC8c248420045cb7b5e"
  );
  const approvalReceipt = await approvalTx.wait();
  console.log(`tx mined, gas used ${approvalReceipt.gasUsed.toString()}`);
  console.log("uri set");
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
start()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
