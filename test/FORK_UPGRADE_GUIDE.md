# Fork Upgrade Test Guide: KRWT to KRWQ

This guide explains how to test upgrading the KRWT implementation to KRWQ using a mainnet fork.

## Overview

The `ForkUpgradeKRWTtoKRWQ.t.sol` test file simulates upgrading an existing KRWT deployment on Ethereum mainnet to the new KRWQ implementation. This is done by:

1. Forking the current mainnet state
2. Deploying a new KRWQ implementation contract
3. Upgrading the existing TransparentUpgradeableProxy to point to the new implementation
4. Verifying state preservation and functionality

## Prerequisites

1. **RPC URL**: You need an Ethereum mainnet RPC URL. Update the `FORK_RPC_URL` constant in the test file.
2. **Deployed KRWT Address**: Update the `KRWT_PROXY` constant with the actual mainnet proxy address.
3. **Foundry**: Ensure you have Foundry installed (`forge`, `cast`, `anvil`).

## Configuration

### Update Test Constants

In `test/ForkUpgradeKRWTtoKRWQ.t.sol`:

```solidity
// Update this with your mainnet RPC URL
string constant FORK_RPC_URL = "https://eth-mainnet.g.alchemy.com/v2/YOUR_API_KEY";

// Update this with the actual KRWT proxy address on mainnet
address constant KRWT_PROXY = 0xYourKRWTProxyAddress;
```

### Environment Variables

Ensure your `.env` file has the following:

```bash
# For deployment script (if deploying to actual mainnet)
PRIVATE_KEY=0x...
OWNER_ETH=0x...
TOKEN_NAME=KRWQ
TOKEN_SYMBOL=KRWQ
ETH_RPC_URL=https://eth-mainnet.g.alchemy.com/v2/YOUR_API_KEY
```

## Running the Tests

### Run All Fork Upgrade Tests

```bash
forge test --match-path test/ForkUpgradeKRWTtoKRWQ.t.sol --fork-url $ETH_RPC_URL -vv
```

### Run Specific Test Functions

#### Test Deployment Only
```bash
forge test --match-test testDeployKRWQImplementation --fork-url $ETH_RPC_URL -vvv
```

#### Test Proxy Upgrade
```bash
forge test --match-test testUpgradeProxyToKRWQ --fork-url $ETH_RPC_URL -vvv
```

#### Test Functionality After Upgrade
```bash
forge test --match-test testKRWQFunctionalityAfterUpgrade --fork-url $ETH_RPC_URL -vvv
```

#### Test Existing Minters Preservation
```bash
forge test --match-test testExistingMintersAfterUpgrade --fork-url $ETH_RPC_URL -vvv
```

#### Test Full Workflow
```bash
forge test --match-test testFullUpgradeWorkflow --fork-url $ETH_RPC_URL -vvv
```

### Verbosity Levels

- `-v`: Basic test results
- `-vv`: Show logs from tests
- `-vvv`: Show execution traces (recommended for debugging)
- `-vvvv`: Show detailed trace with stack traces
- `-vvvvv`: Show all internal calls

## Test Descriptions

### 1. `testDeployKRWQImplementation`

**Purpose**: Verifies that a new KRWQ implementation can be deployed successfully.

**What it tests**:
- Deployment of new KRWQ contract
- Implementation inherits correct name and symbol
- Implementation address is valid

**Expected outcome**: New KRWQ implementation deployed with correct parameters.

---

### 2. `testUpgradeProxyToKRWQ`

**Purpose**: Tests the actual upgrade process from KRWT to KRWQ.

**What it tests**:
- Deploying new KRWQ implementation
- Upgrading the TransparentUpgradeableProxy
- State preservation (total supply, name, symbol, decimals, owner)

**Expected outcome**: Proxy successfully upgraded, all state preserved.

---

### 3. `testKRWQFunctionalityAfterUpgrade`

**Purpose**: Verifies that KRWQ functions work correctly after upgrade.

**What it tests**:
- Adding new minters
- Minting tokens via `minterMint()`
- Burning tokens
- Transferring tokens

**Expected outcome**: All KRWQ functions work as expected post-upgrade.

---

### 4. `testExistingMintersAfterUpgrade`

**Purpose**: Ensures existing minters are preserved after upgrade.

**What it tests**:
- Reading existing minters before upgrade
- Verifying minters still authorized after upgrade
- Checking minters mapping and array

**Expected outcome**: All pre-upgrade minters remain authorized.

---

### 5. `testFullUpgradeWorkflow`

**Purpose**: Comprehensive end-to-end upgrade test.

**What it tests**:
1. Deploy new implementation
2. Record pre-upgrade state
3. Perform upgrade
4. Verify state preservation
5. Test new functionality

**Expected outcome**: Complete upgrade process succeeds with all checks passing.

---

## Understanding the Upgrade Process

### TransparentUpgradeableProxy Pattern

The KRWT token uses OpenZeppelin's `TransparentUpgradeableProxy`:

1. **Proxy Contract**: Holds all state (balances, total supply, owner, etc.)
2. **Implementation Contract**: Contains the logic (KRWT → KRWQ)
3. **Proxy Admin**: The owner address that can upgrade the implementation

### Upgrade Steps

1. **Deploy New Implementation**:
   ```solidity
   KRWQ newImpl = new KRWQ(owner, name, symbol);
   ```

2. **Upgrade Proxy** (as proxy admin):
   ```solidity
   ITransparentUpgradeableProxy(proxy).upgradeToAndCall(
       address(newImpl),
       "" // No initialization needed
   );
   ```

3. **State Preservation**:
   - All storage slots remain unchanged
   - Only the implementation address changes
   - No need to call `initialize()` again

### Storage Compatibility

Both KRWT and KRWQ must have **identical storage layouts** for safe upgrade:

```solidity
// Both contracts inherit same base contracts in same order:
contract KRWT is ERC20Permit, ERC20Burnable, Ownable2Step { ... }
contract KRWQ is ERC20Permit, ERC20Burnable, Ownable2Step { ... }

// Both have same state variables:
address[] public mintersArray;
mapping(address => bool) public minters;
```

⚠️ **Warning**: Adding new storage variables in KRWQ that aren't in KRWT can cause storage collisions. Always add new variables at the end.

---

## Deployment Script (Production)

To deploy just the new KRWQ implementation (for actual upgrade on mainnet):

```bash
# Deploy new KRWQ implementation
forge script script/DeployKRWQImplementation.s.sol \
  --rpc-url $ETH_RPC_URL \
  --private-key $PRIVATE_KEY \
  --broadcast \
  --verify \
  -vvvv
```

This script:
1. Deploys the new KRWQ implementation
2. Outputs the implementation address
3. Outputs the initialization data (for multisig usage)

**Note**: The actual upgrade (`upgradeToAndCall`) should be done through a multisig wallet or governance process, NOT through a script with a private key.

---

## Manual Upgrade Process (Production)

### Step 1: Deploy New Implementation

```bash
forge script script/DeployKRWQImplementation.s.sol \
  --rpc-url $ETH_RPC_URL \
  --private-key $PRIVATE_KEY \
  --broadcast \
  --verify \
  -vvvv
```

**Output**:
- Implementation address: `0x...`
- Initialization data (not needed for upgrade, only for new deployments)

### Step 2: Verify Implementation on Etherscan

Check the deployed implementation contract on Etherscan to ensure:
- Code is verified
- Constructor parameters are correct
- Contract is not initialized (implementation should remain uninitialized)

### Step 3: Upgrade Through Multisig

Using your multisig wallet (e.g., Gnosis Safe), call:

```
Contract: <KRWT_PROXY_ADDRESS>
Function: upgradeToAndCall(address,bytes)
Parameters:
  - newImplementation: <NEW_KRWQ_IMPLEMENTATION_ADDRESS>
  - data: 0x (empty bytes)
```

### Step 4: Verify Upgrade

Check that the proxy now points to the new implementation:

```bash
# Get implementation address
cast call $KRWT_PROXY "implementation()" --rpc-url $ETH_RPC_URL

# Verify state is preserved
cast call $KRWT_PROXY "totalSupply()" --rpc-url $ETH_RPC_URL
cast call $KRWT_PROXY "name()" --rpc-url $ETH_RPC_URL
cast call $KRWT_PROXY "symbol()" --rpc-url $ETH_RPC_URL
cast call $KRWT_PROXY "owner()" --rpc-url $ETH_RPC_URL
```

---

## Troubleshooting

### Test Fails: "Fork RPC URL not responding"

**Issue**: RPC endpoint is down or rate-limited.

**Solution**:
- Use a different RPC provider (Alchemy, Infura, Tenderly)
- Check if the URL is correct
- Ensure you're not hitting rate limits

### Test Fails: "Invalid proxy address"

**Issue**: KRWT_PROXY constant has wrong address.

**Solution**: Update the `KRWT_PROXY` constant in the test file with the correct mainnet address.

### Test Fails: "Caller is not the proxy admin"

**Issue**: Test is trying to upgrade with wrong account.

**Solution**: The test uses `vm.startPrank(proxyAdmin)` which should automatically use the correct admin. Check if the proxy owner is correctly fetched.

### State Not Preserved After Upgrade

**Issue**: Storage layout mismatch between KRWT and KRWQ.

**Solution**: Ensure both contracts have identical storage layouts. Check:
- Same inheritance order
- Same state variables in same order
- No new variables in the middle of existing ones

### Gas Estimation Failed

**Issue**: Not enough gas or transaction will revert.

**Solution**:
- Check if proxy admin has correct permissions
- Verify new implementation is valid
- Run with `-vvvv` to see detailed trace

---

## Expected Test Output

```
=== Fork Upgrade Test Setup ===
Fork RPC: https://...
Chain ID: 1
Block Number: 12345678
KRWT Proxy: 0x...
Token Owner/Proxy Admin: 0x...
Current Token Name: KRWQ
Current Token Symbol: KRWQ
Current Total Supply: 1000000

=== Deploying New KRWQ Implementation ===
New KRWQ Implementation: 0x...
Implementation Name: KRWQ
Implementation Symbol: KRWQ

=== Upgrading Proxy to KRWQ Implementation ===
Total Supply Before: 1000000
Proxy upgraded successfully!
New Implementation Address: 0x...
Total Supply After: 1000000
State preserved successfully!

=== Testing KRWQ Functionality After Upgrade ===
Successfully added new minter: 0x...
Successfully minted 1000 KRWQ to user
Successfully burned half of user's tokens
Successfully transferred tokens

=== All KRWQ Functionality Tests Passed! ===
```

---

## Additional Resources

- [OpenZeppelin TransparentUpgradeableProxy](https://docs.openzeppelin.com/contracts/4.x/api/proxy#TransparentUpgradeableProxy)
- [Foundry Fork Testing](https://book.getfoundry.sh/forge/fork-testing)
- [Proxy Upgrade Pattern](https://docs.openzeppelin.com/upgrades-plugins/1.x/proxies)

---

## Safety Checklist

Before upgrading on mainnet:

- [ ] New implementation deployed and verified on Etherscan
- [ ] Fork tests pass successfully
- [ ] Storage layout compatibility verified
- [ ] All existing minters preserved
- [ ] Total supply and balances preserved
- [ ] Owner/admin privileges preserved
- [ ] New functionality tested on fork
- [ ] Multisig signers reviewed upgrade transaction
- [ ] Monitoring/alerts ready for post-upgrade
- [ ] Rollback plan prepared (if possible)
