import React, { useState, useEffect } from 'react';
import { useWriteContract, useWaitForTransactionReceipt, useReadContract, useAccount } from 'wagmi';
import { parseEther, formatEther, Address } from 'viem';
import LighterAccountABI from '../abis/LighterAccount.json';
import './LighterAccountInteraction.css';

interface LighterAccountInteractionProps {
  contractAddress: string;
}

export const LighterAccountInteraction: React.FC<LighterAccountInteractionProps> = ({ contractAddress }) => {
  const { address: userAddress } = useAccount();
  const { writeContract, data: hash, isPending, error } = useWriteContract();
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });

  // 表单状态
  const [activeFunction, setActiveFunction] = useState<'create' | 'destroy' | 'upgrade'>('create');
  
  // createAccount 参数
  const [recipient, setRecipient] = useState<string>('');
  const [nostrPubKey, setNostrPubKey] = useState<string>('');
  const [rentAmount, setRentAmount] = useState<string>('0.01');
  
  // destroyAccount 参数
  const [tokenIdToDestroy, setTokenIdToDestroy] = useState<string>('');
  const [refundRecipient, setRefundRecipient] = useState<string>('');
  
  // upgradeQuota 参数
  const [tokenIdToUpgrade, setTokenIdToUpgrade] = useState<string>('');
  const [upgradeAmount, setUpgradeAmount] = useState<string>('0.01');

  // 读取合约状态
  const { data: rentPrice } = useReadContract({
    address: contractAddress as Address,
    abi: LighterAccountABI,
    functionName: 'rentPrice',
  });

  const { data: totalRented } = useReadContract({
    address: contractAddress as Address,
    abi: LighterAccountABI,
    functionName: 'totalRented',
  });

  const { data: contractBalance } = useReadContract({
    address: contractAddress as Address,
    abi: LighterAccountABI,
    functionName: 'getBalance',
  });

  // 自动填充当前用户地址
  useEffect(() => {
    if (userAddress && !recipient) {
      setRecipient(userAddress);
    }
    if (userAddress && !refundRecipient) {
      setRefundRecipient(userAddress);
    }
  }, [userAddress, recipient, refundRecipient]);

  // 处理成功
  useEffect(() => {
    if (isSuccess) {
      alert(`✅ 交易成功！\nHash: ${hash}`);
      // 清空表单
      if (activeFunction === 'create') {
        setNostrPubKey('');
      } else if (activeFunction === 'destroy') {
        setTokenIdToDestroy('');
      } else if (activeFunction === 'upgrade') {
        setTokenIdToUpgrade('');
      }
    }
  }, [isSuccess, hash, activeFunction]);

  // createAccount - 创建账户
  const handleCreateAccount = async () => {
    if (!recipient || !nostrPubKey) {
      alert('❌ 请填写所有必需字段');
      return;
    }

    try {
      // 将 hex string 转换为 bytes32
      const pubKeyBytes32 = nostrPubKey.startsWith('0x') ? nostrPubKey : `0x${nostrPubKey}`;
      
      if (pubKeyBytes32.length !== 66) {
        alert('❌ Nostr 公钥必须是 64 个十六进制字符（32 字节）');
        return;
      }

      writeContract({
        address: contractAddress as Address,
        abi: LighterAccountABI,
        functionName: 'createAccount',
        args: [recipient as Address, pubKeyBytes32],
        value: parseEther(rentAmount),
      });
    } catch (err: any) {
      alert(`❌ 错误: ${err.message}`);
    }
  };

  // destroyAccount - 销毁账户
  const handleDestroyAccount = async () => {
    if (!tokenIdToDestroy || !refundRecipient) {
      alert('❌ 请填写所有必需字段');
      return;
    }

    try {
      writeContract({
        address: contractAddress as Address,
        abi: LighterAccountABI,
        functionName: 'destroyAccount',
        args: [BigInt(tokenIdToDestroy), refundRecipient as Address],
      });
    } catch (err: any) {
      alert(`❌ 错误: ${err.message}`);
    }
  };

  // upgradeQuota - 升级配额
  const handleUpgradeQuota = async () => {
    if (!tokenIdToUpgrade) {
      alert('❌ 请填写 Token ID');
      return;
    }

    try {
      writeContract({
        address: contractAddress as Address,
        abi: LighterAccountABI,
        functionName: 'upgradeQuota',
        args: [BigInt(tokenIdToUpgrade)],
        value: parseEther(upgradeAmount),
      });
    } catch (err: any) {
      alert(`❌ 错误: ${err.message}`);
    }
  };

  return (
    <div className="lighter-account-interaction">
      <h2>🎫 LighterAccount 交互</h2>
      
      {/* 合约信息 */}
      <div className="contract-info">
        <h3>📊 合约状态</h3>
        <div className="info-grid">
          <div className="info-item">
            <span className="label">租借价格:</span>
            <span className="value">
              {rentPrice ? formatEther(rentPrice as bigint) : '...'} ETH
            </span>
          </div>
          <div className="info-item">
            <span className="label">总租借数:</span>
            <span className="value">{totalRented?.toString() || '0'}</span>
          </div>
          <div className="info-item">
            <span className="label">合约余额:</span>
            <span className="value">
              {contractBalance ? formatEther(contractBalance as bigint) : '0'} ETH
            </span>
          </div>
          <div className="info-item">
            <span className="label">合约地址:</span>
            <span className="value address">{contractAddress}</span>
          </div>
        </div>
      </div>

      {/* 功能选择 */}
      <div className="function-tabs">
        <button
          className={`tab-btn ${activeFunction === 'create' ? 'active' : ''}`}
          onClick={() => setActiveFunction('create')}
        >
          🎫 创建账户
        </button>
        <button
          className={`tab-btn ${activeFunction === 'destroy' ? 'active' : ''}`}
          onClick={() => setActiveFunction('destroy')}
        >
          🗑️ 销毁账户
        </button>
        <button
          className={`tab-btn ${activeFunction === 'upgrade' ? 'active' : ''}`}
          onClick={() => setActiveFunction('upgrade')}
        >
          ⬆️ 升级配额
        </button>
      </div>

      {/* 功能面板 */}
      <div className="function-panel">
        {/* createAccount */}
        {activeFunction === 'create' && (
          <div className="function-content">
            <h3>🎫 创建账户（租借票券 + 创建 TBA）</h3>
            <p className="description">
              租借一个票券 NFT 并自动创建对应的 Token Bound Account (TBA)
            </p>
            
            <div className="form-group">
              <label>接收者地址:</label>
              <input
                type="text"
                value={recipient}
                onChange={(e) => setRecipient(e.target.value)}
                placeholder="0x..."
                className="input-field"
              />
            </div>

            <div className="form-group">
              <label>Nostr 公钥 (32 bytes hex):</label>
              <input
                type="text"
                value={nostrPubKey}
                onChange={(e) => setNostrPubKey(e.target.value)}
                placeholder="0x1234... (64 个十六进制字符)"
                className="input-field"
              />
              <small className="hint">
                示例: 0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef
              </small>
            </div>

            <div className="form-group">
              <label>支付金额 (ETH):</label>
              <input
                type="text"
                value={rentAmount}
                onChange={(e) => setRentAmount(e.target.value)}
                placeholder="0.01"
                className="input-field"
              />
              <small className="hint">
                当前租借价格: {rentPrice ? formatEther(rentPrice as bigint) : '...'} ETH
              </small>
            </div>

            <button
              onClick={handleCreateAccount}
              disabled={isPending || isConfirming}
              className="action-btn primary"
            >
              {isPending ? '⏳ 确认中...' : isConfirming ? '⏳ 处理中...' : '🎫 创建账户'}
            </button>
          </div>
        )}

        {/* destroyAccount */}
        {activeFunction === 'destroy' && (
          <div className="function-content">
            <h3>🗑️ 销毁账户（退还租金）</h3>
            <p className="description">
              销毁票券并将租金退还给指定地址。只能由 TBA 自己调用。
            </p>
            
            <div className="form-group">
              <label>Token ID:</label>
              <input
                type="text"
                value={tokenIdToDestroy}
                onChange={(e) => setTokenIdToDestroy(e.target.value)}
                placeholder="1"
                className="input-field"
              />
            </div>

            <div className="form-group">
              <label>退款接收地址:</label>
              <input
                type="text"
                value={refundRecipient}
                onChange={(e) => setRefundRecipient(e.target.value)}
                placeholder="0x..."
                className="input-field"
              />
            </div>

            <div className="warning-box">
              ⚠️ 注意：此操作只能由 TBA (Token Bound Account) 调用，并且会销毁票券。
            </div>

            <button
              onClick={handleDestroyAccount}
              disabled={isPending || isConfirming}
              className="action-btn danger"
            >
              {isPending ? '⏳ 确认中...' : isConfirming ? '⏳ 处理中...' : '🗑️ 销毁账户'}
            </button>
          </div>
        )}

        {/* upgradeQuota */}
        {activeFunction === 'upgrade' && (
          <div className="function-content">
            <h3>⬆️ 升级配额</h3>
            <p className="description">
              为已有的票券账户增加配额（通过支付租金）
            </p>
            
            <div className="form-group">
              <label>Token ID:</label>
              <input
                type="text"
                value={tokenIdToUpgrade}
                onChange={(e) => setTokenIdToUpgrade(e.target.value)}
                placeholder="1"
                className="input-field"
              />
            </div>

            <div className="form-group">
              <label>支付金额 (ETH):</label>
              <input
                type="text"
                value={upgradeAmount}
                onChange={(e) => setUpgradeAmount(e.target.value)}
                placeholder="0.01"
                className="input-field"
              />
              <small className="hint">
                租借价格: {rentPrice ? formatEther(rentPrice as bigint) : '...'} ETH / 配额
              </small>
            </div>

            <button
              onClick={handleUpgradeQuota}
              disabled={isPending || isConfirming}
              className="action-btn primary"
            >
              {isPending ? '⏳ 确认中...' : isConfirming ? '⏳ 处理中...' : '⬆️ 升级配额'}
            </button>
          </div>
        )}
      </div>

      {/* 交易状态 */}
      {(isPending || isConfirming || isSuccess) && (
        <div className="transaction-status">
          {isPending && <p className="status pending">⏳ 等待钱包确认...</p>}
          {isConfirming && <p className="status confirming">⏳ 交易处理中...</p>}
          {isSuccess && (
            <div className="status success">
              <p>✅ 交易成功！</p>
              <p className="tx-hash">
                交易哈希: <code>{hash}</code>
              </p>
            </div>
          )}
        </div>
      )}

      {/* 错误显示 */}
      {error && (
        <div className="error-box">
          ❌ 错误: {error.message}
        </div>
      )}

      {/* 使用说明 */}
      <div className="usage-guide">
        <h3>📖 使用说明</h3>
        <div className="guide-section">
          <h4>🎫 创建账户</h4>
          <ol>
            <li>填写接收者地址（默认为当前连接的钱包）</li>
            <li>填写 Nostr 公钥（32 字节十六进制）</li>
            <li>支付租借费用（至少等于 rentPrice）</li>
            <li>点击"创建账户"按钮</li>
            <li>确认交易后，将 mint 一个 NFT 并创建对应的 TBA</li>
          </ol>
        </div>

        <div className="guide-section">
          <h4>🗑️ 销毁账户</h4>
          <ol>
            <li>填写要销毁的 Token ID</li>
            <li>填写退款接收地址</li>
            <li>⚠️ 此操作必须从 TBA 调用（需要特殊设置）</li>
            <li>成功后将退还租金</li>
          </ol>
        </div>

        <div className="guide-section">
          <h4>⬆️ 升级配额</h4>
          <ol>
            <li>填写要升级的 Token ID</li>
            <li>支付额外的租金</li>
            <li>点击"升级配额"按钮</li>
            <li>支付的金额会增加该账户的配额</li>
          </ol>
        </div>
      </div>
    </div>
  );
};

export default LighterAccountInteraction;

