const hre = require("hardhat");
const ethers = hre.ethers;

async function start() {
  const { chainId } = await ethers.provider.getNetwork();
  let addresses;
  try {
    addresses = require(`../deployments/deployment_${chainId}.json`);
  } catch {
    throw("couldnt load addresses");
  }

  const accounts = await ethers.getSigners();
  const signer = await ethers.getSigner();
  const vineyard = new ethers.Contract(
    addresses.vine_address,
    [
      "function currSeason() public view returns (uint256)",
      "function waterMultiple(uint256[] calldata _tokenIds) public",
      "function harvestMultiple(uint256[] calldata _tokenIds) public",
      "function plantMultiple(uint256[] calldata _tokenIds) public",
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

  await vineyard.connect(accounts[15]).plantMultiple([0]);
  for (let i = 0; i <= days; i++) {
    await ethers.provider.send("evm_increaseTime", [time]);
    await vineyard.connect(accounts[2]).waterMultiple([0]);
  }
  await vineyard.connect(accounts[15]).harvestMultiple([0]);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
start()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
