const hre = require("hardhat");
const config = require("../config");
const fs = require("fs");

async function deploy() {
  const Storage = await hre.ethers.getContractFactory("AddressStorage");
  const storage = await Storage.deploy();
  await storage.deployed();
  console.log("Address Storage deployed to:", storage.address);

  const Royalty = await hre.ethers.getContractFactory("RoyaltyManager");
  const royalty = await Royalty.deploy(
    storage.address,
    "0x6749aB437cd8803ecCC3aD707F969298Cda65921"
  );
  await royalty.deployed();
  console.log("Royalty Manager deployed to:", royalty.address);

  const Vineyard = await hre.ethers.getContractFactory("Vineyard");
  const vineyard = await Vineyard.deploy(
    config.vine_base_uri,
    config.vine_img_uri,
    storage.address,
    config.mintReqs,
    config.climates
  );
  await vineyard.deployed();
  console.log("Vineyard deployed to:", vineyard.address);

  const Cellar = await hre.ethers.getContractFactory("Cellar");
  const cellar = await Cellar.deploy(storage.address);
  await cellar.deployed();
  console.log("Cellar deployed to:", cellar.address);

  const WineBottle = await hre.ethers.getContractFactory("WineBottle");
  const bottle = await WineBottle.deploy(
    config.bottle_base_uri,
    config.bottle_img_uri,
    storage.address,
    config.eraBounds
  );
  await bottle.deployed();
  console.log("Bottle deployed to:", bottle.address);

  const Vinegar = await hre.ethers.getContractFactory("Vinegar");
  const vinegar = await Vinegar.deploy(storage.address);
  await vinegar.deployed();
  console.log("Vinegar deployed to:", vinegar.address);

  const Give = await hre.ethers.getContractFactory("GiveawayToken");
  const give = await Give.deploy();
  await give.deployed();
  console.log("GiveToken deployed to:", give.address);

  await storage.setAddresses(
    cellar.address,
    vinegar.address,
    vineyard.address,
    bottle.address,
    give.address,
    royalty.address
  );

  await vineyard.initR();
  await bottle.initR();

  const data = JSON.stringify({
    vine_address: vineyard.address,
    cellar_address: cellar.address,
    bottle_address: bottle.address,
    vinegar_address: vinegar.address,
    giveaway_address: give.address,
    address_storage_address: storage.address,
    royalth_address: royalty.address
  }, null, 2);

  fs.writeFileSync("deployment.json", data, (err) => {
    if (err) {
      throw err;
    }
    console.log("JSON data is saved.");
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
