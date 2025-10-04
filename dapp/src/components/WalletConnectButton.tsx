import React from 'react';

interface WalletConnectButtonProps {
  onConnect: () => void;
}

export const WalletConnectButton: React.FC<WalletConnectButtonProps> = ({ onConnect }) => {
  return (
    <div className="wallet-connect-section">
      <h3>连接钱包</h3>
      <p>请连接您的钱包以使用此应用</p>
      <button onClick={onConnect} className="connect-btn">
        连接 MetaMask
      </button>
    </div>
  );
};
