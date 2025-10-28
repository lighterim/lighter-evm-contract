import React, { useState, useEffect } from 'react';
import { useAccount, usePublicClient, useWalletClient } from 'wagmi';
import { parseUnits, parseEther } from 'viem';
import { SignatureTransfer } from '@uniswap/permit2-sdk';

// Permit2 地址
const PERMIT2_ADDRESS = '0x000000000022D473030F116dDEE9F6B43aC78BA3';

const SellerIntentForm: React.FC = () => {
  const { address } = useAccount();
  const publicClient = usePublicClient();
  const { data: walletClient } = useWalletClient();

  // 合约地址状态
  const [contractAddress, setContractAddress] = useState<string>('');

  // IntentParams 参数状态
  const [tokenAddress, setTokenAddress] = useState<string>('0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238');
  const [tokenDecimals, setTokenDecimals] = useState<number>(6);
  const [amount, setAmount] = useState<string>('1');
  const [nonce, setNonce] = useState<string>('1347343934330334');
  const [deadline, setDeadline] = useState<string>('');
  const [minAmount, setMinAmount] = useState<string>('1');
  const [maxAmount, setMaxAmount] = useState<string>('1');
  const [price, setPrice] = useState<string>('1');
  const [currency, setCurrency] = useState<string>('0xc4ae21aac0c6549d71dd96035b7e0bdb6c79ebdba8891b666115bc976d16a29e');
  const [paymentMethod, setPaymentMethod] = useState<string>('0xa87f59463aa7edfb0cc3cc39e28ba98c83fda1a3b5c6c9d10219c02669eb8a19');
  const [payeeDetails, setPayeeDetails] = useState<string>('0x157a30e0353a95e0152bb1cf546ffbc81ae0983338d4f84307fb58604e42367e');

  // EscrowParams 参数状态
  const [escrowId, setEscrowId] = useState<string>('1');
  const [escrowVolume, setEscrowVolume] = useState<string>('1');
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

  // 全局时间戳管理
  const [globalExpiryTime] = useState<number>(0);
  const [globalDeadline, setGlobalDeadline] = useState<number>(0);

  // 设置默认值
  useEffect(() => {
    if (address) {
      setEscrowSeller(address);
    }
  }, [address]);

  // 生成 Permit2 签名 (使用 SignatureTransfer)
  const generatePermitSignature = async () => {
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

      // 生成过期时间
      // const deadlineTime = Math.floor(Date.now() / 1000) + 3600000; // 1000小时后过期
      // setGlobalDeadline(deadlineTime);

      // 构造 IntentParams
      const intentParams = {
        token: tokenAddress as `0x${string}`,
        range: {
          min: parseUnits(minAmount, tokenDecimals),
          max: parseUnits(maxAmount, tokenDecimals)
        },
        expiryTime: BigInt(globalDeadline),
        currency: currency as `0x${string}`,
        paymentMethod: paymentMethod as `0x${string}`,
        payeeDetails: payeeDetails as `0x${string}`,
        price: parseEther(price)
      };

      // 构造 witness
      const witness = {
        witnessTypeName: 'IntentParams',
        witnessType: {
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
        },
        witness: intentParams
      };

      // 构造 permitData
      const permitData = {
        permitted: {
          token: tokenAddress,
          amount: parseUnits(amount, tokenDecimals).toString()
        },
        spender: contractAddress,
        nonce: BigInt(nonce),
        deadline: globalDeadline
      };

      // 使用 SignatureTransfer.getPermitData
      const { domain: sdkDomain, types, values } = SignatureTransfer.getPermitData(permitData, PERMIT2_ADDRESS, chainId, witness);

      // 转换 domain 格式以兼容 viem
      const domain = {
        name: sdkDomain.name,
        version: sdkDomain.version,
        chainId: Number(sdkDomain.chainId),
        verifyingContract: sdkDomain.verifyingContract as `0x${string}`
      };
      console.log('domain', domain);
      console.log('types', types);
      console.log('values', values);

      // 生成签名
      const signature = await walletClient.signTypedData({
        account: address,
        domain,
        types,
        primaryType: 'PermitWitnessTransferFrom',
        message: values as unknown as Record<string, unknown>
      });

      setPermitSignature(signature);
      setResult(`✅ Permit2 签名生成成功！\n\n签名: ${signature}\n\n📋 签名参数:\n- 签名者: ${address}\n- 代币: ${tokenAddress}\n- Token Decimals: ${tokenDecimals}\n- 数量: ${amount} Token 单位\n- 过期时间: ${new Date(globalDeadline * 1000).toLocaleString()}\n- Nonce: ${nonce}\n- IntentParams 已包含在 witness 中`);

    } catch (err) {
      setError(err instanceof Error ? err.message : '签名生成失败');
    } finally {
      setIsLoading(false);
    }
  };

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
        token: tokenAddress as `0x${string}`,
        volume: parseUnits(escrowVolume, tokenDecimals),
        price: parseEther(escrowPrice),
        usdRate: parseEther(escrowUsdRate),
        payer: escrowSeller as `0x${string}`, // payer 等于 seller
        seller: escrowSeller as `0x${string}`,
        sellerFeeRate: BigInt(escrowSellerFeeRate),
        paymentMethod: escrowPaymentMethod as `0x${string}`,
        currency: escrowCurrency as `0x${string}`,
        payeeDetails: escrowPayeeDetails as `0x${string}`,
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
          { name: 'payer', type: 'address' },
          { name: 'seller', type: 'address' },
          { name: 'sellerFeeRate', type: 'uint256' },
          { name: 'paymentMethod', type: 'bytes32' },
          { name: 'currency', type: 'bytes32' },
          { name: 'payeeDetails', type: 'bytes32' },
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
      setResult(`✅ EscrowParams 签名生成成功！\n\n签名: ${signature}\n\n📋 签名参数:\n- 签名者: ${address}\n- Escrow ID: ${escrowId}\n- 代币: ${tokenAddress}\n- 数量: ${escrowVolume} Token 单位\n- 价格: ${escrowPrice} ETH\n- 卖家: ${escrowSeller}\n- 买家: ${escrowBuyer}`);

    } catch (err) {
      setError(err instanceof Error ? err.message : '签名生成失败');
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <div className="seller-intent-form">
      <h2>🔄 卖家签名生成</h2>
      <p className="section-description">
        卖家需要生成 Permit2 签名和 EscrowParams 签名，供买家调用 takeSellerIntent 时使用
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

      <div className="section">
        <h3>📋 IntentParams 参数</h3>
        <div className="form-row">
          <div className="form-group">
            <label>代币地址:</label>
            <input
              type="text"
              value={tokenAddress}
              onChange={(e) => setTokenAddress(e.target.value)}
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
              value={amount}
              onChange={(e) => setAmount(e.target.value)}
            />
          </div>
        </div>

        <div className="form-row">
          <div className="form-group">
            <label>Nonce:</label>
            <input
              type="text"
              value={nonce}
              onChange={(e) => setNonce(e.target.value)}
            />
          </div>
          <div className="form-group">
            <label>Deadline (Unix 时间戳):</label>
            <input
              type="number"
              value={globalDeadline}
              onChange={(e) => setGlobalDeadline(Number(e.target.value))}
              placeholder="留空自动生成 (当前时间+1小时)"
            />
            {globalDeadline && (
              <div className="time-display">
                可读时间: {new Date(globalDeadline * 1000).toLocaleString()}
              </div>
            )}
          </div>
        </div>

        <div className="form-row">
          <div className="form-group">
            <label>最小数量 (Token 单位):</label>
            <input
              type="number"
              step="0.000001"
              value={minAmount}
              onChange={(e) => setMinAmount(e.target.value)}
            />
          </div>
          <div className="form-group">
            <label>最大数量 (Token 单位):</label>
            <input
              type="number"
              step="0.000001"
              value={maxAmount}
              onChange={(e) => setMaxAmount(e.target.value)}
            />
          </div>
          <div className="form-group">
            <label>价格 (ETH):</label>
            <input
              type="number"
              step="0.1"
              value={price}
              onChange={(e) => setPrice(e.target.value)}
            />
          </div>
        </div>

        <div className="form-row">
          <div className="form-group">
            <label>货币:</label>
            <input
              type="text"
              value={currency}
              onChange={(e) => setCurrency(e.target.value)}
            />
          </div>
          <div className="form-group">
            <label>支付方式:</label>
            <input
              type="text"
              value={paymentMethod}
              onChange={(e) => setPaymentMethod(e.target.value)}
            />
          </div>
        </div>

        <div className="form-group">
          <label>收款人详情:</label>
          <input
            type="text"
            value={payeeDetails}
            onChange={(e) => setPayeeDetails(e.target.value)}
          />
        </div>

        <button onClick={generatePermitSignature} disabled={isLoading}>
          {isLoading ? '生成中...' : '生成 Permit2 签名'}
        </button>

        {permitSignature && (
          <div className="signature-display">
            <label>Permit2 签名:</label>
            <textarea value={permitSignature} readOnly />
          </div>
        )}
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

export default SellerIntentForm;
