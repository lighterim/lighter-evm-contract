import React, { useState, useEffect } from 'react';
import { useAccount, usePublicClient, useWriteContract, useSwitchChain } from 'wagmi';
import { parseUnits, parseEther, decodeErrorResult } from 'viem';
import { sepolia } from 'wagmi/chains';
import { MainnetUserTxnABI } from '../types/contracts';

// 扩展 Window 接口
declare global {
  interface Window {
    ethereum?: any;
  }
}

// 合约 ABI - 使用导入的类型安全 ABI
const CONTRACT_ABI = MainnetUserTxnABI;

// 错误解码函数
const decodeContractError = (error: any, context: any): string => {
  console.log('🔍 开始解码合约错误...');
  console.log('原始错误:', error);
  console.log('调用上下文:', context);

  let errorMessage = '未知错误';
  let errorData = '';
  let decodedError: any = null;

  // 尝试提取错误数据
  if (error instanceof Error) {
    const errorString = error.toString();
    console.log('错误字符串:', errorString);
    
    // 匹配 0x 开头的错误数据
    const errorDataMatch = errorString.match(/0x[a-fA-F0-9]{8,}/);
    if (errorDataMatch) {
      errorData = errorDataMatch[0];
      console.log('提取的错误数据:', errorData);
      
      try {
        decodedError = decodeErrorResult({
          abi: CONTRACT_ABI,
          data: errorData as `0x${string}`
        });
        console.log('解码成功:', decodedError);
      } catch (decodeError) {
        console.log('解码失败:', decodeError);
      }
    }
  }

  // 构建详细的错误信息
  let detailedMessage = '🚨 takeSellerIntent 调用失败\n\n';
  
  if (decodedError) {
    detailedMessage += `❌ 错误类型: ${decodedError.errorName}\n`;
    
    if (decodedError.args && decodedError.args.length > 0) {
      detailedMessage += `📋 错误参数:\n`;
      decodedError.args.forEach((arg: any, index: number) => {
        detailedMessage += `  - 参数 ${index}: ${arg}\n`;
      });
    }
    
    // 根据错误类型提供具体的解释和解决建议
    detailedMessage += `\n🔍 错误分析:\n`;
    switch (decodedError.errorName) {
      case 'SignatureExpired':
        const deadline = decodedError.args?.[0];
        detailedMessage += `- 签名已过期 (deadline: ${deadline})\n`;
        detailedMessage += `- 当前时间: ${Math.floor(Date.now() / 1000)}\n`;
        detailedMessage += `- 建议: 重新生成签名\n`;
        break;
        
      case 'InvalidSpender':
        detailedMessage += `- 转账目标地址不正确\n`;
        detailedMessage += `- 期望: ${context.contractAddress}\n`;
        detailedMessage += `- 实际: ${context.transferDetails?.to}\n`;
        detailedMessage += `- 建议: 确保 transferDetails.to 等于合约地址\n`;
        break;
        
      case 'InvalidToken':
        detailedMessage += `- 代币地址不匹配\n`;
        detailedMessage += `- permit.token: ${context.permit?.permitted?.token}\n`;
        detailedMessage += `- intentParams.token: ${context.intentParams?.token}\n`;
        detailedMessage += `- escrowParams.token: ${context.escrowParams?.token}\n`;
        detailedMessage += `- 建议: 确保所有代币地址相同\n`;
        break;
        
      case 'InvalidAmount':
        detailedMessage += `- 金额验证失败\n`;
        detailedMessage += `- permit.amount: ${context.permit?.permitted?.amount}\n`;
        detailedMessage += `- escrowParams.volume: ${context.escrowParams?.volume}\n`;
        detailedMessage += `- transferDetails.requestedAmount: ${context.transferDetails?.requestedAmount}\n`;
        detailedMessage += `- intentParams.range.min: ${context.intentParams?.range?.min}\n`;
        detailedMessage += `- intentParams.range.max: ${context.intentParams?.range?.max}\n`;
        detailedMessage += `- 建议: 检查金额是否在允许范围内\n`;
        break;
        
      case 'InvalidSignature':
        detailedMessage += `- 签名验证失败\n`;
        detailedMessage += `- 可能是 lighterRelayer 签名验证失败\n`;
        detailedMessage += `- 建议: 检查 lighterRelayer 是否正确签名\n`;
        break;
        
      case 'InvalidNonce':
        detailedMessage += `- Nonce 无效\n`;
        detailedMessage += `- permit.nonce: ${context.permit?.nonce}\n`;
        detailedMessage += `- 建议: 使用正确的 nonce 值\n`;
        break;
        
      case 'InsufficientAllowance':
        const amount = decodedError.args?.[0];
        detailedMessage += `- 授权额度不足\n`;
        detailedMessage += `- 需要金额: ${amount}\n`;
        detailedMessage += `- 建议: 增加 Permit2 授权额度\n`;
        break;
        
      case 'AllowanceExpired':
        const allowanceDeadline = decodedError.args?.[0];
        detailedMessage += `- 授权已过期 (deadline: ${allowanceDeadline})\n`;
        detailedMessage += `- 建议: 重新授权或延长授权期限\n`;
        break;
        
      case 'EscrowAlreadyExists':
        const escrowHash = decodedError.args?.[0];
        detailedMessage += `- Escrow 已存在\n`;
        detailedMessage += `- escrowHash: ${escrowHash}\n`;
        detailedMessage += `- 建议: 使用新的 escrowParams.id\n`;
        break;
        
      case 'InvalidSender':
        detailedMessage += `- 调用者地址不正确\n`;
        detailedMessage += `- 调用者: ${context.caller}\n`;
        detailedMessage += `- 建议: 确保调用者地址正确\n`;
        break;
        
      case 'ForwarderNotAllowed':
        detailedMessage += `- 不允许使用转发器\n`;
        detailedMessage += `- 建议: 直接调用合约，不要通过转发器\n`;
        break;
        
      case 'TransferFromFailed':
        detailedMessage += `- 代币转账失败\n`;
        detailedMessage += `- 可能原因: 余额不足、授权不足或代币合约问题\n`;
        detailedMessage += `- 建议: 检查卖家代币余额和授权状态\n`;
        break;
        
      case 'TransferFailed':
        detailedMessage += `- 代币转账失败\n`;
        detailedMessage += `- 建议: 检查代币合约状态\n`;
        break;
        
      default:
        detailedMessage += `- 未知错误类型: ${decodedError.errorName}\n`;
        detailedMessage += `- 建议: 查看合约源码了解具体原因\n`;
    }
  } else {
    detailedMessage += `❌ 无法解码错误\n`;
    if (errorData) {
      detailedMessage += `📋 原始错误数据: ${errorData}\n`;
    }
    detailedMessage += `📋 原始错误信息: ${error instanceof Error ? error.message : String(error)}\n`;
  }
  
  // 添加调用上下文信息
  detailedMessage += `\n📋 调用上下文:\n`;
  detailedMessage += `- 调用者: ${context.caller}\n`;
  detailedMessage += `- 合约地址: ${context.contractAddress}\n`;
  detailedMessage += `- 代币地址: ${context.permit?.permitted?.token}\n`;
  detailedMessage += `- 数量: ${context.permit?.permitted?.amount}\n`;
  detailedMessage += `- Nonce: ${context.permit?.nonce}\n`;
  detailedMessage += `- Deadline: ${context.permit?.deadline}\n`;
  detailedMessage += `- 转账目标: ${context.transferDetails?.to}\n`;
  detailedMessage += `- 请求数量: ${context.transferDetails?.requestedAmount}\n`;
  
  console.log('🔍 完整错误分析:', detailedMessage);
  return detailedMessage;
};

const BuyerIntentForm: React.FC = () => {
  const { address, isConnected } = useAccount();
  const publicClient = usePublicClient();
  const { writeContract, data: writeData, error: writeError, isPending } = useWriteContract();
  const { switchChain } = useSwitchChain();

  // 合约地址状态
  const [contractAddress, setContractAddress] = useState<string>('');

  // Permit 参数状态
  const [permitTokenAddress, setPermitTokenAddress] = useState<string>('0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238');
  const [tokenDecimals, setTokenDecimals] = useState<number>(6);
  const [permitAmount, setPermitAmount] = useState<string>('1');
  const [permitNonce, setPermitNonce] = useState<string>('1347343934330334');
  const [permitDeadline, setPermitDeadline] = useState<string>('');

  // TransferDetails 参数状态
  const [transferTo, setTransferTo] = useState<string>('');
  const [requestedAmount, setRequestedAmount] = useState<string>('1');

  // IntentParams 参数状态
  const [intentMinAmount, setIntentMinAmount] = useState<string>('0.9');
  const [intentMaxAmount, setIntentMaxAmount] = useState<string>('1.1');
  const [intentPrice, setIntentPrice] = useState<string>('1');
  const [intentExpiryTime, setIntentExpiryTime] = useState<string>('');
  const [intentCurrency, setIntentCurrency] = useState<string>('0xc4ae21aac0c6549d71dd96035b7e0bdb6c79ebdba8891b666115bc976d16a29e');
  const [intentPaymentMethod, setIntentPaymentMethod] = useState<string>('0xa87f59463aa7edfb0cc3cc39e28ba98c83fda1a3b5c6c9d10219c02669eb8a19');
  const [intentPayeeDetails, setIntentPayeeDetails] = useState<string>('0x157a30e0353a95e0152bb1cf546ffbc81ae0983338d4f84307fb58604e42367e');

  // EscrowParams 参数状态
  const [escrowId, setEscrowId] = useState<string>('1');
  const [escrowVolume, setEscrowVolume] = useState<string>('1.5');
  const [escrowPrice, setEscrowPrice] = useState<string>('1');
  const [escrowUsdRate, setEscrowUsdRate] = useState<string>('1');
  const [escrowSeller, setEscrowSeller] = useState<string>('');
  const [escrowSellerFeeRate, setEscrowSellerFeeRate] = useState<string>('0');
  const [escrowPaymentMethod, setEscrowPaymentMethod] = useState<string>('0xa87f59463aa7edfb0cc3cc39e28ba98c83fda1a3b5c6c9d10219c02669eb8a19');
  const [escrowCurrency, setEscrowCurrency] = useState<string>('0xc4ae21aac0c6549d71dd96035b7e0bdb6c79ebdba8891b666115bc976d16a29e');
  const [escrowPayeeDetails, setEscrowPayeeDetails] = useState<string>('0x157a30e0353a95e0152bb1cf546ffbc81ae0983338d4f84307fb58604e42367e');
  const [escrowBuyer, setEscrowBuyer] = useState<string>('');
  const [escrowBuyerFeeRate, setEscrowBuyerFeeRate] = useState<string>('0');

  // 签名状态
  const [permitSignature, setPermitSignature] = useState<string>('');
  const [escrowSignature, setEscrowSignature] = useState<string>('');
  const [result, setResult] = useState<string>('');
  const [error, setError] = useState<string>('');
  const [isLoading, setIsLoading] = useState<boolean>(false);
  const [networkStatus, setNetworkStatus] = useState<string>('');
  const [isCorrectNetwork, setIsCorrectNetwork] = useState<boolean>(false);
  const [metamaskNetworkInfo, setMetamaskNetworkInfo] = useState<string>('');

  // 切换到 Sepolia 网络
  const switchToSepolia = async () => {
    try {
      await switchChain({ chainId: sepolia.id });
    } catch (error) {
      console.error('切换网络失败:', error);
    }
  };

  // 手动配置 Sepolia 网络
  const configureSepoliaNetwork = async () => {
    if (typeof window !== 'undefined' && window.ethereum) {
      try {
        await window.ethereum.request({
          method: 'wallet_addEthereumChain',
          params: [{
            chainId: '0xaa36a7', // 11155111 in hex
            chainName: 'Sepolia Test Network',
            rpcUrls: [
              'https://eth-sepolia.g.alchemy.com/v2/tE4nUL18kXAYmNOM9M4U4K-jL21y5oJ3',
              'https://sepolia.infura.io/v3/9aa3d95b3bc440fa88ea12eaa4456161',
              'https://rpc.sepolia.org'
            ],
            nativeCurrency: {
              name: 'SepoliaETH',
              symbol: 'ETH',
              decimals: 18,
            },
            blockExplorerUrls: ['https://sepolia.etherscan.io'],
          }],
        });
      } catch (error) {
        console.error('配置网络失败:', error);
      }
    }
  };

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
      setTransferTo(contractAddress);
    }
  }, [address, contractAddress]);

  // 检查网络状态
  useEffect(() => {
    const checkNetworkStatus = async () => {
      if (publicClient) {
        try {
          const chainId = await publicClient.getChainId();
          const blockNumber = await publicClient.getBlockNumber();
          const isSepolia = chainId === sepolia.id; // Sepolia Chain ID
          setIsCorrectNetwork(isSepolia);
          
          if (isSepolia) {
            setNetworkStatus(`✅ 网络连接正常 (Sepolia 测试网)\n- Chain ID: ${chainId}\n- 最新区块: ${blockNumber}`);
          } else {
            setNetworkStatus(`⚠️ 网络错误\n- 当前 Chain ID: ${chainId}\n- 需要: 11155111 (Sepolia)\n- 最新区块: ${blockNumber}`);
          }
        } catch (err) {
          setNetworkStatus(`❌ 网络连接失败: ${err instanceof Error ? err.message : '未知错误'}`);
          setIsCorrectNetwork(false);
        }
      } else {
        setNetworkStatus('⚠️ 网络客户端未初始化');
        setIsCorrectNetwork(false);
      }
    };

    checkNetworkStatus();
  }, [publicClient]);

  // 检查 MetaMask 网络配置
  useEffect(() => {
    const checkMetamaskNetwork = async () => {
      if (typeof window !== 'undefined' && window.ethereum) {
        try {
          const chainId = await window.ethereum.request({ method: 'eth_chainId' });
          const networkVersion = await window.ethereum.request({ method: 'net_version' });
          const accounts = await window.ethereum.request({ method: 'eth_accounts' });
          
          setMetamaskNetworkInfo(`MetaMask 网络信息:
- Chain ID: ${chainId} (${parseInt(chainId, 16)})
- Network Version: ${networkVersion}
- 连接账户: ${accounts.length > 0 ? accounts[0] : '未连接'}
- 是否为 Sepolia: ${chainId === '0xaa36a7' ? '是' : '否'}`);
        } catch (err) {
          setMetamaskNetworkInfo(`MetaMask 检查失败: ${err instanceof Error ? err.message : '未知错误'}`);
        }
      } else {
        setMetamaskNetworkInfo('MetaMask 未检测到');
      }
    };

    checkMetamaskNetwork();
  }, []);

  // 调用 takeSellerIntent
  const handleTakeSellerIntent = async () => {
    if (!isConnected || !address) {
      setError('请先连接钱包');
      return;
    }

    if (!contractAddress) {
      setError('请输入合约地址');
      return;
    }

    if (!permitSignature || !escrowSignature) {
      setError('请提供 Permit2 签名和 EscrowParams 签名');
      return;
    }

    // 检查网络连接
    if (!publicClient) {
      setError('❌ 网络连接失败\n\n请检查：\n1. 网络连接是否正常\n2. 钱包是否连接到 Sepolia 测试网\n3. RPC 端点是否可用');
      return;
    }

    // 检查是否在正确的网络上
    if (!isCorrectNetwork) {
      setError('❌ 网络错误\n\n请确保钱包连接到 Sepolia 测试网 (Chain ID: 11155111)\n\n点击"切换到 Sepolia 网络"按钮自动切换');
      return;
    }

    setIsLoading(true);
    setError('');

    try {
      console.log('🚀 开始调用 takeSellerIntent...');
      console.log('钱包连接状态:', { isConnected, accountAddress: address });
      console.log('合约地址:', contractAddress);

      // 构造 permit 参数 - 参考其他工作组件的方式
      const permitAmountBigInt = parseUnits(permitAmount, tokenDecimals);
      const permit = {
        permitted: {
          token: permitTokenAddress as `0x${string}`,
          amount: permitAmountBigInt // 直接使用 parseUnits 的结果
        },
        nonce: BigInt(permitNonce),
        deadline: BigInt(parseInt(permitDeadline) || Math.floor(Date.now() / 1000) + 3600)
      };

      // 构造 transferDetails 参数
      const transferDetails = {
        to: transferTo  as `0x${string}`,
        requestedAmount: parseUnits(requestedAmount, tokenDecimals)
      };

      // 构造 intentParams 参数
      const intentParams = {
        token: permitTokenAddress as `0x${string}`,
        range: {
          min: parseUnits(intentMinAmount, tokenDecimals),
          max: parseUnits(intentMaxAmount, tokenDecimals)
        },
        expiryTime: BigInt(parseInt(intentExpiryTime) || Math.floor(Date.now() / 1000) + 3600),
        currency: intentCurrency as `0x${string}`,
        paymentMethod: intentPaymentMethod as `0x${string}`,
        payeeDetails: intentPayeeDetails as `0x${string}`,
        price: parseEther(intentPrice)
      };

      // 构造 escrowParams 参数
      const escrowParams = {
        id: BigInt(escrowId),
        token: permitTokenAddress as `0x${string}`,
        volume: parseUnits(escrowVolume, tokenDecimals),
        price: parseEther(escrowPrice),
        usdRate: parseEther(escrowUsdRate),
        payer: escrowSeller as `0x${string}`,
        seller: escrowSeller as `0x${string}`,
        sellerFeeRate: BigInt(escrowSellerFeeRate),
        paymentMethod: escrowPaymentMethod as `0x${string}`,
        currency: escrowCurrency as `0x${string}`,
        payeeDetails: escrowPayeeDetails as `0x${string}`,
        buyer: escrowBuyer as `0x${string}`,
        buyerFeeRate: BigInt(escrowBuyerFeeRate)
      };

      console.log('📋 调用参数:', {
        permit,
        transferDetails,
        intentParams,
        escrowParams,
        permitSignature,
        escrowSignature
      });

      // 详细参数调试
      console.log('🔍 详细参数调试:');
      console.log('- permit.permitted.amount (类型):', typeof permit.permitted.amount, permit.permitted.amount);
      console.log('- transferDetails.requestedAmount (类型):', typeof transferDetails.requestedAmount, transferDetails.requestedAmount);
      console.log('- intentParams.range.min (类型):', typeof intentParams.range.min, intentParams.range.min);
      console.log('- intentParams.range.max (类型):', typeof intentParams.range.max, intentParams.range.max);
      console.log('- escrowParams.volume (类型):', typeof escrowParams.volume, escrowParams.volume);
      console.log('- permit.deadline (类型):', typeof permit.deadline, permit.deadline);
      console.log('- intentParams.expiryTime (类型):', typeof intentParams.expiryTime, intentParams.expiryTime);

      // 参数验证
      console.log('🔍 参数验证:');
      console.log('- permit.token === intentParams.token === escrowParams.token:', 
        permit.permitted.token === intentParams.token && intentParams.token === escrowParams.token);
      console.log('- transferDetails.requestedAmount === escrowParams.volume:', 
        transferDetails.requestedAmount === escrowParams.volume);
      console.log('- 调用者地址:', address);
      console.log('- 合约地址:', contractAddress);

      // 模拟合约调用
      console.log('🔄 模拟合约调用...');
      try {
        if (!publicClient) {
          throw new Error('Public client not available');
        }
        
        // 先测试最简单的调用，使用空签名
        console.log('🧪 测试参数准备完成');
        
        await publicClient.simulateContract({
          address: contractAddress as `0x${string}`,
          abi: CONTRACT_ABI,
          functionName: 'takeSellerIntent',
          args: [
            permit, 
            transferDetails, 
            intentParams, 
            escrowParams, 
            permitSignature as `0x${string}`, // 空 permit 签名
            escrowSignature as `0x${string}`  // 空 escrow 签名
          ],
          account: address
        });
        console.log('✅ 模拟调用成功');
      } catch (simError) {
        console.log('❌ 模拟调用失败:', simError);
        const detailedError = decodeContractError(simError, {
          permit,
          transferDetails,
          intentParams,
          escrowParams,
          permitSignature,
          escrowSignature,
          caller: address,
          contractAddress
        });
        console.log('🔍 详细错误信息:', detailedError);
        throw new Error(detailedError);
      }

      console.log('🔄 调用 writeContract...');
      writeContract({
        address: contractAddress as `0x${string}`,
        abi: CONTRACT_ABI,
        functionName: 'takeSellerIntent',
        args: [
          permit, 
          transferDetails, 
          intentParams, 
          escrowParams, 
          permitSignature as `0x${string}`, // 空 permit 签名
          escrowSignature as `0x${string}`  // 空 escrow 签名
        ]
      });
      console.log('✅ writeContract 调用完成');

    } catch (err) {
      console.log('❌ 交易失败:', err);
      
      // 处理不同类型的错误
      let errorMessage = '交易失败';
      
      if (err instanceof Error) {
        if (err.message.includes('Version of JSON-RPC protocol is not supported')) {
          errorMessage = '❌ RPC 连接错误\n\n可能的原因：\n1. 网络连接问题\n2. RPC 端点不可用\n3. 钱包网络配置错误\n\n建议：\n1. 检查网络连接\n2. 确认钱包连接到 Sepolia 测试网\n3. 尝试刷新页面重试';
        } else if (err.message.includes('Unauthorized')) {
          errorMessage = '❌ 认证失败\n\n可能的原因：\n1. RPC 端点需要 API 密钥\n2. 网络配置错误\n3. 钱包权限问题\n\n建议：\n1. 检查 RPC 配置\n2. 确认钱包权限\n3. 尝试重新连接钱包';
        } else if (err.message.includes('insufficient funds')) {
          errorMessage = '❌ 余额不足\n\n请确保账户有足够的 ETH 支付 gas 费用';
        } else {
          errorMessage = `❌ 交易失败: ${err.message}`;
        }
      }
      
      setError(errorMessage);
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <div className="buyer-intent-form">
      <style>{`
        .network-status {
          background: #f5f5f5;
          border: 1px solid #ddd;
          border-radius: 8px;
          padding: 16px;
          margin: 16px 0;
        }
        .network-warning {
          background: #fff3cd;
          border: 1px solid #ffeaa7;
          border-radius: 4px;
          padding: 12px;
          margin-top: 12px;
        }
        .switch-network-btn {
          background: #007bff;
          color: white;
          border: none;
          border-radius: 4px;
          padding: 8px 16px;
          cursor: pointer;
          margin-top: 8px;
        }
        .switch-network-btn:hover {
          background: #0056b3;
        }
        .metamask-info {
          background: #e3f2fd;
          border: 1px solid #2196f3;
          border-radius: 8px;
          padding: 16px;
          margin: 16px 0;
        }
        .network-actions {
          margin-top: 12px;
        }
        .configure-network-btn {
          background: #28a745;
          color: white;
          border: none;
          border-radius: 4px;
          padding: 8px 16px;
          cursor: pointer;
          margin-left: 8px;
        }
        .configure-network-btn:hover {
          background: #218838;
        }
      `}</style>
      <h2>🛒 买家调用 takeSellerIntent</h2>
      <p className="section-description">
        买家使用卖家生成的签名调用 takeSellerIntent 函数
      </p>
      
      <div className="form-group">
        <label>合约地址:</label>
        <input
          type="text"
          value={contractAddress}
          onChange={(e) => setContractAddress(e.target.value)}
          placeholder="输入 MainnetUserTxn 合约地址"
        />
      </div>

      {networkStatus && (
        <div className="network-status">
          <h4>🌐 网络状态</h4>
          <pre>{networkStatus}</pre>
          {!isCorrectNetwork && (
            <div className="network-warning">
              <p>⚠️ 请切换到 Sepolia 测试网</p>
              <button onClick={switchToSepolia} className="switch-network-btn">
                切换到 Sepolia 网络
              </button>
            </div>
          )}
        </div>
      )}

      {metamaskNetworkInfo && (
        <div className="metamask-info">
          <h4>🦊 MetaMask 网络信息</h4>
          <pre>{metamaskNetworkInfo}</pre>
          <div className="network-actions">
            <button onClick={switchToSepolia} className="switch-network-btn">
              切换到 Sepolia 网络
            </button>
            <button onClick={configureSepoliaNetwork} className="configure-network-btn">
              重新配置 Sepolia 网络
            </button>
          </div>
        </div>
      )}

      <div className="section">
        <h3>📋 Permit 参数</h3>
        <div className="form-row">
          <div className="form-group">
            <label>代币地址:</label>
            <input
              type="text"
              value={permitTokenAddress}
              onChange={(e) => setPermitTokenAddress(e.target.value)}
            />
          </div>
          <div className="form-group">
            <label>Token Decimals:</label>
            <input
              type="number"
              min={0}
              max={36}
              value={tokenDecimals}
              onChange={(e) => setTokenDecimals(Number(e.target.value) || 0)}
            />
          </div>
          <div className="form-group">
            <label>数量 (Token 单位):</label>
            <input
              type="number"
              step="0.000001"
              value={permitAmount}
              onChange={(e) => setPermitAmount(e.target.value)}
            />
          </div>
        </div>

        <div className="form-row">
          <div className="form-group">
            <label>Nonce:</label>
            <input
              type="text"
              value={permitNonce}
              onChange={(e) => setPermitNonce(e.target.value)}
            />
          </div>
          <div className="form-group">
            <label>Deadline (Unix 时间戳):</label>
            <input
              type="number"
              value={permitDeadline}
              onChange={(e) => setPermitDeadline(e.target.value)}
              placeholder="从卖家签名生成时获取"
            />
            {permitDeadline && (
              <div className="time-display">
                可读时间: {new Date(parseInt(permitDeadline) * 1000).toLocaleString()}
              </div>
            )}
          </div>
        </div>
      </div>

      <div className="section">
        <h3>📋 TransferDetails 参数</h3>
        <div className="form-row">
          <div className="form-group">
            <label>转账目标地址:</label>
            <input
              type="text"
              value={transferTo}
              onChange={(e) => setTransferTo(e.target.value)}
              placeholder="通常为合约地址"
            />
          </div>
          <div className="form-group">
            <label>请求数量 (Token 单位):</label>
            <input
              type="number"
              step="0.000001"
              value={requestedAmount}
              onChange={(e) => setRequestedAmount(e.target.value)}
            />
          </div>
        </div>
      </div>

      <div className="section">
        <h3>📋 IntentParams 参数</h3>
        <div className="form-row">
          <div className="form-group">
            <label>最小数量 (Token 单位):</label>
            <input
              type="number"
              step="0.000001"
              value={intentMinAmount}
              onChange={(e) => setIntentMinAmount(e.target.value)}
            />
          </div>
          <div className="form-group">
            <label>最大数量 (Token 单位):</label>
            <input
              type="number"
              step="0.000001"
              value={intentMaxAmount}
              onChange={(e) => setIntentMaxAmount(e.target.value)}
            />
          </div>
          <div className="form-group">
            <label>价格 (ETH):</label>
            <input
              type="number"
              step="0.1"
              value={intentPrice}
              onChange={(e) => setIntentPrice(e.target.value)}
            />
          </div>
        </div>

        <div className="form-row">
          <div className="form-group">
            <label>过期时间 (Unix 时间戳):</label>
            <input
              type="number"
              value={intentExpiryTime}
              onChange={(e) => setIntentExpiryTime(e.target.value)}
              placeholder="从卖家签名生成时获取"
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
            <label>数量 (Token 单位):</label>
            <input
              type="number"
              step="0.000001"
              value={escrowVolume}
              onChange={(e) => setEscrowVolume(e.target.value)}
            />
          </div>
          <div className="form-group">
            <label>价格 (ETH):</label>
            <input
              type="number"
              step="0.1"
              value={escrowPrice}
              onChange={(e) => setEscrowPrice(e.target.value)}
            />
          </div>
        </div>

        <div className="form-row">
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
          <div className="form-group">
            <label>买家地址:</label>
            <input
              type="text"
              value={escrowBuyer}
              onChange={(e) => setEscrowBuyer(e.target.value)}
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

        <div className="form-group">
          <label>收款人详情:</label>
          <input
            type="text"
            value={escrowPayeeDetails}
            onChange={(e) => setEscrowPayeeDetails(e.target.value)}
          />
        </div>
      </div>

      <div className="section">
        <h3>🔐 签名</h3>
        <div className="form-group">
          <label>Permit2 签名 (从卖家复制):</label>
          <textarea
            value={permitSignature}
            onChange={(e) => setPermitSignature(e.target.value)}
            placeholder="粘贴卖家生成的 Permit2 签名"
            rows={3}
          />
        </div>

        <div className="form-group">
          <label>EscrowParams 签名 (从卖家复制):</label>
          <textarea
            value={escrowSignature}
            onChange={(e) => setEscrowSignature(e.target.value)}
            placeholder="粘贴卖家生成的 EscrowParams 签名"
            rows={3}
          />
        </div>
      </div>

      <div className="section">
        <h3>🚀 合约调用</h3>
        <button 
          onClick={handleTakeSellerIntent} 
          disabled={isLoading || isPending || !permitSignature || !escrowSignature}
          className="primary-button"
        >
          {isLoading || isPending ? '调用中...' : '调用 takeSellerIntent'}
        </button>
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
    </div>
  );
};

export default BuyerIntentForm;
