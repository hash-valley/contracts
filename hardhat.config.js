require("@nomiclabs/hardhat-waffle");
require("@nomiclabs/hardhat-etherscan");
require("hardhat-abi-exporter");
require("hardhat-gas-reporter");
const config = require("./config.json");

// This is a sample Hardhat task. To learn how to create your own go to
// https://hardhat.org/guides/create-task.html
task("accounts", "Prints the list of accounts", async () => {
  const accounts = await ethers.getSigners();

  for (const account of accounts) {
    console.log(account.address);
  }
});

// You need to export an object to set up your config
// Go to https://hardhat.org/config/ to learn more

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
  solidity: {
    version: "0.8.17",
    settings: {
      optimizer: {
        enabled: true,
      },
    },
  },
  defaultNetwork: "hardhat",
  networks: {
    hardhat: {},
    localhost: {
      url: "http://127.0.0.1:8545/",
    },
    optimisticGoerli: {
      url: `https://opt-goerli.g.alchemy.com/v2/${config.alchemy_op_goerli}`,
      accounts: [`0x${config.test_key}`],
    },
    optimisticEthereum: {
      url: `https://opt-mainnet.g.alchemy.com/v2/${config.alchemy_op}`,
      accounts: [`0x${config.deployer_key}`],
    },
  },
  abiExporter: {
    path: "./abis",
    clear: true,
    flat: true,
    spacing: 2,
  },
  gasReporter: {
    currency: "USD",
    gasPrice: 15,
    coinmarketcap: config.coinmarketcap,
    enabled: false,
  },
  etherscan: {
    apiKey: config.etherscan,
  },
  mocha: {
    timeout: 80000,
  },
};
