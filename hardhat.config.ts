import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import accountUtils from "./utils/accountUtils";
import "@nomicfoundation/hardhat-verify";
import * as dotenv from "dotenv";
const config: HardhatUserConfig = {
  etherscan: {
    apiKey: {
      sepolia: process.env.APIKEY || "",
      avalancheFujiTestnet: "snowtrace",
      polygonMumbai: process.env.APIKEY_POLYGON || "",
      bscTestnet: process.env.APIKEY_BSC || "",
      optimisticGoerli: process.env.APIKEY_OP || "",
    },
  },

  solidity: {
    compilers: [
      {
        version: "0.8.19",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          },
        },
      },
      {
        version: "0.8.20",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          },
        },
      },
    ],
  },
  networks: {
    bkc_test: {
      url: "https://rpc-testnet.bitkubchain.io",
      accounts: accountUtils.getAccounts(),
    },
    bsc_test: {
      url: "https://bsc-testnet.publicnode.com",
      accounts: accountUtils.getAccounts(),
    },
    sepolia: {
      url: "https://ethereum-sepolia.publicnode.com",
      accounts: accountUtils.getAccounts(),
    },
    mumbai: {
      url: "https://polygon-mumbai-bor.publicnode.com",
      accounts: accountUtils.getAccounts(),
    },
    fuji: {
      url: "https://avalanche-fuji-c-chain.publicnode.com",
      accounts: accountUtils.getAccounts(),
    },
    avalanceFuji: {
      url: "https://avalanche-fuji-c-chain.publicnode.com",
      accounts: accountUtils.getAccounts(),
    },
    optimismGoerli: {
      url: "https://optimism-goerli.publicnode.com",
      accounts: accountUtils.getAccounts(),
    },

    localhost: {
      url: "http://127.0.0.1:8545/",
      accounts: accountUtils.getAccounts(),
    },
  },
};

export default config;
