
import "@nomiclabs/hardhat-ethers";
import "@nomiclabs/hardhat-waffle";
import "@nomiclabs/hardhat-etherscan";
import "@typechain/hardhat";

import dotenv from "dotenv";
dotenv.config()

// You need to export an object to set up your config
// Go to https://hardhat.org/config/ to learn more
const PRIVATE_KEY =process.env.privateKey;
const ethapiKey = process.env.ethapikey;

const config = {
  solidity: {
    compilers: [
      {
        version: "0.8.19",
        settings: {
          viaIR: false,
          optimizer: {
            enabled: true,
            runs: 100,
          },
          metadata: {
            bytecodeHash: "none",
          },
        },
      },
    ],
  },
  networks: {
    hardhat: {
      blockGasLimit: 30_000_000,
      throwOnCallFailures: false,
      allowUnlimitedContractSize: true,
    },
    goerli: {
      url: `https://goerli.infura.io/v3/076d9837dcba4214a96e75779e9eed85`,
      accounts: [PRIVATE_KEY] 
    },
  },
  etherscan: {
    apiKey: ethapiKey,
  },
  mocha: {
    timeout: 100000000
  }
};

export default config;
