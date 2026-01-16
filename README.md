# Lighter EVM Contract

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Solidity](https://img.shields.io/badge/Solidity-0.8.25-blue.svg)](https://soliditylang.org/)
[![Foundry](https://img.shields.io/badge/Foundry-1.0+-green.svg)](https://getfoundry.sh/)

A decentralized **Take Intent** processing system built on Ethereum, enabling gasless token authorization and secure escrow transactions through Uniswap Permit2 and ERC6551 Token Bound Accounts.

## 📋 Table of Contents

- [Overview](#overview)
- [Key Features](#key-features)
- [Architecture](#architecture)
- [Technical Implementation](#technical-implementation)
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
- **TransientStorage**: EIP-1153 based reentrancy protection for efficient state management
- **Gas Optimization**: Inline assembly implementations for critical hashing operations

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
- ✅ **EIP-1153 TransientStorage**: Efficient reentrancy protection using transient storage (gas-optimized)
- ✅ **Escrow Custody**: Multi-stage escrow with dispute resolution
- ✅ **Payment Method Registry**: Configurable payment methods with window periods
- ✅ **User Honour System**: Track user reputation and transaction history
- ✅ **Waypoint Support**: Escrow lifecycle management (payment, cancellation, dispute, resolution)
- ✅ **ZK Verification**: Zero-knowledge proof verification support (ZkVerifyProofVerifier)
- ✅ **Gas-Optimized Hashing**: Inline assembly implementations for efficient keccak256 hashing

## 🏗️ Architecture

### Contract Inheritance Structure

The project uses a modular multiple inheritance architecture, following the 0x-settler design pattern:

**Three Main Business Lines:**

1. **Take Intent Line**:
   ```
   Context
     ↓
   SettlerAbstract → SettlerBase
     ↓
   Permit2PaymentAbstract → Permit2PaymentTakeIntent
     ↓
   Settler (core execution logic)
     ↓
   MainnetTakeIntent (mainnet implementation)
   ```

2. **Waypoint Line**:
   ```
   Context
     ↓
   SettlerAbstract → SettlerBase
     ↓
   WaypointAbstract
     ↓
   SettlerWaypoint
     ↓
   MainnetWaypoint (mainnet implementation)
   ```

3. **Verifier Line** (in development):
   ```
   Context
     ↓
   VerifierAbstract
     ↓
   ZkVerifyProofVerifier (mainnet implementation)
   ```

**Core Foundation:**
- **Context**: Base contract providing escrow, relayer, and signature verification
- **SettlerBase**: Core base contract with TransientStorage-based reentrancy protection, payment method registry, and fee calculations

### Directory Structure

```
src/
├── account/              # ERC6551 Token Bound Account implementation
│   ├── LighterAccount.sol      # Main account contract with honour system
│   ├── AccountV3.sol          # ERC6551 account implementation
│   ├── ERC6551Registry.sol     # ERC6551 registry
│   └── TokenBoundConfig.sol   # TBA configuration
├── allowanceholder/      # Permit2 allowance holder for bulk transactions
│   ├── AllowanceHolder.sol
│   └── IAllowanceHolder.sol
├── chains/              # Chain-specific implementations
│   └── Mainnet/
│       ├── TakeIntent.sol           # Mainnet take intent implementation
│       ├── Waypoint.sol            # Mainnet waypoint implementation
│       ├── ZkVerifyProofVerifier.sol # ZK proof verifier
│       └── Common.sol               # Common utilities
├── core/                # Core abstract contracts and implementations
│   ├── Permit2Payment.sol          # Permit2 payment implementation
│   ├── Permit2PaymentAbstract.sol  # Permit2 payment abstract
│   ├── SettlerErrors.sol           # Custom error definitions
│   ├── WaypointAbstract.sol        # Waypoint abstract contract
│   ├── VerifierAbstract.sol        # Verifier abstract contract
│   └── ZkVerifier.sol              # ZK verifier base
├── interfaces/          # Interface definitions
│   ├── ISettlerBase.sol            # Core data structures
│   ├── ISettlerTakeIntent.sol      # Take intent interface
│   ├── ISettlerWaypoint.sol        # Waypoint interface
│   ├── IEscrow.sol                 # Escrow interface
│   ├── IPaymentMethodRegistry.sol  # Payment method registry interface
│   └── ...
├── utils/              # Utility libraries
│   ├── ParamsHash.sol              # EIP-712 parameter hashing (gas-optimized)
│   ├── TransientStorage.sol        # EIP-1153 transient storage for reentrancy
│   ├── SignatureVerification.sol   # Signature verification utilities
│   ├── UnsafeMath.sol              # Unsafe math operations
│   ├── Permit2Helper.sol           # Permit2 helper functions
│   └── ...
├── vendor/             # Third-party vendor libraries
│   ├── SafeTransferLib.sol         # Safe token transfer library
│   ├── FullMath.sol                # Full precision math
│   └── ...
├── Escrow.sol          # Escrow contract (fund custody)
├── Settler.sol         # Core settler contract (intent execution)
├── SettlerBase.sol     # Base settler functionality
├── SettlerAbstract.sol # Abstract settler interface
├── SettlerWaypoint.sol # Waypoint settler implementation
├── PaymentMethodRegistry.sol # Payment method registry
└── ISettlerActions.sol # Action selectors
```

## 🔧 Technical Implementation

### Gas Optimization

The project implements several gas optimization techniques:

1. **EIP-1153 TransientStorage**: Uses transient storage (`tload`/`tstore`) instead of permanent storage for reentrancy protection, saving ~20,000 gas per operation
2. **Inline Assembly Hashing**: All `ParamsHash` functions use inline assembly for `keccak256` hashing, avoiding `abi.encode` overhead
3. **CalldataDecoder**: Optimized calldata decoding without bounds checking (documented trade-off for gas efficiency)
4. **Batch Operations**: Supports bulk transactions through `AllowanceHolder` for efficient token transfers

### Reentrancy Protection

The system uses a multi-layered reentrancy protection approach:

- **TransientStorage**: EIP-1153 based protection for transaction-level state
- **ReentrancyGuard**: OpenZeppelin's `ReentrancyGuard` in Escrow contract
- **State Validation**: Ensures payer, witness, and intent state are properly managed

### Code Quality

- **Foundry Linting**: All code follows Foundry linting recommendations
- **Gas-Optimized Patterns**: Inline assembly where appropriate for critical paths
- **Comprehensive Testing**: Unit tests for core libraries (ParamsHash, etc.)
- **Code Review**: Regular code reviews and security analysis

## 📦 Core Contracts

### Settler Contracts

- **`SettlerAbstract`**: Abstract interface defining `_dispatch` and `_dispatchVIP` methods
- **`SettlerBase`**: Core base contract providing:
  - EIP-1153 TransientStorage-based reentrancy protection
  - Payment method registry integration
  - Fee calculation utilities (`getAmountWithFee`, `getFeeAmount`)
  - Intent validation and state management
- **`Settler`**: Core execution contract handling transaction intent execution logic
  - Implements `_dispatch` for action routing
  - Supports multiple intent types (seller intent, buyer intent, bulk sell)
- **`MainnetTakeIntent`**: Mainnet implementation inheriting from `Settler`
- **`SettlerWaypoint`**: Waypoint contract for escrow lifecycle management
  - Handles payment, cancellation, disputes, and resolution
- **`MainnetWaypoint`**: Mainnet waypoint implementation

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

- **`ISettlerBase`**: Core data structures (IntentParams, EscrowParams, EscrowStatus, PaymentMethodConfig)
- **`ISettlerTakeIntent`**: Interface for take intent functionality
- **`ISettlerWaypoint`**: Interface for waypoint functionality
- **`IEscrow`**: Escrow contract interface with full lifecycle management
- **`ISettlerActions`**: Action selectors for transaction execution
- **`IPaymentMethodRegistry`**: Payment method registry interface

### Utility Libraries

- **`ParamsHash`**: Gas-optimized EIP-712 parameter hashing using inline assembly
  - Supports `Range`, `IntentParams`, `EscrowParams`, `TokenPermissions`
  - All hash functions optimized with inline assembly for gas efficiency
- **`TransientStorage`**: EIP-1153 transient storage library for reentrancy protection
  - Manages payer, witness, intentTypeHash, and tokenPermissions in transient storage
  - Provides efficient state management without permanent storage costs
- **`CalldataDecoder`**: Efficient calldata decoding library (used in SettlerBase)

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

# Test Take Intent
forge test --match-path test/TakeIntent.t.sol -vvvvv

# Test Waypoint
forge test --match-path test/Waypoint.t.sol -vvvvv

# Test unit tests (ParamsHash, etc.)
forge test --match-path test/unit/ -vvvvv

# Test Permit2 transfers
forge test --match-path test/Permit2TransferTest.t.sol -vvvvv
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
# Generate coverage report
forge coverage

# Run unit tests
forge test --match-path test/unit/ -vv

# Run integration tests
forge test --match-path test/TakeIntent.t.sol -vv
forge test --match-path test/Waypoint.t.sol -vv
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

1. **Verifier Branch**: `VerifierAbstract` and ZK verification are in active development
2. **Signature Replay**: Consider adding nonce mechanism for additional protection
3. **CalldataDecoder**: Uses optimized decoding without bounds checking (documented trade-off for gas efficiency)

### Security Best Practices

- Use multi-sig wallets for contract ownership
- Implement time-locked upgrades for critical contracts
- Monitor contract events for suspicious activity
- Regular security audits and code reviews

## 📚 Documentation

### Core Documentation

- [Code Review Report](./CODE_REVIEW_REPORT.md) - Comprehensive code review
- [Security Analysis](./SECURITY_ANALYSIS.md) - Security considerations
- [Inheritance Structure](./INHERITANCE_STRUCTURE.md) - Contract inheritance details
- [Local Test Guide](./LOCAL_TEST_GUIDE.md) - Local testing instructions
- [Test Run Guide](./TEST_RUN_GUIDE.md) - Testing guidelines

### Contract Documentation

- **ISettlerActions**: Action selectors for all supported operations
- **ISettlerBase**: Core data structures and enums
- **IEscrow**: Escrow contract interface and events

### External Resources

- [Permit2 Documentation](https://docs.uniswap.org/contracts/permit2/overview)
- [ERC6551 Standard](https://eips.ethereum.org/EIPS/eip-6551)
- [EIP-712 Standard](https://eips.ethereum.org/EIPS/eip-712)
- [EIP-1153 TransientStorage](https://eips.ethereum.org/EIPS/eip-1153) - Transient storage for reentrancy protection
- [Foundry Documentation](https://book.getfoundry.sh/)
- [Foundry Linting Guide](https://getfoundry.sh/forge/linting/) - Code quality and gas optimization

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
