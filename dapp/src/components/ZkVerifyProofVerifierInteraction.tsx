import React, { useEffect, useMemo, useState } from 'react';
import { useAccount, usePublicClient, useWriteContract } from 'wagmi';
import { parseEther, parseUnits } from 'viem';

// Minimal ABI for ZkVerifyProofVerifier.releaseAfterProofVerify
const ZK_VERIFY_PROOF_VERIFIER_ABI = [
  {
    type: 'function',
    name: 'releaseAfterProofVerify',
    stateMutability: 'nonpayable',
    inputs: [
      {
        name: 'escrowParams',
        type: 'tuple',
        components: [
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
          { name: 'buyerFeeRate', type: 'uint256' },
        ],
      },
      {
        name: 'payment',
        type: 'tuple',
        components: [
          { name: 'paymentId', type: 'bytes32' },
          { name: 'method', type: 'bytes32' },
          { name: 'currency', type: 'bytes32' },
          { name: 'payeeDetails', type: 'bytes32' },
          { name: 'amount', type: 'uint256' },
        ],
      },
      {
        name: 'zkProof',
        type: 'tuple',
        components: [
          { name: 'domainId', type: 'uint256' },
          { name: 'aggregationId', type: 'uint256' },
          { name: 'index', type: 'uint256' },
          { name: 'leaf', type: 'bytes32' },
          { name: 'leafCount', type: 'uint256' },
          { name: 'merklePath', type: 'bytes32[]' },
        ],
      },
      { name: 'sig', type: 'bytes' },
    ],
    outputs: [{ name: '', type: 'bool' }],
  },
] as const;

const ZkVerifyProofVerifierInteraction: React.FC = () => {
  const { address, isConnected } = useAccount();
  const publicClient = usePublicClient();
  const { writeContract, data: txHash, isPending, error: writeError } = useWriteContract();

  // Contract address
  const [contractAddress, setContractAddress] = useState<string>('');

  // Token decimals for parsing human-readable amounts
  const [tokenDecimals, setTokenDecimals] = useState<number>(6);

  // EscrowParams (reuse defaults similar to BuyerIntentForm)
  const [escrowId, setEscrowId] = useState<string>('1');
  const [escrowToken, setEscrowToken] = useState<string>('0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238');
  const [escrowVolume, setEscrowVolume] = useState<string>('1.5');
  const [escrowPrice, setEscrowPrice] = useState<string>('1');
  const [escrowUsdRate, setEscrowUsdRate] = useState<string>('1');
  const [escrowPayer, setEscrowPayer] = useState<string>('');
  const [escrowSeller, setEscrowSeller] = useState<string>('');
  const [escrowSellerFeeRate, setEscrowSellerFeeRate] = useState<string>('0');
  const [escrowPaymentMethod, setEscrowPaymentMethod] = useState<string>('0xa87f59463aa7edfb0cc3cc39e28ba98c83fda1a3b5c6c9d10219c02669eb8a19');
  const [escrowCurrency, setEscrowCurrency] = useState<string>('0xc4ae21aac0c6549d71dd96035b7e0bdb6c79ebdba8891b666115bc976d16a29e');
  const [escrowPayeeDetails, setEscrowPayeeDetails] = useState<string>('0x157a30e0353a95e0152bb1cf546ffbc81ae0983338d4f84307fb58604e42367e');
  const [escrowBuyer, setEscrowBuyer] = useState<string>('');
  const [escrowBuyerFeeRate, setEscrowBuyerFeeRate] = useState<string>('0');

  // PaymentDetails
  const [paymentId, setPaymentId] = useState<string>('0x');
  const [paymentMethod, setPaymentMethod] = useState<string>('0xa87f59463aa7edfb0cc3cc39e28ba98c83fda1a3b5c6c9d10219c02669eb8a19');
  const [paymentCurrency, setPaymentCurrency] = useState<string>('0xc4ae21aac0c6549d71dd96035b7e0bdb6c79ebdba8891b666115bc976d16a29e');
  const [paymentPayeeDetails, setPaymentPayeeDetails] = useState<string>('0x157a30e0353a95e0152bb1cf546ffbc81ae0983338d4f84307fb58604e42367e');
  const [paymentAmount, setPaymentAmount] = useState<string>('1.5');

  // Proof
  const [domainId, setDomainId] = useState<string>('');
  const [aggregationId, setAggregationId] = useState<string>('');
  const [index, setIndex] = useState<string>('');
  const [leaf, setLeaf] = useState<string>('0x');
  const [leafCount, setLeafCount] = useState<string>('');
  const [merklePathRaw, setMerklePathRaw] = useState<string>('');

  // Seller/UserTxn signature over EscrowParams
  const [escrowSig, setEscrowSig] = useState<string>('');

  // UI state
  const [result, setResult] = useState<string>('');
  const [error, setError] = useState<string>('');

  useEffect(() => {
    if (address) {
      setEscrowBuyer(address);
      setEscrowPayer(address);
    }
  }, [address]);

  const merklePathArray = useMemo(() => {
    return merklePathRaw
      .split(',')
      .map((s) => s.trim())
      .filter((s) => s.length > 0) as `0x${string}`[];
  }, [merklePathRaw]);

  const buildArgs = () => {
    const escrowParams = {
      id: BigInt(escrowId || '0'),
      token: escrowToken as `0x${string}`,
      volume: parseUnits(escrowVolume || '0', tokenDecimals),
      price: parseEther(escrowPrice || '0'),
      usdRate: parseEther(escrowUsdRate || '0'),
      payer: (escrowPayer || address || '0x0000000000000000000000000000000000000000') as `0x${string}`,
      seller: (escrowSeller || '0x0000000000000000000000000000000000000000') as `0x${string}`,
      sellerFeeRate: BigInt(escrowSellerFeeRate || '0'),
      paymentMethod: escrowPaymentMethod as `0x${string}`,
      currency: escrowCurrency as `0x${string}`,
      payeeDetails: escrowPayeeDetails as `0x${string}`,
      buyer: (escrowBuyer || address || '0x0000000000000000000000000000000000000000') as `0x${string}`,
      buyerFeeRate: BigInt(escrowBuyerFeeRate || '0'),
    };

    const payment = {
      paymentId: (paymentId && paymentId !== '0x' ? paymentId : '0x0000000000000000000000000000000000000000000000000000000000000000') as `0x${string}`,
      method: paymentMethod as `0x${string}`,
      currency: paymentCurrency as `0x${string}`,
      payeeDetails: paymentPayeeDetails as `0x${string}`,
      amount: parseUnits(paymentAmount || '0', tokenDecimals),
    };

    const zkProof = {
      domainId: BigInt(domainId || '0'),
      aggregationId: BigInt(aggregationId || '0'),
      index: BigInt(index || '0'),
      leaf: (leaf && leaf !== '0x' ? leaf : '0x0000000000000000000000000000000000000000000000000000000000000000') as `0x${string}`,
      leafCount: BigInt(leafCount || '0'),
      merklePath: merklePathArray,
    };

    const sig = (escrowSig || '0x') as `0x${string}`;

    return { escrowParams, payment, zkProof, sig };
  };

  const handleCall = async () => {
    setError('');
    setResult('');

    if (!isConnected || !address) {
      setError('请先连接钱包');
      return;
    }
    if (!contractAddress) {
      setError('请输入 ZkVerifyProofVerifier 合约地址');
      return;
    }
    if (!publicClient) {
      setError('网络客户端未初始化');
      return;
    }

    const { escrowParams, payment, zkProof, sig } = buildArgs();

    try {
      // Simulate
      await publicClient.simulateContract({
        address: contractAddress as `0x${string}`,
        abi: ZK_VERIFY_PROOF_VERIFIER_ABI,
        functionName: 'releaseAfterProofVerify',
        args: [escrowParams, payment, zkProof, sig],
        account: address,
      });

      // Write
      writeContract({
        address: contractAddress as `0x${string}`,
        abi: ZK_VERIFY_PROOF_VERIFIER_ABI,
        functionName: 'releaseAfterProofVerify',
        args: [escrowParams, payment, zkProof, sig],
      });
    } catch (e: any) {
      setError(e?.message || String(e));
    }
  };

  useEffect(() => {
    if (txHash) {
      setResult(`交易已提交: ${txHash}`);
    }
    if (writeError) {
      setError(writeError.message);
    }
  }, [txHash, writeError]);

  return (
    <div>
      <h2>🧩 ZkVerifyProofVerifier 调用</h2>
      <p>调用 releaseAfterProofVerify 进行零知识证明后的释放。注意: 必须由买家地址调用。</p>

      <div className="form-group">
        <label>合约地址:</label>
        <input value={contractAddress} onChange={(e) => setContractAddress(e.target.value)} placeholder="输入 ZkVerifyProofVerifier 合约地址" />
      </div>

      <div className="form-row">
        <div className="form-group">
          <label>Token Decimals</label>
          <input type="number" value={tokenDecimals} onChange={(e) => setTokenDecimals(Number(e.target.value) || 0)} />
        </div>
      </div>

      <h3>🏦 EscrowParams</h3>
      <div className="form-row">
        <div className="form-group"><label>id</label><input type="number" value={escrowId} onChange={(e)=>setEscrowId(e.target.value)} /></div>
        <div className="form-group"><label>token</label><input value={escrowToken} onChange={(e)=>setEscrowToken(e.target.value)} /></div>
        <div className="form-group"><label>volume (token)</label><input type="number" step="0.000001" value={escrowVolume} onChange={(e)=>setEscrowVolume(e.target.value)} /></div>
      </div>
      <div className="form-row">
        <div className="form-group"><label>price (ETH)</label><input type="number" step="0.000001" value={escrowPrice} onChange={(e)=>setEscrowPrice(e.target.value)} /></div>
        <div className="form-group"><label>usdRate</label><input type="number" step="0.000001" value={escrowUsdRate} onChange={(e)=>setEscrowUsdRate(e.target.value)} /></div>
        <div className="form-group"><label>seller</label><input value={escrowSeller} onChange={(e)=>setEscrowSeller(e.target.value)} /></div>
      </div>
      <div className="form-row">
        <div className="form-group"><label>payer</label><input value={escrowPayer} onChange={(e)=>setEscrowPayer(e.target.value)} /></div>
        <div className="form-group"><label>buyer</label><input value={escrowBuyer} onChange={(e)=>setEscrowBuyer(e.target.value)} /></div>
        <div className="form-group"><label>sellerFeeRate (wei)</label><input type="number" value={escrowSellerFeeRate} onChange={(e)=>setEscrowSellerFeeRate(e.target.value)} /></div>
      </div>
      <div className="form-row">
        <div className="form-group"><label>buyerFeeRate (wei)</label><input type="number" value={escrowBuyerFeeRate} onChange={(e)=>setEscrowBuyerFeeRate(e.target.value)} /></div>
        <div className="form-group"><label>paymentMethod (bytes32)</label><input value={escrowPaymentMethod} onChange={(e)=>setEscrowPaymentMethod(e.target.value)} /></div>
        <div className="form-group"><label>currency (bytes32)</label><input value={escrowCurrency} onChange={(e)=>setEscrowCurrency(e.target.value)} /></div>
      </div>
      <div className="form-row">
        <div className="form-group" style={{flex: 1}}><label>payeeDetails (bytes32)</label><input value={escrowPayeeDetails} onChange={(e)=>setEscrowPayeeDetails(e.target.value)} /></div>
      </div>

      <h3>💳 PaymentDetails</h3>
      <div className="form-row">
        <div className="form-group"><label>paymentId (bytes32)</label><input value={paymentId} onChange={(e)=>setPaymentId(e.target.value)} placeholder="0x..." /></div>
        <div className="form-group"><label>method (bytes32)</label><input value={paymentMethod} onChange={(e)=>setPaymentMethod(e.target.value)} /></div>
        <div className="form-group"><label>currency (bytes32)</label><input value={paymentCurrency} onChange={(e)=>setPaymentCurrency(e.target.value)} /></div>
      </div>
      <div className="form-row">
        <div className="form-group" style={{flex: 1}}><label>payeeDetails (bytes32)</label><input value={paymentPayeeDetails} onChange={(e)=>setPaymentPayeeDetails(e.target.value)} /></div>
        <div className="form-group"><label>amount (token)</label><input type="number" step="0.000001" value={paymentAmount} onChange={(e)=>setPaymentAmount(e.target.value)} /></div>
      </div>

      <h3>🧾 ZkProof</h3>
      <div className="form-row">
        <div className="form-group"><label>domainId</label><input type="number" value={domainId} onChange={(e)=>setDomainId(e.target.value)} /></div>
        <div className="form-group"><label>aggregationId</label><input type="number" value={aggregationId} onChange={(e)=>setAggregationId(e.target.value)} /></div>
        <div className="form-group"><label>index</label><input type="number" value={index} onChange={(e)=>setIndex(e.target.value)} /></div>
      </div>
      <div className="form-row">
        <div className="form-group"><label>leaf (bytes32)</label><input value={leaf} onChange={(e)=>setLeaf(e.target.value)} placeholder="0x..." /></div>
        <div className="form-group"><label>leafCount</label><input type="number" value={leafCount} onChange={(e)=>setLeafCount(e.target.value)} /></div>
      </div>
      <div className="form-group">
        <label>merklePath (bytes32[], 用逗号分隔)</label>
        <input value={merklePathRaw} onChange={(e)=>setMerklePathRaw(e.target.value)} placeholder="0xaaa..., 0xbbb..." />
      </div>

      <h3>🔐 EscrowParams 签名</h3>
      <div className="form-group">
        <label>签名 (bytes)</label>
        <textarea rows={3} value={escrowSig} onChange={(e)=>setEscrowSig(e.target.value)} placeholder="0x..." />
      </div>

      <div className="section">
        <button className="primary-button" disabled={!isConnected || isPending} onClick={handleCall}>
          {isPending ? '调用中...' : '调用 releaseAfterProofVerify'}
        </button>
      </div>

      {result && (
        <div className="result"><pre>{result}</pre></div>
      )}
      {error && (
        <div className="error"><pre>{error}</pre></div>
      )}
    </div>
  );
};

export default ZkVerifyProofVerifierInteraction;


