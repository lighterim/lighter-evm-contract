import { network } from "hardhat";
import { formatEther, parseEther } from "viem";

/**
 * 部署策略：使用 TokenBound 官方的 AccountV3
 * 
 * 生产环境推荐方案：
 * - 使用 TokenBound 官方已部署的 AccountV3 地址
 * - 这些地址通过 CREATE2 在各网络部署，地址一致
 * - 包含完整的 ERC-4337、权限、锁定、批量执行功能
 * 
 * 测试环境：
 * - 部署简化版本 AccountV3Simplified
 * - 用于快速测试和开发
 */

// TokenBound 官方合约地址（主网和测试网）
const OFFICIAL_ADDRESSES = {
  // 标准基础设施（跨网络一致）
  entryPoint: "0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789",        // ERC-4337 EntryPoint v0.6
  multicallForwarder: "0xcA1167915584462449EE5b4Ea51c37fE81eCDCCD",  // TokenBound Multicall
  registry: "0x000000006551c19487814612e58FE06813775758",            // ERC-6551 Registry
  
  // TokenBound AccountV3 (需要在实际网络上验证)
  // 这些地址通过 CREATE2 使用固定 salt 部署：
  // salt: 0x6551655165516551655165516551655165516551655165516551655165516551
  // factory: 0x4e59b44847b379578588920cA78FbF26c0B4956C
  
  // 主网地址（示例 - 需要从 TokenBound 官方获取实际地址）
  mainnet: {
    accountGuardian: "0x...", // 需要更新
    accountV3: "0x...",        // 需要更新
    accountProxy: "0x...",     // 需要更新
  },
  
  // 测试网地址
  sepolia: {
    accountGuardian: "0x...", // 需要更新
    accountV3: "0x...",        // 需要更新
    accountProxy: "0x...",     // 需要更新
  }
};

async function main() {
  console.log("\n🚀 Starting deployment with TokenBound Official AccountV3...\n");

  const { viem } = await network.connect();
  const [deployer] = await viem.getWalletClients();
  const publicClient = await viem.getPublicClient();

  console.log("📍 Deployer address:", deployer.account.address);
  const balance = await publicClient.getBalance({ address: deployer.account.address });
  console.log("💰 Deployer balance:", formatEther(balance), "ETH");
  
  const chainId = await publicClient.getChainId();
  console.log("🔗 Chain ID:", chainId);
  console.log("🌐 Network:", network.name);

  // 判断是使用官方地址还是部署新的
  const isProduction = chainId === 1 || chainId === 137 || chainId === 10; // Mainnet, Polygon, Optimism
  const isTestnet = chainId === 11155111 || chainId === 84532; // Sepolia, Base Sepolia

  console.log("\n" + "=".repeat(70));
  console.log("📋 DEPLOYMENT STRATEGY");
  console.log("=".repeat(70));

  let accountImplementation: string;
  let registryAddress: string = OFFICIAL_ADDRESSES.registry;

  if (isProduction) {
    console.log("✅ Production Network Detected");
    console.log("   Strategy: Use TokenBound Official Deployed Contracts");
    console.log("\n⚠️  IMPORTANT:");
    console.log("   Please verify and update the official AccountV3 addresses in the script");
    console.log("   Current mainnet addresses are placeholders.");
    console.log("\n   Official addresses:");
    console.log("   - EntryPoint:", OFFICIAL_ADDRESSES.entryPoint);
    console.log("   - MulticallForwarder:", OFFICIAL_ADDRESSES.multicallForwarder);
    console.log("   - Registry:", OFFICIAL_ADDRESSES.registry);
    
    // 使用官方地址
    accountImplementation = OFFICIAL_ADDRESSES.mainnet.accountV3;
    
    if (accountImplementation === "0x...") {
      console.log("\n❌ ERROR: Official AccountV3 address not configured!");
      console.log("   Please update OFFICIAL_ADDRESSES.mainnet.accountV3 with the actual deployed address.");
      console.log("   Refer to: https://github.com/tokenbound/contracts");
      process.exit(1);
    }
    
  } else if (isTestnet) {
    console.log("✅ Testnet Detected");
    console.log("   Strategy: Use TokenBound Official Testnet Contracts (if available)");
    console.log("   or Deploy Simplified Version for testing");
    
    // 可以选择使用官方测试网地址或部署新的
    const useOfficialTestnet = false; // 设置为 true 使用官方地址
    
    if (useOfficialTestnet && OFFICIAL_ADDRESSES.sepolia.accountV3 !== "0x...") {
      accountImplementation = OFFICIAL_ADDRESSES.sepolia.accountV3;
      console.log("   Using official testnet AccountV3:", accountImplementation);
    } else {
      console.log("   Deploying simplified AccountV3 for testing...");
      
      const registry = await viem.deployContract("ERC6551Registry", []);
      registryAddress = registry.address;
      console.log("   ✅ ERC6551Registry deployed:", registryAddress);
      
      const account = await viem.deployContract("AccountV3Simplified", []);
      accountImplementation = account.address;
      console.log("   ✅ AccountV3Simplified deployed:", accountImplementation);
    }
    
  } else {
    console.log("✅ Local/Development Network Detected");
    console.log("   Strategy: Deploy All Contracts for Testing");
    
    // 本地开发环境：部署所有合约
    const registry = await viem.deployContract("ERC6551Registry", []);
    registryAddress = registry.address;
    console.log("\n📦 ERC6551Registry deployed:", registryAddress);
    
    const account = await viem.deployContract("AccountV3Simplified", []);
    accountImplementation = account.address;
    console.log("📦 AccountV3Simplified deployed:", accountImplementation);
  }

  console.log("=".repeat(70));

  // 部署 LighterTicket
  console.log("\n📦 Deploying LighterTicket...");
  const nftName = "Lighter Ticket";
  const nftSymbol = "LTKT";
  const baseURI = "https://api.lighter.xyz/metadata/";

  const lighterNFT = await viem.deployContract("LighterTicket", [
    nftName,
    nftSymbol,
    baseURI,
  ]);
  console.log("✅ LighterTicket deployed at:", lighterNFT.address);

  // 部署 LighterAccount
  console.log("\n📦 Deploying LighterAccount...");
  const initialRentPrice = parseEther("0.00001");
  
  const minter = await viem.deployContract("LighterAccount", [
    lighterNFT.address,
    registryAddress,
    accountImplementation,
    initialRentPrice,
  ]);
  console.log("✅ LighterAccount deployed at:", minter.address);
  console.log("   Rent price:", formatEther(initialRentPrice), "ETH");

  // 转移 NFT 所有权
  console.log("\n📦 Transferring LighterTicket ownership to Minter...");
  await lighterNFT.write.transferOwnership([minter.address]);
  console.log("✅ Ownership transferred");

  // 总结
  console.log("\n" + "=".repeat(70));
  console.log("📋 DEPLOYMENT SUMMARY");
  console.log("=".repeat(70));
  console.log("Network:", network.name, `(Chain ID: ${chainId})`);
  console.log("\n📄 Contract Addresses:");
  console.log("  • LighterTicket:           ", lighterNFT.address);
  console.log("  • ERC6551Registry:         ", registryAddress);
  console.log("  • Account Implementation:  ", accountImplementation);
  console.log("  • LighterAccount:          ", minter.address);

  console.log("\n💡 Account Implementation Details:");
  if (isProduction) {
    console.log("  ✅ Using TokenBound Official AccountV3");
    console.log("  ✅ Full features: ERC-4337, Permissions, Locking, Batch Execution");
    console.log("  ✅ EntryPoint:", OFFICIAL_ADDRESSES.entryPoint);
    console.log("  ✅ MulticallForwarder:", OFFICIAL_ADDRESSES.multicallForwarder);
  } else {
    console.log("  ⚠️  Using Simplified Version (for testing)");
    console.log("  ℹ️  Features: Basic ERC-6551 functionality");
    console.log("  ℹ️  For production, use TokenBound official addresses");
  }

  console.log("\n💡 Usage:");
  console.log("  lighterAccount.createAccount(recipient, nostrPubKey) { value: 0.01 ETH }");

  console.log("\n📚 Resources:");
  console.log("  TokenBound: https://tokenbound.org");
  console.log("  GitHub: https://github.com/tokenbound/contracts");
  console.log("  Docs: https://docs.tokenbound.org");
  console.log("=".repeat(70) + "\n");

  return {
    lighterNFT: lighterNFT.address,
    registry: registryAddress,
    accountImplementation: accountImplementation,
    minter: minter.address,
  };
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });

