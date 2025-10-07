import React, { useState } from 'react';
import { useAccount, useConnect, useDisconnect } from 'wagmi';
import { injected } from 'wagmi/connectors';
import { WalletConnectButton } from './components/WalletConnectButton';
import { ContractInteraction } from './components/ContractInteraction';
import BuyerInteraction from './components/BuyerInteraction';
import './App.css';

function App() {
  const { address, isConnected } = useAccount();
  const { connect } = useConnect();
  const { disconnect } = useDisconnect();
  const [contractAddress, setContractAddress] = useState<string>('');
  const [activeTab, setActiveTab] = useState<'seller' | 'buyer'>('seller');

  const handleConnectWallet = () => {
    connect({ connector: injected() });
  };

  const handleDisconnectWallet = () => {
    disconnect();
  };

  return (
    <div className="App">
      <header className="App-header">
        <h1>MainnetUserTxn DApp</h1>
        <p>与 MainnetUserTxn 合约交互的前端应用</p>
        
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

          {isConnected && contractAddress && (
            <div className="tabs">
              <div className="tab-buttons">
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
              </div>
              
              <div className="tab-content">
                {activeTab === 'seller' && (
                  <ContractInteraction 
                    contractAddress={contractAddress} 
                    userAddress={address!} 
                  />
                )}
                {activeTab === 'buyer' && (
                  <BuyerInteraction />
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
