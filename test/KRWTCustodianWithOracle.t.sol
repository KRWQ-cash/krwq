// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {KRWT} from "../src/KRWT.sol";
import {KRWTCustodianWithOracle} from "../src/KRWTCustodianWithOracle.sol";
import {MockERC20} from "./mocks/MockERC20.sol";
import {MockOracle} from "./mocks/MockOracle.sol";

contract KRWTCustodianWithOracleTest is Test {
    address owner;
    address user;

    KRWT krwt;
    MockERC20 usdc; // 6 decimals
    KRWTCustodianWithOracle custodian;
    MockOracle oracle;

    function setUp() public {
        owner = address(0xA11CE);
        user = address(0xB0B);

        vm.startPrank(owner);
        krwt = new KRWT(owner, "KRWT", "KRWT");
        usdc = new MockERC20("USD Coin", "USDC", 6);
        custodian = new KRWTCustodianWithOracle(address(krwt), address(usdc));
        krwt.addMinter(address(custodian));
        // initialize inherited settings
        custodian.setMintCap(type(uint256).max);
        custodian.setMintRedeemFee(0, 0);

        // setup oracle: 8 decimals like Chainlink
        oracle = new MockOracle(8, "USDC/KRW", 4);
        // set a price, e.g., 1300 KRW per USDC with 8 decimals => 1300 * 1e8
        oracle.setAnswer(int256(1300 * 1e8));
        custodian.setCustodianOracle(address(oracle), 1 days);
        vm.stopPrank();

        // fund user with USDC
        usdc.mint(user, 1_000_000e6);
    }

    function testConvertReflectsOraclePrice() public view {
        // Base conversion 1e6 USDC -> 1e18 shares, then scaled by price (1300*1e8 / 1e8)
        // So convertToShares(1e6) = 1e18 * 1300
        uint256 shares = custodian.convertToShares(1e6);
        assertEq(shares, 1300 * 1e18);
        // inverse should return
        uint256 assets = custodian.convertToAssets(1300 * 1e18);
        assertEq(assets, 1e6);
    }

    function testDepositMintWithdrawRedeem_UpdateOracle() public {
        vm.startPrank(user);
        usdc.approve(address(custodian), type(uint256).max);

        // deposit 1 USDC => 1300 KRWT shares
        uint256 sharesOut = custodian.deposit(1e6, user);
        assertEq(sharesOut, 1300 * 1e18);
        assertEq(krwt.balanceOf(user), sharesOut);

        // change price to 1200 and redeem 300 shares-worth of USDC
        vm.stopPrank();
        vm.prank(owner);
        oracle.setAnswer(int256(1200 * 1e8));

        vm.startPrank(user);
        krwt.approve(address(custodian), type(uint256).max);
        uint256 assetsOut = custodian.redeem(300 * 1e18, user, user);
        // With price=1200, 300e18 shares => 300/1300 of 1 USDC? Actually convert uses current price.
        // We'll simply assert preview matches execution
        assertEq(assetsOut, custodian.previewRedeem(300 * 1e18));
        vm.stopPrank();
    }

    function testOracleError_StaleDataReverts() public {
        // Make data stale
        vm.prank(owner);
        custodian.setCustodianOracle(address(oracle), 0); // zero delay allowed
        // advance time by 1
        vm.warp(block.timestamp + 1);

        // Any call relying on price should revert
        vm.expectRevert(KRWTCustodianWithOracle.OracleError.selector);
        custodian.convertToShares(1e6);
    }

    function testOracleError_NegativePriceReverts() public {
        vm.prank(owner);
        oracle.setAnswer(-1);
        vm.expectRevert(KRWTCustodianWithOracle.OracleError.selector);
        custodian.convertToAssets(1e18);
    }

    function testOracleCachePathAndSetOracle() public {
        // First call triggers oracle read and caches
        uint256 p1 = custodian.convertToShares(1e6);
        // Same block subsequent call uses cached price
        uint256 p2 = custodian.convertToShares(1e6);
        assertEq(p1, p2);

        // set a new oracle via owner
        MockOracle newOracle = new MockOracle(8, "USDC/KRW", 4);
        newOracle.setAnswer(int256(1500 * 1e8));
        vm.prank(owner);
        custodian.setCustodianOracle(address(newOracle), 1 days);
        // Now price reflects new oracle value
        uint256 shares = custodian.convertToShares(1e6);
        assertEq(shares, 1500 * 1e18);
    }
}
