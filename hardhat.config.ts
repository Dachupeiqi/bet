
import "@nomiclabs/hardhat-ethers";
import "@nomiclabs/hardhat-waffle";
import "@nomiclabs/hardhat-etherscan";
import "@typechain/hardhat";

// You need to export an object to set up your config
// Go to https://hardhat.org/config/ to learn more

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
  },
  etherscan: {
   
  },
  mocha: {
    timeout: 100000000
  }
};

export default config;
