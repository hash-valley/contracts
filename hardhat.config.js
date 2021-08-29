require("@nomiclabs/hardhat-waffle");
require("@nomiclabs/hardhat-etherscan");
require('hardhat-abi-exporter');
require("hardhat-gas-reporter");
const config = require("./config.json")


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
    version: "0.8.4",
    settings: {
      optimizer: {
        enabled: true
      }
    }
  },
  defaultNetwork: "localhost",
  networks: {
    hardhat: {},
    localhost: {
      url: "http://127.0.0.1:8545/",
    },
    ropsten: {
      url: `https://eth-ropsten.alchemyapi.io/v2/${config.alchemy}`,
      accounts: [`0x${config.test_key}`],
    },
    rinkeby: {
      url: `https://eth-rinkeby.alchemyapi.io/v2/${config.alchemy_rink}`,
      accounts: [`0x${config.test_key}`],
    },
  },
  abiExporter: {
    path: './abis',
    clear: true,
    flat: true,
    spacing: 2
  },
  gasReporter: {
    currency: 'USD',
    gasPrice: 80,
    coinmarketcap: config.coinmarketcap
  },
  etherscan: {
    apiKey: config.etherscan
  }
};
