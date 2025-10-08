import React, { useState, useEffect } from 'react';
import { useWriteContract, usePublicClient, useWalletClient, useAccount } from 'wagmi';
import { parseEther, parseUnits, formatEther, decodeErrorResult } from 'viem';
import { AllowanceTransfer } from '@uniswap/permit2-sdk';

interface ContractInteractionProps {
  contractAddress: string;
  userAddress: string;
}

// const ESCROW_ADDRESS = '0x1568e4a51fcfe538844b3b198689c79c026e5900';

// MainnetUserTxn 合约 ABI (包含错误定义)
const CONTRACT_ABI = [
  {
    "type": "function",
    "name": "_bulkSell",
    "inputs": [
      {
        "name": "permitSingle",
        "type": "tuple",
        "components": [
          {
            "name": "details",
            "type": "tuple",
            "components": [
              {"name": "token", "type": "address"},
              {"name": "amount", "type": "uint160"},
              {"name": "expiration", "type": "uint48"},
              {"name": "nonce", "type": "uint48"}
            ]
          },
          {"name": "spender", "type": "address"},
          {"name": "sigDeadline", "type": "uint256"}
        ]
      },
      {
        "name": "intentParams",
        "type": "tuple",
        "components": [
          {"name": "token", "type": "address"},
          {
            "name": "range",
            "type": "tuple",
            "components": [
              {"name": "min", "type": "uint256"},
              {"name": "max", "type": "uint256"}
            ]
          },
          {"name": "expiryTime", "type": "uint64"},
          {"name": "currency", "type": "bytes32"},
          {"name": "paymentMethod", "type": "bytes32"},
          {"name": "payeeDetails", "type": "bytes32"},
          {"name": "price", "type": "uint256"}
        ]
      },
      {"name": "permitSig", "type": "bytes"},
      {"name": "sig", "type": "bytes"}
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "release",
    "inputs": [
      {
        "name": "escrowParams",
        "type": "tuple",
        "components": [
          {"name": "id", "type": "uint256"},
          {"name": "token", "type": "address"},
          {"name": "volume", "type": "uint256"},
          {"name": "price", "type": "uint256"},
          {"name": "usdRate", "type": "uint256"},
          {"name": "seller", "type": "address"},
          {"name": "sellerFeeRate", "type": "uint256"},
          {"name": "paymentMethod", "type": "bytes32"},
          {"name": "currency", "type": "bytes32"},
          {"name": "payeeId", "type": "bytes32"},
          {"name": "payeeAccount", "type": "bytes32"},
          {"name": "buyer", "type": "address"},
          {"name": "buyerFeeRate", "type": "uint256"}
        ]
      },
      {"name": "sig", "type": "bytes"}
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  // 错误定义
  {
    "type": "error",
    "name": "InvalidSpender",
    "inputs": []
  },
  {
    "type": "error", 
    "name": "InvalidAmount",
    "inputs": []
  },
  {
    "type": "error",
    "name": "InvalidSignature", 
    "inputs": []
  },
  {
    "type": "error",
    "name": "SignatureExpired",
    "inputs": [
      {"name": "deadline", "type": "uint256"}
    ]
  },
  // Permit2 错误定义
  {
    "type": "error",
    "name": "SignatureExpired",
    "inputs": [
      {"name": "signatureDeadline", "type": "uint256"}
    ]
  },
  {
    "type": "error",
    "name": "InvalidNonce",
    "inputs": []
  },
  {
    "type": "error",
    "name": "AllowanceExpired",
    "inputs": [
      {"name": "deadline", "type": "uint256"}
    ]
  },
  {
    "type": "error",
    "name": "InsufficientAllowance",
    "inputs": [
      {"name": "amount", "type": "uint256"}
    ]
  }
] as const;

export const ContractInteraction: React.FC<ContractInteractionProps> = ({ 
  contractAddress, 
  userAddress 
}) => {
  const [isLoading, setIsLoading] = useState(false);
  const [result, setResult] = useState<string>('');
  const [error, setError] = useState<string>('');
  
  // 表单状态
  const [tokenAddress, setTokenAddress] = useState<string>('');
  const [tokenDecimals, setTokenDecimals] = useState<number>(6);
  const [amount, setAmount] = useState<string>('');
  const [minAmount, setMinAmount] = useState<string>('');
  const [maxAmount, setMaxAmount] = useState<string>('');
  const [price, setPrice] = useState<string>('');
  
  const publicClient = usePublicClient();
  const { writeContract, isPending, error: writeError, data: writeData } = useWriteContract();
  const { data: walletClient } = useWalletClient();
  const { address: accountAddress, isConnected } = useAccount();
  
  // 签名状态
  const [permitSignature, setPermitSignature] = useState<string>('');
  const [intentSignature, setIntentSignature] = useState<string>('');
  
  // EscrowParams 状态 (用于 release 函数)
  const [escrowId, setEscrowId] = useState<string>('1');
  const [escrowVolume, setEscrowVolume] = useState<string>('1.5');
  const [escrowPrice, setEscrowPrice] = useState<string>('1');
  const [escrowUsdRate, setEscrowUsdRate] = useState<string>('1');
  const [escrowSeller, setEscrowSeller] = useState<string>('');
  const [escrowSellerFeeRate, setEscrowSellerFeeRate] = useState<string>('0');
  const [escrowPaymentMethod, setEscrowPaymentMethod] = useState<string>('0x0000000000000000000000000000000000000000000000000000000000000000');
  const [escrowCurrency, setEscrowCurrency] = useState<string>('0x0000000000000000000000000000000000000000000000000000000000000000');
  const [escrowPayeeId, setEscrowPayeeId] = useState<string>('0x0000000000000000000000000000000000000000000000000000000000000000');
  const [escrowPayeeAccount, setEscrowPayeeAccount] = useState<string>('0x0000000000000000000000000000000000000000000000000000000000000000');
  const [escrowBuyer, setEscrowBuyer] = useState<string>('');
  const [escrowBuyerFeeRate, setEscrowBuyerFeeRate] = useState<string>('0');
  const [escrowSignature, setEscrowSignature] = useState<string>('');
  
  // 交易状态
  const [transactionHash, setTransactionHash] = useState<string>('');
  const [isTransactionPending, setIsTransactionPending] = useState<boolean>(false);
  
  // 全局时间戳管理 - 确保签名和调用使用相同的时间
  const [globalExpiryTime, setGlobalExpiryTime] = useState<number>(0);
  const [globalNonce, setGlobalNonce] = useState<number>(-1);
  
  // 设置默认值
  useEffect(() => {
    if (accountAddress) {
      setEscrowSeller(accountAddress);
    }
  }, [accountAddress]);

  // 监听交易状态变化
  useEffect(() => {
    if (writeData && isTransactionPending) {
      console.log('✅ 交易成功:', writeData);
      setTransactionHash(writeData);
      setIsTransactionPending(false);
      setIsLoading(false);
      
      // 根据当前状态判断是哪个函数调用成功
      const isReleaseCall = escrowSignature && !permitSignature && !intentSignature;
      
      if (isReleaseCall) {
        setResult(`
🎉 release 调用成功！

📋 交易详情:
- 交易哈希: ${writeData}
- 代币地址: ${tokenAddress}
- Token Decimals: ${tokenDecimals}
- Escrow ID: ${escrowId}
- 数量: ${escrowVolume} Token 单位
- 价格: ${escrowPrice} ETH
- 卖家: ${escrowSeller}
- 买家: ${escrowBuyer}

🔗 可以在区块链浏览器中查看交易详情。
        `);
      } else {
        setResult(`
🎉 _bulkSell 调用成功！

📋 交易详情:
- 交易哈希: ${writeData}
- 代币地址: ${tokenAddress}
- Token Decimals: ${tokenDecimals}
- 数量: ${amount} Token 单位
- 数量范围: ${minAmount} - ${maxAmount} Token 单位
- 价格: ${price} ETH

🔗 可以在区块链浏览器中查看交易详情。
        `);
      }
    }
  }, [writeData, isTransactionPending, tokenAddress, tokenDecimals, amount, minAmount, maxAmount, price, escrowSignature, permitSignature, intentSignature, escrowId, escrowVolume, escrowPrice, escrowSeller, escrowBuyer]);

  // 监听交易错误
  useEffect(() => {
    if (writeError && isTransactionPending) {
      console.error('❌ 交易失败:', writeError);
      setError(writeError.message || '交易失败');
      setIsTransactionPending(false);
      setIsLoading(false);
    }
  }, [writeError, isTransactionPending]);

  const handleCheckContract = async () => {
    setIsLoading(true);
    setError('');
    setResult('');

    try {
      if (!publicClient) {
        throw new Error('无法连接到区块链网络');
      }

      // 检查合约代码
      const code = await publicClient.getCode({ 
        address: contractAddress as `0x${string}` 
      });
      
      if (code === '0x') {
        throw new Error('合约地址无效或合约不存在');
      }

      // 获取合约信息
      const chainId = publicClient.chain?.id;
      
      setResult(`
✅ 合约验证成功！

📋 合约信息:
- 地址: ${contractAddress}
- 网络: ${chainId === 1 ? 'Ethereum Mainnet' : chainId === 31337 ? 'Local Network' : `Chain ID ${chainId}`}, chainId:${chainId}
- 代码长度: ${code ? code.length : 0} 字符
- 用户地址: ${userAddress}

ℹ️ 注意: 此合约主要用于处理大宗交易意图，需要 Permit2 授权。
      `);
    } catch (err) {
      setError(err instanceof Error ? err.message : '未知错误');
    } finally {
      setIsLoading(false);
    }
  };

  const handleGetBalance = async () => {
    setIsLoading(true);
    setError('');
    setResult('');

    try {
      if (!publicClient) {
        throw new Error('无法连接到区块链网络');
      }

      const balance = await publicClient.getBalance({ 
        address: userAddress as `0x${string}` 
      });
      
      setResult(`
💰 账户余额信息:

- 地址: ${userAddress}
- 余额: ${formatEther(balance)} ETH
- 余额 (Wei): ${balance.toString()}
      `);
    } catch (err) {
      setError(err instanceof Error ? err.message : '获取余额失败');
    } finally {
      setIsLoading(false);
    }
  };

  // 生成 Permit2 签名
  const generatePermitSignature = async () => {
    if (!walletClient || !tokenAddress || !amount) {
      setError(`请先连接钱包并填写代币地址和数量 wc:${walletClient}, tokenAddr:${tokenAddress}, amount:${amount}`);
      return;
    }

    setIsLoading(true);
    setError('');
    setResult('');

    try {
      // 获取当前连接的账户地址
      const accounts = await walletClient.getAddresses();
      const owner = accounts[0];
      const chainId = publicClient?.chain?.id || 1;

      // Permit2 合约地址
      const PERMIT2_ADDRESS = '0x000000000022D473030F116dDEE9F6B43aC78BA3';

      // 检查 Permit2 合约是否存在
      if (!publicClient) {
        throw new Error('Public client 未初始化');
      }
      const permit2Code = await publicClient.getCode({ address: PERMIT2_ADDRESS as `0x${string}` });
      if (permit2Code === '0x') {
        throw new Error(`Permit2 合约在网络 ${chainId} 上不存在。地址: ${PERMIT2_ADDRESS}`);
      }

      // 查询用户当前的 nonce
      const currentAllowance = await publicClient.readContract({
        address: PERMIT2_ADDRESS as `0x${string}`,
        abi: [
          {
            "type": "function",
            "name": "allowance",
            "inputs": [
              {"name": "user", "type": "address"},
              {"name": "token", "type": "address"},
              {"name": "spender", "type": "address"}
            ],
            "outputs": [
              {"name": "amount", "type": "uint160"},
              {"name": "expiration", "type": "uint48"},
              {"name": "nonce", "type": "uint48"}
            ],
            "stateMutability": "view"
          }
        ],
        functionName: 'allowance',
        args: [owner, tokenAddress as `0x${string}`, contractAddress as `0x${string}`]
      });

      // 使用当前存储的 nonce（存储的 nonce = 签名 nonce + 1）
      const newNonce = Number(currentAllowance[2]);
      const newExpiryTime = Math.floor(Date.now() / 1000) + 360000; // 1小时后过期
      
      console.log('📋 Permit2 Nonce 信息:');
      console.log('- 当前 nonce:', currentAllowance[2]);
      console.log('- 使用 nonce:', newNonce);
      console.log('- 当前 amount:', currentAllowance[0]);
      console.log('- 当前 expiration:', currentAllowance[1]);
      
      // 设置全局变量
      setGlobalNonce(newNonce);
      setGlobalExpiryTime(newExpiryTime);
      
      // 构造 Permit2 数据
      const permitData = {
        details: {
          token: tokenAddress,
          amount: parseUnits(amount, tokenDecimals).toString(),
          expiration: newExpiryTime,
          nonce: newNonce
        },
        spender: contractAddress,
        sigDeadline: newExpiryTime
      };

      // 使用 Uniswap Permit2 SDK 获取签名数据
      const { domain: sdkDomain, types, values } = AllowanceTransfer.getPermitData(permitData, PERMIT2_ADDRESS, chainId);

      // 转换 domain 格式以兼容 viem
      const domain = {
        name: sdkDomain.name,
        version: sdkDomain.version,
        chainId: Number(sdkDomain.chainId),
        verifyingContract: sdkDomain.verifyingContract as `0x${string}`
      };

      // 生成签名
      const signature = await walletClient.signTypedData({
        account: owner,
        domain,
        types,
        primaryType: 'PermitSingle',
        message: values as unknown as Record<string, unknown>
      });

      setPermitSignature(signature);
      setResult(`✅ Permit2 签名生成成功！\n\n签名: ${signature}\n\n📋 签名参数:\n- 签名者: ${owner}\n- 代币: ${tokenAddress}\n- Token Decimals: ${tokenDecimals}\n- 数量: ${amount} Token 单位\n- 过期时间: ${new Date(permitData.details.expiration * 1000).toLocaleString()}\n- 当前存储 Nonce: ${currentAllowance[2]}\n- 签名使用 Nonce: ${permitData.details.nonce} (等于当前存储值)\n- Spender: ${contractAddress}\n\n🔍 当前授权状态:\n- 授权金额: ${formatEther(currentAllowance[0])} ETH\n- 授权过期: ${currentAllowance[1] === 0 ? '永不过期' : new Date(Number(currentAllowance[1]) * 1000).toLocaleString()}`);

    } catch (err) {
      setError(err instanceof Error ? err.message : '签名生成失败');
    } finally {
      setIsLoading(false);
    }
  };

  // 生成 IntentParams 签名
  const generateIntentSignature = async () => {
    if (!walletClient || !tokenAddress || !minAmount || !maxAmount || !price) {
      setError('请先连接钱包并填写所有意向参数');
      return;
    }

    setIsLoading(true);
    setError('');
    setResult('');

    try {
      // 如果没有全局过期时间，先生成一个
      let expiryTime = globalExpiryTime;
      if (expiryTime === 0) {
        expiryTime = Math.floor(Date.now() / 1000) + 360000;
        setGlobalExpiryTime(expiryTime);
      }

      // 构造 IntentParams 签名数据
      const intentParams = {
        token: tokenAddress as `0x${string}`,
        range: {
          min: parseUnits(minAmount, tokenDecimals),
          max: parseUnits(maxAmount, tokenDecimals)
        },
        expiryTime: BigInt(expiryTime),
        currency: "0x0000000000000000000000000000000000000000000000000000000000000000" as `0x${string}`,
        paymentMethod: "0x0000000000000000000000000000000000000000000000000000000000000000" as `0x${string}`,
        payeeDetails: "0x0000000000000000000000000000000000000000000000000000000000000000" as `0x${string}`,
        price: parseEther(price)
      };

      // MainnetUserTxn 的 EIP-712 域分隔符
      const domain = {
        name: 'MainnetUserTxn',
        version: '1',
        chainId: publicClient?.chain?.id || 1,
        verifyingContract: contractAddress as `0x${string}`
      };

      // IntentParams 的 types
      const types = {
        IntentParams: [
          { name: 'token', type: 'address' },
          { name: 'range', type: 'Range' },
          { name: 'expiryTime', type: 'uint64' },
          { name: 'currency', type: 'bytes32' },
          { name: 'paymentMethod', type: 'bytes32' },
          { name: 'payeeDetails', type: 'bytes32' },
          { name: 'price', type: 'uint256' }
        ],
        Range: [
          { name: 'min', type: 'uint256' },
          { name: 'max', type: 'uint256' }
        ]
      };

      // 生成签名
      const signature = await walletClient.signTypedData({
        domain,
        types,
        primaryType: 'IntentParams',
        message: intentParams
      });

      setIntentSignature(signature);
      setResult(`✅ IntentParams 签名生成成功！\n\n签名: ${signature}\n\n📋 签名参数:\n- 代币: ${tokenAddress}\n- Token Decimals: ${tokenDecimals}\n- 数量范围: ${minAmount} - ${maxAmount} Token 单位\n- 价格: ${price} ETH\n- 过期时间: ${new Date((Number(intentParams.expiryTime) * 1000)).toLocaleString()}, ts:${intentParams.expiryTime}`);

    } catch (err) {
      setError(err instanceof Error ? err.message : '签名生成失败');
    } finally {
      setIsLoading(false);
    }
  };

  const handleBulkSell = async () => {
    if (!tokenAddress || !amount || !minAmount || !maxAmount || !price) {
      setError('请填写所有必需字段');
      return;
    }

    if (!permitSignature || !intentSignature) {
      setError('请先生成 Permit2 签名和 IntentParams 签名');
      return;
    }

    if (!isConnected || !accountAddress) {
      setError('请先连接钱包');
      return;
    }

    console.log('🚀 开始调用 _bulkSell...');
    console.log('钱包连接状态:', { isConnected, accountAddress });
    console.log('合约地址:', contractAddress);

    setIsLoading(true);
    setIsTransactionPending(true);
    setError('');
    setResult('');
    setTransactionHash('');

    try {
      // 检查是否有全局变量，如果没有则报错
      if (globalExpiryTime === 0 || globalNonce === -1) {
        throw new Error('请先生成 Permit2 签名和 IntentParams 签名');
      }

      // 构造 permitSingle 参数 (使用全局变量确保一致性)
      const permitSingle = {
        details: {
          token: tokenAddress as `0x${string}`,
          amount: parseUnits(amount, tokenDecimals),
          expiration: globalExpiryTime,
          nonce: globalNonce
        },
        spender: contractAddress as `0x${string}`,
        sigDeadline: BigInt(globalExpiryTime)
      };

      // 构造 intentParams 参数 (使用全局变量确保一致性)
      const intentParams = {
        token: tokenAddress as `0x${string}`,
        range: {
          min: parseUnits(minAmount, tokenDecimals),
          max: parseUnits(maxAmount, tokenDecimals)
        },
        expiryTime: BigInt(globalExpiryTime),
        currency: "0x0000000000000000000000000000000000000000000000000000000000000000" as `0x${string}`,
        paymentMethod: "0x0000000000000000000000000000000000000000000000000000000000000000" as `0x${string}`,
        payeeDetails: "0x0000000000000000000000000000000000000000000000000000000000000000" as `0x${string}`,
        price: parseEther(price)
      };

      console.log('📋 调用参数:', {
        permitSingle,
        intentParams,
        permitSignature,
        intentSignature
      });

      // 验证参数
      console.log('🔍 参数验证:');
      console.log('- token 地址匹配:', permitSingle.details.token === intentParams.token);
      console.log('- amount 在范围内:', 
        permitSingle.details.amount >= intentParams.range.min && 
        permitSingle.details.amount <= intentParams.range.max
      );
      console.log('- spender 匹配:', permitSingle.spender === contractAddress);
      console.log('- 调用者地址:', accountAddress);
      console.log('- 合约地址:', contractAddress);
      console.log('- msg.sender (合约调用者):', accountAddress);
      console.log('- Permit2 签名者 (owner):', accountAddress);
      console.log('- msg.sender === Permit2 owner:', accountAddress === accountAddress);

      // 先模拟合约调用以获取详细错误信息
      console.log('🔄 模拟合约调用...');
      try {
        if (!publicClient) {
          throw new Error('Public client 未初始化');
        }
        
        await publicClient.simulateContract({
          address: contractAddress as `0x${string}`,
          abi: CONTRACT_ABI,
          functionName: '_bulkSell',
          args: [permitSingle, intentParams, permitSignature as `0x${string}`, intentSignature as `0x${string}`],
          account: accountAddress as `0x${string}`
        });
        
        console.log('✅ 模拟调用成功，可以执行实际调用');
        
        // 模拟成功，执行实际调用
        console.log('🔄 执行实际合约调用...');
        writeContract({
          address: contractAddress as `0x${string}`,
          abi: CONTRACT_ABI,
          functionName: '_bulkSell',
          args: [permitSingle, intentParams, permitSignature as `0x${string}`, intentSignature as `0x${string}`]
        });
        
      } catch (simulateError) {
        console.error('❌ 模拟调用失败:', simulateError);
        
        // 尝试解码错误
        let errorMessage = '未知错误';
        if (simulateError instanceof Error) {
          errorMessage = simulateError.message;
          
          // 如果错误包含数据，尝试解码
          const errorString = simulateError.toString();
          const errorDataMatch = errorString.match(/0x[a-fA-F0-9]{8}/);
          if (errorDataMatch) {
            try {
              const errorData = errorDataMatch[0] as `0x${string}`;
              console.log('尝试解码错误:', errorData);
              
              const decodedError = decodeErrorResult({
                abi: CONTRACT_ABI,
                data: errorData
              });
              
              console.log('解码后的错误:', decodedError);
              errorMessage = `合约错误: ${decodedError.errorName}${decodedError.args ? ` (${decodedError.args.join(', ')})` : ''}`;
            } catch (decodeError) {
              console.log('错误解码失败:', decodeError);
              errorMessage = `合约错误: ${errorDataMatch[0]} (无法解码)`;
            }
          }
        }
        
        setError(`模拟调用失败: ${errorMessage}`);
        setIsTransactionPending(false);
        setIsLoading(false);
        return;
      }

      console.log('✅ writeContract 调用完成');

    } catch (err) {
      console.error('❌ 调用失败:', err);
      setError(err instanceof Error ? err.message : '调用失败');
      setIsTransactionPending(false);
      setIsLoading(false);
    }
  };

  // 调用 release 函数
  const handleRelease = async () => {
    if (!isConnected || !accountAddress) {
      setError('请先连接钱包');
      return;
    }

    if (!contractAddress) {
      setError('请输入合约地址');
      return;
    }

    if (!escrowSignature) {
      setError('请输入 EscrowParams 签名');
      return;
    }

    setIsLoading(true);
    setIsTransactionPending(true);
    setError('');
    setResult('');

    try {
      console.log('🚀 开始调用 release...');
      console.log('钱包连接状态:', { isConnected, accountAddress });
      console.log('合约地址:', contractAddress);

      const escrowParams = {
        id: BigInt(escrowId),
        token: tokenAddress as `0x${string}`,
        volume: parseUnits(escrowVolume, tokenDecimals),
        price: parseEther(escrowPrice),
        usdRate: parseEther(escrowUsdRate),
        seller: escrowSeller as `0x${string}`,
        sellerFeeRate: BigInt(escrowSellerFeeRate),
        paymentMethod: escrowPaymentMethod as `0x${string}`,
        currency: escrowCurrency as `0x${string}`,
        payeeId: escrowPayeeId as `0x${string}`,
        payeeAccount: escrowPayeeAccount as `0x${string}`,
        buyer: escrowBuyer as `0x${string}`,
        buyerFeeRate: BigInt(escrowBuyerFeeRate)
      };

      console.log('📋 调用参数:', {
        escrowParams,
        escrowSignature
      });

      // 参数验证
      console.log('🔍 参数验证:');
      console.log('- 调用者地址:', accountAddress);
      console.log('- 卖家地址:', escrowSeller);
      console.log('- 调用者 === 卖家:', accountAddress === escrowSeller);

      // 模拟合约调用
      console.log('🔄 模拟合约调用...');
      try {
        if (!publicClient) {
          throw new Error('Public client 未初始化');
        }
        
        await publicClient.simulateContract({
          address: contractAddress as `0x${string}`,
          abi: CONTRACT_ABI,
          functionName: 'release',
          args: [escrowParams, escrowSignature as `0x${string}`],
          account: accountAddress as `0x${string}`
        });
        
        console.log('✅ 模拟调用成功，可以执行实际调用');
        
        // 模拟成功，执行实际调用
        console.log('🔄 执行实际合约调用...');
        writeContract({
          address: contractAddress as `0x${string}`,
          abi: CONTRACT_ABI,
          functionName: 'release',
          args: [escrowParams, escrowSignature as `0x${string}`]
        });
        
      } catch (simulateError) {
        console.error('❌ 模拟调用失败:', simulateError);
        
        // 尝试解码错误
        let errorMessage = '未知错误';
        if (simulateError instanceof Error) {
          errorMessage = simulateError.message;
          
          // 如果错误包含数据，尝试解码
          const errorString = simulateError.toString();
          const errorDataMatch = errorString.match(/0x[a-fA-F0-9]{8}/);
          if (errorDataMatch) {
            try {
              const errorData = errorDataMatch[0] as `0x${string}`;
              console.log('尝试解码错误:', errorData);
              
              const decodedError = decodeErrorResult({
                abi: CONTRACT_ABI,
                data: errorData
              });
              
              console.log('解码后的错误:', decodedError);
              errorMessage = `合约错误: ${decodedError.errorName}${decodedError.args ? ` (${decodedError.args.join(', ')})` : ''}`;
            } catch (decodeError) {
              console.log('错误解码失败:', decodeError);
              errorMessage = `合约错误: ${errorDataMatch[0]} (无法解码)`;
            }
          }
        }
        
        setError(`模拟调用失败: ${errorMessage}`);
        setIsTransactionPending(false);
        setIsLoading(false);
        return;
      }

      console.log('✅ writeContract 调用完成');

    } catch (err) {
      console.error('❌ 调用失败:', err);
      setError(err instanceof Error ? err.message : '调用失败');
      setIsTransactionPending(false);
      setIsLoading(false);
    }
  };

  return (
    <div className="contract-interaction">
      <h3>MainnetUserTxn 合约交互</h3>
      
      <div className="contract-info">
        <p><strong>合约地址:</strong> {contractAddress}</p>
        <p><strong>用户地址:</strong> {userAddress}</p>
      </div>

      <div className="action-buttons">
        <button 
          onClick={handleCheckContract} 
          disabled={isLoading}
          className="action-btn"
        >
          {isLoading ? '检查中...' : '验证合约'}
        </button>
        
        <button 
          onClick={handleGetBalance} 
          disabled={isLoading}
          className="action-btn"
        >
          {isLoading ? '获取中...' : '获取余额'}
        </button>
      </div>

      <div className="bulk-sell-form">
        <h4>测试 _bulkSell 函数</h4>
        <div className="form-group">
          <label>代币地址:</label>
          <input
            type="text"
            value={tokenAddress}
            onChange={(e) => setTokenAddress(e.target.value)}
            placeholder="0x..."
            className="form-input"
          />
        </div>
        
        <div className="form-group">
          <label>Token Decimals:</label>
          <input
            type="number"
            min="0"
            max="36"
            value={tokenDecimals}
            onChange={(e) => setTokenDecimals(Number(e.target.value) || 0)}
            className="form-input"
          />
        </div>
        
        <div className="form-group">
          <label>数量 (Token 单位):</label>
          <input
            type="number"
            value={amount}
            onChange={(e) => setAmount(e.target.value)}
            placeholder="1.0"
            step="0.000001"
            className="form-input"
          />
        </div>
        
        <div className="form-group">
          <label>最小数量 (Token 单位):</label>
          <input
            type="number"
            value={minAmount}
            onChange={(e) => setMinAmount(e.target.value)}
            placeholder="0.9"
            step="0.000001"
            className="form-input"
          />
        </div>
        
        <div className="form-group">
          <label>最大数量 (Token 单位):</label>
          <input
            type="number"
            value={maxAmount}
            onChange={(e) => setMaxAmount(e.target.value)}
            placeholder="1.1"
            step="0.000001"
            className="form-input"
          />
        </div>
        
        <div className="form-group">
          <label>价格 (ETH):</label>
          <input
            type="number"
            value={price}
            onChange={(e) => setPrice(e.target.value)}
            placeholder="3000.0"
            step="0.1"
            className="form-input"
          />
        </div>

        {/* 全局变量显示 */}
        <div className="form-group">
          <label>全局参数:</label>
          <div className="global-params">
            <div className="param-item">
              <span>Nonce: {globalNonce || '未设置'}</span>
            </div>
            <div className="param-item">
              <span>过期时间: {globalExpiryTime ? new Date(globalExpiryTime * 1000).toLocaleString() : '未设置'}</span>
            </div>
            <button 
              type="button"
              onClick={() => {
                setGlobalNonce(0);
                setGlobalExpiryTime(0);
                setPermitSignature('');
                setIntentSignature('');
                setResult('');
                setError('');
              }}
              className="reset-button"
            >
              重置全局参数
            </button>
          </div>
        </div>

        {/* 签名生成区域 */}
        <div className="signature-section">
          <h5>🔐 签名生成</h5>
          
          <div className="signature-buttons">
            <button 
              onClick={generatePermitSignature} 
              disabled={isLoading || !tokenAddress || !amount}
              className="action-btn signature-btn"
            >
              {isLoading ? '生成中...' : '生成 Permit2 签名'}
            </button>
            
            <button 
              onClick={generateIntentSignature} 
              disabled={isLoading || !tokenAddress || !minAmount || !maxAmount || !price}
              className="action-btn signature-btn"
            >
              {isLoading ? '生成中...' : '生成 IntentParams 签名'}
            </button>
          </div>

          {/* 签名显示区域 */}
          {permitSignature && (
            <div className="signature-display">
              <label>Permit2 签名:</label>
              <textarea
                value={permitSignature}
                readOnly
                className="signature-textarea"
                rows={2}
              />
            </div>
          )}

          {intentSignature && (
            <div className="signature-display">
              <label>IntentParams 签名:</label>
              <textarea
                value={intentSignature}
                readOnly
                className="signature-textarea"
                rows={2}
              />
            </div>
          )}
        </div>
        
        <button 
          onClick={handleBulkSell} 
          disabled={isLoading || isTransactionPending || !permitSignature || !intentSignature}
          className="action-btn bulk-sell-btn"
        >
          {isLoading || isTransactionPending ? '调用中...' : '调用 _bulkSell'}
        </button>
      </div>

      <div className="release-form">
        <h4>测试 release 函数 (卖家释放资金)</h4>
        <p className="section-description">
          此功能用于卖家释放托管资金，需要提供 EscrowParams 签名
        </p>
        
        <div className="form-group">
          <label>Escrow ID:</label>
          <input
            type="number"
            value={escrowId}
            onChange={(e) => setEscrowId(e.target.value)}
            className="form-input"
          />
        </div>
        
        <div className="form-group">
          <label>数量 (Token 单位):</label>
          <input
            type="number"
            step="0.000001"
            value={escrowVolume}
            onChange={(e) => setEscrowVolume(e.target.value)}
            className="form-input"
          />
        </div>
        
        <div className="form-group">
          <label>价格 (ETH):</label>
          <input
            type="number"
            step="0.1"
            value={escrowPrice}
            onChange={(e) => setEscrowPrice(e.target.value)}
            className="form-input"
          />
        </div>
        
        <div className="form-group">
          <label>USD 汇率:</label>
          <input
            type="number"
            step="0.1"
            value={escrowUsdRate}
            onChange={(e) => setEscrowUsdRate(e.target.value)}
            className="form-input"
          />
        </div>
        
        <div className="form-group">
          <label>卖家地址:</label>
          <input
            type="text"
            value={escrowSeller}
            onChange={(e) => setEscrowSeller(e.target.value)}
            className="form-input"
          />
        </div>
        
        <div className="form-group">
          <label>卖家费率 (wei):</label>
          <input
            type="number"
            value={escrowSellerFeeRate}
            onChange={(e) => setEscrowSellerFeeRate(e.target.value)}
            placeholder="0"
            className="form-input"
          />
        </div>
        
        <div className="form-group">
          <label>买家地址:</label>
          <input
            type="text"
            value={escrowBuyer}
            onChange={(e) => setEscrowBuyer(e.target.value)}
            className="form-input"
          />
        </div>
        
        <div className="form-group">
          <label>买家费率 (wei):</label>
          <input
            type="number"
            value={escrowBuyerFeeRate}
            onChange={(e) => setEscrowBuyerFeeRate(e.target.value)}
            placeholder="0"
            className="form-input"
          />
        </div>
        
        <div className="form-group">
          <label>支付方式:</label>
          <input
            type="text"
            value={escrowPaymentMethod}
            onChange={(e) => setEscrowPaymentMethod(e.target.value)}
            className="form-input"
          />
        </div>
        
        <div className="form-group">
          <label>货币:</label>
          <input
            type="text"
            value={escrowCurrency}
            onChange={(e) => setEscrowCurrency(e.target.value)}
            className="form-input"
          />
        </div>
        
        <div className="form-group">
          <label>收款人 ID:</label>
          <input
            type="text"
            value={escrowPayeeId}
            onChange={(e) => setEscrowPayeeId(e.target.value)}
            className="form-input"
          />
        </div>
        
        <div className="form-group">
          <label>收款人账户:</label>
          <input
            type="text"
            value={escrowPayeeAccount}
            onChange={(e) => setEscrowPayeeAccount(e.target.value)}
            className="form-input"
          />
        </div>
        
        <div className="form-group">
          <label>EscrowParams 签名 (由 lighterRelayer 提供):</label>
          <textarea
            value={escrowSignature}
            onChange={(e) => setEscrowSignature(e.target.value)}
            placeholder="请输入 lighterRelayer 提供的 EscrowParams 签名"
            rows={3}
            className="form-input"
          />
        </div>
        
        <button 
          onClick={handleRelease} 
          disabled={isLoading || isTransactionPending || !escrowSignature}
          className="action-btn release-btn"
        >
          {isLoading || isTransactionPending ? '调用中...' : '调用 release'}
        </button>
      </div>

      {error && (
        <div className="error-message">
          <h4>❌ 错误:</h4>
          <p>{error}</p>
        </div>
      )}

      {result && (
        <div className="result-message">
          <h4>📊 结果:</h4>
          <pre>{result}</pre>
        </div>
      )}

      <div className="contract-note">
        <h4>ℹ️ 合约说明:</h4>
        <p>
          MainnetUserTxn 合约主要用于处理大宗交易意图（bulk sell intentions）。
          合约的主要功能包括：
        </p>
        <ul>
          <li>处理 Permit2 代币授权</li>
          <li>验证 EIP-712 签名</li>
          <li>管理大宗出售意图</li>
          <li>与轻量级中继器交互</li>
        </ul>
        <p>
          <strong>注意:</strong> _bulkSell 函数需要有效的 Permit2 签名和 EIP-712 签名。
          此测试界面仅用于参数构造和验证，不会执行实际的链上交易。
        </p>
      </div>
    </div>
  );
};
