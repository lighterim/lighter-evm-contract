# Lighter EVM Contract

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Solidity](https://img.shields.io/badge/Solidity-0.8.25-blue.svg)](https://soliditylang.org/)
[![Foundry](https://img.shields.io/badge/Foundry-1.0+-green.svg)](https://getfoundry.sh/)

A decentralized **Take Intent** processing system built on Ethereum, enabling gasless token authorization and secure escrow transactions through Uniswap Permit2 and ERC6551 Token Bound Accounts.

## 📋 Table of Contents

- [Overview](#overview)
- [Key Features](#key-features)
- [Architecture](#architecture)
- [Core Contracts](#core-contracts)
- [Quick Start](#quick-start)
- [Development](#development)
- [Testing](#testing)
- [Deployment](#deployment)
- [Security](#security)
- [Documentation](#documentation)
- [Contributing](#contributing)
- [License](#license)

## 🎯 Overview

Lighter EVM Contract is a smart contract system that implements a decentralized transaction intent processing mechanism. The system allows buyers and sellers to express trading intentions through EIP-712 signed intents, execute transactions through relayers, and provides secure fund escrow services.

### Core Concepts

- **Take Intent**: A mechanism where users express trading intentions (buy/sell) through signed messages, allowing relayers to execute transactions on their behalf
- **Permit2 Integration**: Uses Uniswap Permit2 for gasless token authorization and transfers
- **Token Bound Accounts**: ERC6551-based account system for enhanced user experience
- **Escrow System**: Secure fund custody with multiple release mechanisms (seller release, verifier release, dispute resolution)

## ✨ Key Features

### 1. Three Intent Modes

#### Take Seller Intent
The seller publishes a sell intent and authorizes token transfer via Permit2. The buyer initiates the transaction.

**Process**:
1. Seller signs a token transfer authorization using `Permit2.permitWitnessTransferFrom` with `IntentParams` as witness
2. Relayer signs `EscrowParams` (escrow parameters)
3. Buyer executes `execute`, transferring seller's tokens to Escrow contract

#### Take Buyer Intent
The buyer publishes a purchase intent. The seller authorizes tokens via Permit2 before executing.

**Process**:
1. Buyer signs `IntentParams`
2. Seller authorizes tokens via Permit2
3. Relayer signs `EscrowParams`
4. Seller executes `execute` to initiate the transaction

#### Take Bulk Sell Intent
The seller authorizes all tokens to `AllowanceHolder` at once via Permit2's `permit` function, supporting batch transactions.

**Process**:
1. Seller authorizes tokens to `AllowanceHolder` via Permit2 `permit`
2. Seller signs `IntentParams`
3. Relayer signs `EscrowParams`
4. Buyer can execute multiple times, transferring tokens through `AllowanceHolder`

### 2. Advanced Features

- ✅ **EIP-712 Signatures**: Typed data signatures for better UX and security
- ✅ **ERC6551 Support**: Token Bound Accounts (TBA) for account abstraction
- ✅ **Escrow Custody**: Multi-stage escrow with dispute resolution
- ✅ **Payment Method Registry**: Configurable payment methods with window periods
- ✅ **User Honour System**: Track user reputation and transaction history
- ✅ **Waypoint Support**: Additional verification layer (in development)
- ✅ **ZK Verification**: Zero-knowledge proof verification support

## 🏗️ Architecture

### Contract Inheritance Structure

The project uses a modular multiple inheritance architecture, following the 0x-settler design pattern:

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

### Directory Structure

```
src/
├── account/              # ERC6551 Token Bound Account implementation
│   ├── LighterAccount.sol
│   ├── AccountV3.sol
│   └── TokenBoundConfig.sol
├── allowanceholder/      # Permit2 allowance holder for bulk transactions
│   └── AllowanceHolder.sol
├── chains/              # Chain-specific implementations
│   └── Mainnet/
│       ├── TakeIntent.sol
│       ├── Waypoint.sol
│       └── Common.sol
├── core/                # Core abstract contracts
│   ├── Permit2Payment.sol
│   ├── SettlerErrors.sol
│   ├── WaypointAbstract.sol
│   └── ZkVerifier.sol
├── interfaces/          # Interface definitions
│   ├── ISettlerBase.sol
│   ├── ISettlerTakeIntent.sol
│   ├── IEscrow.sol
│   └── ...
├── utils/              # Utility libraries
│   ├── ParamsHash.sol
│   ├── SignatureVerification.sol
│   └── UnsafeMath.sol
├── Escrow.sol          # Escrow contract
├── Settler.sol         # Core settler contract
├── SettlerBase.sol     # Base settler functionality
└── PaymentMethodsRegistry.sol
```

## 📦 Core Contracts

### Settler Contracts

- **`Settler`**: Core abstract contract handling transaction intent execution logic
- **`SettlerBase`**: Base functionality including payment method registry, domain separator, and intent validation
- **`MainnetTakeIntent`**: Concrete implementation for mainnet, inherits from `Settler`
- **`SettlerWaypoint`**: Waypoint functionality for additional verification

### Account & Token Management

- **`LighterAccount`**: ERC6551 Token Bound Account implementation
  - Mints Ticket NFTs and creates corresponding TBAs
  - Manages user honour system
  - Tracks pending transactions and quotas
- **`LighterTicket`**: ERC721 NFT contract for user tickets
- **`AllowanceHolder`**: Permit2 authorization holder for bulk transactions

### Escrow & Payment

- **`Escrow`**: Fund escrow contract managing transaction lifecycle
  - Creates and manages escrow transactions
  - Handles payment, release, cancellation, and dispute resolution
  - Supports multiple release mechanisms
- **`PaymentMethodsRegistry`**: Registry for payment methods with configurable windows

### Core Interfaces

- **`ISettlerBase`**: Core data structures (IntentParams, EscrowParams, EscrowStatus)
- **`ISettlerTakeIntent`**: Interface for take intent functionality
- **`IEscrow`**: Escrow contract interface
- **`ISettlerActions`**: Action selectors for transaction execution

## 🚀 Quick Start

### Prerequisites

- **Foundry**: >= 1.0.0 ([Installation Guide](https://getfoundry.sh/))
- **Solidity**: 0.8.25
- **Node.js**: >= 18.0.0 (optional, for Hardhat scripts)

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

# Install Node.js dependencies (optional, for Hardhat)
npm install
```

### Environment Setup

Create a `.env` file in the root directory:

```bash
# RPC endpoints
MAINNET_RPC_URL=https://eth-mainnet.g.alchemy.com/v2/YOUR_KEY
SEPOLIA_RPC_URL=https://eth-sepolia.g.alchemy.com/v2/YOUR_KEY
BASE_MAINNET_RPC_URL=https://mainnet.base.org
BNB_MAINNET_RPC_URL=https://bsc-dataseed.binance.org

# Deployment account
PRIV_KEY=your_private_key_here
DEPLOYER=0xYourDeployerAddress

# Test accounts (optional)
BUYER_PRIVATE_KEY=your_buyer_private_key
SELLER_PRIVATE_KEY=your_seller_private_key
RELAYER_PRIVATE_KEY=your_relayer_private_key
```

### Compilation

```bash
# Compile with Foundry
forge build

# Or compile with Hardhat (optional)
npm run compile
```

## 💻 Development

### Code Formatting

```bash
# Format code
forge fmt

# Check formatting
forge fmt --check
```

### Gas Optimization

```bash
# Generate gas report
forge test --gas-report
```

### Code Coverage

```bash
# Generate coverage report
forge coverage
```

## 🧪 Testing

### Run All Tests

```bash
forge test
```

### Run Specific Test Suites

```bash
# Test Settler functionality
forge test --match-path test/Settler.t.sol -vvvvv

# Test User Transaction
forge test --match-path test/UserTxn.t.sol -vvvvv

# Test LighterAccount
forge test --match-path test/LighterAccount.ts -vvvvv
```

### Fork Testing

Tests support testnet fork testing:

```bash
# Set RPC URL
export SEPOLIA_RPC_URL=your_rpc_url

# Run fork tests
forge test --match-path test/TakeIntent.t.sol --ffi -vvvvv
```

### Test Coverage

```bash
forge coverage
```

## 📦 Deployment

### Prerequisites

1. Set up environment variables (see [Environment Setup](#environment-setup))
2. Ensure sufficient balance for deployment
3. Configure network in `foundry.toml` or `hardhat.config.ts`

### Foundry Deployment

```bash
# Deploy to Sepolia testnet
forge script script/Deploy.s.sol \
  --rpc-url $SEPOLIA_RPC_URL \
  --broadcast \
  --private-key $PRIV_KEY \
  --verify
```

### Hardhat Deployment

```bash
# Deploy using Hardhat
npx hardhat run scripts/deploy-sepolia.ts --network sepolia
```

### Contract Verification

```bash
# Verify contract on Etherscan
forge verify-contract \
  --rpc-url https://sepolia.drpc.org \
  --verifier etherscan \
  --verifier-url https://api-sepolia.etherscan.io/api \
  $CONTRACT_ADDRESS \
  src/account/LighterAccount.sol:LighterAccount \
  --constructor-args $(cast abi-encode "constructor(address,address,address,uint256)" $TICKET_CONTRACT $REGISTRY $ACCOUNT_IMPL 0)
```

For detailed deployment instructions, see [DEPLOYMENT_README.md](./DEPLOYMENT_README.md).

## 🔒 Security

### Security Considerations

- ⚠️ **Before Production**: Conduct a comprehensive security audit
- ⚠️ **Private Key Management**: Never commit private keys to the repository
- ⚠️ **Access Control**: Review all authorization mechanisms carefully
- ⚠️ **Test Coverage**: Ensure all critical paths have test coverage
- ⚠️ **Reentrancy**: Escrow contract uses `ReentrancyGuard` for protection

### Known Limitations

1. **Finalize Branch**: `FinalizeAbstract` currently only has abstract definitions
2. **Signature Replay**: Consider adding nonce mechanism for additional protection
3. **Waypoint**: Waypoint functionality is in active development

### Security Best Practices

- Use multi-sig wallets for contract ownership
- Implement time-locked upgrades for critical contracts
- Monitor contract events for suspicious activity
- Regular security audits and code reviews

## 📚 Documentation

### Core Documentation

- [Foundry Setup Guide](./FOUNDRY_SETUP.md) - Foundry project setup and configuration
- [Deployment Guide](./DEPLOYMENT_README.md) - Detailed deployment instructions
- [DApp README](./DAPP_README.md) - Frontend application documentation

### Contract Documentation

- **ISettlerActions**: Action selectors for all supported operations
- **ISettlerBase**: Core data structures and enums
- **IEscrow**: Escrow contract interface and events

### External Resources

- [Permit2 Documentation](https://docs.uniswap.org/contracts/permit2/overview)
- [ERC6551 Standard](https://eips.ethereum.org/EIPS/eip-6551)
- [EIP-712 Standard](https://eips.ethereum.org/EIPS/eip-712)
- [Foundry Documentation](https://book.getfoundry.sh/)

## 🤝 Contributing

We welcome contributions! Please see our contributing guidelines:

### Ways to Contribute

- 🐛 **Report Bugs**: Open an issue with detailed information
- 💡 **Suggest Features**: Propose new features or improvements
- 📝 **Improve Documentation**: Help improve our documentation
- 🔧 **Submit Code**: Submit pull requests with fixes or features
- ✅ **Add Tests**: Increase test coverage

### Development Workflow

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes
4. Add tests for new functionality
5. Ensure all tests pass (`forge test`)
6. Format code (`forge fmt`)
7. Commit your changes (`git commit -m 'Add amazing feature'`)
8. Push to the branch (`git push origin feature/amazing-feature`)
9. Open a Pull Request

## 📄 License

This project is licensed under the [MIT License](./LICENSE).

## 🙏 Acknowledgments

- [0x Project](https://github.com/0xProject) - Referenced 0x-settler architecture design
- [Uniswap Permit2](https://github.com/Uniswap/permit2) - Token authorization mechanism
- [OpenZeppelin](https://github.com/OpenZeppelin/openzeppelin-contracts) - Security contract library
- [Foundry](https://github.com/foundry-rs/foundry) - Development framework
- [ERC6551](https://github.com/erc6551/reference-implementation) - Token Bound Account reference implementation

## 📞 Contact & Support

- **Issues**: [GitHub Issues](https://github.com/lighterim/lighter-evm-contract/issues)
- **Discussions**: [GitHub Discussions](https://github.com/lighterim/lighter-evm-contract/discussions)

## 🔗 Related Links

- [Permit2 Documentation](https://docs.uniswap.org/contracts/permit2/overview)
- [ERC6551 Standard](https://eips.ethereum.org/EIPS/eip-6551)
- [EIP-712 Standard](https://eips.ethereum.org/EIPS/eip-712)
- [Foundry Documentation](https://book.getfoundry.sh/)

---

**⚠️ Disclaimer**: This project is in active development. Please conduct thorough security audits and testing before production deployment.
