const hre = require("hardhat");

async function deploy() {
  const network = await hre.ethers.provider.getNetwork();

  let addresses;
  try {
    addresses = require(`../deployments/deployment_${network.chainId}.json`);
  } catch {
    throw "couldnt load addresses";
  }

  let market_address;
  if (network.chainId === 420) {
    //alchemy_op_goerli
    market_address = "0x6749aB437cd8803ecCC3aD707F969298Cda65921";
  } else if (network.chainId === 10) {
    // optimism
    market_address = "0xe5c7b4865d7f2b08faadf3f6d392e6d6fa7b903c";
  } else if (network.chainId === 31337) {
    // localhost
    const Quixotic = await hre.ethers.getContractFactory("DummyQuixotic");
    quixotic = await Quixotic.deploy();
    await quixotic.deployed();
    market_address = quixotic.address;
  } else {
    throw "unrecognized network";
  }

  console.log(addresses.address_storage_address, market_address);

  const Royalty = await hre.ethers.getContractFactory("RoyaltyManagerV2");
  const royalty = await Royalty.deploy(addresses.address_storage_address, market_address);
  await royalty.deployed();
  console.log("Royalty Manager deployed to:", royalty.address);

  const signer = await ethers.getSigner();
  const ast = new ethers.Contract(
    addresses.address_storage_address,
    ["function newRoyaltyManager(address _royaltyManager) external"],
    signer
  );

  await ast.newRoyaltyManager(royalty.address);

  await royalty.init();
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
deploy()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
