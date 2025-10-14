import type { HardhatUserConfig } from "hardhat/config";

import hardhatToolboxViemPlugin from "@nomicfoundation/hardhat-toolbox-viem";
import { configVariable } from "hardhat/config";

const config: HardhatUserConfig = {
  plugins: [hardhatToolboxViemPlugin],
  paths: {
    cache: "./cache",
  },
  remappings: [
    "@uniswap/permit2/=lib/permit2/src/", 
    "forge-std/=npm/forge-std@1.9.4/src",
    "@openzeppelin/contracts/=node_modules/@openzeppelin/contracts/",
    "lib/openzeppelin-contracts/contracts/=node_modules/@openzeppelin/contracts/",
    "@tokenbound/=lib/tokenbound/src/",
    "erc6551/=lib/tokenbound/lib/erc6551/",
    "solady/=node_modules/solady/"
  ],
  solidity: {
    compilers: [
      {
        version: "0.8.29", // Using 0.8.29 (0.8.28 has WASM compiler bug with Cancun features)
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          },
          evmVersion: "cancun",  // Required for mcopy, tload, tstore instructions
        },
      },
      {
        version: "0.8.0",
      },
      {
        version: "0.8.17",
      },
      {
        version: "0.8.15",
      },
      {
        version: "0.8.10",
      },
    ]
  },
  networks: {
    hardhatMainnet: {
      type: "edr-simulated",
      chainType: "l1",
    },
    hardhatOp: {
      type: "edr-simulated",
      chainType: "op",
    },
    sepolia: {
      type: "http",
      chainType: "l1",
      url: configVariable("SEPOLIA_RPC_URL"),
      accounts: [configVariable("SEPOLIA_PRIVATE_KEY")],
    },
    baseSepolia: {
      type: "http",
      chainType: "generic",
      url: configVariable("BASE_SEPOLIA_RPC_URL"),
      accounts: [configVariable("BASE_SEPOLIA_PRIVATE_KEY")],
      chainId: 84532,
    },
  },
};

export default config;
