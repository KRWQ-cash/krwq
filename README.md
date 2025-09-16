# KRWT Token Contract

A Solidity implementation of an ERC20 token with minting capabilities, built using Foundry and OpenZeppelin contracts.

## Overview

The KRWT token is an ERC20-compliant token that extends standard functionality with:

- **ERC20Permit**: EIP-2612 permit functionality for gasless approvals
- **ERC20Burnable**: Ability to burn tokens
- **Ownable2Step**: Two-step ownership transfer for enhanced security
- **Minter Management**: Owner-controlled list of authorized minters
- **Proxy Support**: Upgradeable via TransparentUpgradeableProxy

## Features

### Core Functionality
- Standard ERC20 token operations (transfer, approve, etc.)
- Permit-based approvals (EIP-2612) for gasless transactions
- Token burning capabilities
- Two-step ownership transfer for security

### Minter System
- Owner can add/remove authorized minters
- Minters can mint new tokens to any address
- Minters can burn tokens from addresses with sufficient allowance
- Events emitted for all minter operations

### Upgradeability
- Deployed behind a TransparentUpgradeableProxy
- ProxyAdmin for upgrade management
- Initialize function for proxy deployment

## Project Structure

```
├── src/
│   ├── KRWT.sol                 # Main token contract
│   └── KRWTUsdcMinter.sol       # USDC-based minter/redeemer
├── script/
│   └── DeployKRWT.s.sol         # Deployment script
├── test/
│   ├── KRWT.t.sol               # Token tests
│   └── KRWTUsdcMinter.t.sol     # Minter tests
├── lib/                         # Dependencies (OpenZeppelin, Forge-std)
├── foundry.toml                 # Foundry configuration
└── .env.example                 # Environment variables template
```

## Setup

### Prerequisites
- [Foundry](https://book.getfoundry.sh/getting-started/installation)
- Git

### Installation
```bash
# Clone the repository
git clone <repository-url>
cd ikrw-contracts

# Install dependencies
forge install

# Copy environment template
cp .env.example .env
# Edit .env with your values
```

### Environment Variables
Create a `.env` file with:
```bash
PRIVATE_KEY=your_private_key_here
TOKEN_NAME=KRWT
TOKEN_SYMBOL=KRWT
# RPC_URL=https://your-rpc-url-here  # Optional
```

## Development Commands

### Build
```bash
forge build
```

### Test
```bash
# Run all tests
forge test

# Run with gas reporting
forge test --gas-report

# Run specific test
forge test --match-test testMinterMint

# Run with verbosity
forge test -vvv
```

### Code Quality
```bash
# Format code
forge fmt

# Check for issues
forge build --force

# Run linter
forge build --force
```

### Gas Analysis
```bash
# Generate gas snapshots
forge snapshot

# Compare gas usage
forge snapshot --diff
```

## Deployment

### Local Development
```bash
# Start local node
anvil

# Deploy to local network
forge script script/DeployKRWT.s.sol --rpc-url http://localhost:8545 --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 --broadcast
```

### Testnet/Mainnet
```bash
# Deploy to testnet
forge script script/DeployKRWT.s.sol --rpc-url $RPC_URL --private-key $PRIVATE_KEY --broadcast --verify

# Deploy to mainnet (be careful!)
forge script script/DeployKRWT.s.sol --rpc-url $RPC_URL --private-key $PRIVATE_KEY --broadcast --verify --slow
```

## Contract Interaction

### Using Cast
```bash
# Check token balance
cast call <TOKEN_ADDRESS> "balanceOf(address)" <ADDRESS>

# Check total supply
cast call <TOKEN_ADDRESS> "totalSupply()"

# Check if address is minter
cast call <TOKEN_ADDRESS> "minters(address)" <ADDRESS>

# Get token name
cast call <TOKEN_ADDRESS> "name()"
```

### Owner Functions
```bash
# Add minter (owner only)
cast send <TOKEN_ADDRESS> "addMinter(address)" <MINTER_ADDRESS> --private-key $OWNER_PRIVATE_KEY

# Remove minter (owner only)
cast send <TOKEN_ADDRESS> "removeMinter(address)" <MINTER_ADDRESS> --private-key $OWNER_PRIVATE_KEY
```

### Minter Functions
```bash
# Mint tokens (minter only)
cast send <TOKEN_ADDRESS> "minterMint(address,uint256)" <RECIPIENT_ADDRESS> <AMOUNT> --private-key $MINTER_PRIVATE_KEY

# Burn tokens from address (minter only)
cast send <TOKEN_ADDRESS> "minterBurnFrom(address,uint256)" <ADDRESS> <AMOUNT> --private-key $MINTER_PRIVATE_KEY
```

## Testing

The test suite covers:
- ✅ Constructor and initialization
- ✅ Owner functions (add/remove minters)
- ✅ Minter functions (mint/burn)
- ✅ Access control (onlyOwner, onlyMinters)
- ✅ ERC20Permit functionality
- ✅ Event emissions
- ✅ Edge cases and error conditions

Run tests with:
```bash
forge test -vvv
```

## Security Considerations

- **Ownership**: Use two-step ownership transfer for security
- **Minters**: Only add trusted addresses as minters
- **Upgrades**: Proxy upgrades should be carefully planned
- **Private Keys**: Never commit private keys to version control

## License

This project is licensed under the Unlicense - see the SPDX-License-Identifier in source files.

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests for new functionality
5. Ensure all tests pass
6. Submit a pull request

## Support

For questions or issues, please open an issue on the repository.