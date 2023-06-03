const hre = require("hardhat");
const config = require("../config");
const fs = require("fs");

async function deploy() {
  const network = await hre.ethers.provider.getNetwork();

  console.log("beginning deployments to network id", network.chainId);

  const SaleParams = await hre.ethers.getContractFactory("SaleParams");
  const params = await SaleParams.deploy();
  await params.deployed();
  console.log("Params deployed to:", params.address);

  const vineyardAddress = "0xE55A395d98dAd2D4B0F1C1186dE828EeD9a4F5AB";
  const vineyard = await hre.ethers.getContractAt("Vineyard", vineyardAddress);

  await vineyard.setSaleParams(params.address);
  console.log("vineyard updated");

  if (!fs.existsSync("deployments")) {
    fs.mkdirSync("deployments");
  }

  fs.writeFileSync(`deployments/deployment_updated_${network.chainId}.json`, data, (err) => {
    if (err) {
      throw err;
    }
  });
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
deploy()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
