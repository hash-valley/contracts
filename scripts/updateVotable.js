const hre = require("hardhat");
const config = require("../config");
const fs = require("fs");

async function deploy() {
  const network = await hre.ethers.provider.getNetwork();

  console.log("beginning deployments to network id", network.chainId);

  const storageAddress = "0xC90e001D24Fc128f94A42a34b655A9DDA50699D7"

  const storage = await hre.ethers.getContractAt(
    "AddressStorage",
    storageAddress
  );

  const VineUri = await hre.ethers.getContractFactory("VotableUri");
  const vineUri = await VineUri.deploy(
    storageAddress,
    config.vine_animation_uri,
    config.vine_img_uri
  );
  await vineUri.deployed();
  console.log("VineURi deployed to:", vineUri.address);
  await storage.newVineUri(vineUri.address);
  console.log("storage updated");

  const WineUri = await hre.ethers.getContractFactory("VotableUri");
  const wineUri = await WineUri.deploy(
    storageAddress,
    config.bottle_animation_uri,
    config.bottle_img_uri
  );
  await wineUri.deployed();
  console.log("WineURi deployed to:", wineUri.address);
  await storage.newWineUri(vineUri.address);
  console.log("storage updated");

  const TY = await hre.ethers.getContractFactory("Badge");
  const ty = await TY.deploy(config.ty_uri);
  await ty.deployed();
  console.log("TY deployed to:", ty.address);
  await ty.airdrop(config.airdrop_recipients);
  console.log("ty airdrop complete");

  const data = JSON.stringify(
    {
      wine_uri_address: wineUri.address,
      vine_uri_address: vineUri.address,
      badge_address: ty.address,
    },
    null,
    2
  );

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
