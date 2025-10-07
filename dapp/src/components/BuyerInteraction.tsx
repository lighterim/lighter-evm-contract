import React, { useState, useEffect } from 'react';
import { useAccount, usePublicClient, useWalletClient, useWriteContract } from 'wagmi';
import { parseEther, formatEther, decodeErrorResult } from 'viem';
import { AllowanceTransfer } from '@uniswap/permit2-sdk';

// 合约 ABI
const CONTRACT_ABI = [
  {
    "type": "function",
    "name": "_takeBulkSellIntent",
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
      {"name": "sig", "type": "bytes"},
      {"name": "intentSig", "type": "bytes"}
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "paid",
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
  // 错误定义 - UserTxn.sol & SettlerErrors.sol
  { "type": "error", "name": "InvalidToken", "inputs": [] },
  { "type": "error", "name": "InvalidAmount", "inputs": [] },
  { "type": "error", "name": "SignatureExpired", "inputs": [ {"name": "deadline", "type": "uint256"} ] },
  { "type": "error", "name": "InvalidSender", "inputs": [] },
  { "type": "error", "name": "InvalidSpender", "inputs": [] },
  { "type": "error", "name": "InvalidSignature", "inputs": [] },
  
  // 错误定义 - SignatureVerification.sol
  { "type": "error", "name": "InvalidSignatureLength", "inputs": [] },
  { "type": "error", "name": "InvalidSigner", "inputs": [] },
  { "type": "error", "name": "InvalidContractSignature", "inputs": [] },
  
  // 其他可能的错误
  { "type": "error", "name": "EscrowAlreadyExists", "inputs": [ {"name": "escrowHash", "type": "bytes32"} ] },
  { "type": "error", "name": "EscrowNotExists", "inputs": [ {"name": "escrowHash", "type": "bytes32"} ] },
  { "type": "error", "name": "EscrowStatusError", "inputs": [ 
    {"name": "escrowHash", "type": "bytes32"},
    {"name": "expected", "type": "uint8"},
    {"name": "actual", "type": "uint8"}
  ] },
  { "type": "error", "name": "InvalidOffset", "inputs": [] },
  { "type": "error", "name": "ConfusedDeputy", "inputs": [] },
  { "type": "error", "name": "InvalidTarget", "inputs": [] },
  { "type": "error", "name": "ForwarderNotAllowed", "inputs": [] },
  { "type": "error", "name": "InvalidSignatureLen", "inputs": [] },
  { "type": "error", "name": "TooMuchSlippage", "inputs": [ 
    {"name": "token", "type": "address"},
    {"name": "expected", "type": "uint256"},
    {"name": "actual", "type": "uint256"}
  ] }
] as const;

// Permit2 地址
const PERMIT2_ADDRESS = '0x000000000022D473030F116dDEE9F6B43aC78BA3';

const BuyerInteraction: React.FC = () => {
  const { address, isConnected } = useAccount();
  const publicClient = usePublicClient();
  const { data: walletClient } = useWalletClient();
  const { writeContract, data: writeData, error: writeError, isPending } = useWriteContract();

  // 合约地址状态
  const [contractAddress, setContractAddress] = useState<string>('');

  // IntentParams 参数状态
  const [intentToken, setIntentToken] = useState<string>('0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238');
  const [intentMinAmount, setIntentMinAmount] = useState<string>('1');
  const [intentMaxAmount, setIntentMaxAmount] = useState<string>('2');
  const [intentPrice, setIntentPrice] = useState<string>('1');
  const [intentExpiryTime, setIntentExpiryTime] = useState<string>('');
  const [intentCurrency, setIntentCurrency] = useState<string>('0x0000000000000000000000000000000000000000000000000000000000000000');
  const [intentPaymentMethod, setIntentPaymentMethod] = useState<string>('0x0000000000000000000000000000000000000000000000000000000000000000');
  const [intentPayeeDetails, setIntentPayeeDetails] = useState<string>('0x0000000000000000000000000000000000000000000000000000000000000000');

  // EscrowParams 参数状态
  const [escrowId, setEscrowId] = useState<string>('1');
  const [escrowToken, setEscrowToken] = useState<string>('0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238');
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

  // 签名状态
  const [intentSignature, setIntentSignature] = useState<string>('');
  const [escrowSignature, setEscrowSignature] = useState<string>('');
  const [result, setResult] = useState<string>('');
  const [error, setError] = useState<string>('');
  const [isLoading, setIsLoading] = useState<boolean>(false);

  // 全局时间戳管理
  const [globalExpiryTime, setGlobalExpiryTime] = useState<number>(0);

  // 监听交易状态变化
  useEffect(() => {
    if (writeData) {
      setResult(`✅ 交易已提交！\n\n交易哈希: ${writeData}`);
    }
  }, [writeData]);

  useEffect(() => {
    if (writeError) {
      setError(`❌ 交易失败: ${writeError.message}`);
    }
  }, [writeError]);

  // 设置默认值
  useEffect(() => {
    if (address) {
      setEscrowBuyer(address);
      // if (!escrowSeller) {
      //   setEscrowSeller(address);
      // }
      // if (!escrowSellerFeeRate) {
      //   setEscrowSellerFeeRate(address);
      // }
      // if (!escrowBuyerFeeRate) {
      //   setEscrowBuyerFeeRate(address);
      // }
    }
  }, [address, escrowSeller, escrowSellerFeeRate, escrowBuyerFeeRate]);


  // 生成 EscrowParams 签名
  const generateEscrowSignature = async () => {
    if (!walletClient || !publicClient || !address) {
      setError('请先连接钱包');
      return;
    }

    if (!contractAddress) {
      setError('请输入合约地址');
      return;
    }

    setIsLoading(true);
    setError('');

    try {
      const chainId = await publicClient.getChainId();

      const escrowParams = {
        id: BigInt(escrowId),
        token: escrowToken as `0x${string}`,
        volume: parseEther(escrowVolume),
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

      // EIP-712 域
      const domain = {
        name: 'MainnetUserTxn',
        version: '1',
        chainId: chainId,
        verifyingContract: contractAddress as `0x${string}`
      };

      // EIP-712 类型
      const types = {
        EscrowParams: [
          { name: 'id', type: 'uint256' },
          { name: 'token', type: 'address' },
          { name: 'volume', type: 'uint256' },
          { name: 'price', type: 'uint256' },
          { name: 'usdRate', type: 'uint256' },
          { name: 'seller', type: 'address' },
          { name: 'sellerFeeRate', type: 'uint256' },
          { name: 'paymentMethod', type: 'bytes32' },
          { name: 'currency', type: 'bytes32' },
          { name: 'payeeId', type: 'bytes32' },
          { name: 'payeeAccount', type: 'bytes32' },
          { name: 'buyer', type: 'address' },
          { name: 'buyerFeeRate', type: 'uint256' }
        ]
      };

      const signature = await walletClient.signTypedData({
        account: address,
        domain,
        types,
        primaryType: 'EscrowParams',
        message: escrowParams
      });

      setEscrowSignature(signature);
      setResult(`✅ EscrowParams 签名生成成功！\n\n签名: ${signature}\n\n📋 签名参数:\n- 签名者: ${address}\n- Escrow ID: ${escrowId}\n- 代币: ${escrowToken}\n- 数量: ${escrowVolume} ETH\n- 价格: ${escrowPrice} ETH\n- 卖家: ${escrowSeller}\n- 买家: ${escrowBuyer}`);

    } catch (err) {
      setError(err instanceof Error ? err.message : '签名生成失败');
    } finally {
      setIsLoading(false);
    }
  };

  // 调用 _takeBulkSellIntent
  const handleTakeBulkSellIntent = async () => {
    if (!isConnected || !address) {
      setError('请先连接钱包');
      return;
    }

    if (!contractAddress) {
      setError('请输入合约地址');
      return;
    }

    if (!intentSignature || !escrowSignature) {
      setError('请输入 IntentParams 签名和生成 EscrowParams 签名');
      return;
    }

    if (!intentExpiryTime) {
      setError('请输入 IntentParams 过期时间');
      return;
    }

    setIsLoading(true);
    setError('');

    try {
      console.log('🚀 开始调用 _takeBulkSellIntent...');
      console.log('钱包连接状态:', { isConnected, accountAddress: address });
      console.log('合约地址:', contractAddress);

      const escrowParams = {
        id: BigInt(escrowId),
        token: escrowToken as `0x${string}`,
        volume: parseEther(escrowVolume),
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

      const intentParams = {
        token: intentToken as `0x${string}`,
        range: {
          min: parseEther(intentMinAmount),
          max: parseEther(intentMaxAmount)
        },
        expiryTime: BigInt(parseInt(intentExpiryTime)),
        currency: intentCurrency as `0x${string}`,
        paymentMethod: intentPaymentMethod as `0x${string}`,
        payeeDetails: intentPayeeDetails as `0x${string}`,
        price: parseEther(intentPrice)
      };

      console.log('📋 调用参数:', {
        escrowParams,
        intentParams,
        escrowSignature,
        intentSignature
      });

      // 参数验证
      console.log('🔍 参数验证:');
      console.log('- escrow token === intent token:', escrowToken === intentToken);
      console.log('- volume 在范围内:', parseEther(escrowVolume) >= parseEther(intentMinAmount) && parseEther(escrowVolume) <= parseEther(intentMaxAmount));
      console.log('- 调用者地址:', address);
      console.log('- 合约地址:', contractAddress);

      // 模拟合约调用
      console.log('🔄 模拟合约调用...');
      try {
        if (!publicClient) {
          throw new Error('Public client not available');
        }
        await publicClient.simulateContract({
          address: contractAddress as `0x${string}`,
          abi: CONTRACT_ABI,
          functionName: '_takeBulkSellIntent',
          args: [escrowParams, intentParams, escrowSignature as `0x${string}`, intentSignature as `0x${string}`],
          account: address
        });
        console.log('✅ 模拟调用成功');
      } catch (simError) {
        console.log('❌ 模拟调用失败:', simError);
        if (simError instanceof Error && simError.message.includes('0x')) {
          const errorSignature = simError.message.match(/0x[a-fA-F0-9]{8}/)?.[0];
          if (errorSignature) {
            console.log('尝试解码错误:', errorSignature);
            try {
              const decodedError = decodeErrorResult({
                abi: CONTRACT_ABI,
                data: errorSignature as `0x${string}`
              });
              console.log('错误解码成功:', decodedError);
            } catch (decodeError) {
              console.log('错误解码失败:', decodeError);
            }
          }
        }
        throw simError;
      }

      console.log('🔄 调用 writeContract...');
      writeContract({
        address: contractAddress as `0x${string}`,
        abi: CONTRACT_ABI,
        functionName: '_takeBulkSellIntent',
        args: [escrowParams, intentParams, escrowSignature as `0x${string}`, intentSignature as `0x${string}`]
      });
      console.log('✅ writeContract 调用完成');

    } catch (err) {
      console.log('❌ 交易失败:', err);
      setError(err instanceof Error ? err.message : '交易失败');
    } finally {
      setIsLoading(false);
    }
  };

  // 调用 paid
  const handlePaid = async () => {
    if (!isConnected || !address) {
      setError('请先连接钱包');
      return;
    }

    if (!contractAddress) {
      setError('请输入合约地址');
      return;
    }

    if (!escrowSignature) {
      setError('请先生成 EscrowParams 签名');
      return;
    }

    setIsLoading(true);
    setError('');

    try {
      console.log('🚀 开始调用 paid...');
      console.log('钱包连接状态:', { isConnected, accountAddress: address });
      console.log('合约地址:', contractAddress);

      const escrowParams = {
        id: BigInt(escrowId),
        token: escrowToken as `0x${string}`,
        volume: parseEther(escrowVolume),
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
      console.log('- 调用者地址:', address);
      console.log('- 买家地址:', escrowBuyer);
      console.log('- 调用者 === 买家:', address === escrowBuyer);

      // 模拟合约调用
      console.log('🔄 模拟合约调用...');
      try {
        if (!publicClient) {
          throw new Error('Public client not available');
        }
        await publicClient.simulateContract({
          address: contractAddress as `0x${string}`,
          abi: CONTRACT_ABI,
          functionName: 'paid',
          args: [escrowParams, escrowSignature as `0x${string}`],
          account: address
        });
        console.log('✅ 模拟调用成功');
      } catch (simError) {
        console.log('❌ 模拟调用失败:', simError);
        throw simError;
      }

      console.log('🔄 调用 writeContract...');
      writeContract({
        address: contractAddress as `0x${string}`,
        abi: CONTRACT_ABI,
        functionName: 'paid',
        args: [escrowParams, escrowSignature as `0x${string}`]
      });
      console.log('✅ writeContract 调用完成');

    } catch (err) {
      console.log('❌ 交易失败:', err);
      setError(err instanceof Error ? err.message : '交易失败');
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <div className="buyer-interaction">
      <h2>🛒 买家业务交互</h2>
      
      <div className="form-group">
        <label>合约地址:</label>
        <input
          type="text"
          value={contractAddress}
          onChange={(e) => setContractAddress(e.target.value)}
          placeholder="输入 MainnetUserTxn 合约地址"
        />
      </div>

      <div className="section">
        <h3>📋 IntentParams 参数 (卖家提供)</h3>
        <p className="section-description">
          这些参数和签名由卖家在调用 _bulkSell 时生成，买家需要复制使用
        </p>
        <div className="form-row">
          <div className="form-group">
            <label>代币地址:</label>
            <input
              type="text"
              value={intentToken}
              onChange={(e) => setIntentToken(e.target.value)}
            />
          </div>
          <div className="form-group">
            <label>最小数量 (ETH):</label>
            <input
              type="number"
              step="0.1"
              value={intentMinAmount}
              onChange={(e) => setIntentMinAmount(e.target.value)}
            />
          </div>
          <div className="form-group">
            <label>最大数量 (ETH):</label>
            <input
              type="number"
              step="0.1"
              value={intentMaxAmount}
              onChange={(e) => setIntentMaxAmount(e.target.value)}
            />
          </div>
        </div>
        <div className="form-row">
          <div className="form-group">
            <label>价格 (ETH):</label>
            <input
              type="number"
              step="0.1"
              value={intentPrice}
              onChange={(e) => setIntentPrice(e.target.value)}
            />
          </div>
          <div className="form-group">
            <label>过期时间 (Unix 时间戳):</label>
            <input
              type="number"
              value={intentExpiryTime}
              onChange={(e) => setIntentExpiryTime(e.target.value)}
              placeholder="留空自动生成 (当前时间+1小时)"
            />
            {intentExpiryTime && (
              <div className="time-display">
                可读时间: {new Date(parseInt(intentExpiryTime) * 1000).toLocaleString()}
              </div>
            )}
          </div>
          <div className="form-group">
            <label>货币:</label>
            <input
              type="text"
              value={intentCurrency}
              onChange={(e) => setIntentCurrency(e.target.value)}
            />
          </div>
        </div>
        <div className="form-row">
          <div className="form-group">
            <label>支付方式:</label>
            <input
              type="text"
              value={intentPaymentMethod}
              onChange={(e) => setIntentPaymentMethod(e.target.value)}
            />
          </div>
        </div>
        <div className="form-group">
          <label>收款人详情:</label>
          <input
            type="text"
            value={intentPayeeDetails}
            onChange={(e) => setIntentPayeeDetails(e.target.value)}
          />
        </div>
        <div className="form-group">
          <label>IntentParams 签名 (卖家提供):</label>
          <textarea
            value={intentSignature}
            onChange={(e) => setIntentSignature(e.target.value)}
            placeholder="请输入卖家提供的 IntentParams 签名"
            rows={3}
          />
        </div>
      </div>

      <div className="section">
        <h3>🏦 EscrowParams 参数</h3>
        <div className="form-row">
          <div className="form-group">
            <label>Escrow ID:</label>
            <input
              type="number"
              value={escrowId}
              onChange={(e) => setEscrowId(e.target.value)}
            />
          </div>
          <div className="form-group">
            <label>代币地址:</label>
            <input
              type="text"
              value={escrowToken}
              onChange={(e) => setEscrowToken(e.target.value)}
            />
          </div>
          <div className="form-group">
            <label>数量 (ETH):</label>
            <input
              type="number"
              step="0.1"
              value={escrowVolume}
              onChange={(e) => setEscrowVolume(e.target.value)}
            />
          </div>
        </div>
        <div className="form-row">
          <div className="form-group">
            <label>价格 (ETH):</label>
            <input
              type="number"
              step="0.1"
              value={escrowPrice}
              onChange={(e) => setEscrowPrice(e.target.value)}
            />
          </div>
          <div className="form-group">
            <label>USD 汇率:</label>
            <input
              type="number"
              step="0.1"
              value={escrowUsdRate}
              onChange={(e) => setEscrowUsdRate(e.target.value)}
            />
          </div>
          <div className="form-group">
            <label>卖家地址:</label>
            <input
              type="text"
              value={escrowSeller}
              onChange={(e) => setEscrowSeller(e.target.value)}
            />
          </div>
        </div>
        <div className="form-row">
          <div className="form-group">
            <label>卖家费率 (wei):</label>
            <input
              type="number"
              value={escrowSellerFeeRate}
              onChange={(e) => setEscrowSellerFeeRate(e.target.value)}
              placeholder="0"
            />
          </div>
          <div className="form-group">
            <label>买家地址:</label>
            <input
              type="text"
              value={escrowBuyer}
              onChange={(e) => setEscrowBuyer(e.target.value)}
            />
          </div>
          <div className="form-group">
            <label>买家费率 (wei):</label>
            <input
              type="number"
              value={escrowBuyerFeeRate}
              onChange={(e) => setEscrowBuyerFeeRate(e.target.value)}
              placeholder="0"
            />
          </div>
        </div>
        <div className="form-row">
          <div className="form-group">
            <label>支付方式:</label>
            <input
              type="text"
              value={escrowPaymentMethod}
              onChange={(e) => setEscrowPaymentMethod(e.target.value)}
            />
          </div>
          <div className="form-group">
            <label>货币:</label>
            <input
              type="text"
              value={escrowCurrency}
              onChange={(e) => setEscrowCurrency(e.target.value)}
            />
          </div>
        </div>
        <div className="form-row">
          <div className="form-group">
            <label>收款人 ID:</label>
            <input
              type="text"
              value={escrowPayeeId}
              onChange={(e) => setEscrowPayeeId(e.target.value)}
            />
          </div>
          <div className="form-group">
            <label>收款人账户:</label>
            <input
              type="text"
              value={escrowPayeeAccount}
              onChange={(e) => setEscrowPayeeAccount(e.target.value)}
            />
          </div>
        </div>
        <button onClick={generateEscrowSignature} disabled={isLoading}>
          {isLoading ? '生成中...' : '生成 EscrowParams 签名'}
        </button>
        {escrowSignature && (
          <div className="signature-display">
            <label>EscrowParams 签名:</label>
            <textarea value={escrowSignature} readOnly />
          </div>
        )}
      </div>

      <div className="section">
        <h3>🚀 合约调用</h3>
        <div className="button-group">
          <button 
            onClick={handleTakeBulkSellIntent} 
            disabled={isLoading || isPending || !intentSignature || !escrowSignature || !intentExpiryTime}
            className="primary-button"
          >
            {isLoading || isPending ? '处理中...' : '调用 _takeBulkSellIntent'}
          </button>
          <button 
            onClick={handlePaid} 
            disabled={isLoading || isPending || !escrowSignature}
            className="secondary-button"
          >
            {isLoading || isPending ? '处理中...' : '调用 paid'}
          </button>
        </div>
      </div>

      {result && (
        <div className="result">
          <h3>📋 执行结果</h3>
          <pre>{result}</pre>
        </div>
      )}

      {error && (
        <div className="error">
          <h3>❌ 错误信息</h3>
          <pre>{error}</pre>
        </div>
      )}

      {globalExpiryTime > 0 && (
        <div className="global-params">
          <h4>⏰ 全局参数</h4>
          <div className="param-item">
            <span>过期时间:</span> {new Date(globalExpiryTime * 1000).toLocaleString()}
          </div>
        </div>
      )}
    </div>
  );
};

export default BuyerInteraction;
