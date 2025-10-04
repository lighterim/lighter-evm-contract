import React from 'react';
import ReactDOM from 'react-dom/client';
import { WagmiProvider, createConfig, http } from 'wagmi';
import { mainnet, sepolia, hardhat } from 'wagmi/chains';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { injected } from 'wagmi/connectors';
import './index.css';
import App from './App';

// 创建查询客户端
const queryClient = new QueryClient();

// 创建 Wagmi 配置
const config = createConfig({
  chains: [mainnet, sepolia, hardhat],
  connectors: [
    injected(),
  ],
  transports: {
    [mainnet.id]: http(),
    [sepolia.id]: http(),
    [hardhat.id]: http(),
  },
});

const root = ReactDOM.createRoot(
  document.getElementById('root') as HTMLElement
);

root.render(
  <React.StrictMode>
    <WagmiProvider config={config}>
      <QueryClientProvider client={queryClient}>
        <App />
      </QueryClientProvider>
    </WagmiProvider>
  </React.StrictMode>
);
