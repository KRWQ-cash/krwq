# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

KRWT (Korean Won Token) is a Solidity smart contract system implementing a stablecoin with ERC4626 vault functionality, Chainlink oracle integration, and LayerZero cross-chain bridging. The codebase uses Foundry for development and testing.

**Key Technical Details:**
- Solidity version: ^0.8.24
- Contract version: 0.2.8
- Framework: Foundry (forge, anvil, cast)
- License: MIT
- Compilation: Via IR optimization enabled
- Dependencies: OpenZeppelin contracts, LayerZero OFT v2, Chainlink oracles

## Build & Test Commands

```bash
# Build contracts
forge build

# Run all tests
forge test

# Run tests with verbosity (useful for debugging)
forge test -vvv

# Run specific test file
forge test --match-path test/KRWT.t.sol

# Run specific test by name
forge test --match-test testMinterMint

# Run with gas reporting
forge test --gas-report

# Generate gas snapshots
forge snapshot

# Compare gas usage against snapshot
forge snapshot --diff

# Format code
forge fmt

# Fork testing (requires RPC URL in env)
forge test --match-path test/ForkTest.t.sol --fork-url $RPC_URL
```

## Deployment Commands

The project deploys across two chains: **Ethereum** (KRWT token, Custodian, OFT Adapter) and **Base** (OFT token).

### Local Development
```bash
# Start local anvil node
anvil

# Deploy to local node (use default anvil private key)
forge script script/DeployKRWT.s.sol \
  --rpc-url http://localhost:8545 \
  --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
  --broadcast
```

### Deployment Order for Production

**1. Deploy OFT on Base:**
```bash
forge script script/DeployOFT.s.sol \
  --rpc-url $BASE_RPC_URL \
  --private-key $PRIVATE_KEY \
  --broadcast --verify -vvvv
```

**2. Deploy KRWT + Custodian + Adapter on Ethereum:**
```bash
forge script script/DeployAll.s.sol \
  --rpc-url $ETH_RPC_URL \
  --private-key $PRIVATE_KEY \
  --broadcast --verify -vvvv
```

**3. Configure LayerZero on Ethereum:**
```bash
forge script script/DeployConfig.s.sol \
  --rpc-url $ETH_RPC_URL \
  --private-key $PRIVATE_KEY \
  --broadcast -vvvv
```

**4. Configure LayerZero on Base:**
```bash
forge script script/DeployConfigOFT.s.sol \
  --rpc-url $BASE_RPC_URL \
  --private-key $PRIVATE_KEY \
  --broadcast -vvvv
```

**5. Transfer ownership (optional):**
- Use `script/TransferOwnershipETH.s.sol` for Ethereum
- Use `script/TransferOwnershipBase.s.sol` for Base

### Cross-Chain Token Transfers
```bash
# Send from Ethereum to Base
forge script script/SendKRWT.s.sol \
  --rpc-url $ETH_RPC_URL \
  --private-key $PRIVATE_KEY \
  --broadcast -vvvv

# Send from Base to Ethereum
forge script script/SendKRWT.s.sol \
  --rpc-url $BASE_RPC_URL \
  --private-key $PRIVATE_KEY \
  --broadcast -vvvv
```

## High-Level Architecture

### Multi-Chain Design Pattern

The system uses a **hub-and-spoke architecture** across Ethereum and Base chains:

- **Ethereum (Hub)**: Primary chain hosting the main KRWT token, ERC4626 Custodian vault (with/without oracle), and the OFT Adapter
- **Base (Spoke)**: Secondary chain hosting the bridged OFT token implementation

**Cross-chain flow:**
1. User deposits assets into KRWTCustodian on Ethereum → receives KRWT shares
2. User can bridge KRWT from Ethereum → Base using LayerZero OFT Adapter/OFT pair
3. The OFT Adapter on Ethereum locks KRWT, LayerZero mints equivalent on Base OFT
4. Reverse flow burns on Base, unlocks on Ethereum

### Core Contract Relationships

```
KRWT.sol (ERC20 + Permit + Burnable)
    ↓ (is minter for)
KRWTCustodian.sol (ERC4626-like vault)
    ↓ (extended by)
KRWTCustodianWithOracle.sol (adds Chainlink price feeds)

KRWT.sol
    ↓ (wrapped by)
KRWTOFTAdapter.sol (Ethereum) ←→ LayerZero ←→ KRWTOFT.sol (Base)
```

### Key Design Patterns

**1. Proxy Pattern for Upgradeability:**
- KRWT uses TransparentUpgradeableProxy (owner acts as proxy admin, no separate ProxyAdmin)
- KRWTOFT and KRWTOFTAdapter use LayerZero's upgradeable OFT pattern
- Contracts have both `constructor` and `initialize()` functions for proxy compatibility

**2. Minter Pattern:**
- KRWT maintains a `mapping(address => bool) minters` and `address[] mintersArray`
- Only authorized minters can call `minterMint()` and `minterBurnFrom()`
- KRWTCustodian is added as a minter to enable vault deposit/redeem operations
- Owner manages minters via `addMinter()` and `removeMinter()`

**3. ERC4626-Style Vault (not fully compliant):**
- KRWTCustodian implements deposit/mint/withdraw/redeem pattern
- Includes configurable mint and redeem fees (basis points)
- Enforces mint cap to limit total KRWT issuance
- Asset recovery function for owner to rescue stuck tokens
- **Important**: Uses KRWT shares directly (not a separate vault token)

**4. Oracle Integration:**
- KRWTCustodianWithOracle extends base custodian with Chainlink price feeds
- Validates oracle freshness via `maxOracleDelay` parameter
- Overrides `_convertToShares()` and `_convertToAssets()` to use oracle prices
- Enables price-based conversions rather than 1:1 decimal-adjusted conversions

**5. LayerZero OFT V2:**
- KRWTOFT (Base): Native OFT implementation with upgradeable pattern
- KRWTOFTAdapter (Ethereum): Adapter pattern wrapping existing KRWT token
- Both use `OAppCore` for peer configuration and message libraries
- Owner configures trusted peers via `setPeer()` and enforced options via `setEnforcedOptions()`

### Storage and Initialization

**KRWT initialization quirk:**
- `initialize()` directly writes to storage slots 3 and 4 for ERC20 name/symbol (see KRWT.sol:65-66)
- This is for proxy compatibility - avoids constructor storage writes
- Owner check: `require(owner() == address(0), "Already initialized")`

**Custodian initialization:**
- `wasInitialized` flag prevents double-initialization
- Constructor sets immutable token addresses and decimals
- `initialize()` sets owner, fees, and mint cap

**OFT initialization:**
- Constructor calls `_disableInitializers()` to prevent implementation initialization
- Proxy calls `initialize()` with name, symbol, and delegate address
- Delegate address receives both ownership and LayerZero configuration rights

### Fee and Cap Mechanisms

**Fees (18 decimals, basis points):**
- `mintFee`: Applied on deposit/mint operations (deducted from assets before conversion)
- `redeemFee`: Applied on withdraw/redeem operations (deducted from assets after conversion)
- Example: 50 = 0.5% fee (50 / 1e18 = 0.00005)

**Mint Cap:**
- Enforced in KRWTCustodian via `krwtMinted` accounting
- Tracks total KRWT minted through vault operations
- `_deposit()` reverts if `krwtMinted + shares > mintCap`
- `_withdraw()` decrements `krwtMinted` (safely handles underflow)

## Contract Locations

**Core contracts:**
- `src/KRWT.sol` - Main ERC20 token with minter system
- `src/KRWTCustodian.sol` - ERC4626-style vault (no oracle)
- `src/KRWTCustodianWithOracle.sol` - Oracle-enabled vault (extends Custodian)

**Bridge contracts:**
- `src/bridge/KRWTOFT.sol` - LayerZero OFT for Base chain
- `src/bridge/KRWTOFTAdapter.sol` - LayerZero OFT Adapter for Ethereum chain

**Test utilities:**
- `test/mocks/MockERC20.sol` - Mock ERC20 for testing
- `test/mocks/MockOracle.sol` - Mock Chainlink oracle
- `test/ForkTest.t.sol` - Fork testing utilities

**Scripts:**
- `script/DeployAll.s.sol` - Orchestrator script deploying KRWT + Custodian + Adapter on Ethereum
- `script/DeployOFT.s.sol` - Deploys OFT on Base
- `script/DeployConfig.s.sol` - Configures LayerZero for Ethereum Adapter
- `script/DeployConfigOFT.s.sol` - Configures LayerZero for Base OFT
- `script/SendKRWT.s.sol` - Cross-chain transfer script
- `script/utils/LZConfigUtils.sol` - LayerZero configuration helper functions

## Important Development Notes

**When modifying KRWT token:**
- Remember that `minterMint()` and `minterBurnFrom()` require caller to be in `minters` mapping
- The `mintersArray` is sparse (uses address(0) for removed entries) - iterate carefully
- `initialize()` writes directly to storage slots - be cautious with storage layout changes

**When modifying Custodian contracts:**
- Always check `convertToShares()` and `convertToAssets()` are inverse operations
- Oracle version overrides these functions - don't call super implementation
- Fees are applied in `preview*` functions, not in internal conversion helpers
- `_deposit()` and `_withdraw()` use ReentrancyGuard - don't add cross-function reentrancy vulnerabilities

**When modifying Bridge contracts:**
- LayerZero V2 uses `MessagingFee` struct (nativeFee + lzTokenFee)
- Always check `approvalRequired()` on Adapter before calling `send()`
- `enforceOptions()` should align with executor gas limits in `SendParam`
- Peer addresses are bytes32 (use `addressToBytes32()` helper)

**Testing best practices:**
- Use `-vvv` for stack traces when tests fail
- Fork tests require RPC_URL in environment
- BridgeTest.t.sol uses mock LayerZero endpoint - for real testing, use fork tests
- Gas snapshots track optimization progress - commit them to track changes

**Solidity version and compiler:**
- Must use solc 0.8.24 (specified in foundry.toml)
- `via_ir = true` enables IR-based compilation (better optimization, longer compile times)
- Optimizer runs = 200 (balance between deployment and runtime costs)

## Environment Variables

Required for deployment scripts:

```bash
# Private key (no 0x prefix)
PRIVATE_KEY=

# Token configuration
TOKEN_NAME="Korean Won Token"
TOKEN_SYMBOL="KRWT"

# Custodian configuration
CUSTODIAN_TOKEN_ADDRESS=        # Underlying asset address
CUSTODIAN_ORACLE_ADDRESS=       # Chainlink oracle address (for WithOracle variant)
MAX_ORACLE_DELAY=               # Max staleness in seconds
MINT_CAP=                       # Max KRWT mintable (wei units)
MINT_FEE=                       # Basis points (e.g., 50 for 0.5%)
REDEEM_FEE=                     # Basis points

# LayerZero configuration
LZ_ENDPOINT=                    # Ethereum LayerZero endpoint
LZ_ENDPOINT_BASE=               # Base LayerZero endpoint
ETH_EID=                        # Ethereum endpoint ID
BASE_EID=                       # Base endpoint ID
ETH_SEND_LIB=                   # Ethereum send library
ETH_RECEIVE_LIB=                # Ethereum receive library
BASE_SEND_LIB=                  # Base send library
BASE_RECEIVE_LIB=               # Base receive library

# Ownership
OWNER_ETH=                      # Final owner address on Ethereum
OWNER_BASE=                     # Final owner address on Base

# RPC URLs
ETH_RPC_URL=
BASE_RPC_URL=

# Verification
ETHERSCAN_API_KEY=
```

## Common Cast Commands

```bash
# Check token balance
cast call <TOKEN_ADDRESS> "balanceOf(address)" <ADDRESS> --rpc-url $RPC_URL

# Check total supply
cast call <TOKEN_ADDRESS> "totalSupply()" --rpc-url $RPC_URL

# Check if address is minter
cast call <TOKEN_ADDRESS> "minters(address)" <ADDRESS> --rpc-url $RPC_URL

# Add minter (owner only)
cast send <TOKEN_ADDRESS> "addMinter(address)" <MINTER_ADDRESS> \
  --rpc-url $RPC_URL --private-key $PRIVATE_KEY

# Deposit assets to vault
cast send <VAULT_ADDRESS> "deposit(uint256,address)" <AMOUNT> <RECEIVER> \
  --rpc-url $RPC_URL --private-key $PRIVATE_KEY

# Check vault preview functions
cast call <VAULT_ADDRESS> "previewDeposit(uint256)" <AMOUNT> --rpc-url $RPC_URL
cast call <VAULT_ADDRESS> "previewMint(uint256)" <SHARES> --rpc-url $RPC_URL
cast call <VAULT_ADDRESS> "previewWithdraw(uint256)" <AMOUNT> --rpc-url $RPC_URL
cast call <VAULT_ADDRESS> "previewRedeem(uint256)" <SHARES> --rpc-url $RPC_URL

# Transfer ownership (2-step process)
cast send <CONTRACT> "transferOwnership(address)" <NEW_OWNER> \
  --rpc-url $RPC_URL --private-key $PRIVATE_KEY
# Then new owner must accept:
cast send <CONTRACT> "acceptOwnership()" \
  --rpc-url $RPC_URL --private-key $NEW_OWNER_PRIVATE_KEY
```

## Remappings

The project uses custom import paths (configured in foundry.toml):

```
@openzeppelin/contracts/          → lib/openzeppelin-contracts/contracts/
@openzeppelin/contracts-upgradeable/ → node_modules/@openzeppelin/contracts-upgradeable/
@layerzerolabs/                   → node_modules/@layerzerolabs/
forge-std/                        → lib/forge-std/src/
```

When importing, use these prefixes rather than relative paths.
