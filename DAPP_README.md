# MainnetUserTxn DApp 使用指南

## 项目概述

已成功创建了一个用于与 MainnetUserTxn 合约交互的前端应用，位于 `dapp/` 目录下。

## 项目结构

```
dapp/
├── public/                 # 静态文件
├── src/                   # 源代码
│   ├── components/        # React 组件
│   │   ├── WalletConnectButton.tsx
│   │   └── ContractInteraction.tsx
│   ├── App.tsx           # 主应用组件
│   ├── App.css           # 主应用样式
│   ├── index.tsx         # 应用入口
│   └── index.css         # 全局样式
├── build/                # 构建输出
├── package.json          # 项目配置
├── deploy.sh            # 部署脚本
└── README.md            # 项目说明
```

## 功能特性

### ✅ 已实现功能

1. **钱包连接**
   - 支持 MetaMask 钱包连接
   - 显示连接状态和地址
   - 断开连接功能

2. **合约交互**
   - 合约地址输入和验证
   - 合约代码检查
   - 读取合约基本信息
   - 账户余额查询

3. **用户界面**
   - 现代化渐变背景设计
   - 响应式布局
   - 清晰的错误和结果显示
   - 详细的合约说明

4. **网络支持**
   - Ethereum Mainnet
   - Ethereum Sepolia
   - Hardhat Local Network

## 使用方法

### 1. 启动开发服务器

```bash
cd dapp
npm start
```

应用将在 [http://localhost:3000](http://localhost:3000) 打开。

### 2. 构建生产版本

```bash
cd dapp
npm run build
# 或使用部署脚本
./deploy.sh
```

### 3. 本地测试生产版本

```bash
cd dapp
npm run serve
```

## 使用步骤

### 1. 连接钱包
- 打开应用页面
- 点击 "连接 MetaMask" 按钮
- 在 MetaMask 中确认连接

### 2. 输入合约地址
- 在 "合约地址" 输入框中输入 MainnetUserTxn 合约地址
- 例如本地测试地址: `0x5fbdb2315678afecb367f032d93f642f64180aa3`

### 3. 与合约交互
- 点击 "验证合约" 检查合约有效性
- 点击 "获取余额" 查看当前账户余额
- 查看详细的合约信息和状态

## 技术栈

- **React 18** - 前端框架
- **TypeScript** - 类型安全
- **Viem** - 以太坊交互库
- **Wagmi** - React Hooks 库
- **TanStack Query** - 数据获取和缓存
- **CSS3** - 现代化样式

## 合约说明

MainnetUserTxn 合约主要用于处理大宗交易意图，主要功能包括：

- 处理 Permit2 代币授权
- 验证 EIP-712 签名
- 管理大宗出售意图
- 与轻量级中继器交互

**注意**: 此合约主要为内部函数，通常由其他合约或中继器调用。前端应用主要用于查看合约状态和基本信息。

## 部署选项

### 1. 本地开发
```bash
cd dapp
npm start
```

### 2. 生产构建
```bash
cd dapp
npm run build
```

### 3. 本地测试生产版本
```bash
cd dapp
npm run serve
```

### 4. 部署到静态服务器
将 `build/` 目录中的文件上传到任何静态文件服务器。

## 环境配置

应用支持以下网络：

- **Mainnet** (Chain ID: 1) - 以太坊主网
- **Sepolia** (Chain ID: 11155111) - 以太坊测试网
- **Hardhat** (Chain ID: 31337) - 本地开发网络

## 故障排除

### 常见问题

1. **钱包连接失败**
   - 确保 MetaMask 已安装并解锁
   - 检查网络连接
   - 尝试刷新页面

2. **合约验证失败**
   - 检查合约地址是否正确
   - 确保合约已部署到当前网络
   - 检查网络配置

3. **构建失败**
   - 确保 Node.js 版本 >= 16
   - 删除 `node_modules` 并重新安装
   - 检查网络连接

### 调试模式

在浏览器开发者工具中查看控制台输出，获取详细的错误信息。

## 下一步开发建议

1. **添加更多网络支持**
   - Base Mainnet/Sepolia
   - Polygon
   - Arbitrum

2. **增强合约交互**
   - 添加事件监听
   - 实现交易历史
   - 添加更多合约函数调用

3. **改进用户体验**
   - 添加加载状态
   - 实现交易确认
   - 添加错误重试机制

4. **安全性增强**
   - 添加合约验证
   - 实现权限检查
   - 添加安全警告

## 联系和支持

如有问题或建议，请查看项目文档或提交 Issue。

---

**项目状态**: ✅ 已完成并测试通过
**最后更新**: 2024年10月4日

