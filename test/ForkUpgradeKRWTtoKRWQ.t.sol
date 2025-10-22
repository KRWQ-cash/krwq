// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {console2 as console} from "forge-std/console2.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {KRWT} from "../src/KRWT.sol";
import {KRWQ} from "../src/KRWQ.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {ITransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";

/**
 * @title ForkUpgradeKRWTtoKRWQ
 * @notice Tests upgrading KRWT token implementation to KRWQ on a mainnet fork
 * @dev This test can either:
 *      1. Use an existing KRWT deployment on mainnet (set USE_EXISTING_DEPLOYMENT = true)
 *      2. Deploy a fresh KRWT on the fork for testing (set USE_EXISTING_DEPLOYMENT = false)
 */
contract ForkUpgradeKRWTtoKRWQ is Test {
    // Fork configuration
    string constant FORK_RPC_URL = "https://virtual.mainnet.eu.rpc.tenderly.co/b279c3be-2699-4d27-b295-91d4135686a6";

    // Configuration: Set to true to use existing mainnet deployment, false to deploy fresh for testing
    bool constant USE_EXISTING_DEPLOYMENT = true;

    // Mainnet KRWT addresses (only used if USE_EXISTING_DEPLOYMENT = true)
    address constant KRWT_PROXY_MAINNET = 0xc00db6b41473d065027F5Ed6fAdA20fde75f142e; // Update with actual proxy address

    // Mainnet addresses for fresh deployment
    address constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

    // Test accounts
    address proxyAdminOwner; // Owner of the ProxyAdmin contract
    address tokenOwner;
    address user;
    address deployer;

    // Contract addresses
    address krwtProxyAddress;
    ProxyAdmin proxyAdmin; // ProxyAdmin contract

    // Contracts
    KRWT krwtOldImplementation;
    KRWQ krwqNewImplementation;
    KRWT krwtProxy; // Proxy interface (pre-upgrade)
    KRWQ krwqProxy; // Proxy interface (post-upgrade)

    function setUp() public {
        // Create and select fork
        vm.createSelectFork(FORK_RPC_URL);

        console.log("=== Fork Upgrade Test Setup ===");
        console.log("Fork RPC:", FORK_RPC_URL);
        console.log("Chain ID:", block.chainid);
        console.log("Block Number:", block.number);

        if (USE_EXISTING_DEPLOYMENT) {
            console.log("\nUsing existing mainnet deployment...");
            _setupExistingDeployment();
        } else {
            console.log("\nDeploying fresh KRWT for testing...");
            _setupFreshDeployment();
        }

        console.log("\nKRWT Proxy:", krwtProxyAddress);
        console.log("Token Owner:", tokenOwner);
        console.log("Current Token Name:", krwtProxy.name());
        console.log("Current Token Symbol:", krwtProxy.symbol());
        console.log("Current Total Supply:", krwtProxy.totalSupply() / 1e18);

        // Create test user
        user = makeAddr("user");

        // Fund user with ETH for gas
        vm.deal(user, 10 ether);
    }

    function _setupExistingDeployment() internal {
        // Connect to existing KRWT proxy on mainnet
        krwtProxyAddress = KRWT_PROXY_MAINNET;
        krwtProxy = KRWT(krwtProxyAddress);

        // Get the token owner
        tokenOwner = krwtProxy.owner();

        // Get the ProxyAdmin contract address (stored in ERC1967 admin slot)
        bytes32 adminSlot = bytes32(uint256(keccak256("eip1967.proxy.admin")) - 1);
        address proxyAdminAddress = address(uint160(uint256(vm.load(krwtProxyAddress, adminSlot))));
        proxyAdmin = ProxyAdmin(proxyAdminAddress);

        // Get the owner of the ProxyAdmin
        proxyAdminOwner = proxyAdmin.owner();
        console.log("ProxyAdmin contract:", address(proxyAdmin));
        console.log("ProxyAdmin owner:", proxyAdminOwner);
    }

    function _setupFreshDeployment() internal {
        // Create deployer account
        deployer = makeAddr("deployer");
        tokenOwner = makeAddr("owner");
        proxyAdminOwner = makeAddr("proxyAdminOwner"); // Owner of ProxyAdmin contract

        vm.deal(deployer, 10 ether);

        vm.startPrank(deployer);

        // Deploy KRWT implementation
        krwtOldImplementation = new KRWT(tokenOwner, "KRWQ", "KRWQ");
        console.log("KRWT Implementation deployed:", address(krwtOldImplementation));

        // Prepare initialization data
        bytes memory initData = abi.encodeWithSelector(KRWT.initialize.selector, tokenOwner, "KRWQ", "KRWQ");

        // Deploy TransparentUpgradeableProxy
        // Note: This will automatically deploy a ProxyAdmin contract with proxyAdminOwner as owner
        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(
            address(krwtOldImplementation),
            proxyAdminOwner, // This will be the owner of the auto-deployed ProxyAdmin
            initData
        );

        krwtProxyAddress = address(proxy);
        krwtProxy = KRWT(krwtProxyAddress);

        // Get the ProxyAdmin contract that was auto-deployed
        bytes32 adminSlot = bytes32(uint256(keccak256("eip1967.proxy.admin")) - 1);
        address proxyAdminAddress = address(uint160(uint256(vm.load(krwtProxyAddress, adminSlot))));
        proxyAdmin = ProxyAdmin(proxyAdminAddress);

        console.log("KRWT Proxy deployed:", krwtProxyAddress);
        console.log("ProxyAdmin contract:", address(proxyAdmin));
        console.log("ProxyAdmin owner:", proxyAdminOwner);
        console.log("Token Owner:", tokenOwner);

        // Mint some initial supply for testing
        vm.stopPrank();

        // Add deployer as minter temporarily to create initial supply
        vm.startPrank(tokenOwner);
        krwtProxy.addMinter(deployer);
        vm.stopPrank();

        vm.startPrank(deployer);
        krwtProxy.minterMint(deployer, 1000000 * 1e18); // 1M tokens
        console.log("Minted initial supply: 1000000 KRWQ");
        vm.stopPrank();
    }

    /**
     * @notice Test deploying new KRWQ implementation
     */
    function testDeployKRWQImplementation() public {
        console.log("\n=== Deploying New KRWQ Implementation ===");

        vm.startPrank(tokenOwner);

        // Deploy new KRWQ implementation
        string memory name = "KRWQ";
        string memory symbol = "KRWQ";

        krwqNewImplementation = new KRWQ(tokenOwner, name, symbol);

        console.log("New KRWQ Implementation:", address(krwqNewImplementation));
        console.log("Implementation Name:", krwqNewImplementation.name());
        console.log("Implementation Symbol:", krwqNewImplementation.symbol());

        vm.stopPrank();

        // Verify implementation was deployed
        assertTrue(address(krwqNewImplementation) != address(0), "Implementation should be deployed");
    }

    /**
     * @notice Test upgrading the proxy from KRWT to KRWQ implementation
     */
    function testUpgradeProxyToKRWQ() public {
        // First deploy new implementation
        testDeployKRWQImplementation();

        console.log("\n=== Upgrading Proxy to KRWQ Implementation ===");

        // Record state before upgrade
        uint256 totalSupplyBefore = krwtProxy.totalSupply();
        uint8 decimalsBefore = krwtProxy.decimals();

        console.log("Total Supply Before:", totalSupplyBefore / 1e18);

        // Upgrade the proxy to new implementation using ProxyAdmin
        vm.prank(proxyAdminOwner);
        proxyAdmin.upgradeAndCall(
            ITransparentUpgradeableProxy(krwtProxyAddress),
            address(krwqNewImplementation),
            "" // No initialization call needed
        );

        // Now interact with proxy as KRWQ
        krwqProxy = KRWQ(krwtProxyAddress);

        // Update metadata to change name/symbol from KRWT to KRWQ
        vm.prank(tokenOwner);
        krwqProxy.updateMetadata("KRWQ", "KRWQ");

        console.log("Proxy upgraded successfully!");
        console.log("New Implementation Address:", address(krwqNewImplementation));

        // Verify state was preserved (except name and symbol which were updated)
        assertEq(krwqProxy.totalSupply(), totalSupplyBefore, "Total supply should be preserved");
        assertEq(krwqProxy.name(), "KRWQ", "Name should be updated to KRWQ");
        assertEq(krwqProxy.symbol(), "KRWQ", "Symbol should be updated to KRWQ");
        assertEq(krwqProxy.decimals(), decimalsBefore, "Decimals should be preserved");
        assertEq(krwqProxy.owner(), tokenOwner, "Owner should be preserved");

        console.log("Total Supply After:", krwqProxy.totalSupply() / 1e18);
        console.log("Name After:", krwqProxy.name());
        console.log("Symbol After:", krwqProxy.symbol());
        console.log("Owner After:", krwqProxy.owner());
        console.log("State preserved and name/symbol updated successfully!");
    }

    /**
     * @notice Test that KRWQ functionality works after upgrade
     */
    function testKRWQFunctionalityAfterUpgrade() public {
        // First upgrade to KRWQ
        testUpgradeProxyToKRWQ();

        console.log("\n=== Testing KRWQ Functionality After Upgrade ===");

        // Test adding a minter
        address newMinter = makeAddr("newMinter");

        vm.startPrank(tokenOwner);
        krwqProxy.addMinter(newMinter);
        vm.stopPrank();

        assertTrue(krwqProxy.minters(newMinter), "New minter should be added");
        console.log("Successfully added new minter:", newMinter);

        // Test minting
        uint256 mintAmount = 1000 * 1e18;
        vm.startPrank(newMinter);
        krwqProxy.minterMint(user, mintAmount);
        vm.stopPrank();

        assertEq(krwqProxy.balanceOf(user), mintAmount, "User should receive minted tokens");
        console.log("Successfully minted", mintAmount / 1e18, "KRWQ to user");

        // Test burning
        vm.startPrank(user);
        krwqProxy.burn(mintAmount / 2);
        vm.stopPrank();

        assertEq(krwqProxy.balanceOf(user), mintAmount / 2, "Half should be burned");
        console.log("Successfully burned half of user's tokens");

        // Test transfer
        address recipient = makeAddr("recipient");
        vm.startPrank(user);
        krwqProxy.transfer(recipient, mintAmount / 4);
        vm.stopPrank();

        assertEq(krwqProxy.balanceOf(recipient), mintAmount / 4, "Recipient should receive tokens");
        console.log("Successfully transferred tokens");

        console.log("\n=== All KRWQ Functionality Tests Passed! ===");
    }

    /**
     * @notice Test that existing minters still work after upgrade
     */
    function testExistingMintersAfterUpgrade() public {
        // Record existing minters before upgrade
        address[] memory existingMinters = new address[](10); // Assume max 10 minters
        uint256 minterCount = 0;

        // Get existing minters from KRWT
        for (uint256 i = 0; i < 10; i++) {
            try krwtProxy.mintersArray(i) returns (address minter) {
                if (minter != address(0) && krwtProxy.minters(minter)) {
                    existingMinters[minterCount] = minter;
                    minterCount++;
                    console.log("Existing minter found:", minter);
                }
            } catch {
                break;
            }
        }

        console.log("Total existing minters:", minterCount);

        // Upgrade to KRWQ
        testUpgradeProxyToKRWQ();

        console.log("\n=== Verifying Existing Minters After Upgrade ===");

        // Verify all existing minters are still minters in KRWQ
        for (uint256 i = 0; i < minterCount; i++) {
            address minter = existingMinters[i];
            assertTrue(krwqProxy.minters(minter), "Existing minter should still be authorized");
            console.log("Minter still authorized:", minter);
        }

        console.log("All existing minters preserved after upgrade!");
    }

    /**
     * @notice Test full upgrade workflow including state preservation and functionality
     */
    function testFullUpgradeWorkflow() public {
        console.log("\n=== Running Full Upgrade Workflow ===");

        // 1. Deploy new implementation
        console.log("\n1. Deploying new KRWQ implementation...");
        testDeployKRWQImplementation();

        // 2. Record pre-upgrade state
        console.log("\n2. Recording pre-upgrade state...");
        uint256 totalSupplyBefore = krwtProxy.totalSupply();
        console.log("Total Supply:", totalSupplyBefore / 1e18);

        // 3. Perform upgrade
        console.log("\n3. Performing upgrade...");
        vm.prank(proxyAdminOwner);
        proxyAdmin.upgradeAndCall(
            ITransparentUpgradeableProxy(krwtProxyAddress),
            address(krwqNewImplementation),
            "" // No initialization call needed
        );
        krwqProxy = KRWQ(krwtProxyAddress);

        // Update metadata to KRWQ
        vm.prank(tokenOwner);
        krwqProxy.updateMetadata("KRWQ", "KRWQ");

        // 4. Verify state preservation and name/symbol update
        console.log("\n4. Verifying state preservation and name/symbol update...");
        assertEq(krwqProxy.totalSupply(), totalSupplyBefore, "Supply preserved");
        assertEq(krwqProxy.name(), "KRWQ", "Name updated to KRWQ");
        assertEq(krwqProxy.symbol(), "KRWQ", "Symbol updated to KRWQ");
        assertEq(krwqProxy.owner(), tokenOwner, "Owner should be preserved");
        console.log("New Name:", krwqProxy.name());
        console.log("New Symbol:", krwqProxy.symbol());
        console.log("Owner:", krwqProxy.owner());
        console.log("State preserved and name/symbol updated successfully!");

        // 5. Test new functionality
        console.log("\n5. Testing new KRWQ functionality...");
        address testMinter = makeAddr("testMinter");
        vm.prank(tokenOwner);
        krwqProxy.addMinter(testMinter);
        assertTrue(krwqProxy.minters(testMinter), "Minter added");
        console.log("Functionality working!");

        console.log("\n=== Full Upgrade Workflow Completed Successfully! ===");
    }

    /**
     * @notice Helper function to check if we're on mainnet fork
     */
    function requireMainnetFork() internal view returns (bool) {
        return block.chainid == 1;
    }
}
