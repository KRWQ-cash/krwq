// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {console2 as console} from "forge-std/console2.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AggregatorV3Interface} from "../src/interfaces/AggregatorV3Interface.sol";

import {KRWT} from "../src/KRWT.sol";
import {KRWTCustodianWithOracle} from "../src/KRWTCustodianWithOracle.sol";
import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

contract ForkTest is Test {
    // Skip fork tests by default - use --match-test "Fork" to run them
    modifier skipFork() {
        if (block.chainid == 1) {
            _;
        } else {
            vm.skip(true);
        }
    }
    // Fork configuration

    string constant FORK_RPC_URL = "https://virtual.mainnet.eu.rpc.tenderly.co/acfc718e-6f5d-49f5-a2cd-4aca99cf965c";

    // Mainnet addresses
    address constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48; // USDC on Ethereum mainnet
    address constant USDC_ORACLE = 0x01435677FB11763550905594A16B645847C1d0F3; // KRW/USD Chainlink oracle

    // Test accounts
    address owner;
    address user;
    address deployer;

    // Deployed contracts
    KRWT krwt;
    KRWTCustodianWithOracle custodian;
    ProxyAdmin krwtAdmin;
    ProxyAdmin custodianAdmin;
    TransparentUpgradeableProxy krwtProxy;
    TransparentUpgradeableProxy custodianProxy;

    // Test parameters
    uint256 constant MINT_CAP = 1000000 * 1e18; // 1M KRWT
    uint256 constant MINT_FEE = 0; // 0% fee
    uint256 constant REDEEM_FEE = 0; // 0% fee
    uint256 constant MAX_ORACLE_DELAY = 3600 * 24; // 1 day

    function setUp() public skipFork {
        // Fork the mainnet at a specific block
        vm.createFork(FORK_RPC_URL);

        // Set up test accounts
        owner = makeAddr("owner");
        user = makeAddr("user");
        deployer = makeAddr("deployer");

        // Fund the deployer with some ETH for gas
        vm.deal(deployer, 10 ether);

        // Fund the user with USDC (impersonate a whale)
        address usdcWhale = 0x8F2D3803b9D5F20f070bC56790841F3800edb515;
        vm.startPrank(usdcWhale);
        IERC20(USDC).transfer(user, 100000 * 1e6); // 100k USDC
        vm.stopPrank();

        console.log("=== Fork Test Setup ===");
        console.log("Fork RPC:", FORK_RPC_URL);
        console.log("USDC Address:", USDC);
        console.log("USDC Oracle:", USDC_ORACLE);
        console.log("Owner:", owner);
        console.log("User:", user);
        console.log("User USDC Balance:", IERC20(USDC).balanceOf(user) / 1e6);
    }

    function testDeployKRWT() public skipFork {
        vm.startPrank(deployer);

        console.log("\n=== Deploying KRWT ===");

        // 1) Deploy KRWT implementation
        KRWT impl = new KRWT(owner, "KRWT", "KRWT");
        console.log("KRWT Implementation:", address(impl));

        // 2) Deploy ProxyAdmin
        krwtAdmin = new ProxyAdmin(owner);
        console.log("KRWT ProxyAdmin:", address(krwtAdmin));

        // 3) Encode initializer
        bytes memory initData = abi.encodeWithSelector(KRWT.initialize.selector, owner, "KRWT", "KRWT");

        // 4) Deploy Transparent proxy
        krwtProxy = new TransparentUpgradeableProxy(address(impl), address(krwtAdmin), initData);
        krwt = KRWT(address(krwtProxy));
        console.log("KRWT Proxy:", address(krwt));

        vm.stopPrank();

        // Verify deployment
        assertEq(krwt.owner(), owner);
        assertEq(krwt.name(), "KRWT");
        assertEq(krwt.symbol(), "KRWT");
        assertEq(krwt.decimals(), 18);
        assertEq(krwt.totalSupply(), 0);

        console.log("KRWT deployed successfully!");
    }

    function testDeployCustodianWithOracle() public skipFork {
        // First deploy KRWT
        testDeployKRWT();

        vm.startPrank(deployer);

        console.log("\n=== Deploying KRWTCustodianWithOracle ===");

        // 1) Deploy implementation
        KRWTCustodianWithOracle impl = new KRWTCustodianWithOracle(address(krwt), USDC);
        console.log("Custodian Implementation:", address(impl));

        // 2) Deploy ProxyAdmin
        custodianAdmin = new ProxyAdmin(owner);
        console.log("Custodian ProxyAdmin:", address(custodianAdmin));

        // 3) Encode initializer
        bytes memory initData = abi.encodeWithSelector(
            KRWTCustodianWithOracle.initialize.selector,
            owner,
            USDC_ORACLE,
            MAX_ORACLE_DELAY,
            MINT_CAP,
            MINT_FEE,
            REDEEM_FEE
        );

        // 4) Deploy Transparent proxy
        custodianProxy = new TransparentUpgradeableProxy(address(impl), address(custodianAdmin), initData);
        custodian = KRWTCustodianWithOracle(address(custodianProxy));
        console.log("Custodian Proxy:", address(custodian));

        vm.stopPrank();

        // Verify deployment
        assertEq(custodian.owner(), owner);
        assertEq(custodian.custodianOracle(), USDC_ORACLE);
        assertEq(custodian.maximumOracleDelay(), MAX_ORACLE_DELAY);
        assertEq(custodian.mintCap(), MINT_CAP);
        assertEq(custodian.mintFee(), MINT_FEE);
        assertEq(custodian.redeemFee(), REDEEM_FEE);

        console.log("Custodian deployed successfully!");
    }

    function testSetMinter() public skipFork {
        // Deploy both contracts
        testDeployCustodianWithOracle();

        vm.startPrank(owner);

        console.log("\n=== Setting Custodian as Minter ===");

        // Add custodian as minter
        krwt.addMinter(address(custodian));

        // Verify minter was added
        assertTrue(krwt.minters(address(custodian)));

        console.log("Custodian set as minter successfully!");

        vm.stopPrank();
    }

    function testOraclePriceFeed() public skipFork {
        // Deploy and setup everything
        testSetMinter();

        console.log("\n=== Testing Oracle Price Feed ===");

        // Get oracle price
        uint256 oraclePrice = custodian.getCustodianOraclePrice();
        console.log("Oracle Price (8 decimals):", oraclePrice);

        // Verify oracle is working
        assertTrue(oraclePrice > 0, "Oracle price should be positive");

        // Test oracle decimals
        uint256 oracleDecimals = custodian.oracleDecimals();
        console.log("Oracle Decimals:", oracleDecimals);
        assertEq(oracleDecimals, 8, "Chainlink USDC/USD oracle should have 8 decimals");

        console.log("Oracle price feed working correctly!");
    }

    function testMintKRWTWithUSDC() public skipFork {
        // Deploy and setup everything
        testSetMinter();

        console.log("\n=== Testing KRWT Minting with USDC ===");

        // Get initial balances
        uint256 initialUSDCBalance = IERC20(USDC).balanceOf(user);
        uint256 initialKRWTBalance = krwt.balanceOf(user);

        console.log("Initial USDC Balance:", initialUSDCBalance / 1e6);
        console.log("Initial KRWT Balance:", initialKRWTBalance / 1e18);

        // Get oracle price for calculations
        uint256 oraclePrice = custodian.getCustodianOraclePrice();
        console.log("Oracle Price (8 decimals):", oraclePrice);

        vm.startPrank(user);

        // Approve USDC spending
        IERC20(USDC).approve(address(custodian), type(uint256).max);

        // Deposit 500 USDC (to stay under mint cap)
        uint256 usdcAmount = 500 * 1e6; // 500 USDC (6 decimals)
        console.log("Depositing USDC Amount:", usdcAmount / 1e6);

        // Preview the shares we'll get
        uint256 expectedShares = custodian.previewDeposit(usdcAmount);
        console.log("Expected KRWT Shares:", expectedShares / 1e18);

        // Perform the deposit
        uint256 sharesOut = custodian.deposit(usdcAmount, user);
        console.log("Actual KRWT Shares Received:", sharesOut / 1e18);

        vm.stopPrank();

        // Verify balances
        uint256 finalUSDCBalance = IERC20(USDC).balanceOf(user);
        uint256 finalKRWTBalance = krwt.balanceOf(user);

        console.log("Final USDC Balance:", finalUSDCBalance / 1e6);
        console.log("Final KRWT Balance:", finalKRWTBalance / 1e18);

        // Verify the deposit worked correctly
        assertEq(sharesOut, expectedShares, "Shares received should match preview");
        assertEq(finalKRWTBalance, initialKRWTBalance + sharesOut, "KRWT balance should increase by shares received");
        assertEq(finalUSDCBalance, initialUSDCBalance - usdcAmount, "USDC balance should decrease by amount deposited");

        // Verify custodian received the USDC
        assertEq(IERC20(USDC).balanceOf(address(custodian)), usdcAmount, "Custodian should hold the deposited USDC");

        console.log("KRWT minting with USDC successful!");
    }

    function testRedeemKRWTForUSDC() public skipFork {
        // First mint some KRWT
        testMintKRWTWithUSDC();

        // Set public flag to allow redemption
        vm.startPrank(owner);
        custodian.setPublic(true);
        vm.stopPrank();

        console.log("\n=== Testing KRWT Redemption for USDC ===");

        // Get initial balances
        uint256 initialUSDCBalance = IERC20(USDC).balanceOf(user);
        uint256 initialKRWTBalance = krwt.balanceOf(user);

        console.log("Initial USDC Balance:", initialUSDCBalance / 1e6);
        console.log("Initial KRWT Balance:", initialKRWTBalance / 1e18);

        vm.startPrank(user);

        // Approve KRWT spending
        krwt.approve(address(custodian), type(uint256).max);

        // Redeem half of the KRWT
        uint256 redeemAmount = initialKRWTBalance / 2;
        console.log("Redeeming KRWT Amount:", redeemAmount / 1e18);

        // Preview the USDC we'll get
        uint256 expectedUSDC = custodian.previewRedeem(redeemAmount);
        console.log("Expected USDC Amount:", expectedUSDC / 1e6);

        // Perform the redemption
        uint256 usdcOut = custodian.redeem(redeemAmount, user, user);
        console.log("Actual USDC Amount Received:", usdcOut / 1e6);

        vm.stopPrank();

        // Verify balances
        uint256 finalUSDCBalance = IERC20(USDC).balanceOf(user);
        uint256 finalKRWTBalance = krwt.balanceOf(user);

        console.log("Final USDC Balance:", finalUSDCBalance / 1e6);
        console.log("Final KRWT Balance:", finalKRWTBalance / 1e18);

        // Verify the redemption worked correctly
        assertEq(usdcOut, expectedUSDC, "USDC received should match preview");
        assertEq(finalKRWTBalance, initialKRWTBalance - redeemAmount, "KRWT balance should decrease by amount redeemed");
        assertEq(finalUSDCBalance, initialUSDCBalance + usdcOut, "USDC balance should increase by amount received");

        console.log("KRWT redemption for USDC successful!");
    }

    function testFullWorkflow() public skipFork {
        console.log("\n=== Running Full Workflow Test ===");

        // Deploy and setup
        testSetMinter();

        // Test oracle
        testOraclePriceFeed();

        // Test minting
        testMintKRWTWithUSDC();

        // Test redemption
        testRedeemKRWTForUSDC();

        console.log("\n=== Full Workflow Test Completed Successfully! ===");
    }

    function testMultipleDepositsAndRedemptions() public skipFork {
        // Deploy and setup
        testSetMinter();

        // Set public flag to allow anyone to mint/redeem
        vm.startPrank(owner);
        custodian.setPublic(true);
        vm.stopPrank();

        console.log("\n=== Testing Multiple Deposits and Redemptions ===");

        vm.startPrank(user);
        IERC20(USDC).approve(address(custodian), type(uint256).max);
        krwt.approve(address(custodian), type(uint256).max);

        // Multiple deposits
        uint256[] memory depositAmounts = new uint256[](3);
        depositAmounts[0] = 200 * 1e6; // 200 USDC
        depositAmounts[1] = 300 * 1e6; // 300 USDC
        depositAmounts[2] = 100 * 1e6; // 100 USDC

        uint256 totalKRWTReceived = 0;

        for (uint256 i = 0; i < depositAmounts.length; i++) {
            uint256 shares = custodian.deposit(depositAmounts[i], user);
            totalKRWTReceived += shares;
            console.log("Deposit %d: %d USDC -> %d KRWT", i + 1, depositAmounts[i] / 1e6, shares / 1e18);
        }

        console.log("Total KRWT Received:", totalKRWTReceived / 1e18);

        // Multiple redemptions
        uint256[] memory redeemAmounts = new uint256[](2);
        redeemAmounts[0] = totalKRWTReceived / 3; // Redeem 1/3
        redeemAmounts[1] = totalKRWTReceived / 4; // Redeem 1/4

        uint256 totalUSDCReceived = 0;

        for (uint256 i = 0; i < redeemAmounts.length; i++) {
            uint256 usdc = custodian.redeem(redeemAmounts[i], user, user);
            totalUSDCReceived += usdc;
            console.log("Redemption %d: %d KRWT -> %d USDC", i + 1, redeemAmounts[i] / 1e18, usdc / 1e6);
        }

        console.log("Total USDC Received:", totalUSDCReceived / 1e6);

        vm.stopPrank();

        console.log("Multiple deposits and redemptions test completed!");
    }
}
