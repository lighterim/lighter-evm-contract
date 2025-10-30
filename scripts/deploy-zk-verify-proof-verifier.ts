import { network } from "hardhat";

// Network configuration type
interface NetworkConfig {
  name: string;
  chainType: "l1" | "generic" | "op";
  explorerUrl: string;
  faucetUrls?: string[];
}

// Supported networks configuration
const NETWORK_CONFIGS: Record<string, NetworkConfig> = {
  sepolia: {
    name: "Ethereum Sepolia",
    chainType: "l1",
    explorerUrl: "https://sepolia.etherscan.io",
    faucetUrls: [
      "https://sepoliafaucet.com/",
      "https://faucet.sepolia.dev/",
      "https://www.infura.io/faucet/sepolia",
      "https://sepolia-faucet.pk910.de/"
    ]
  },
  baseSepolia: {
    name: "Base Sepolia",
    chainType: "generic",
    explorerUrl: "https://sepolia.basescan.org",
  },
  // 添加新网络示例：
  // customNetwork: {
  //   name: "Custom EVM Network",
  //   chainType: "generic", // 或 "l1" 取决于网络类型
  //   explorerUrl: "https://explorer.customnetwork.com",
  // }
};

async function main() {
  // 从命令行参数或环境变量获取网络名称
  let networkName = process.argv[2] || process.env.DEPLOY_NETWORK || "sepolia";
  
  // 从命令行参数获取构造函数参数（可选，如果不提供则使用默认值）
  const escrowAddress = (process.argv[3] || process.env.ESCROW_ADDRESS || "0x8cf60ed4c97df0021eb819bc92c5d1b65b642edd") as `0x${string}`;
  const zkVerifyAddress = (process.argv[4] || process.env.ZK_VERIFY_ADDRESS || "0xEA0A0f1EfB1088F4ff0Def03741Cb2C64F89361E") as `0x${string}`;
  const mainnetUserTxnAddress = (process.argv[5] || process.env.MAINNET_USER_TXN_ADDRESS || "0xd3196e7da35ce842055f89c19c225b60f16eb3d9") as `0x${string}`;

  const networkConfig = NETWORK_CONFIGS[networkName];
  
  if (!networkConfig) {
    throw new Error(
      `Unknown network: ${networkName}\n` +
      `Supported networks: ${Object.keys(NETWORK_CONFIGS).join(", ")}\n` +
      `To add a new network, add it to NETWORK_CONFIGS and hardhat.config.ts`
    );
  }

  console.log(`🚀 Deploying ZkVerifyProofVerifier to ${networkConfig.name}...`);
  console.log("=========================================================");

  console.log("\n📋 Configuration:");
  console.log("   Network:", networkName);
  console.log("   Constructor Parameters:");
  console.log("   - IEscrow:", escrowAddress);
  console.log("   - _zkVerify:", zkVerifyAddress);
  console.log("   - MainnetUserTxn:", mainnetUserTxnAddress);

  try {
    // Connect to the specified network
    console.log(`\n📡 Connecting to ${networkConfig.name} network...`);
    const { viem } = await network.connect({ 
      network: networkName, 
      chainType: networkConfig.chainType 
    });
    
    // Get wallet clients
    const walletClients = await viem.getWalletClients();
    if (walletClients.length === 0) {
      throw new Error("No wallet clients found. Please check your private key configuration.");
    }
    
    const wallet = walletClients[0];
    console.log("✅ Connected! Deploying from address:", wallet.account.address);
    
    // Get the public client
    const publicClient = await viem.getPublicClient();
    
    // Check balance
    console.log("\n💰 Checking account balance...");
    const balance = await publicClient.getBalance({
      address: wallet.account.address,
    });
    
    console.log("Account balance:", balance.toString(), "wei");
    
    if (balance === 0n) {
      const faucetMessage = networkConfig.faucetUrls 
        ? `\nPlease get some test tokens from:\n${networkConfig.faucetUrls.map(url => `  - ${url}`).join("\n")}`
        : "\nPlease ensure your account has sufficient balance.";
      throw new Error(`Account balance is 0.${faucetMessage}`);
    }

    // Deploy ZkVerifyProofVerifier contract
    console.log("\n📦 Deploying ZkVerifyProofVerifier contract...");
    const zkVerifyProofVerifier = await viem.deployContract("ZkVerifyProofVerifier", [
      escrowAddress,
      zkVerifyAddress,
      mainnetUserTxnAddress
    ]);
    
    console.log("✅ ZkVerifyProofVerifier deployed at:", zkVerifyProofVerifier.address);
    
    // Get chain ID for verification
    const chainId = await publicClient.getChainId();
    console.log(`Contract deployed on ${networkConfig.name} (Chain ID: ${chainId})`);
    
    // Verify contract deployment
    console.log("\n🔍 Verifying contract deployment...");
    const code = await publicClient.getBytecode({
      address: zkVerifyProofVerifier.address,
    });
    
    if (code && code !== "0x") {
      console.log("✅ Contract code verified on-chain");
    } else {
      throw new Error("❌ Contract deployment verification failed");
    }

    // Contract Verification Instructions
    console.log("\n🔍 Contract verification instructions:");
    console.log("Run the following command to verify contract on block explorer:");
    console.log("");
    console.log("Verify ZkVerifyProofVerifier:");
    console.log(`npx hardhat verify --network ${networkName} ${zkVerifyProofVerifier.address} ${escrowAddress} ${zkVerifyAddress} ${mainnetUserTxnAddress}`);
    console.log("");
    
    // Display results
    console.log(`\n🎉 ZkVerifyProofVerifier successfully deployed on ${networkConfig.name}!`);
    console.log("You can view your contract at:");
    console.log("- ZkVerifyProofVerifier:", `${networkConfig.explorerUrl}/address/${zkVerifyProofVerifier.address}`);
    
    // Additional contract information
    console.log("\n📋 Contract Details:");
    console.log("- Contract Name: ZkVerifyProofVerifier");
    console.log("- Network:", networkConfig.name);
    console.log("- Chain ID:", chainId);
    console.log("- Deployer:", wallet.account.address);
    console.log("- Transaction Hash:", zkVerifyProofVerifier.transactionHash);
    console.log("\n📋 Constructor Parameters:");
    console.log("- IEscrow:", escrowAddress);
    console.log("- _zkVerify:", zkVerifyAddress);
    console.log("- MainnetUserTxn:", mainnetUserTxnAddress);
    console.log("\n📋 Contract Address:");
    console.log("- ZkVerifyProofVerifier:", zkVerifyProofVerifier.address);
    
    // Instructions for next steps
    console.log("\n📝 Next Steps:");
    console.log(`- Contract is deployed and ready to use on ${networkConfig.name}`);
    console.log("- You can interact with ZkVerifyProofVerifier using the contract address above");
    console.log("- Verify the contract on block explorer using the command provided above");
    
    return {
      contractAddress: zkVerifyProofVerifier.address,
      transactionHash: zkVerifyProofVerifier.transactionHash,
      deployer: wallet.account.address,
      chainId: chainId,
      network: networkName,
      explorerUrl: `${networkConfig.explorerUrl}/address/${zkVerifyProofVerifier.address}`,
      constructorParams: {
        escrow: escrowAddress,
        zkVerify: zkVerifyAddress,
        mainnetUserTxn: mainnetUserTxnAddress
      }
    };
    
  } catch (error) {
    console.error("❌ Deployment failed:", error);
    throw error;
  }
}

// Export for use in other scripts
export { main as deployZKVerifyProofVerifier };

// Run if called directly
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });

