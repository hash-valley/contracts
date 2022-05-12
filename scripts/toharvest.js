const hre = require("hardhat");
const ethers = hre.ethers;

const ADDRESS = "0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512";

async function start() {
  const signer = await ethers.getSigner();
  const vineyard = new ethers.Contract(
    ADDRESS,
    ["function currSeason() public view returns (uint256)"],
    signer
  );

  let days;
  const currSeason = await vineyard.currSeason();
  if (currSeason == 0) {
    console.log("game not started");
    return;
  } else if (currSeason == 1) {
    days = 14;
  } else {
    days = 77;
  }

  const daylength = 86400;

  await ethers.provider.send("evm_increaseTime", [days * daylength]);
  await ethers.provider.send("evm_mine", []);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
start()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
