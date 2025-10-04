# MainnetUserTxn 部署指南

本文档提供了 MainnetUserTxn 合约的部署脚本使用说明。

## 部署脚本

### 1. 统一部署脚本 (交互式)
`scripts/deploy-user-txn-unified.ts`
- 支持本地和 Base Sepolia 部署
- 交互式选择部署目标
- 支持自定义 lighterRelayer 地址

```bash
npx hardhat run scripts/deploy-user-txn-unified.ts --network hardhatMainnet
# 或
npx hardhat run scripts/deploy-user-txn-unified.ts --network baseSepolia
```

### 2. 本地部署脚本 (非交互式)
`scripts/deploy-user-txn-local.ts`
- 专门用于本地测试部署
- 自动使用部署者地址作为 lighterRelayer
- 适合自动化测试

```bash
npx hardhat run scripts/deploy-user-txn-local.ts --network hardhatMainnet
```

### 3. Base Sepolia 部署脚本 (非交互式)
`scripts/deploy-user-txn-base-sepolia-noninteractive.ts`
- 专门用于 Base Sepolia 测试网部署
- 自动使用部署者地址作为 lighterRelayer
- 包含余额检查和错误处理

```bash
npx hardhat run scripts/deploy-user-txn-base-sepolia-noninteractive.ts --network baseSepolia
```

### 4. 合约测试脚本
`scripts/test-user-txn.ts`
- 验证已部署合约的基本功能
- 检查合约代码和可访问性

```bash
npx hardhat run scripts/test-user-txn.ts --network hardhatMainnet
```

## 网络配置

### 本地网络
- **网络名称**: `hardhatMainnet`
- **链 ID**: 31337
- **用途**: 本地开发和测试

### Base Sepolia 测试网
- **网络名称**: `baseSepolia`
- **链 ID**: 84532
- **RPC URL**: 需要在环境变量中配置 `BASE_SEPOLIA_RPC_URL`
- **私钥**: 需要在环境变量中配置 `BASE_SEPOLIA_PRIVATE_KEY`

## 环境变量配置

### Base Sepolia 部署需要以下环境变量:

```bash
export BASE_SEPOLIA_RPC_URL="https://sepolia.base.org"
export BASE_SEPOLIA_PRIVATE_KEY="your_private_key_here"
```

### 或者使用 Hardhat Keystore:

```bash
npx hardhat keystore set BASE_SEPOLIA_RPC_URL
npx hardhat keystore set BASE_SEPOLIA_PRIVATE_KEY
```

## 合约参数

### MainnetUserTxn 构造函数参数:
- `lighterRelayer`: 轻量级中继器地址
  - 用于验证意图签名
  - 在生产环境中应设置为实际的中继器地址
  - 在测试环境中可以使用部署者地址

## 部署流程示例

### 1. 本地测试部署
```bash
# 部署到本地网络
npx hardhat run scripts/deploy-user-txn-local.ts --network hardhatMainnet

# 测试合约
npx hardhat run scripts/test-user-txn.ts --network hardhatMainnet
```

### 2. Base Sepolia 部署
```bash
# 确保有足够的测试币
# 部署到 Base Sepolia
npx hardhat run scripts/deploy-user-txn-base-sepolia-noninteractive.ts --network baseSepolia
```

### 3. 交互式部署
```bash
# 使用统一脚本进行交互式部署
npx hardhat run scripts/deploy-user-txn-unified.ts --network hardhatMainnet
# 或
npx hardhat run scripts/deploy-user-txn-unified.ts --network baseSepolia
```

## 获取测试币

### Base Sepolia ETH
- [Base Bridge](https://bridge.base.org/)
- [QuickNode Faucet](https://faucet.quicknode.com/base/sepolia)
- [Coinbase Faucet](https://www.coinbase.com/faucets/base-ethereum-sepolia-faucet)

## 合约验证

部署到测试网后，建议在 Basescan 上验证合约代码：

1. 访问 [Basescan](https://sepolia.basescan.org/)
2. 输入合约地址
3. 点击 "Verify and Publish"
4. 选择编译器版本和设置
5. 上传合约源代码

## 故障排除

### 常见错误

1. **"No wallet clients found"**
   - 检查私钥配置
   - 确保环境变量正确设置

2. **"Account balance is 0"**
   - 获取测试网代币
   - 检查网络连接

3. **"Contract not found"**
   - 确认合约地址正确
   - 检查网络配置

### 调试技巧

- 使用 `--verbose` 标志获取详细日志
- 检查 Hardhat 配置中的网络设置
- 验证 RPC URL 和私钥配置

## 注意事项

1. **安全性**: 永远不要在代码中硬编码私钥
2. **测试**: 始终先在本地网络测试合约
3. **Gas**: 确保账户有足够的 Gas 费用
4. **网络**: 确认连接到正确的网络
5. **参数**: 仔细检查构造函数参数

## 支持

如果遇到问题，请检查：
- Hardhat 配置
- 网络连接
- 环境变量设置
- 合约编译状态
