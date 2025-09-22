import { network } from "hardhat";

async function main() {
  console.log("Deploying Counter to Ethereum Sepolia...");
  
  try {
    // Connect to Sepolia network
    const { viem } = await network.connect({ network: "sepolia", chainType: "l1" });
    
    // Get wallet clients
    const walletClients = await viem.getWalletClients();
    if (walletClients.length === 0) {
      throw new Error("No wallet clients found. Please check your private key configuration.");
    }
    
    const wallet = walletClients[0];
    console.log("Deploying from address:", wallet.account.address);
    
    // Get the public client
    const publicClient = await viem.getPublicClient();
    
    // Check balance
    const balance = await publicClient.getBalance({
      address: wallet.account.address,
    });
    
    console.log("Account balance:", balance.toString(), "wei");
    
    if (balance === 0n) {
      throw new Error(
        "Account balance is 0. Please get some Sepolia ETH from:\n" +
        "1. https://sepoliafaucet.com/\n" +
        "2. https://faucet.sepolia.dev/\n" +
        "3. https://www.alchemy.com/faucets/sepolia-faucet"
      );
    }
    
    // Deploy the Counter contract
    console.log("Deploying Counter contract...");
    const counter = await viem.deployContract("Counter");
    
    console.log("✅ Deployment completed!");
    console.log("Counter contract deployed at:", counter.address);
    
    // Verify the deployment by calling a function
    const currentValue = await counter.read.x();
    console.log("Initial counter value:", currentValue.toString());
    
    // Call incBy function to test the contract
    console.log("Calling incBy(5)...");
    await counter.write.incBy([5n]);
    
    const newValue = await counter.read.x();
    console.log("Counter value after incBy(5):", newValue.toString());
    
    console.log("\n🎉 Contract successfully deployed and tested!");
    console.log("You can view your contract at: https://sepolia.etherscan.io/address/" + counter.address);
    
  } catch (error) {
    console.error("❌ Deployment failed:", error);
    process.exit(1);
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  }); 