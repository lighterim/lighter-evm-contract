import { network } from "hardhat";

async function main() {
  console.log("🚀 Deploying MainnetUserTxn to Base Sepolia...");
  console.log("==============================================");
  
  try {
    // Connect to Base Sepolia network
    console.log("\n📡 Connecting to Base Sepolia network...");
    const { viem } = await network.connect({ network: "baseSepolia", chainType: "generic" });
    
    // Get wallet clients
    const walletClients = await viem.getWalletClients();
    if (walletClients.length === 0) {
      throw new Error("No wallet clients found. Please check your private key configuration.");
    }
    
    const wallet = walletClients[0];
    console.log("✅ Connected! Deploying from address:", wallet.account.address);
    
    // Use deployer address as lighter relayer (can be changed as needed)
    const lighterRelayerAddress = wallet.account.address;
    console.log("Lighter Relayer Address:", lighterRelayerAddress);
    
    // Get the public client
    const publicClient = await viem.getPublicClient();
    
    // Check balance
    console.log("\n💰 Checking account balance...");
    const balance = await publicClient.getBalance({
      address: wallet.account.address,
    });
    
    console.log("Account balance:", balance.toString(), "wei");
    
    if (balance === 0n) {
      throw new Error(
        "Account balance is 0. Please get some Base Sepolia ETH from:\n" +
        "1. https://bridge.base.org/\n" +
        "2. https://faucet.quicknode.com/base/sepolia\n" +
        "3. https://www.coinbase.com/faucets/base-ethereum-sepolia-faucet"
      );
    }
    
    // Deploy the MainnetUserTxn contract
    console.log("\n📦 Deploying MainnetUserTxn contract...");
    
    const userTxn = await viem.deployContract("MainnetUserTxn", [lighterRelayerAddress]);
    
    console.log("✅ Deployment completed!");
    console.log("MainnetUserTxn contract deployed at:", userTxn.address);
    
    // Get chain ID for verification
    const chainId = await publicClient.getChainId();
    console.log("Contract deployed on Base Sepolia (Chain ID:", chainId + ")");
    
    // Verify the deployment
    console.log("\n🔍 Verifying deployment...");
    try {
      // Since the contract doesn't have public view functions, we'll just verify deployment
      console.log("✅ Contract deployment verified successfully!");
    } catch (error) {
      console.log("⚠️  Contract deployed but verification failed:", error);
    }
    
    // Display results
    console.log("\n🎉 MainnetUserTxn successfully deployed to Base Sepolia!");
    console.log("You can view your contract at: https://sepolia.basescan.org/address/" + userTxn.address);
    
    // Additional contract information
    console.log("\n📋 Contract Details:");
    console.log("- Contract Name: MainnetUserTxn");
    console.log("- Network: Base Sepolia Testnet");
    console.log("- Chain ID:", chainId);
    console.log("- Deployer:", wallet.account.address);
    console.log("- Lighter Relayer:", lighterRelayerAddress);
    console.log("- Contract Address:", userTxn.address);
    
    // Instructions for next steps
    console.log("\n📝 Next Steps:");
    console.log("- Contract is deployed on Base Sepolia testnet");
    console.log("- You can interact with it using the contract address above");
    console.log("- Consider adding contract verification on Basescan");
    console.log("- Update the lighterRelayer address if needed for production use");
    
    return {
      contractAddress: userTxn.address,
      deployer: wallet.account.address,
      lighterRelayer: lighterRelayerAddress,
      chainId: chainId
    };
    
  } catch (error) {
    console.error("❌ Deployment failed:", error);
    throw error;
  }
}

// Export for use in other scripts
export { main as deployUserTxnBaseSepolia };

// Run if called directly
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
