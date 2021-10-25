const hre = require("hardhat");
const config = require("../config.json")

async function deploy() {
  const Storage = await hre.ethers.getContractFactory("AddressStorage");
  const storage = await Storage.deploy();
  await storage.deployed();
  console.log("Address Storage deployed to:", storage.address);

  const Vineyard = await hre.ethers.getContractFactory("VineyardV1");
  const vineyard = await Vineyard.deploy(config.vine_base_uri, config.vine_img_uri, storage.address);
  await vineyard.deployed();
  console.log("Vineyard deployed to:", vineyard.address);

  const Cellar = await hre.ethers.getContractFactory("CellarV1");
  const cellar = await Cellar.deploy(storage.address);
  await cellar.deployed();
  console.log("Cellar deployed to:", cellar.address);

  const WineBottle = await hre.ethers.getContractFactory("WineBottleV1");
  const bottle = await WineBottle.deploy(config.bottle_base_uri, config.bottle_img_uri, storage.address);
  await bottle.deployed();
  console.log("Bottle deployed to:", bottle.address);

  const Vinegar = await hre.ethers.getContractFactory("Vinegar");
  const vinegar = await Vinegar.deploy(storage.address);
  await vinegar.deployed();
  console.log("Vinegar deployed to:", vinegar.address);

  await storage.setAddresses(
    cellar.address,
    vinegar.address,
    vineyard.address,
    bottle.address
  )
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
deploy()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
