// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {console2 as console} from "forge-std/console2.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {KRWTOFT} from "../src/bridge/KRWTOFT.sol";
import {KRWQOFT} from "../src/bridge/KRWQOFT.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {ITransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";

/**
 * @title ForkUpgradeKRWTOFTtoKRWQOFT
 * @notice Tests upgrading KRWTOFT token implementation to KRWQOFT on a Base mainnet fork
 * @dev This test can either:
 *      1. Use an existing KRWTOFT deployment on Base mainnet (set USE_EXISTING_DEPLOYMENT = true)
 *      2. Deploy a fresh KRWTOFT on the fork for testing (set USE_EXISTING_DEPLOYMENT = false)
 */
contract ForkUpgradeKRWTOFTtoKRWQOFT is Test {
    // Fork configuration - Base mainnet
    string constant FORK_RPC_URL = "https://virtual.base.eu.rpc.tenderly.co/abad4bc6-1d64-452e-8886-22d599124cec";

    // Configuration: Set to true to use existing mainnet deployment, false to deploy fresh for testing
    bool constant USE_EXISTING_DEPLOYMENT = true;

    // Base mainnet KRWTOFT addresses (only used if USE_EXISTING_DEPLOYMENT = true)
    address constant KRWTOFT_PROXY_BASE = 0x370923D39f139C64813f173a1bf0b4f9Ba36a24f; // Update with actual proxy address when available
    address constant LZ_ENDPOINT_BASE = 0x1a44076050125825900e736c501f859c50fE728c; // Base LayerZero endpoint

    // Test accounts
    address proxyAdminOwner; // Owner of the ProxyAdmin contract
    address tokenOwner;
    address user;
    address deployer;

    // Contract addresses
    address krwtoftProxyAddress;
    ProxyAdmin proxyAdmin; // ProxyAdmin contract

    // Contracts
    KRWTOFT krwtoftOldImplementation;
    KRWQOFT krwqoftNewImplementation;
    KRWTOFT krwtoftProxy; // Proxy interface (pre-upgrade)
    KRWQOFT krwqoftProxy; // Proxy interface (post-upgrade)

    function setUp() public {
        // Create and select fork
        vm.createSelectFork(FORK_RPC_URL);

        console.log("=== Fork Upgrade Test Setup (OFT on Base) ===");
        console.log("Fork RPC:", FORK_RPC_URL);
        console.log("Chain ID:", block.chainid);
        console.log("Block Number:", block.number);

        if (USE_EXISTING_DEPLOYMENT) {
            console.log("\nUsing existing Base mainnet deployment...");
            _setupExistingDeployment();
        } else {
            console.log("\nDeploying fresh KRWTOFT for testing...");
            _setupFreshDeployment();
        }

        console.log("\nKRWTOFT Proxy:", krwtoftProxyAddress);
        console.log("Token Owner:", tokenOwner);
        console.log("Current Token Name:", krwtoftProxy.name());
        console.log("Current Token Symbol:", krwtoftProxy.symbol());
        console.log("Current Total Supply:", krwtoftProxy.totalSupply() / 1e18);

        // Create test user
        user = makeAddr("user");

        // Fund user with ETH for gas
        vm.deal(user, 10 ether);
    }

    function _setupExistingDeployment() internal {
        // Connect to existing KRWTOFT proxy on Base mainnet
        krwtoftProxyAddress = KRWTOFT_PROXY_BASE;
        krwtoftProxy = KRWTOFT(krwtoftProxyAddress);

        // Get the token owner
        tokenOwner = krwtoftProxy.owner();

        // Get the ProxyAdmin contract address (stored in ERC1967 admin slot)
        bytes32 adminSlot = bytes32(uint256(keccak256("eip1967.proxy.admin")) - 1);
        address proxyAdminAddress = address(uint160(uint256(vm.load(krwtoftProxyAddress, adminSlot))));
        proxyAdmin = ProxyAdmin(proxyAdminAddress);

        // Get the owner of the ProxyAdmin
        proxyAdminOwner = proxyAdmin.owner();
        console.log("ProxyAdmin contract:", address(proxyAdmin));
        console.log("ProxyAdmin owner:", proxyAdminOwner);
        console.log("Token Owner:", tokenOwner);
    }

    function _setupFreshDeployment() internal {
        // Create deployer account
        deployer = makeAddr("deployer");
        tokenOwner = makeAddr("owner");
        proxyAdminOwner = makeAddr("proxyAdminOwner"); // Owner of ProxyAdmin contract

        vm.deal(deployer, 10 ether);

        vm.startPrank(deployer);

        // Deploy KRWTOFT implementation
        krwtoftOldImplementation = new KRWTOFT(LZ_ENDPOINT_BASE);
        console.log("KRWTOFT Implementation deployed:", address(krwtoftOldImplementation));

        // Prepare initialization data
        bytes memory initData = abi.encodeWithSelector(KRWTOFT.initialize.selector, "KRWT", "KRWT", tokenOwner);

        // Deploy TransparentUpgradeableProxy
        // Note: This will automatically deploy a ProxyAdmin contract with proxyAdminOwner as owner
        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(
            address(krwtoftOldImplementation),
            proxyAdminOwner, // This will be the owner of the auto-deployed ProxyAdmin
            initData
        );

        krwtoftProxyAddress = address(proxy);
        krwtoftProxy = KRWTOFT(krwtoftProxyAddress);

        // Get the ProxyAdmin contract that was auto-deployed
        bytes32 adminSlot = bytes32(uint256(keccak256("eip1967.proxy.admin")) - 1);
        address proxyAdminAddress = address(uint160(uint256(vm.load(krwtoftProxyAddress, adminSlot))));
        proxyAdmin = ProxyAdmin(proxyAdminAddress);

        console.log("KRWTOFT Proxy deployed:", krwtoftProxyAddress);
        console.log("ProxyAdmin contract:", address(proxyAdmin));
        console.log("ProxyAdmin owner:", proxyAdminOwner);
        console.log("Token Owner:", tokenOwner);

        vm.stopPrank();

        // Note: OFT tokens don't have a direct mint function
        // Tokens are minted through cross-chain messaging
        // For testing, we'll deal tokens directly or test with zero supply
        console.log("KRWTOFT deployed with zero initial supply (normal for OFT)");
    }

    /**
     * @notice Test deploying new KRWQOFT implementation
     */
    function testDeployKRWQOFTImplementation() public {
        console.log("\n=== Deploying New KRWQOFT Implementation ===");

        vm.startPrank(tokenOwner);

        // Deploy new KRWQOFT implementation
        krwqoftNewImplementation = new KRWQOFT(LZ_ENDPOINT_BASE);

        console.log("New KRWQOFT Implementation:", address(krwqoftNewImplementation));
        console.log("Implementation initialized:", address(krwqoftNewImplementation) != address(0));

        vm.stopPrank();

        // Verify implementation was deployed
        assertTrue(address(krwqoftNewImplementation) != address(0), "Implementation should be deployed");
    }

    /**
     * @notice Test upgrading the proxy from KRWTOFT to KRWQOFT implementation
     */
    function testUpgradeProxyToKRWQOFT() public {
        // First deploy new implementation
        testDeployKRWQOFTImplementation();

        console.log("\n=== Upgrading Proxy to KRWQOFT Implementation ===");

        // Record state before upgrade
        uint256 totalSupplyBefore = krwtoftProxy.totalSupply();
        uint8 decimalsBefore = krwtoftProxy.decimals();

        console.log("Total Supply Before:", totalSupplyBefore / 1e18);

        // Upgrade the proxy to new implementation using ProxyAdmin
        // Call reinitialize during upgrade to update name and symbol
        bytes memory reinitData = abi.encodeWithSelector(KRWQOFT.reinitialize.selector, "KRWQ", "KRWQ");

        vm.prank(proxyAdminOwner);
        proxyAdmin.upgradeAndCall(
            ITransparentUpgradeableProxy(krwtoftProxyAddress), address(krwqoftNewImplementation), reinitData
        );

        // Now interact with proxy as KRWQOFT
        krwqoftProxy = KRWQOFT(krwtoftProxyAddress);

        console.log("Proxy upgraded successfully!");
        console.log("New Implementation Address:", address(krwqoftNewImplementation));

        // Verify state was preserved (except name and symbol which were updated)
        assertEq(krwqoftProxy.totalSupply(), totalSupplyBefore, "Total supply should be preserved");
        assertEq(krwqoftProxy.name(), "KRWQ", "Name should be updated to KRWQ");
        assertEq(krwqoftProxy.symbol(), "KRWQ", "Symbol should be updated to KRWQ");
        assertEq(krwqoftProxy.decimals(), decimalsBefore, "Decimals should be preserved");
        assertEq(krwqoftProxy.owner(), tokenOwner, "Owner should be preserved");

        console.log("Total Supply After:", krwqoftProxy.totalSupply() / 1e18);
        console.log("Name After:", krwqoftProxy.name());
        console.log("Symbol After:", krwqoftProxy.symbol());
        console.log("Owner After:", krwqoftProxy.owner());
        console.log("State preserved and name/symbol updated successfully!");
    }

    /**
     * @notice Test that KRWQOFT functionality works after upgrade
     */
    function testKRWQOFTFunctionalityAfterUpgrade() public {
        // First upgrade to KRWQOFT
        testUpgradeProxyToKRWQOFT();

        console.log("\n=== Testing KRWQOFT Functionality After Upgrade ===");

        // Give user some tokens via deal (simulating tokens received from bridge)
        uint256 initialAmount = 1000 * 1e18;
        deal(address(krwqoftProxy), user, initialAmount);

        assertEq(krwqoftProxy.balanceOf(user), initialAmount, "User should have initial tokens");
        console.log("User has", initialAmount / 1e18, "KRWQ tokens");

        // Test transfer
        address recipient = makeAddr("recipient");
        vm.startPrank(user);
        krwqoftProxy.transfer(recipient, initialAmount / 4);
        vm.stopPrank();

        assertEq(krwqoftProxy.balanceOf(recipient), initialAmount / 4, "Recipient should receive tokens");
        assertEq(krwqoftProxy.balanceOf(user), initialAmount - initialAmount / 4, "User balance should be reduced");
        console.log("Successfully transferred tokens");

        // Test approve and transferFrom
        address spender = makeAddr("spender");
        vm.prank(user);
        krwqoftProxy.approve(spender, initialAmount / 4);

        vm.prank(spender);
        krwqoftProxy.transferFrom(user, spender, initialAmount / 4);

        assertEq(krwqoftProxy.balanceOf(spender), initialAmount / 4, "Spender should receive tokens");
        console.log("Successfully tested approve and transferFrom");

        console.log("\n=== All KRWQOFT Functionality Tests Passed! ===");
    }

    /**
     * @notice Test full upgrade workflow including state preservation and functionality
     */
    function testFullUpgradeWorkflow() public {
        console.log("\n=== Running Full Upgrade Workflow ===");

        // 1. Deploy new implementation
        console.log("\n1. Deploying new KRWQOFT implementation...");
        testDeployKRWQOFTImplementation();

        // 2. Record pre-upgrade state
        console.log("\n2. Recording pre-upgrade state...");
        uint256 totalSupplyBefore = krwtoftProxy.totalSupply();
        console.log("Total Supply:", totalSupplyBefore / 1e18);

        // 3. Perform upgrade
        console.log("\n3. Performing upgrade...");
        bytes memory reinitData = abi.encodeWithSelector(KRWQOFT.reinitialize.selector, "KRWQ", "KRWQ");

        vm.prank(proxyAdminOwner);
        proxyAdmin.upgradeAndCall(
            ITransparentUpgradeableProxy(krwtoftProxyAddress), address(krwqoftNewImplementation), reinitData
        );
        krwqoftProxy = KRWQOFT(krwtoftProxyAddress);

        // 4. Verify state preservation and name/symbol update
        console.log("\n4. Verifying state preservation and name/symbol update...");
        assertEq(krwqoftProxy.totalSupply(), totalSupplyBefore, "Supply preserved");
        assertEq(krwqoftProxy.name(), "KRWQ", "Name updated to KRWQ");
        assertEq(krwqoftProxy.symbol(), "KRWQ", "Symbol updated to KRWQ");
        assertEq(krwqoftProxy.owner(), tokenOwner, "Owner should be preserved");
        console.log("New Name:", krwqoftProxy.name());
        console.log("New Symbol:", krwqoftProxy.symbol());
        console.log("Owner:", krwqoftProxy.owner());
        console.log("State preserved and name/symbol updated successfully!");

        // 5. Test new functionality
        console.log("\n5. Testing new KRWQOFT functionality...");
        deal(address(krwqoftProxy), user, 100 * 1e18);
        assertEq(krwqoftProxy.balanceOf(user), 100 * 1e18, "Token balance works");

        // Test transfer
        address testRecipient = makeAddr("testRecipient");
        vm.prank(user);
        krwqoftProxy.transfer(testRecipient, 50 * 1e18);
        assertEq(krwqoftProxy.balanceOf(testRecipient), 50 * 1e18, "Transfer works");
        console.log("Functionality working!");

        console.log("\n=== Full Upgrade Workflow Completed Successfully! ===");
    }

    /**
     * @notice Helper function to check if we're on Base fork
     */
    function requireBaseFork() internal view returns (bool) {
        return block.chainid == 8453; // Base mainnet chain ID
    }
}
