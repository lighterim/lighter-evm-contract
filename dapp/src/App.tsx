import React, { useState } from 'react';
import { useAccount, useConnect, useDisconnect } from 'wagmi';
import { injected } from 'wagmi/connectors';
import { WalletConnectButton } from './components/WalletConnectButton';
import { ContractInteraction } from './components/ContractInteraction';
import BuyerInteraction from './components/BuyerInteraction';
import LighterAccountInteraction from './components/LighterAccountInteraction';
import SellerIntentForm from './components/SellerIntentForm';
import BuyerIntentForm from './components/BuyerIntentForm';
import ZkVerifyProofVerifierInteraction from './components/ZkVerifyProofVerifierInteraction';
import './App.css';

function App() {
  const { address, isConnected } = useAccount();
  const { connect } = useConnect();
  const { disconnect } = useDisconnect();
  const [contractAddress, setContractAddress] = useState<string>('');
  const [lighterAccountAddress, setLighterAccountAddress] = useState<string>('');
  const [activeTab, setActiveTab] = useState<'seller' | 'buyer' | 'lighter' | 'sellerIntent' | 'buyerIntent' | 'zkVerify'>('lighter');

  const handleConnectWallet = () => {
    connect({ connector: injected() });
  };

  const handleDisconnectWallet = () => {
    disconnect();
  };

  return (
    <div className="App">
      <header className="App-header">
        <h1>Lighter Platform DApp</h1>
        <p>与 Lighter 智能合约交互的前端应用</p>
        
        <div className="wallet-section">
          {!isConnected ? (
            <WalletConnectButton onConnect={handleConnectWallet} />
          ) : (
            <div className="connected-wallet">
              <div className="wallet-info">
                <p>已连接钱包: {address}</p>
                <button onClick={handleDisconnectWallet} className="disconnect-btn">
                  断开连接
                </button>
              </div>
            </div>
          )}
        </div>

        <div className="contract-section">
          <div className="contract-address-input">
            <label htmlFor="contract-address">合约地址:</label>
            <input
              id="contract-address"
              type="text"
              value={contractAddress}
              onChange={(e) => setContractAddress(e.target.value)}
              placeholder="输入 MainnetUserTxn 合约地址"
              className="address-input"
            />
          </div>

          {isConnected && (
            <div className="tabs">
              <div className="tab-buttons">
                <button 
                  className={`tab-button ${activeTab === 'lighter' ? 'active' : ''}`}
                  onClick={() => setActiveTab('lighter')}
                >
                  🎫 LighterAccount (票券管理)
                </button>
                <button 
                  className={`tab-button ${activeTab === 'seller' ? 'active' : ''}`}
                  onClick={() => setActiveTab('seller')}
                >
                  🏪 卖家业务 (_bulkSell)
                </button>
                <button 
                  className={`tab-button ${activeTab === 'buyer' ? 'active' : ''}`}
                  onClick={() => setActiveTab('buyer')}
                >
                  🛒 买家业务 (_takeBulkSellIntent, paid)
                </button>
                <button 
                  className={`tab-button ${activeTab === 'sellerIntent' ? 'active' : ''}`}
                  onClick={() => setActiveTab('sellerIntent')}
                >
                  🔄 卖家签名生成 (takeSellerIntent)
                </button>
                <button 
                  className={`tab-button ${activeTab === 'buyerIntent' ? 'active' : ''}`}
                  onClick={() => setActiveTab('buyerIntent')}
                >
                  🛒 买家调用 (takeSellerIntent)
                </button>
                <button 
                  className={`tab-button ${activeTab === 'zkVerify' ? 'active' : ''}`}
                  onClick={() => setActiveTab('zkVerify')}
                >
                  🧩 ZK 验证释放 (releaseAfterProofVerify)
                </button>
              </div>
              
              <div className="tab-content">
                {activeTab === 'lighter' && (
                  <div>
                    <div className="contract-address-input" style={{marginBottom: '20px'}}>
                      <label htmlFor="lighter-account-address">LighterAccount 合约地址:</label>
                      <input
                        id="lighter-account-address"
                        type="text"
                        value={lighterAccountAddress}
                        onChange={(e) => setLighterAccountAddress(e.target.value)}
                        placeholder="输入 LighterAccount 合约地址"
                        className="address-input"
                      />
                    </div>
                    {lighterAccountAddress && (
                      <LighterAccountInteraction contractAddress={lighterAccountAddress} />
                    )}
                  </div>
                )}
                {activeTab === 'seller' && contractAddress && (
                  <ContractInteraction 
                    contractAddress={contractAddress} 
                    userAddress={address!} 
                  />
                )}
                {activeTab === 'buyer' && (
                  <BuyerInteraction />
                )}
                {activeTab === 'sellerIntent' && contractAddress && (
                  <SellerIntentForm />
                )}
                {activeTab === 'buyerIntent' && (
                  <BuyerIntentForm />
                )}
                {activeTab === 'zkVerify' && (
                  <ZkVerifyProofVerifierInteraction />
                )}
              </div>
            </div>
          )}
        </div>
      </header>
    </div>
  );
}

export default App;
