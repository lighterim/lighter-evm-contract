# Foundry 项目设置说明

本项目已从 Hardhat 转换为 Foundry 项目。

## 已完成的设置

1. ✅ 创建了 `foundry.toml` 配置文件
2. ✅ 将 `contracts/` 目录移动到 `src/`（Foundry 标准目录）
3. ✅ 将测试文件移动到 `test/` 目录
4. ✅ 更新了 `remappings.txt` 路径映射
5. ✅ 安装了以下依赖：
   - forge-std (用于测试框架)
   - solady
   - permit2
   - OpenZeppelin Contracts (通过 npm)

## 需要手动安装的依赖

由于网络问题，以下依赖需要手动安装：

### 1. erc6551

项目使用了 erc6551 参考实现。需要手动安装：

```bash
# 方法 1: 使用 forge install
forge install erc6551/reference-implementation

# 方法 2: 手动克隆
git submodule add https://github.com/erc6551/reference-implementation lib/reference-implementation
```

安装后需要更新 `remappings.txt`：

```
erc6551/=lib/reference-implementation/src/
```

或者如果使用 tokenbound 目录结构：

```bash
# 如果需要 tokenbound 目录结构
mkdir -p lib/tokenbound/lib
git submodule add https://github.com/erc6551/reference-implementation lib/tokenbound/lib/erc6551
```

### 2. OpenZeppelin Contracts (可选)

如果希望通过 git submodule 安装（而不是 npm），可以运行：

```bash
forge install OpenZeppelin/openzeppelin-contracts
```

然后更新 `remappings.txt`，优先使用 lib 目录：

```
@openzeppelin/contracts/=lib/openzeppelin-contracts/contracts/
@openzeppelin/contracts/=node_modules/@openzeppelin/contracts/
```

## 使用 Foundry 命令

安装完所有依赖后，可以使用以下命令：

```bash
# 编译合约
forge build

# 运行测试
forge test

# 运行特定测试
forge test --match-contract SettlerTest

# 运行测试并显示 gas 报告
forge test --gas-report

# 格式化代码
forge fmt

# 生成文档
forge doc
```

## 项目结构

```
.
├── src/              # 合约源代码（原 contracts/）
├── test/             # 测试文件（Solidity 测试）
├── script/            # 部署脚本（原 scripts/）
├── lib/               # Foundry 依赖项
├── out/               # 编译输出
├── cache_forge/       # Foundry 缓存
└── foundry.toml       # Foundry 配置
```

## 注意事项

1. **TypeScript 测试文件**: 原 `test/` 目录中的 TypeScript 测试文件（如 `UserTxn.ts`、`LighterAccount.ts`）需要继续使用 Hardhat 运行，或者转换为 Solidity 测试。

2. **脚本文件**: `scripts/` 目录中的 TypeScript 部署脚本仍可使用 Hardhat 运行，或转换为 Foundry 脚本。

3. **依赖项**: 某些依赖项（如 erc6551）需要手动安装后才能编译。

