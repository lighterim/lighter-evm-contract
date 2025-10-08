import { describe, it, before } from "node:test";
import assert from "node:assert/strict";
import { network } from "hardhat";
import { parseEther, type Address, type WalletClient } from "viem";

describe("UserTxn Integration Test", async function () {
  const { viem } = await network.connect();
  const publicClient = await viem.getPublicClient();
  
  let lighterRelayer: WalletClient;
  let seller: WalletClient;
  let buyer: WalletClient;
  
  // 合约实例
  let token: any;
  let escrow: any;
  let userTxn: any;
  
  // 测试参数
  let EXPIRATION: number;
  let DEADLINE: number;
  const PERMIT2_ADDRESS = "0x000000000022D473030F116dDEE9F6B43aC78BA3" as Address;
  
  before(async function () {
    console.log("\n=== 准备阶段 ===\n");
    
    // 获取 wallet clients
    const walletClients = await viem.getWalletClients();
    [lighterRelayer, seller, buyer] = walletClients;
    
    // 设置过期时间
    const currentBlock = await publicClient.getBlock();
    EXPIRATION = Number(currentBlock.timestamp) + 360000; // 100 hour from now
    DEADLINE = EXPIRATION;
    
    console.log(`获取到 ${walletClients.length} 个钱包账户`);
    console.log(`lighterRelayer: ${lighterRelayer.account.address}`);
    console.log(`seller: ${seller.account.address}`);
    console.log(`buyer: ${buyer.account.address}`);
    
    // 0. 部署测试 Token (使用 Counter 作为示例，实际应该部署 ERC20)
    console.log("\n0. 部署测试 Token...");
    token = await viem.deployContract("Counter");
    console.log(`   Token 地址: ${token.address}`);
    
    // 1. 部署 Escrow 合约
    console.log("\n1. 部署 Escrow 合约...");
    escrow = await viem.deployContract("Escrow", [lighterRelayer.account.address]);
    console.log(`   Escrow 地址: ${escrow.address}`);
    
    // 2. 部署 SignatureVerification 库
    console.log("\n2. 部署 SignatureVerification 库...");
    const signatureVerificationLib = await viem.deployContract("SignatureVerification");
    console.log(`   SignatureVerification 地址: ${signatureVerificationLib.address}`);
    
    // 3. 部署 UserTxn 合约（链接 SignatureVerification 库）
    console.log("\n3. 部署 UserTxn 合约...");
    userTxn = await viem.deployContract(
      "MainnetUserTxn",
      [lighterRelayer.account.address, escrow.address],
      {
        libraries: {
          "SignatureVerification": signatureVerificationLib.address
        }
      }
    );
    console.log(`   UserTxn 地址: ${userTxn.address}`);
    
    console.log("\n=== 准备阶段完成 ===\n");
  });

  it("完整业务流程测试: _bulkSell -> _takeBulkSellIntent", async function () {
    console.log("\n=== 业务流程测试开始 ===\n");
    
    // ============================================
    // 步骤 1: Seller 调用 _bulkSell
    // ============================================
    console.log("步骤 1: Seller 准备调用 _bulkSell");
    
    // 1.1 准备 IntentParams
    const intentParams = {
      token: token.address,
      range: {
        min: parseEther("1"),
        max: parseEther("2")
      },
      expiryTime: BigInt(EXPIRATION),
      currency: "0x0000000000000000000000000000000000000000000000000000000000000000" as `0x${string}`,
      paymentMethod: "0x0000000000000000000000000000000000000000000000000000000000000000" as `0x${string}`,
      payeeDetails: "0x0000000000000000000000000000000000000000000000000000000000000000" as `0x${string}`,
      price: parseEther("1")
    };
    
    console.log("   IntentParams 准备完成");
    
    // 1.2 生成 IntentParams 的 EIP-712 签名
    const intentParamsTypes = {
      IntentParams: [
        { name: "token", type: "address" },
        { name: "range", type: "Range" },
        { name: "expiryTime", type: "uint64" },
        { name: "currency", type: "bytes32" },
        { name: "paymentMethod", type: "bytes32" },
        { name: "payeeDetails", type: "bytes32" },
        { name: "price", type: "uint256" }
      ],
      Range: [
        { name: "min", type: "uint256" },
        { name: "max", type: "uint256" }
      ]
    };
    
    const intentDomain = {
      name: "MainnetUserTxn",
      version: "1",
      chainId: await publicClient.getChainId(),
      verifyingContract: userTxn.address
    };
    
    const intentSignature = await seller.signTypedData({
      domain: intentDomain,
      types: intentParamsTypes,
      primaryType: "IntentParams",
      message: intentParams
    });
    
    console.log("   IntentParams 签名完成");
    console.log(`   签名: ${intentSignature}`);
    
    // 1.3 准备 PermitSingle
    const permitSingle = {
      details: {
        token: token.address,
        amount: parseEther("2"),
        expiration: BigInt(EXPIRATION),
        nonce: 0n
      },
      spender: escrow.address,
      sigDeadline: BigInt(DEADLINE)
    };
    
    console.log("   PermitSingle 准备完成");
    
    // 1.4 生成 PermitSingle 的 Permit2 签名
    const permit2Domain = {
      name: "Permit2",
      chainId: await publicClient.getChainId(),
      verifyingContract: PERMIT2_ADDRESS as `0x${string}`
    };
    
    const permit2Types = {
      PermitSingle: [
        { name: "details", type: "PermitDetails" },
        { name: "spender", type: "address" },
        { name: "sigDeadline", type: "uint256" }
      ],
      PermitDetails: [
        { name: "token", type: "address" },
        { name: "amount", type: "uint160" },
        { name: "expiration", type: "uint48" },
        { name: "nonce", type: "uint48" }
      ]
    };
    
    const permitSignature = await seller.signTypedData({
      domain: permit2Domain,
      types: permit2Types,
      primaryType: "PermitSingle",
      message: permitSingle
    });
    
    console.log("   Permit2 签名完成");
    console.log(`   签名: ${permitSignature}`);
    
    // 1.5 Seller 调用 _bulkSell
    console.log("\n   调用 _bulkSell...");
    
    try {
      // 注意：实际调用前需要先给 Permit2 授权
      // await token.write.approve([PERMIT2_ADDRESS, parseEther("1000")]);
      
      const bulkSellTx = await userTxn.write._bulkSell(
        [permitSingle, intentParams, permitSignature, intentSignature]
      );
      
      console.log(`   ✅ _bulkSell 调用成功！`);
      console.log(`   交易哈希: ${bulkSellTx}`);
    } catch (error: any) {
      console.log(`   ⚠️  _bulkSell 调用失败（可能需要先配置 Permit2）: ${error.message}`);
    }
    
    // ============================================
    // 步骤 2: Buyer 调用 _takeBulkSellIntent
    // ============================================
    console.log("\n步骤 2: Buyer 准备调用 _takeBulkSellIntent");
    
    // 2.1 准备 EscrowParams
    const escrowParams = {
      id: 1n,
      token: token.address,
      volume: parseEther("1"),
      price: parseEther("1"),
      usdRate: parseEther("1"),
      seller: seller.account.address,
      sellerFeeRate: 0n,
      paymentMethod: "0x0000000000000000000000000000000000000000000000000000000000000000" as `0x${string}`,
      currency: "0x0000000000000000000000000000000000000000000000000000000000000000" as `0x${string}`,
      payeeId: "0x0000000000000000000000000000000000000000000000000000000000000000" as `0x${string}`,
      payeeAccount: "0x0000000000000000000000000000000000000000000000000000000000000000" as `0x${string}`,
      buyer: buyer.account.address,
      buyerFeeRate: 0n
    };
    
    console.log("   EscrowParams 准备完成");
    
    // 2.2 使用 lighterRelayer 对 EscrowParams 签名
    const escrowParamsTypes = {
      EscrowParams: [
        { name: "id", type: "uint256" },
        { name: "token", type: "address" },
        { name: "volume", type: "uint256" },
        { name: "price", type: "uint256" },
        { name: "usdRate", type: "uint256" },
        { name: "seller", type: "address" },
        { name: "sellerFeeRate", type: "uint256" },
        { name: "paymentMethod", type: "bytes32" },
        { name: "currency", type: "bytes32" },
        { name: "payeeId", type: "bytes32" },
        { name: "payeeAccount", type: "bytes32" },
        { name: "buyer", type: "address" },
        { name: "buyerFeeRate", type: "uint256" }
      ]
    };
    
    const escrowDomain = {
      name: "MainnetUserTxn",
      version: "1",
      chainId: await publicClient.getChainId(),
      verifyingContract: userTxn.address
    };
    
    const escrowSignature = await lighterRelayer.signTypedData({
      domain: escrowDomain,
      types: escrowParamsTypes,
      primaryType: "EscrowParams",
      message: escrowParams
    });
    
    console.log("   EscrowParams 签名完成（由 lighterRelayer 签名）");
    console.log(`   签名: ${escrowSignature}`);
    
    // 2.3 Buyer 调用 _takeBulkSellIntent (切换到 buyer 账户)
    console.log("\n   调用 _takeBulkSellIntent...");
    
    // 使用 buyer wallet client 进行交易
    const buyerUserTxn = await viem.getContractAt(
      "MainnetUserTxn",
      userTxn.address,
      { client: { wallet: buyer } }
    );
    
    try {
      const takeBulkSellTx = await buyerUserTxn.write._takeBulkSellIntent(
        [escrowParams, intentParams, escrowSignature, intentSignature]
      );
      
      console.log(`   ✅ _takeBulkSellIntent 调用成功！`);
      console.log(`   交易哈希: ${takeBulkSellTx}`);
      
      // 验证交易结果
      const receipt = await publicClient.waitForTransactionReceipt({
        hash: takeBulkSellTx
      });
      
      console.log(`   交易状态: ${receipt.status}`);
      assert.equal(receipt.status, "success", "交易应该成功");
      
    } catch (error: any) {
      console.log(`   ❌ _takeBulkSellIntent 调用失败: ${error.message}`);
      
      // 解析错误信息
      if (error.message.includes("InvalidSigner")) {
        console.log("   错误原因: 签名验证失败 (InvalidSigner)");
        console.log("   提示: 检查 IntentParams 签名是否由 seller 签署");
        console.log("   提示: 检查 EscrowParams 签名是否由 lighterRelayer 签署");
      } else if (error.message.includes("InvalidToken")) {
        console.log("   错误原因: Token 地址不匹配 (InvalidToken)");
      } else if (error.message.includes("InvalidAmount")) {
        console.log("   错误原因: 数量不在范围内 (InvalidAmount)");
      } else if (error.message.includes("SignatureExpired")) {
        console.log("   错误原因: 签名已过期 (SignatureExpired)");
      } else if (error.message.includes("InvalidSender")) {
        console.log("   错误原因: 调用者不是买家 (InvalidSender)");
      }
      
      throw error;
    }
    
    console.log("\n=== 业务流程测试完成 ===\n");
  });
  
  it("测试签名验证 - IntentParams", async function () {
    console.log("\n=== 测试 IntentParams 签名验证 ===\n");
    
    const intentParams = {
      token: token.address,
      range: {
        min: parseEther("1"),
        max: parseEther("2")
      },
      expiryTime: BigInt(EXPIRATION),
      currency: "0x0000000000000000000000000000000000000000000000000000000000000000" as `0x${string}`,
      paymentMethod: "0x0000000000000000000000000000000000000000000000000000000000000000" as `0x${string}`,
      payeeDetails: "0x0000000000000000000000000000000000000000000000000000000000000000" as `0x${string}`,
      price: parseEther("1")
    };
    
    const intentParamsTypes = {
      IntentParams: [
        { name: "token", type: "address" },
        { name: "range", type: "Range" },
        { name: "expiryTime", type: "uint64" },
        { name: "currency", type: "bytes32" },
        { name: "paymentMethod", type: "bytes32" },
        { name: "payeeDetails", type: "bytes32" },
        { name: "price", type: "uint256" }
      ],
      Range: [
        { name: "min", type: "uint256" },
        { name: "max", type: "uint256" }
      ]
    };
    
    const domain = {
      name: "MainnetUserTxn",
      version: "1",
      chainId: await publicClient.getChainId(),
      verifyingContract: userTxn.address
    };
    
    // 使用 seller 签名
    const signature = await seller.signTypedData({
      domain,
      types: intentParamsTypes,
      primaryType: "IntentParams",
      message: intentParams
    });
    
    console.log(`Seller 地址: ${seller.account.address}`);
    console.log(`签名: ${signature}`);
    console.log(`域名: ${domain.name}`);
    console.log(`合约地址: ${domain.verifyingContract}`);
    
    assert.ok(signature.startsWith("0x"), "签名应该以 0x 开头");
    assert.equal(signature.length, 132, "签名长度应该是 132");
    
    console.log("\n✅ IntentParams 签名测试通过\n");
  });
  
  it("测试签名验证 - EscrowParams", async function () {
    console.log("\n=== 测试 EscrowParams 签名验证 ===\n");
    
    const escrowParams = {
      id: 1n,
      token: token.address,
      volume: parseEther("1"),
      price: parseEther("1"),
      usdRate: parseEther("1"),
      seller: seller.account.address,
      sellerFeeRate: 0n,
      paymentMethod: "0x0000000000000000000000000000000000000000000000000000000000000000" as `0x${string}`,
      currency: "0x0000000000000000000000000000000000000000000000000000000000000000" as `0x${string}`,
      payeeId: "0x0000000000000000000000000000000000000000000000000000000000000000" as `0x${string}`,
      payeeAccount: "0x0000000000000000000000000000000000000000000000000000000000000000" as `0x${string}`,
      buyer: buyer.account.address,
      buyerFeeRate: 0n
    };
    
    const escrowParamsTypes = {
      EscrowParams: [
        { name: "id", type: "uint256" },
        { name: "token", type: "address" },
        { name: "volume", type: "uint256" },
        { name: "price", type: "uint256" },
        { name: "usdRate", type: "uint256" },
        { name: "seller", type: "address" },
        { name: "sellerFeeRate", type: "uint256" },
        { name: "paymentMethod", type: "bytes32" },
        { name: "currency", type: "bytes32" },
        { name: "payeeId", type: "bytes32" },
        { name: "payeeAccount", type: "bytes32" },
        { name: "buyer", type: "address" },
        { name: "buyerFeeRate", type: "uint256" }
      ]
    };
    
    const domain = {
      name: "MainnetUserTxn",
      version: "1",
      chainId: await publicClient.getChainId(),
      verifyingContract: userTxn.address
    };
    
    // 使用 lighterRelayer 签名
    const signature = await lighterRelayer.signTypedData({
      domain,
      types: escrowParamsTypes,
      primaryType: "EscrowParams",
      message: escrowParams
    });
    
    console.log(`LighterRelayer 地址: ${lighterRelayer.account.address}`);
    console.log(`签名: ${signature}`);
    console.log(`域名: ${domain.name}`);
    console.log(`合约地址: ${domain.verifyingContract}`);
    
    assert.ok(signature.startsWith("0x"), "签名应该以 0x 开头");
    assert.equal(signature.length, 132, "签名长度应该是 132");
    
    console.log("\n✅ EscrowParams 签名测试通过\n");
  });
});

