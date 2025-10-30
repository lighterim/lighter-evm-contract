import type { HardhatUserConfig } from "hardhat/config";
import hardhatVerify from "@nomicfoundation/hardhat-verify";
import * as dotenv from "dotenv";

import hardhatToolboxViemPlugin from "@nomicfoundation/hardhat-toolbox-viem";
import { configVariable } from "hardhat/config";

// Load environment variables from .env file
dotenv.config();

const config: HardhatUserConfig = {
  plugins: [hardhatToolboxViemPlugin, hardhatVerify],
  paths: {
    cache: "./cache",
  },
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
  verify: {
    etherscan: {
      apiKey: configVariable("ETHERSCAN_API_KEY"),
    },
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
    horizen:{
        type: "http",                    // 对于标准 EVM 网络使用 "http"
        chainType: "generic",            // L3 应用链使用 "generic"
        url: configVariable("HORIZEN_RPC_URL"),  // 从环境变量读取 RPC URL
        accounts: [configVariable("SEPOLIA_PRIVATE_KEY")],  // 从环境变量读取私钥
        chainId: 2651420,          // 可选，通常会自动检测
    }
  },
};

export default config;
