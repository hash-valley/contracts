const hre = require("hardhat");
const ethers = hre.ethers;
const fs = require("fs");
const completedVinegar = require("../completed_vinegar_address.json");
const completedGrape = require("../completed_grape_address.json");

let recipients = [];

async function start() {
  const { chainId } = await ethers.provider.getNetwork();
  let addresses;
  try {
    addresses = require(`../deployments/deployment_${chainId}.json`);
  } catch {
    throw "couldnt load addresses";
  }

  const signer = await ethers.getSigner();

  const getVineyardOwners = async () => {
    const vineyard = new ethers.Contract(addresses["vine_address"], [
      "function ownerOf(uint256 tokenId) public view returns (address)",
    ]);

    let recipients_set = new Set();
    for (let i = 0; i < 235; i++) {
      const owner = await vineyard.ownerOf(i);
      if (owner !== "0x00000023F6B4ED7185E7B8928072a8bfEC660ff3") {
        recipients_set.add(owner);
      }
    }
    recipients = Array.from(recipients_set);
    console.log(recipients, recipients.length);
  };

  await getVineyardOwners();

  let complete = {
    vinegar_address: completedVinegar,
    grape_address: completedGrape,
  };

  const sendTokens = async (contract_name, recipients, amount) => {
    const contract = new ethers.Contract(
      addresses[contract_name],
      ["function transfer(address to, uint256 amount) public returns (bool)"],
      signer
    );

    let i = 0;
    try {
      for (i; i < recipients.length; i++) {
        if (complete[contract_name][recipients[i]]) {
          continue;
        }
        const tx = await contract.transfer(recipients[i], amount);
        complete[contract_name][recipients[i]] = true;

        // write completed to json
        fs.writeFileSync(
          `./completed_${contract_name}.json`,
          JSON.stringify(complete[contract_name], null, 2)
        );
      }
    } catch (e) {
      console.log(e, contract_name, i);
    }
    console.log("done", contract_name);
  };

  await sendTokens("vinegar_address", recipients, ethers.utils.parseEther("8300"));
  await sendTokens("grape_address", recipients, ethers.utils.parseEther("8300"));
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
start()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
