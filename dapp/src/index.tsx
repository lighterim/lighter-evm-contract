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

// 获取 RPC URL，优先使用环境变量，否则使用默认值
const getSepoliaRpcUrl = () => {
  // 在浏览器环境中，我们可以使用多个备选 RPC
  const rpcUrls = [
    'https://eth-sepolia.g.alchemy.com/v2/tE4nUL18kXAYmNOM9M4U4K-jL21y5oJ3',
    'https://rpc.sepolia.org',
    'https://sepolia.gateway.tenderly.co',
    'https://ethereum-sepolia-rpc.publicnode.com'
  ];
  
  // 返回第一个可用的 RPC URL
  return rpcUrls[0];
};

// 创建 Wagmi 配置
const config = createConfig({
  chains: [mainnet, sepolia, hardhat],
  connectors: [
    injected(),
  ],
  transports: {
    [mainnet.id]: http(),
    [sepolia.id]: http(getSepoliaRpcUrl()),
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
