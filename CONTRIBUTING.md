# Contributing Guide

Thank you for your interest in the Lighter EVM Contract project! This guide will help you understand how to contribute to the project.

## 📋 Table of Contents

- [Code of Conduct](#code-of-conduct)
- [How to Contribute](#how-to-contribute)
- [Development Environment Setup](#development-environment-setup)
- [Code Standards](#code-standards)
- [Commit Standards](#commit-standards)
- [Pull Request Process](#pull-request-process)
- [Testing Requirements](#testing-requirements)
- [Documentation Contributions](#documentation-contributions)

## 📜 Code of Conduct

This project follows the [Contributor Covenant Code of Conduct](https://www.contributor-covenant.org/). When participating in the project, please:

- Use friendly and inclusive language
- Respect different viewpoints and experiences
- Accept constructive criticism gracefully
- Focus on what is best for the community
- Show empathy towards other community members

## 🤝 How to Contribute

### Reporting Bugs

If you discover a bug, please:

1. **Check for Existing Issues**
   - Search in [Issues](https://github.com/lighterim/lighter-evm-contract/issues)
   - If one exists, please add information to the existing issue

2. **Create a New Bug Report**
   - Use the [Bug Report template](.github/ISSUE_TEMPLATE/bug_report.md)
   - Provide a clear problem description
   - Include reproduction steps
   - Attach relevant logs or error messages

3. **Bug Report Should Include**:
   - Problem description
   - Reproduction steps
   - Expected behavior
   - Actual behavior
   - Environment information (Solidity version, Foundry version, etc.)
   - Relevant code snippets (if applicable)

### Suggesting New Features

If you have a feature suggestion, please:

1. **Check for Existing Discussions**
   - Search in [Discussions](https://github.com/lighterim/lighter-evm-contract/discussions)
   - Check if there are similar feature requests

2. **Create a Feature Request**
   - Use the [Feature Request template](.github/ISSUE_TEMPLATE/feature_request.md)
   - Clearly describe the feature requirement and use cases
   - Explain why this feature is valuable to the project

3. **Feature Request Should Include**:
   - Feature description
   - Use cases
   - Expected behavior
   - Possible implementation approach
   - Relevant references (if applicable)

### Submitting Code

1. **Fork the repository**
2. **Create a feature branch**: `git checkout -b feature/your-feature-name`
3. **Develop your changes**
4. **Write tests**
5. **Ensure tests pass**
6. **Commit your code** (following commit standards)
7. **Create a Pull Request**

## 🛠️ Development Environment Setup

### 1. Clone the Repository

```bash
git clone https://github.com/lighterim/lighter-evm-contract.git
cd lighter-evm-contract
```

### 2. Install Dependencies

```bash
# Install Foundry
curl -L https://foundry.paradigm.xyz | bash
foundryup

# Install Foundry dependencies
forge install

# Install Node.js dependencies (optional)
npm install
```

### 3. Configure Environment

```bash
# Copy environment variable template
cp .env.example .env

# Edit .env file and fill in necessary configuration
# At minimum, configure RPC_URL for testing
```

### 4. Verify Installation

```bash
# Compile contracts
forge build

# Run tests
forge test
```

## 📝 Code Standards

### Solidity Code Standards

1. **Naming Conventions**
   - Contract names: `PascalCase`
   - Function names: `camelCase`
   - Constants: `UPPER_SNAKE_CASE`
   - Private variables: `_camelCase`

2. **Code Formatting**
   - Use `forge fmt` to format code
   - Line length: 120 characters (configured in `foundry.toml`)
   - Indentation: 4 spaces

3. **Comment Standards**
   - All public functions must have NatSpec comments
   - Complex logic requires inline comments
   - Use `///` for single-line comments, `/** */` for multi-line comments

4. **Example**:

```solidity
/// @notice Execute transaction intent
/// @param payer Payer address
/// @param tokenPermissionsHash Hash of TokenPermissions
/// @param escrowTypedHash EIP-712 hash of EscrowParams
/// @param intentTypeHash EIP-712 hash of IntentParams
/// @param actions Array of actions
/// @return Whether execution succeeded
function execute(
    address payer,
    bytes32 tokenPermissionsHash,
    bytes32 escrowTypedHash,
    bytes32 intentTypeHash,
    bytes[] calldata actions
) public payable override returns (bool) {
    // Implementation logic
}
```

### JavaScript/TypeScript Code Standards

1. **Use ESLint and Prettier**
2. **Follow Airbnb JavaScript Style Guide**
3. **Use TypeScript type annotations**

## 📤 Commit Standards

We use [Conventional Commits](https://www.conventionalcommits.org/) specification:

### Commit Format

```
<type>(<scope>): <subject>

<body>

<footer>
```

### Type Categories

- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation update
- `style`: Code formatting (does not affect functionality)
- `refactor`: Code refactoring
- `test`: Test related
- `chore`: Build/tool related
- `perf`: Performance optimization
- `ci`: CI configuration

### Examples

```bash
# New feature
feat(take-intent): add support for bulk sell intent

# Bug fix
fix(escrow): fix reentrancy vulnerability in release function

# Documentation update
docs(readme): update installation instructions

# Test
test(take-intent): add test case for expired intent
```

## 🔄 Pull Request Process

### 1. Preparation

- [ ] Fork repository and sync latest code
- [ ] Create feature branch
- [ ] Ensure all tests pass
- [ ] Update relevant documentation

### 2. Create PR

1. **Push branch to Fork**
   ```bash
   git push origin feature/your-feature-name
   ```

2. **Create Pull Request on GitHub**
   - Use clear title and description
   - Link related issues (using `Closes #123`)
   - Add labels (e.g., `enhancement`, `bug`, `documentation`)

3. **PR Description Template**:

```markdown
## Description of Changes
Briefly describe the changes in this PR

## Type of Change
- [ ] Bug fix
- [ ] New feature
- [ ] Refactoring
- [ ] Documentation update
- [ ] Other

## Testing
- [ ] Added test cases
- [ ] All tests pass
- [ ] Tested relevant scenarios

## Checklist
- [ ] Code follows project standards
- [ ] Updated relevant documentation
- [ ] Added necessary comments
- [ ] No new warnings introduced
- [ ] Backward compatibility considered
```

### 3. Code Review

- Maintainers will review your code
- Please respond to comments promptly and make modifications
- Keep PR updated (rebase or merge main branch)

### 4. Merge

- After PR passes review, maintainers will merge the code
- Your contribution will be recorded in project history

## ✅ Testing Requirements

### Unit Tests

All new features must include test cases:

```solidity
function testNewFeature() public {
    // Arrange
    // Act
    // Assert
}
```

### Test Coverage

- New code should have >= 80% test coverage
- Critical paths must have 100% coverage

### Running Tests

```bash
# Run all tests
forge test

# Run specific test
forge test --match-test testNewFeature

# View coverage
forge coverage
```

### Integration Tests

For complex features involving multiple contracts, integration tests should be added.

## 📚 Documentation Contributions

### Code Documentation

- All public functions must have NatSpec comments
- Complex algorithms require detailed explanations
- Reference existing code comment style

### Project Documentation

- README.md: Project overview and quick start
- CONTRIBUTING.md: Contribution guide (this document)
- Other documentation: Add according to feature modules

### Documentation Format

- Use Markdown format
- Maintain consistent style
- Add appropriate code examples
- Use clear headings and table of contents

## 🔍 Code Review Checklist

Before submitting PR, please self-check:

### Security

- [ ] No reentrancy attack risks
- [ ] Integer overflow/underflow handled
- [ ] Access control correctly implemented
- [ ] Input validation sufficient
- [ ] No hardcoded private keys or sensitive information

### Code Quality

- [ ] Code follows project standards
- [ ] Functions have single responsibility
- [ ] Variable names are clear
- [ ] No duplicate code
- [ ] Error handling is complete

### Testing

- [ ] Test coverage is sufficient
- [ ] Edge cases tested
- [ ] Error cases tested
- [ ] Test code is clear and understandable

### Gas Optimization

- [ ] Avoid unnecessary storage operations
- [ ] Use appropriate variable types
- [ ] Optimize loops and conditionals

## 🐛 Debugging Tips

### Foundry Debugging

```bash
# Verbose output
forge test -vvvvv

# Trace specific function
forge test --debug <function_name>

# Use console.log
import "forge-std/console.sol";
console.log("Debug value:", value);
```

### Common Issues

1. **Compilation Errors**
   - Check if Solidity version matches
   - Confirm all dependencies are installed
   - Run `forge clean` and recompile

2. **Test Failures**
   - Check environment variable configuration
   - Confirm RPC node is available (for fork tests)
   - View detailed logs with `-vvvvv`

3. **Gas Estimation Failures**
   - Check if contract logic is correct
   - Confirm all parameters are valid
   - Check revert reason in error message

## 📞 Getting Help

If you encounter problems during contribution:

1. **Check Documentation**: First consult project documentation and code comments
2. **Search Issues**: Check if similar issues exist
3. **Create Issue**: Describe your problem and attempted solutions
4. **Participate in Discussions**: Ask questions in Discussions

## 🎉 Contributors

Thank you to all developers who contribute to the project!

---

**Thank you again for your contribution!** 🚀
