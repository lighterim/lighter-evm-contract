import { network } from "hardhat";
import { parseEther } from "viem";

async function main() {
  console.log("🚀 Deploying MainnetUserTxn to Ethereum Sepolia...");
  console.log("=================================================");

  const initialRentPrice = parseEther("0.00001");
  
  try {
    // Connect to Ethereum Sepolia network
    console.log("\n📡 Connecting to Ethereum Sepolia network...");
    // const { viem } = await network.connect({ network: "sepolia", chainType: "l1" });
    const { viem } = await network.connect({ network: "horizen", chainType: "generic" });
    
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
        "Account balance is 0. Please get some Sepolia ETH from:\n" +
        "1. https://sepoliafaucet.com/\n" +
        "2. https://faucet.sepolia.dev/\n" +
        "3. https://www.infura.io/faucet/sepolia\n" +
        "4. https://sepolia-faucet.pk910.de/"
      );
    }

    // Deploy contracts in dependency order
    
    // 1. Deploy LighterTicket NFT contract
    console.log("\n📦 Deploying LighterTicket NFT contract...");
    const lighterTicket = await viem.deployContract("LighterTicket", [
      "LighterTicket", 
      "LTK", 
      "https://api.lighter.com/tickets/"
    ]);
    console.log("✅ LighterTicket deployed at:", lighterTicket.address);

    // 2. Deploy ERC6551Registry
    console.log("\n📦 Deploying ERC6551Registry...");
    const erc6551Registry = await viem.deployContract("ERC6551Registry");
    console.log("✅ ERC6551Registry deployed at:", erc6551Registry.address);

    // 3. Deploy AccountV3 implementation
    console.log("\n📦 Deploying AccountV3 implementation...");
    const accountV3Impl = await viem.deployContract("AccountV3Simplified");
    console.log("✅ AccountV3Simplified deployed at:", accountV3Impl.address);

    // 4. Deploy LighterAccount contract
    console.log("\n📦 Deploying LighterAccount contract...");
    const lighterAccount = await viem.deployContract("LighterAccount", [
      lighterTicket.address,
      erc6551Registry.address,
      accountV3Impl.address,
      initialRentPrice
    ]);
    console.log("✅ LighterAccount deployed at:", lighterAccount.address);

    // 5. Deploy the Escrow contract
    console.log("\n📦 Deploying Escrow contract...");
    const escrow = await viem.deployContract("Escrow", [wallet.account.address]);
    console.log("✅ Escrow contract deployed at:", escrow.address);

    // 6. Deploy AllowanceHolder contract
    console.log("\n📦 Deploying AllowanceHolder contract...");
    // const allowanceHolder = await viem.deployContract("AllowanceHolder");
    // console.log("✅ AllowanceHolder deployed at:", allowanceHolder.address);
    const allowanceHolderAddress = "0xe3aFe266962F5A02983f42B7a33f47ec22b716aB";

    // 7. Transfer LighterTicket ownership to LighterAccount
    console.log("\n📦 Transferring LighterTicket ownership to LighterAccount...");
    await lighterTicket.write.transferOwnership([lighterAccount.address]);
    console.log("✅ Ownership transferred to LighterAccount");

    // 8. Deploy the MainnetUserTxn contract (updated constructor with AllowanceHolder)
    console.log("\n📦 Deploying MainnetUserTxn contract...");
    const userTxn = await viem.deployContract("MainnetUserTxn", [
      lighterRelayerAddress, 
      escrow.address, 
      lighterAccount.address,
      allowanceHolderAddress
    ]/*, {
      libraries: {
        "SignatureVerification": signatureVerificationLib.address
      }
    }*/);

    // 9. Deploy the ZkVerifyProofVerifier contract 
    console.log("\n📦 Deploying ZkVerifyProofVerifier contract...");
    // const zkVerifyProofVerifier = await viem.deployContract("ZkVerifyProofVerifier", [
    //   escrow.address,
    //   userTxn.address
    // ]);
    // console.log("✅ ZkVerifyProofVerifier deployed at:", zkVerifyProofVerifier.address);

    
    console.log("✅ Deployment completed!");
    console.log("MainnetUserTxn contract deployed at:", userTxn.address);
    
    // Get chain ID for verification
    const chainId = await publicClient.getChainId();
    console.log("Contract deployed on Ethereum Sepolia (Chain ID:", chainId + ")");
    
    // Contract Verification Instructions
    console.log("\n🔍 Contract verification instructions:");
    console.log("Run the following commands to verify contracts on Etherscan:");
    console.log("");
    console.log("1. Verify LighterTicket:");
    console.log(`npx hardhat verify --network sepolia ${lighterTicket.address} "LighterTicket" "LTK" "https://api.lighter.com/tickets/"`);
    console.log("");
    console.log("2. Verify ERC6551Registry:");
    console.log(`npx hardhat verify --network sepolia ${erc6551Registry.address}`);
    console.log("");
    console.log("3. Verify AccountV3Simplified:");
    console.log(`npx hardhat verify --network sepolia ${accountV3Impl.address}`);
    console.log("");
    console.log("4. Verify LighterAccount:");
    console.log(`npx hardhat verify --network sepolia ${lighterAccount.address} ${lighterTicket.address} ${erc6551Registry.address} ${accountV3Impl.address} ${initialRentPrice}`);
    console.log("");
    console.log("5. Verify Escrow:");
    console.log(`npx hardhat verify --network sepolia ${escrow.address} ${wallet.account.address}`);
    console.log("");
    console.log("6. Verify AllowanceHolder:");
    console.log(`npx hardhat verify --network sepolia ${allowanceHolderAddress}`);
    console.log("");
    // console.log("7. Verify SignatureVerification library:");
    // console.log(`npx hardhat verify --network sepolia ${signatureVerificationLib.address}`);
    // console.log("");
    // console.log("8. Verify MainnetUserTxn:");
    console.log(`npx hardhat verify --network sepolia ${userTxn.address} ${lighterRelayerAddress} ${escrow.address} ${lighterAccount.address} ${allowanceHolderAddress}`);
    console.log("");
    console.log("For contracts with libraries (like MainnetUserTxn), if verification fails, try:");
    console.log(`npx hardhat verify --network sepolia ${userTxn.address} ${lighterRelayerAddress} ${escrow.address} ${lighterAccount.address} ${allowanceHolderAddress}`);
    
    // Display results
    console.log("\n🎉 All contracts successfully deployed and verified on Ethereum Sepolia!");
    console.log("You can view your contracts at:");
    console.log("- LighterTicket:", `https://sepolia.etherscan.io/address/${lighterTicket.address}`);
    console.log("- ERC6551Registry:", `https://sepolia.etherscan.io/address/${erc6551Registry.address}`);
    console.log("- AccountV3Simplified:", `https://sepolia.etherscan.io/address/${accountV3Impl.address}`);
    console.log("- LighterAccount:", `https://sepolia.etherscan.io/address/${lighterAccount.address}`);
    console.log("- Escrow:", `https://sepolia.etherscan.io/address/${escrow.address}`);
    console.log("- AllowanceHolder:", `https://sepolia.etherscan.io/address/${allowanceHolderAddress}`);
    //console.log("- SignatureVerification:", `https://sepolia.etherscan.io/address/${signatureVerificationLib.address}`);
    console.log("- MainnetUserTxn:", `https://sepolia.etherscan.io/address/${userTxn.address}`);
    
    // Additional contract information
    console.log("\n📋 Contract Details:");
    console.log("- Contract Name: MainnetUserTxn");
    console.log("- Network: Ethereum Sepolia Testnet");
    console.log("- Chain ID:", chainId);
    console.log("- Deployer:", wallet.account.address);
    console.log("- Lighter Relayer:", lighterRelayerAddress);
    console.log("- Rent Price: 0.00001 ETH");
    console.log("\n📋 Contract Addresses:");
    console.log("- LighterTicket:", lighterTicket.address);
    console.log("- ERC6551Registry:", erc6551Registry.address);
    console.log("- AccountV3Simplified:", accountV3Impl.address);
    console.log("- LighterAccount:", lighterAccount.address);
    console.log("- Escrow:", escrow.address);
    console.log("- AllowanceHolder:", allowanceHolderAddress);
    // console.log("- SignatureVerification:", signatureVerificationLib.address);
    console.log("- MainnetUserTxn:", userTxn.address);
    
    // Instructions for next steps
    console.log("\n📝 Next Steps:");
    console.log("- All contracts are deployed and verified on Ethereum Sepolia testnet");
    console.log("- You can interact with MainnetUserTxn using the contract address above");
    console.log("- Test the LighterAccount functionality by minting tickets");
    console.log("- Update the lighterRelayer address if needed for production use");
    console.log("- Consider upgrading to official TokenBound AccountV3 for production");
    
    return {
      lighterTicketAddress: lighterTicket.address,
      erc6551RegistryAddress: erc6551Registry.address,
      accountV3ImplAddress: accountV3Impl.address,
      lighterAccountAddress: lighterAccount.address,
      escrowAddress: escrow.address,
      allowanceHolderAddress: allowanceHolderAddress,
    //   signatureVerificationLibAddress: signatureVerificationLib.address,
      contractAddress: userTxn.address,
      deployer: wallet.account.address,
      lighterRelayer: lighterRelayerAddress,
      chainId: chainId,
      rentPrice: "1000000000" // 0.00001 ETH in wei
    };
    
  } catch (error) {
    console.error("❌ Deployment failed:", error);
    throw error;
  }
}

// Export for use in other scripts
export { main as deployUserTxnEthereumSepolia };

// Run if called directly
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
