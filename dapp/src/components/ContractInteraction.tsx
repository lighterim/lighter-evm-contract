import React, { useState } from 'react';
import { useReadContract, useWriteContract, usePublicClient, useWalletClient } from 'wagmi';
import { parseEther, formatEther, encodeAbiParameters, parseAbiParameters, hashTypedData } from 'viem';

interface ContractInteractionProps {
  contractAddress: string;
  userAddress: string;
}

// MainnetUserTxn 合约 ABI
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
  const [amount, setAmount] = useState<string>('');
  const [minAmount, setMinAmount] = useState<string>('');
  const [maxAmount, setMaxAmount] = useState<string>('');
  const [price, setPrice] = useState<string>('');
  
  const publicClient = usePublicClient();
  const { writeContract } = useWriteContract();
  const { data: walletClient } = useWalletClient();
  
  // 签名状态
  const [permitSignature, setPermitSignature] = useState<string>('');
  const [intentSignature, setIntentSignature] = useState<string>('');

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
- 网络: ${chainId === 1 ? 'Ethereum Mainnet' : chainId === 31337 ? 'Local Network' : `Chain ID ${chainId}`}
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
      setError('请先连接钱包并填写代币地址和数量');
      return;
    }

    setIsLoading(true);
    setError('');
    setResult('');

    try {
      // 构造 Permit2 签名数据
      const permitSingle = {
        details: {
          token: tokenAddress as `0x${string}`,
          amount: parseEther(amount),
          expiration: BigInt(Math.floor(Date.now() / 1000) + 3600), // 1小时后过期
          nonce: BigInt(Math.floor(Date.now() / 1000)) // 使用时间戳作为nonce
        },
        spender: contractAddress as `0x${string}`,
        sigDeadline: BigInt(Math.floor(Date.now() / 1000) + 3600)
      };

      // Permit2 的 EIP-712 域分隔符
      const domain = {
        name: 'Permit2',
        chainId: publicClient?.chain?.id || 1,
        verifyingContract: '0x000000000022D473030F116dDEE9F6B43aC78BA3' as `0x${string}`
      };

      // Permit2 的 types
      const types = {
        PermitSingle: [
          { name: 'details', type: 'PermitDetails' },
          { name: 'spender', type: 'address' },
          { name: 'sigDeadline', type: 'uint256' }
        ],
        PermitDetails: [
          { name: 'token', type: 'address' },
          { name: 'amount', type: 'uint160' },
          { name: 'expiration', type: 'uint48' },
          { name: 'nonce', type: 'uint48' }
        ]
      };

      // 生成签名
      const signature = await walletClient.signTypedData({
        domain,
        types,
        primaryType: 'PermitSingle',
        message: permitSingle
      });

      setPermitSignature(signature);
      setResult(`✅ Permit2 签名生成成功！\n\n签名: ${signature}\n\n📋 签名参数:\n- 代币: ${tokenAddress}\n- 数量: ${amount} ETH\n- 过期时间: ${new Date((Number(permitSingle.details.expiration) * 1000)).toLocaleString()}\n- Nonce: ${permitSingle.details.nonce.toString()}\n- Spender: ${contractAddress}`);

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
      // 构造 IntentParams 签名数据
      const intentParams = {
        token: tokenAddress as `0x${string}`,
        range: {
          min: parseEther(minAmount),
          max: parseEther(maxAmount)
        },
        expiryTime: BigInt(Math.floor(Date.now() / 1000) + 3600),
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
      setResult(`✅ IntentParams 签名生成成功！\n\n签名: ${signature}\n\n📋 签名参数:\n- 代币: ${tokenAddress}\n- 数量范围: ${minAmount} - ${maxAmount} ETH\n- 价格: ${price} ETH\n- 过期时间: ${new Date((Number(intentParams.expiryTime) * 1000)).toLocaleString()}`);

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

    setIsLoading(true);
    setError('');
    setResult('');

    try {
      // 构造 permitSingle 参数
      const permitSingle = {
        details: {
          token: tokenAddress as `0x${string}`,
          amount: parseEther(amount),
          expiration: Math.floor(Date.now() / 1000) + 3600,
          nonce: Math.floor(Date.now() / 1000)
        },
        spender: contractAddress as `0x${string}`,
        sigDeadline: BigInt(Math.floor(Date.now() / 1000) + 3600)
      };

      // 构造 intentParams 参数
      const intentParams = {
        token: tokenAddress as `0x${string}`,
        range: {
          min: parseEther(minAmount),
          max: parseEther(maxAmount)
        },
        expiryTime: BigInt(Math.floor(Date.now() / 1000) + 3600),
        currency: "0x0000000000000000000000000000000000000000000000000000000000000000" as `0x${string}`,
        paymentMethod: "0x0000000000000000000000000000000000000000000000000000000000000000" as `0x${string}`,
        payeeDetails: "0x0000000000000000000000000000000000000000000000000000000000000000" as `0x${string}`,
        price: parseEther(price)
      };

      // 调用 _bulkSell 函数
      const hash = await writeContract({
        address: contractAddress as `0x${string}`,
        abi: CONTRACT_ABI,
        functionName: '_bulkSell',
        args: [permitSingle, intentParams, permitSignature as `0x${string}`, intentSignature as `0x${string}`]
      });

      setResult(`
🎉 _bulkSell 调用成功！

📋 交易详情:
- 交易哈希: ${hash}
- 代币地址: ${tokenAddress}
- 数量: ${amount} ETH
- 数量范围: ${minAmount} - ${maxAmount} ETH
- 价格: ${price} ETH

🔗 可以在区块链浏览器中查看交易详情。
      `);

    } catch (err) {
      setError(err instanceof Error ? err.message : '调用失败');
    } finally {
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
          <label>数量 (ETH):</label>
          <input
            type="number"
            value={amount}
            onChange={(e) => setAmount(e.target.value)}
            placeholder="1.0"
            step="0.1"
            className="form-input"
          />
        </div>
        
        <div className="form-group">
          <label>最小数量 (ETH):</label>
          <input
            type="number"
            value={minAmount}
            onChange={(e) => setMinAmount(e.target.value)}
            placeholder="0.9"
            step="0.1"
            className="form-input"
          />
        </div>
        
        <div className="form-group">
          <label>最大数量 (ETH):</label>
          <input
            type="number"
            value={maxAmount}
            onChange={(e) => setMaxAmount(e.target.value)}
            placeholder="1.1"
            step="0.1"
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
          disabled={isLoading || !permitSignature || !intentSignature}
          className="action-btn bulk-sell-btn"
        >
          {isLoading ? '调用中...' : '调用 _bulkSell'}
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
