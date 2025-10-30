import { network } from "hardhat";

async function main() {
  console.log("🚀 Deploying ZkVerifyProofVerifier to Ethereum Sepolia...");
  console.log("=========================================================");

  // Constructor parameters
  const escrowAddress = "0x8cf60ed4c97df0021eb819bc92c5d1b65b642edd" as `0x${string}`;
  const zkVerifyAddress = "0xEA0A0f1EfB1088F4ff0Def03741Cb2C64F89361E" as `0x${string}`;
  const mainnetUserTxnAddress = "0xd3196e7da35ce842055f89c19c225b60f16eb3d9" as `0x${string}`;

  console.log("\n📋 Constructor Parameters:");
  console.log("   IEscrow:", escrowAddress);
  console.log("   _zkVerify:", zkVerifyAddress);
  console.log("   MainnetUserTxn:", mainnetUserTxnAddress);

  try {
    // Connect to Ethereum Sepolia network
    console.log("\n📡 Connecting to Ethereum Sepolia network...");
    const { viem } = await network.connect({ network: "sepolia", chainType: "l1" });
    
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
      throw new Error(
        "Account balance is 0. Please get some Sepolia ETH from:\n" +
        "1. https://sepoliafaucet.com/\n" +
        "2. https://faucet.sepolia.dev/\n" +
        "3. https://www.infura.io/faucet/sepolia\n" +
        "4. https://sepolia-faucet.pk910.de/"
      );
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
    console.log("Contract deployed on Ethereum Sepolia (Chain ID:", chainId + ")");
    
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
    console.log("Run the following command to verify contract on Etherscan:");
    console.log("");
    console.log("Verify ZkVerifyProofVerifier:");
    console.log(`npx hardhat verify --network sepolia ${zkVerifyProofVerifier.address} ${escrowAddress} ${zkVerifyAddress} ${mainnetUserTxnAddress}`);
    console.log("");
    
    // Display results
    console.log("\n🎉 ZkVerifyProofVerifier successfully deployed on Ethereum Sepolia!");
    console.log("You can view your contract at:");
    console.log("- ZkVerifyProofVerifier:", `https://sepolia.etherscan.io/address/${zkVerifyProofVerifier.address}`);
    
    // Additional contract information
    console.log("\n📋 Contract Details:");
    console.log("- Contract Name: ZkVerifyProofVerifier");
    console.log("- Network: Ethereum Sepolia Testnet");
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
    console.log("- Contract is deployed and ready to use on Ethereum Sepolia testnet");
    console.log("- You can interact with ZkVerifyProofVerifier using the contract address above");
    console.log("- Verify the contract on Etherscan using the command provided above");
    
    return {
      contractAddress: zkVerifyProofVerifier.address,
      transactionHash: zkVerifyProofVerifier.transactionHash,
      deployer: wallet.account.address,
      chainId: chainId,
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
export { main as deployZKVerifyProofVerifierEthereumSepolia };

// Run if called directly
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });

