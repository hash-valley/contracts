const hre = require("hardhat");
const config = require("../config");
const fs = require("fs");

async function deploy() {
  const network = await hre.ethers.provider.getNetwork();

  const Storage = await hre.ethers.getContractFactory("AddressStorage");
  const storage = await Storage.deploy();
  const storage_deploy_tx = await storage.deployed();
  console.log("Address Storage deployed to:", storage.address);

  let market_address;
  if (network.chainId === 69) {
    //kovan
    market_address = config.kovan_quixotic;
  } else if (network.chainId === 10) {
    // optimism
    market_address = config.op_quixotic;
  } else if (network.chainId === 31337) {
    // localhost
    const Quixotic = await hre.ethers.getContractFactory("DummyQuixotic");
    quixotic = await Quixotic.deploy();
    await quixotic.deployed();
    market_address = quixotic.address;
    console.log(`Mock market deployed to ${quixotic.address}`);
  } else {
    throw "unrecognized network";
  }

  const Royalty = await hre.ethers.getContractFactory("RoyaltyManager");
  const royalty = await Royalty.deploy(storage.address, market_address);
  await royalty.deployed();
  console.log("Royalty Manager deployed to:", royalty.address);

  const Merkle = await hre.ethers.getContractFactory("MerkleDiscount");
  const merkle = await Merkle.deploy(
    config.discountMerkleRoot,
    storage.address
  );
  await merkle.deployed();
  console.log("MerkleDiscount deployed to:", merkle.address);

  const VineUri = await hre.ethers.getContractFactory("VotableUri");
  const vineUri = await VineUri.deploy(
    storage.address,
    config.vine_animation_uri,
    config.vine_img_uri
  );
  await vineUri.deployed();
  console.log("VineURi deployed to:", vineUri.address);

  const Vineyard = await hre.ethers.getContractFactory("Vineyard");
  const vineyard = await Vineyard.deploy(
    config.vine_base_uri,
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

  const WineUri = await hre.ethers.getContractFactory("VotableUri");
  const wineUri = await WineUri.deploy(
    storage.address,
    config.bottle_animation_uri,
    config.bottle_img_uri
  );
  await wineUri.deployed();
  console.log("WineURi deployed to:", wineUri.address);

  const WineBottle = await hre.ethers.getContractFactory("WineBottle");
  const bottle = await WineBottle.deploy(
    config.bottle_base_uri,
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
    royalty.address,
    merkle.address,
    wineUri.address,
    vineUri.address
  );

  await vineyard.initR();
  await bottle.initR();

  const data = JSON.stringify(
    {
      startBlock: storage_deploy_tx.deployTransaction.blockNumber,
      vine_address: vineyard.address,
      cellar_address: cellar.address,
      bottle_address: bottle.address,
      vinegar_address: vinegar.address,
      giveaway_address: give.address,
      address_storage_address: storage.address,
      royalty_address: royalty.address,
      merkle_address: merkle.address,
      wine_uri_address: wineUri.address,
      vine_uri_address: vineUri.address,
    },
    null,
    2
  );

  if (!fs.existsSync("deployments")) {
    fs.mkdirSync("deployments");
  }

  fs.writeFileSync(
    `deployments/deployment_${network.chainId}.json`,
    data,
    (err) => {
      if (err) {
        throw err;
      }
      console.log("JSON data is saved.");
    }
  );
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
deploy()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
