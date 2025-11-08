# Hardhat 到 Foundry 迁移总结

## ✅ 已完成的工作

### 1. 项目结构转换
- ✅ 创建了 `foundry.toml` 配置文件，设置 Solidity 0.8.29，优化器 runs 200，evmVersion cancun
- ✅ 将 `contracts/` 目录复制到 `src/`（Foundry 标准目录结构）
- ✅ 将 Solidity 测试文件移动到 `test/` 目录：
  - `UserTxn.t.sol` → `test/UserTxn.t.sol`
  - `Settler.t.sol` → `test/Settler.t.sol`
- ✅ 更新了测试文件中的导入路径（从 `../../` 改为 `../src/`）

### 2. 依赖项安装
- ✅ 安装了 `forge-std` (v1.11.0)
- ✅ 安装了 `solady` (v0.1.26)
- ✅ 安装了 `permit2` (Uniswap)
- ✅ 通过 npm 安装了 `@openzeppelin/contracts`

### 3. 配置更新
- ✅ 更新了 `remappings.txt`，映射所有依赖项路径
- ✅ 修复了 `hardhat/console.sol` → `forge-std/console.sol` 的引用
- ✅ 配置了 `foundry.toml`，包括优化器、测试路径等

## ⚠️ 待完成的工作

### 1. 安装 erc6551 依赖（必需）

项目依赖 erc6551 参考实现，由于网络问题无法自动安装。需要手动安装：

```bash
# 方法 1: 使用 forge install（推荐）
forge install erc6551/reference-implementation

# 方法 2: 手动 git submodule
git submodule add https://github.com/erc6551/reference-implementation lib/reference-implementation
```

安装后，`remappings.txt` 中已包含正确的映射：
```
erc6551/=lib/reference-implementation/src/
```

### 2. 测试运行

安装完 erc6551 后，可以运行：

```bash
# 编译合约
forge build

# 运行所有测试
forge test

# 运行特定测试
forge test --match-contract SettlerTest
forge test --match-contract UserTxnTest

# 显示 gas 报告
forge test --gas-report
```

### 3. TypeScript 测试（可选）

原 `test/` 目录中的 TypeScript 测试文件（如 `UserTxn.ts`、`LighterAccount.ts`）仍可使用 Hardhat 运行：

```bash
# 使用 Hardhat 运行 TypeScript 测试
npx hardhat test
```

或者将这些测试转换为 Solidity 测试以在 Foundry 中运行。

## 📁 项目结构

```
.
├── src/                    # 合约源代码（原 contracts/）
│   ├── account/
│   ├── allowanceholder/
│   ├── chains/
│   ├── core/
│   ├── interfaces/
│   ├── token/
│   └── utils/
├── test/                   # Solidity 测试文件
│   ├── UserTxn.t.sol
│   └── Settler.t.sol
├── script/                 # Foundry 脚本目录
├── scripts/                # 原 TypeScript 脚本（仍可使用 Hardhat）
├── lib/                    # Foundry 依赖项
│   ├── forge-std/
│   ├── solady/
│   ├── permit2/
│   └── reference-implementation/  # 需要手动安装
├── foundry.toml            # Foundry 配置文件
├── remappings.txt         # 路径映射配置
├── hardhat.config.ts     # Hardhat 配置（保留用于 TS 脚本）
└── package.json           # npm 依赖（保留）
```

## 🔧 常用命令

### Foundry 命令

```bash
# 编译
forge build

# 运行测试
forge test

# 格式化代码
forge fmt

# 生成文档
forge doc --serve

# 清理缓存
forge clean
```

### Hardhat 命令（用于 TypeScript 脚本）

```bash
# 编译（使用 Hardhat）
npx hardhat compile

# 运行 TypeScript 测试
npx hardhat test

# 运行部署脚本
npx hardhat run scripts/deploy-xxx.ts
```

## 📝 注意事项

1. **双重工具链**: 项目现在同时支持 Hardhat 和 Foundry：
   - Foundry 用于 Solidity 合约编译和测试
   - Hardhat 用于 TypeScript 脚本和集成测试

2. **依赖管理**:
   - Foundry 依赖通过 `forge install` 安装到 `lib/` 目录
   - npm 依赖通过 `npm install` 安装到 `node_modules/`
   - `remappings.txt` 确保 Foundry 能找到所有依赖

3. **路径映射**: `remappings.txt` 中的映射优先级很重要，确保正确解析所有导入路径。

## ✨ 下一步

1. 安装 erc6551 依赖
2. 运行 `forge build` 验证编译
3. 运行 `forge test` 验证测试
4. 根据需要转换更多 TypeScript 测试为 Solidity 测试

