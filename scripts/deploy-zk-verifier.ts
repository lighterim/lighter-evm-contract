import { network } from "hardhat";

async function main() {
  console.log("🚀 Deploying ZkVerifier Contract...");
  console.log("====================================");

  // 从命令行参数获取 zkVerify 地址，如果没有提供则使用默认值
  // 支持通过 --zk-verify 参数传递，例如: --zk-verify 0x123...
  let zkVerifyAddress = "0x5a3c35CCC5c05fDeFe5Ecafc15F4B1aC8eF71481"; // 默认值
  
  // 检查命令行参数
  const args = process.argv.slice(2);
  for (let i = 0; i < args.length; i++) {
    if (args[i] === '--zk-verify' && i + 1 < args.length) {
      zkVerifyAddress = args[i + 1];
      break;
    }
  }
  
  // 也支持环境变量
  if (process.env.ZK_VERIFY_ADDRESS) {
    zkVerifyAddress = process.env.ZK_VERIFY_ADDRESS;
  }
  
  console.log(`📋 Configuration:`);
  console.log(`   ZkVerify Address: ${zkVerifyAddress}`);
  
  try {
    // 连接网络
    console.log("\n📡 Connecting to network...");
    const { viem } = await network.connect();
    
    // 获取钱包客户端
    const walletClients = await viem.getWalletClients();
    if (walletClients.length === 0) {
      throw new Error("No wallet clients found. Please check your private key configuration.");
    }
    
    const wallet = walletClients[0];
    console.log("✅ Connected! Deploying from address:", wallet.account.address);
    
    // 获取公共客户端
    const publicClient = await viem.getPublicClient();
    
    // 检查余额
    console.log("\n💰 Checking account balance...");
    const balance = await publicClient.getBalance({
      address: wallet.account.address,
    });
    
    console.log("Account balance:", balance.toString(), "wei");
    
    if (balance === BigInt(0)) {
      throw new Error(
        "Account balance is 0. Please get some ETH for the network you're deploying to."
      );
    }

    // 部署 ZkVerifier 合约
    console.log("\n🔨 Deploying ZkVerifier contract...");
    console.log(`   Constructor parameter (zkVerify): ${zkVerifyAddress}`);
    
    const zkVerifier = await viem.deployContract("ZkVerifier", [zkVerifyAddress as `0x${string}`], {
      walletClient: wallet,
    });
    
    console.log("✅ ZkVerifier deployed successfully!");
    console.log("=========================================");
    console.log(`📄 Contract Address: ${zkVerifier.address}`);
    console.log(`🔗 Transaction Hash: ${zkVerifier.transactionHash}`);
    console.log(`📋 Constructor Parameters:`);
    console.log(`   - zkVerify: ${zkVerifyAddress}`);
    
    // 验证合约部署
    console.log("\n🔍 Verifying contract deployment...");
    const code = await publicClient.getBytecode({
      address: zkVerifier.address,
    });
    
    if (code && code !== "0x") {
      console.log("✅ Contract code verified on-chain");
    } else {
      throw new Error("❌ Contract deployment verification failed");
    }

    // 测试合约功能
    console.log("\n🧪 Testing contract functionality...");
    try {
      const zkVerifyStored = await publicClient.readContract({
        address: zkVerifier.address,
        abi: [
          {
            "inputs": [],
            "name": "zkVerify",
            "outputs": [{"internalType": "address", "name": "", "type": "address"}],
            "stateMutability": "view",
            "type": "function"
          }
        ],
        functionName: "zkVerify",
      });
      
      console.log(`✅ zkVerify address stored: ${zkVerifyStored}`);
      
      if (zkVerifyStored.toLowerCase() === zkVerifyAddress.toLowerCase()) {
        console.log("✅ Constructor parameter verification successful");
      } else {
        console.log("⚠️  Warning: Constructor parameter mismatch");
        console.log(`   Expected: ${zkVerifyAddress}`);
        console.log(`   Actual: ${zkVerifyStored}`);
      }
    } catch (error) {
      console.log("⚠️  Warning: Could not test contract functionality:", error);
    }

    console.log("\n📝 Deployment Summary:");
    console.log("======================");
    console.log(`Contract: ZkVerifier`);
    console.log(`Address: ${zkVerifier.address}`);
    console.log(`Transaction: ${zkVerifier.transactionHash}`);
    console.log(`ZkVerify: ${zkVerifyAddress}`);
    
    console.log("\n🔗 Verification Commands:");
    console.log("=========================");
    console.log("Run the following command to verify contract on Etherscan:");
    console.log("");
    console.log("Verify ZkVerifier:");
    console.log(`npx hardhat verify --network <network> ${zkVerifier.address} "${zkVerifyAddress}"`);
    console.log("");
    
    console.log("🎉 ZkVerifier contract successfully deployed!");
    
  } catch (error) {
    console.error("❌ Deployment failed:", error);
    process.exit(1);
  }
}

// Export for use in other scripts
export { main as deployZkVerifier };

// Run if called directly
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });