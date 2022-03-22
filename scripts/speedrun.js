const hre = require("hardhat");
const ethers = hre.ethers;

const ADDRESS = "0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512";

async function start() {
  const accounts = await ethers.getSigners();
  const signer = await ethers.getSigner();
  const vineyard = new ethers.Contract(
    ADDRESS,
    [
      "function currSeason() public view returns (uint256)",
      "function waterMultiple(uint256[] calldata _tokenIds) public",
      "function minWaterTime(uint256 _tokenId) public view returns (uint256)",
    ],
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

  let time = Number(await vineyard.minWaterTime(0));
  for (let i = 0; i <= days; i++) {
    await ethers.provider.send("evm_increaseTime", [time]);
    await vineyard.connect(accounts[2]).waterMultiple([0, 1]);
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
