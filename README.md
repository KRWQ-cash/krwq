# 🪙 KRWT Token Contracts

A comprehensive Solidity implementation of Korean Won Token (KRWT) with advanced features including ERC4626 vault functionality, LayerZero cross-chain bridging, and Oracle integration. Built using Foundry and OpenZeppelin contracts.

## 🌟 Overview

The KRWT ecosystem consists of multiple interconnected contracts that provide:

- **🪙 KRWT Token**: ERC20-compliant token with minting capabilities
- **🏦 Custodian Vault**: ERC4626-compliant vault for asset management
- **📊 Oracle Integration**: Chainlink price feed integration for accurate pricing
- **🌉 Cross-Chain Bridge**: LayerZero-powered cross-chain token transfers

## 🏗️ Architecture

### Core Contracts

#### 🪙 KRWT Token (`KRWT.sol`)
- **ERC20Permit**: EIP-2612 permit functionality for gasless approvals
- **ERC20Burnable**: Ability to burn tokens
- **Ownable2Step**: Two-step ownership transfer for enhanced security
- **Minter Management**: Owner-controlled list of authorized minters
- **Proxy Support**: Upgradeable via TransparentUpgradeableProxy

#### 🏦 KRWT Custodian (`KRWTCustodian.sol`)
- **ERC4626 Compliance**: Standard vault interface for asset management
- **Mint/Redeem Operations**: Deposit underlying assets to mint KRWT shares
- **Fee Management**: Configurable mint and redeem fees
- **Mint Cap**: Configurable maximum minting limit
- **Asset Recovery**: Owner can recover stuck tokens

#### 📊 KRWT Custodian with Oracle (`KRWTCustodianWithOracle.sol`)
- **Chainlink Integration**: Real-time price feeds for accurate conversions
- **Oracle Validation**: Staleness checks and maximum delay enforcement
- **Price-Based Conversions**: Dynamic asset-to-share conversions based on oracle prices

### Bridge Contracts

#### 🌉 KRWT OFT (`KRWTOFT.sol`)
- **LayerZero Integration**: Cross-chain token transfers
- **Upgradeable**: Built on LayerZero's upgradeable OFT standard
- **Gas Efficient**: Optimized for cross-chain operations

#### 🔗 KRWT OFT Adapter (`KRWTOFTAdapter.sol`)
- **Token Wrapping**: Wraps existing KRWT tokens for cross-chain transfers
- **Backward Compatibility**: Works with existing token deployments
- **Flexible Integration**: Can be deployed alongside existing tokens

## 📁 Project Structure

```
├── 📂 src/
│   ├── 🪙 KRWT.sol                           # Main token contract
│   ├── 🏦 KRWTCustodian.sol                  # ERC4626 vault contract
│   ├── 📊 KRWTCustodianWithOracle.sol        # Oracle-enabled vault
│   ├── 📂 bridge/
│   │   ├── 🌉 KRWTOFT.sol                    # LayerZero OFT contract
│   │   └── 🔗 KRWTOFTAdapter.sol             # LayerZero OFT Adapter
│   └── 📂 interfaces/
│       └── 📡 AggregatorV3Interface.sol      # Chainlink oracle interface
├── 📂 script/
│   ├── 🚀 DeployKRWT.s.sol                   # Token deployment script
│   ├── 🏦 DeployKRWTCustodianWithOracle.s.sol # Oracle vault deployment
│   ├── 🌉 DeployOFT.s.sol                    # OFT deployment script
│   └── 🔗 DeployOFTAdapter.s.sol             # OFT Adapter deployment
├── 📂 test/
│   ├── 🧪 KRWT.t.sol                         # Token tests
│   ├── 🏦 KRWTCustodian.t.sol                # Vault tests
│   ├── 📊 KRWTCustodianWithOracle.t.sol      # Oracle vault tests
│   └── 📂 mocks/
│       ├── 🪙 MockERC20.sol                  # Mock ERC20 token
│       └── 📡 MockOracle.sol                 # Mock Chainlink oracle
├── 📂 lib/                                   # Dependencies
├── ⚙️ foundry.toml                           # Foundry configuration
└── 📦 package.json                           # Node.js dependencies
```

## 🚀 Quick Start

### Prerequisites
- [Foundry](https://book.getfoundry.sh/getting-started/installation) 🔨
- Git 📋
- Node.js (for LayerZero dependencies) 📦

### Installation
```bash
# Clone the repository
git clone https://github.com/IQAIcom/ikrw_contracts.git
cd ikrw-contracts

# Install Foundry dependencies
forge install

# Install Node.js dependencies
npm install
```

### Environment Setup
Create a `.env` file with your configuration:
```bash
# Required
PRIVATE_KEY=your_private_key_here
TOKEN_NAME=Korean Won Token
TOKEN_SYMBOL=KRWT

# Optional
RPC_URL=https://your-rpc-url-here
ETHERSCAN_API_KEY=your_etherscan_api_key
```

## 🛠️ Development Commands

### Build & Test
```bash
# 🔨 Build contracts
forge build

# 🧪 Run all tests
forge test

# 📊 Run with gas reporting
forge test --gas-report

# 🎯 Run specific test
forge test --match-test testMinterMint

# 🔍 Run with verbosity
forge test -vvv
```

### Code Quality
```bash
# 🎨 Format code
forge fmt

# 🔍 Check for issues
forge build --force

# 📸 Generate gas snapshots
forge snapshot

# 📈 Compare gas usage
forge snapshot --diff
```

## 🚀 Deployment

### Local Development
```bash
# 🏃 Start local node
anvil

# 🚀 Deploy to local network
forge script script/DeployKRWT.s.sol --rpc-url http://localhost:8545 --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 --broadcast
```

### Testnet/Mainnet
```bash
# 🧪 Deploy to testnet
forge script script/DeployKRWT.s.sol --rpc-url $RPC_URL --private-key $PRIVATE_KEY --broadcast --verify

# 🌐 Deploy to mainnet (be careful!)
forge script script/DeployKRWT.s.sol --rpc-url $RPC_URL --private-key $PRIVATE_KEY --broadcast --verify --slow
```

## 💡 Key Features

### 🪙 Token Features
- ✅ **ERC20 Compliance**: Standard token functionality
- ✅ **Gasless Approvals**: EIP-2612 permit support
- ✅ **Controlled Minting**: Owner-managed minter system
- ✅ **Token Burning**: Burn tokens from any address (with allowance)
- ✅ **Upgradeable**: Proxy pattern for future upgrades

### 🏦 Vault Features
- ✅ **ERC4626 Standard**: Industry-standard vault interface
- ✅ **Asset Management**: Deposit/withdraw underlying assets
- ✅ **Fee System**: Configurable mint and redeem fees
- ✅ **Mint Caps**: Prevent unlimited minting
- ✅ **Oracle Pricing**: Real-time price-based conversions

### 🌉 Bridge Features
- ✅ **Cross-Chain**: LayerZero-powered transfers
- ✅ **Gas Efficient**: Optimized for multi-chain operations
- ✅ **Upgradeable**: Future-proof architecture
- ✅ **Flexible**: Both native and adapter implementations

## 🔧 Contract Interaction

### Using Cast
```bash
# 💰 Check token balance
cast call <TOKEN_ADDRESS> "balanceOf(address)" <ADDRESS>

# 📊 Check total supply
cast call <TOKEN_ADDRESS> "totalSupply()"

# 🔍 Check if address is minter
cast call <TOKEN_ADDRESS> "minters(address)" <ADDRESS>

# 🏷️ Get token name
cast call <TOKEN_ADDRESS> "name()"
```

### Owner Functions
```bash
# ➕ Add minter (owner only)
cast send <TOKEN_ADDRESS> "addMinter(address)" <MINTER_ADDRESS> --private-key $OWNER_PRIVATE_KEY

# ➖ Remove minter (owner only)
cast send <TOKEN_ADDRESS> "removeMinter(address)" <MINTER_ADDRESS> --private-key $OWNER_PRIVATE_KEY
```

### Vault Operations
```bash
# 💰 Deposit assets to mint shares
cast send <VAULT_ADDRESS> "deposit(uint256,address)" <AMOUNT> <RECEIVER> --private-key $PRIVATE_KEY

# 🔄 Redeem shares for assets
cast send <VAULT_ADDRESS> "redeem(uint256,address,address)" <SHARES> <RECEIVER> <OWNER> --private-key $PRIVATE_KEY
```

## 🧪 Testing

The comprehensive test suite covers:

- ✅ **Token Operations**: Minting, burning, transfers
- ✅ **Access Control**: Owner and minter permissions
- ✅ **Vault Functions**: Deposit, withdraw, redeem operations
- ✅ **Oracle Integration**: Price feed validation and updates
- ✅ **Bridge Operations**: Cross-chain transfer simulations
- ✅ **Edge Cases**: Error conditions and boundary testing
- ✅ **Gas Optimization**: Efficient operation costs

Run tests with:
```bash
forge test -vvv
```

## 🔒 Security Considerations

- **🔐 Ownership**: Use two-step ownership transfer for security
- **👥 Minters**: Only add trusted addresses as minters
- **🔄 Upgrades**: Proxy upgrades should be carefully planned
- **🔑 Private Keys**: Never commit private keys to version control
- **📊 Oracle Security**: Validate oracle data freshness and accuracy
- **💰 Fee Management**: Set reasonable fees to prevent abuse

## 📋 Dependencies

### Foundry Dependencies
- **OpenZeppelin Contracts**: Industry-standard security libraries
- **Forge Standard Library**: Testing and development utilities

### Node.js Dependencies
- **@layerzerolabs/oapp-evm-upgradeable**: LayerZero OApp framework
- **@layerzerolabs/oft-evm**: LayerZero OFT implementation
- **@layerzerolabs/oft-evm-upgradeable**: Upgradeable OFT contracts
- **@openzeppelin/contracts-upgradeable**: Upgradeable OpenZeppelin contracts

## 📄 License

This project is licensed under the MIT License - see the SPDX-License-Identifier in source files.

## 🤝 Contributing

1. 🍴 Fork the repository
2. 🌿 Create a feature branch
3. ✏️ Make your changes
4. 🧪 Add tests for new functionality
5. ✅ Ensure all tests pass
6. 📤 Submit a pull request

## 🆘 Support

For questions or issues, please open an issue on the [GitHub repository](https://github.com/IQAIcom/ikrw_contracts/issues).

## 🔗 Links

- **Repository**: [GitHub](https://github.com/IQAIcom/ikrw_contracts)
- **Issues**: [GitHub Issues](https://github.com/IQAIcom/ikrw_contracts/issues)
- **LayerZero**: [LayerZero Documentation](https://docs.layerzero.network/)
- **OpenZeppelin**: [OpenZeppelin Contracts](https://docs.openzeppelin.com/contracts/)
- **Foundry**: [Foundry Book](https://book.getfoundry.sh/)

---

Made with ❤️ by the IQAI team