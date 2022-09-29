const hre = require("hardhat");
const config = require("../config");
const fs = require("fs");

async function deploy() {
  const network = await hre.ethers.provider.getNetwork();

  console.log("beginning deployments to network id", network.chainId);

  const Storage = await hre.ethers.getContractFactory("AddressStorage");
  const storage = await Storage.deploy();
  const storage_deploy_tx = await storage.deployed();
  console.log("Address Storage deployed to:", storage.address);

  let market_address;
  if (network.chainId === 420) {
    //goerli
    market_address = config.goerli_quixotic;
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
  console.log("GiveawayToken deployed to:", give.address);

  const Alchemy = await hre.ethers.getContractFactory("Alchemy");
  const alchemy = await Alchemy.deploy(storage.address);
  await alchemy.deployed();
  console.log("Alchemy deployed to:", alchemy.address);

  const Grape = await hre.ethers.getContractFactory("Grape");
  const grape = await Grape.deploy(storage.address);
  await grape.deployed();
  console.log("Grape deployed to:", grape.address);

  const SpellParams = await hre.ethers.getContractFactory("SpellParams");
  const spellParams = await SpellParams.deploy(storage.address);
  await spellParams.deployed();
  console.log("SpellParams deployed to:", spellParams.address);

  const Multi = await hre.ethers.getContractFactory("Multicall");
  const multi = await Multi.deploy();
  await multi.deployed();
  console.log("Multicall deployed to:", multi.address);

  const SaleParams = await hre.ethers.getContractFactory("SaleParams");
  const saleParams = await SaleParams.deploy();
  await saleParams.deployed();
  await vineyard.setSaleParams(saleParams.address);
  console.log("SaleParams deployed to:", saleParams.address);

  await storage.setAddresses(
    cellar.address,
    vinegar.address,
    vineyard.address,
    bottle.address,
    give.address,
    royalty.address,
    alchemy.address,
    grape.address,
    spellParams.address,
    wineUri.address,
    vineUri.address
  );
  console.log("addresses set");

  await vineyard.initR();
  await bottle.initR();
  console.log("royalties initialized");

  await give.airdrop(config.airdrop_recipients, config.airdrop_values);
  console.log("vineyard airdrop complete");

  const TY = await hre.ethers.getContractFactory("Badge");
  const ty = await TY.deploy(config.ty_uri);
  await ty.deployed();
  await ty.airdrop(config.airdrop_recipients);
  console.log("ty airdrop complete");

  if (network.chainId === 31337) {
    console.log("unlocking locales");
    await vineyard.unlockLocale();
    await vineyard.unlockLocale();
    await vineyard.unlockLocale();
  }

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
      wine_uri_address: wineUri.address,
      vine_uri_address: vineUri.address,
      multi_address: multi.address,
      sale_params_address: saleParams.address,
      alchemy_address: alchemy.address,
      grape_address: grape.address,
      spell_params_address: spellParams.address,
      badge_address: ty.address,
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
