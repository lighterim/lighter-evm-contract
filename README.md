# Lighter EVM Contract

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Solidity](https://img.shields.io/badge/Solidity-0.8.25-blue.svg)](https://soliditylang.org/)
[![Foundry](https://img.shields.io/badge/Foundry-1.0+-green.svg)](https://getfoundry.sh/)

A decentralized Take Intent processing system based on the 0x-settler architecture, supporting token authorization and escrow transactions through Permit2.

## 📋 Table of Contents

- [Project Overview](#project-overview)
- [Core Features](#core-features)
- [Architecture](#architecture)
- [Quick Start](#quick-start)
- [Development Guide](#development-guide)
- [Testing](#testing)
- [Deployment](#deployment)
- [Security](#security)
- [Contributing](#contributing)
- [License](#license)

## 🎯 Project Overview

Lighter EVM Contract is a smart contract system designed to implement a decentralized transaction intent processing mechanism. The system allows buyers and sellers to express trading intentions through signed intents, execute transactions through relayers, and provides fund escrow services through the Escrow contract.

### Key Features

- ✅ **Three Intent Modes**: Supports seller intent, buyer intent, and bulk sell intent
- ✅ **Permit2 Integration**: Uses Uniswap Permit2 for gasless token authorization
- ✅ **ERC6551 Support**: Token Bound Accounts (TBA) based account system
- ✅ **Escrow Custody**: Secure fund custody and release mechanism
- ✅ **EIP-712 Signatures**: Typed data signatures for better user experience
- ✅ **Multiple Inheritance Architecture**: Modular design, easy to extend

## 🚀 Core Features

### 1. Take Seller Intent

The seller publishes a sell intent and authorizes token transfer via Permit2, and the buyer initiates the transaction.

**Process**:
1. The seller signs a token transfer authorization using `Permit2.permitWitnessTransferFrom` with `IntentParams` (containing token, amount, price, etc.) as the `witness`
2. The relayer signs `EscrowParams` (escrow parameters)
3. The buyer executes the `execute` function, transferring the seller's tokens to the `Escrow` contract, initiating a bilateral transaction based on the intent

### 2. Take Buyer Intent

The buyer publishes a purchase intent, and the seller authorizes tokens via Permit2 before executing the transaction.

**Process**:
1. The buyer signs `IntentParams`
2. The relayer signs `EscrowParams`
3. The seller authorizes tokens to the contract via Permit2
4. The seller executes the `execute` function, initiating a bilateral transaction based on the intent

### 3. Take Bulk Sell Intent

The seller authorizes all tokens in the intent to `$AllowanceHolder` at once via Permit2's `permit` function, supporting batch transactions.

**Process**:
1. The seller authorizes all tokens in the intent to `$AllowanceHolder` at once via Permit2's `permit` function
2. The seller signs `IntentParams`
3. The relayer signs `EscrowParams`
4. The buyer can execute the `execute` function multiple times, transferring tokens through `$AllowanceHolder`, with each execution initiating a bilateral transaction based on the intent. This continues until the intent no longer meets execution conditions (quantity exhausted or deadline reached)

## 🏗️ Architecture

### Contract Inheritance Structure

The project uses a multiple inheritance architecture, following the 0x-settler design pattern:

```
AbstractContext
    ↓
Context (escrow, relayer, signature verification)
    ↓
    ├─→ SettlerAbstract → SettlerBase
    │       ↓
    │   Permit2PaymentTakeIntent (Permit2 payment logic)
    │       ↓
    │   Settler (core execution logic)
    │       ↓
    │   MainnetTakeIntent (mainnet implementation)
    │
    ├─→ Permit2PaymentAbstract (Permit2 abstract interface)
    ├─→ WaypointAbstract (Waypoint functionality)
    └─→ FinalizeAbstract (Finalize functionality, in development)
```

For detailed inheritance structure diagrams, please refer to [INHERITANCE_STRUCTURE.md](./INHERITANCE_STRUCTURE.md)

### Core Contracts

- **`Settler`**: Core abstract contract that handles transaction intent execution logic
- **`MainnetTakeIntent`**: Concrete implementation on mainnet, inherits from `Settler`
- **`Escrow`**: Fund escrow contract that manages transaction status and fund release
- **`LighterAccount`**: ERC6551 Token Bound Account implementation
- **`AllowanceHolder`**: Permit2 authorization holder for bulk transactions

## 🛠️ Quick Start

### Requirements

- **Foundry**: >= 1.0.0
- **Solidity**: 0.8.25
- **Node.js**: >= 18.0.0 (optional, for Hardhat)

### Installation

```bash
# Clone the repository
git clone https://github.com/lighterim/lighter-evm-contract.git
cd lighter-evm-contract

# Install Foundry (if not installed)
curl -L https://foundry.paradigm.xyz | bash
foundryup

# Install dependencies
forge install

# Install Node.js dependencies (optional)
npm install
```

### Environment Configuration

Create a `.env` file:

```bash
# RPC endpoints
MAINNET_RPC_URL=https://eth-mainnet.g.alchemy.com/v2/YOUR_KEY
SEPOLIA_RPC_URL=https://eth-sepolia.g.alchemy.com/v2/YOUR_KEY
BASE_MAINNET_RPC_URL=https://mainnet.base.org
BNB_MAINNET_RPC_URL=https://bsc-dataseed.binance.org

# Deployment account (for testing)
PRIV_KEY=your_private_key_here
DEPLOYER=0xYourDeployerAddress

# Test accounts
BUYER_PRIVATE_KEY=your_buyer_private_key
SELLER_PRIVATE_KEY=your_seller_private_key
RELAYER_PRIVATE_KEY=your_relayer_private_key

# Contract addresses (update after deployment)
LighterAccount=0x...
Escrow=0x...
AllowanceHolder=0x...
TakeIntent=0x...
```

### Compilation

```bash
# Compile with Foundry
forge build

# Or compile with Hardhat
npm run compile
```

## 🧪 Testing

### Run All Tests

```bash
forge test
```

### Run Specific Tests

```bash
# Test Take Seller Intent
forge test --match-path test/TakeIntent.t.sol --match-test testTakeSellerIntent -vvvvv

# Test Take Buyer Intent
forge test --match-path test/TakeIntent.t.sol --match-test testTakeBuyerIntent -vvvvv

# Test Take Bulk Sell Intent
forge test --match-path test/TakeIntent.t.sol --match-test testTakeBulkSellIntent -vvvvv
```

### Fork Testing

Tests support Sepolia testnet fork, requires environment variable setup:

```bash
export SEPOLIA_RPC_URL=your_rpc_url
forge test --match-path test/TakeIntent.t.sol --ffi
```

### Test Coverage

```bash
forge coverage
```

## 📦 Deployment

### Deployment Script

Deploy using Foundry script:

```bash
# Set environment variables
export PRIV_KEY=your_private_key
export RPC_URL=your_rpc_url

# Deploy to Sepolia testnet
forge script script/Deploy.s.sol \
  --rpc-url $SEPOLIA_RPC_URL \
  --broadcast \
  --private-key $PRIV_KEY \
  --verify
```

### Contract Verification

```bash
forge verify-contract \
  --rpc-url https://sepolia.drpc.org \
  --verifier blockscout \
  --verifier-url 'https://eth-sepolia.blockscout.com/api/' \
  $LighterAccount \
  src/account/LighterAccount.sol:LighterAccount
```

For detailed deployment instructions, please refer to [DEPLOYMENT_README.md](./DEPLOYMENT_README.md)

## 🔒 Security

### Security Audit

The project has completed preliminary security analysis. For detailed report, please refer to [SECURITY_ANALYSIS.md](./SECURITY_ANALYSIS.md)

### Known Issues

1. **Finalize Branch Incomplete**: `FinalizeAbstract` currently only has abstract definitions, concrete implementation pending
2. **Reentrancy Protection**: `Escrow` contract should add `ReentrancyGuard` protection
3. **Signature Replay**: Recommend adding nonce mechanism to prevent signature replay attacks

### Security Best Practices

- ⚠️ **Before Production Deployment**: Conduct a full security audit
- ⚠️ **Private Key Management**: Never commit private keys to the code repository
- ⚠️ **Access Control**: Carefully review `Escrow` contract permission settings
- ⚠️ **Test Coverage**: Ensure all critical paths have test coverage

## 📚 Documentation

- [Contract Inheritance Structure](./INHERITANCE_STRUCTURE.md) - Detailed inheritance relationship diagrams
- [Security Analysis Report](./SECURITY_ANALYSIS.md) - Security review and fix recommendations
- [Function Selector List](./ISETTLER_ACTIONS_SELECTORS.md) - Selectors for all functions
- [Deployment Guide](./DEPLOYMENT_README.md) - Deployment steps and configuration
- [Test Run Guide](./TEST_RUN_GUIDE.md) - Test configuration and execution methods

## 🤝 Contributing

We welcome all forms of contributions! Please see [CONTRIBUTING.md](./CONTRIBUTING.md) for detailed contribution guidelines.

### Ways to Contribute

- 🐛 Report Bugs
- 💡 Suggest New Features
- 📝 Improve Documentation
- 🔧 Submit Code Fixes
- ✅ Add Test Cases

## 📄 License

This project is licensed under the [MIT License](./LICENSE).

## 🙏 Acknowledgments

- [0x Project](https://github.com/0xProject) - Referenced 0x-settler architecture design
- [Uniswap Permit2](https://github.com/Uniswap/permit2) - Token authorization mechanism
- [OpenZeppelin](https://github.com/OpenZeppelin/openzeppelin-contracts) - Security contract library
- [Foundry](https://github.com/foundry-rs/foundry) - Development framework

## 📞 Contact

- **Issues**: [GitHub Issues](https://github.com/lighterim/lighter-evm-contract/issues)
- **Discussions**: [GitHub Discussions](https://github.com/lighterim/lighter-evm-contract/discussions)

## 🔗 Related Links

- [Permit2 Documentation](https://docs.uniswap.org/contracts/permit2/overview)
- [ERC6551 Standard](https://eips.ethereum.org/EIPS/eip-6551)
- [EIP-712 Standard](https://eips.ethereum.org/EIPS/eip-712)
- [Foundry Documentation](https://book.getfoundry.sh/)

## 📝 Common Commands

### Test Commands

```bash
# Run all tests
forge test

# Run specific test file
forge test --match-path test/TakeIntent.t.sol

# Run specific test function
forge test --match-path test/TakeIntent.t.sol --match-test testTakeSellerIntent -vvvvv

# Fork testing (requires RPC_URL)
forge test --match-path test/TakeIntent.t.sol --match-test testTakeSellerIntent -vvvvv --ffi
```

### Deployment Commands

```bash
# Set environment variables
export PRIV_KEY=your_private_key
export DEPLOYER=your_deployer_address
export RPC_URL=your_rpc_url

# Deploy contracts
forge script script/Deploy.s.sol --rpc-url $RPC_URL --broadcast --private-key $PRIV_KEY

# Verify contract
forge verify-contract \
  --rpc-url https://sepolia.drpc.org \
  --verifier blockscout \
  --verifier-url 'https://eth-sepolia.blockscout.com/api/' \
  $LighterAccount \
  src/account/LighterAccount.sol:LighterAccount
```

### Environment Variable Examples

```bash
# Deployment related
export PRIV_KEY=your_private_key
export DEPLOYER=$deployer
export RPC_URL=your_rpc_url

# Contract addresses (update after deployment)
export LighterAccount=0xD18e648B1CBee795f100ca450cc13CcC6849Be64
export Escrow=0xe31527c75edc58343D702e3840a00c10c4858e25
export AllowanceHolder=0x302950de9b74202d74DF5e29dc2B19D491AE57a3
export TakeIntent=0x3DB826B7063bf8e51832B7350F7cbe359AEA3f60

# Test accounts
export BUYER_PRIVATE_KEY=your_buyer_private_key
export SELLER_PRIVATE_KEY=your_seller_private_key
export RELAYER_PRIVATE_KEY=your_relayer_private_key
export BUYER_TBA=$your_tba_for_buyer
export SELLER_TBA=$your_tba_for_seller
export USDC=0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238

# Create TBA account example
cast send $LighterAccount 'createAccount(address,bytes32)' $DEPLOYER $nostrSeller \
  --value 0.00001ether --private-key $PRIV_KEY
```

### Utility Commands

```bash
# Format code
forge fmt

# Check code format
forge fmt --check

# Generate gas report
forge test --gas-report

# View coverage
forge coverage
```

---

**⚠️ Disclaimer**: This project is in development. Please conduct thorough security audits and testing before production deployment.
