# LighterAccount DApp 快速启动

## 🚀 5 分钟快速开始

### 1. 部署合约（如果还未部署）

```bash
# 在项目根目录
cd /Users/dustlee/myworks/kmfrog/lighter-evm-contract

# 部署到本地网络
npx hardhat node  # 在一个终端运行

# 在另一个终端部署
npx hardhat run scripts/deploy-with-official-accountv3.ts --network localhost
```

记录部署输出中的 **LighterAccount 地址**，例如：
```
✅ LighterAccount deployed at: 0xcf7ed3acca5a467e9e704c703e8d87f634fb0fc9
```

### 2. 启动 DApp

```bash
cd dapp
npm install  # 首次运行需要
npm start
```

浏览器会自动打开 http://localhost:3000

### 3. 连接钱包

1. 点击页面上的"连接钱包"按钮
2. 在 MetaMask 中选择账户并连接
3. 确保钱包连接到正确的网络（本地网络或测试网）

### 4. 配置 LighterAccount

1. 点击"🎫 LighterAccount (票券管理)"标签
2. 在"LighterAccount 合约地址"输入框中粘贴步骤 1 中记录的地址
3. 合约信息会自动加载

### 5. 创建你的第一个账户

1. 在"🎫 创建账户"子标签中
2. 接收者地址会自动填充为你的钱包地址
3. 填写 Nostr 公钥，例如：
   ```
   0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef
   ```
4. 点击"🎫 创建账户"
5. 在 MetaMask 中确认交易
6. 等待交易确认
7. 成功！你现在拥有一个票券 NFT 和对应的 TBA

---

## 📱 页面功能

### 主界面

- **钱包连接状态**：显示当前连接的钱包地址
- **合约信息**：显示租借价格、总租借数、合约余额
- **三个功能标签**：创建账户、销毁账户、升级配额

### 🎫 创建账户标签

**输入**：
- 接收者地址（默认当前钱包）
- Nostr 公钥（32 字节 hex）
- 支付金额（ETH）

**输出**：
- Token ID
- TBA 地址
- 交易哈希

**使用场景**：
- 用户租借票券
- 绑定 Nostr 身份
- 获得 TBA 钱包功能

### 🗑️ 销毁账户标签

**输入**：
- Token ID
- 退款接收地址

**输出**：
- 退还的租金
- 交易哈希

**使用场景**：
- 退租并拿回押金
- 清理不需要的票券

**限制**：
- 必须从 TBA 调用
- 需要特殊权限设置

### ⬆️ 升级配额标签

**输入**：
- Token ID
- 支付金额（ETH）

**输出**：
- 新的配额
- 交易哈希

**使用场景**：
- 增加账户使用额度
- 支付更多租金获得更多权限

**配额计算**：
```
配额 = 总支付金额 / rentPrice
```

---

## 🌐 网络配置

### 本地开发（Hardhat）

在 MetaMask 中添加自定义网络：

```
Network Name: Hardhat Local
RPC URL: http://localhost:8545
Chain ID: 31337
Currency Symbol: ETH
```

### Sepolia 测试网

```
Network Name: Sepolia
RPC URL: https://rpc.sepolia.org
Chain ID: 11155111
Currency Symbol: ETH
```

获取测试 ETH：https://sepoliafaucet.com

---

## 💡 使用技巧

### 1. 快速测试

使用示例 Nostr 公钥进行测试：
```
0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef
```

### 2. 查看创建的 TBA

创建账户后，可以使用 `getAccountAddress(tokenId)` 查询 TBA 地址，然后在区块浏览器中查看。

### 3. 配额管理

- 创建账户时支付的金额会记录为初始配额
- 后续可以通过 upgradeQuota 增加配额
- 使用 `getQuota(tbaAddress)` 查询当前配额

### 4. 监控交易

所有交易哈希都会显示在界面上，可以复制到区块浏览器查看详情。

---

## 🔧 开发者

### 修改 ABI

如果更新了 LighterAccount 合约，需要重新生成 ABI：

```bash
# 在项目根目录
npx hardhat compile

# 导出 ABI
cat artifacts/contracts/account/LighterAccount.sol/LighterAccount.json | jq '.abi' > dapp/src/abis/LighterAccount.json
```

### 添加新功能

1. 在 `LighterAccountInteraction.tsx` 中添加新的 state 和处理函数
2. 添加新的表单元素
3. 调用 `writeContract` 执行合约方法

### 自定义样式

修改 `LighterAccountInteraction.css` 来自定义界面样式。

---

## 📸 截图示例

（界面包含）：
- ✅ 美观的渐变背景
- ✅ 清晰的功能分组
- ✅ 实时合约状态显示
- ✅ 交易状态反馈
- ✅ 错误提示
- ✅ 使用说明

---

## 🐛 常见问题

**Q: 为什么创建账户需要支付 ETH？**
A: 这是票券的租借费用，会记录到合约中并可以通过销毁账户退还。

**Q: Nostr 公钥是什么？**
A: Nostr 是一个去中心化社交协议，公钥是用户的身份标识。格式为 32 字节的十六进制字符串。

**Q: 为什么无法销毁账户？**
A: destroyAccount 必须从 TBA 调用。普通用户需要通过 TBA 的 execute 功能来调用此方法。

**Q: 配额有什么用？**
A: 配额用于限制账户的使用次数或权限，具体业务逻辑由 LighterAccount 合约定义。

---

## 📚 相关文档

- **合约文档**: `../REFACTORING_AND_SOLADY_SUMMARY.md`
- **部署指南**: `../ACCOUNTV3_INTEGRATION_STRATEGY.md`
- **详细使用**: `LIGHTER_ACCOUNT_DAPP.md`

---

🎉 **开始使用 LighterAccount DApp！**

