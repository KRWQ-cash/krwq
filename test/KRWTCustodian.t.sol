// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {KRWT} from "../src/KRWT.sol";
import {KRWTCustodian} from "../src/KRWTCustodian.sol";
import {MockERC20} from "./mocks/MockERC20.sol";

contract KRWTCustodianTest is Test {
    address owner;
    address user;

    KRWT krwt;
    MockERC20 usdc; // custodian token
    KRWTCustodian custodian;

    function setUp() public {
        owner = address(0xA11CE);
        user = address(0xB0B);

        vm.startPrank(owner);
        krwt = new KRWT(owner, "KRWT", "KRWT");
        usdc = new MockERC20("USD Coin", "USDC", 6);
        custodian = new KRWTCustodian(address(krwt), address(usdc));

        // KRWT: add custodian as minter so it can mint/burn
        krwt.addMinter(address(custodian));

        // initialize custodian settings via owner functions
        custodian.setMintCap(type(uint256).max);
        custodian.setMintRedeemFee(0, 0);
        vm.stopPrank();

        // fund user with USDC
        usdc.mint(user, 1_000_000e6);
    }

    function testConvertAndPreview_NoFees_ParValueDecimals() public view {
        // KRWT has 18 decimals, USDC 6 → 1e6 assets = 1e18 shares
        uint256 shares = custodian.convertToShares(1e6);
        assertEq(shares, 1e18);
        uint256 assets = custodian.convertToAssets(1e18);
        assertEq(assets, 1e6);

        // previews mirror converts when fees == 0
        assertEq(custodian.previewDeposit(1e6), 1e18);
        assertEq(custodian.previewMint(1e18), 1e6);
        assertEq(custodian.previewWithdraw(1e6), 1e18);
        assertEq(custodian.previewRedeem(1e18), 1e6);
    }

    function testDepositAndWithdraw_NoFees() public {
        vm.startPrank(user);
        // approve
        usdc.approve(address(custodian), type(uint256).max);

        // deposit 100 USDC
        uint256 assetsIn = 100e6;
        uint256 expectedShares = custodian.previewDeposit(assetsIn);
        uint256 sharesOut = custodian.deposit(assetsIn, user);
        assertEq(sharesOut, expectedShares);

        // balances
        assertEq(krwt.balanceOf(user), expectedShares);
        assertEq(usdc.balanceOf(address(custodian)), assetsIn);

        // withdraw 40 USDC
        uint256 withdrawAssets = 40e6;
        // approve custodian to burn user's KRWT shares
        krwt.approve(address(custodian), type(uint256).max);
        uint256 sharesIn = custodian.withdraw(withdrawAssets, user, user);
        assertEq(sharesIn, custodian.previewWithdraw(withdrawAssets));

        // balances after
        assertEq(usdc.balanceOf(user), 1_000_000e6 - assetsIn + withdrawAssets);
        assertEq(krwt.balanceOf(user), expectedShares - sharesIn);
        vm.stopPrank();
    }

    function testMintAndRedeem_NoFees() public {
        vm.startPrank(user);
        usdc.approve(address(custodian), type(uint256).max);

        uint256 sharesWanted = 250e18;
        uint256 assetsNeeded = custodian.previewMint(sharesWanted);
        uint256 assetsIn = custodian.mint(sharesWanted, user);
        assertEq(assetsIn, assetsNeeded);

        // approve custodian to burn user's KRWT shares for redeem
        krwt.approve(address(custodian), type(uint256).max);
        // redeem half
        uint256 sharesIn = sharesWanted / 2;
        uint256 assetsOut = custodian.redeem(sharesIn, user, user);
        assertEq(assetsOut, custodian.previewRedeem(sharesIn));
        vm.stopPrank();
    }

    function testFees_AppliedCorrectly() public {
        vm.prank(owner);
        custodian.setMintRedeemFee(0.01e18, 0.02e18); // 1% mint, 2% redeem

        vm.startPrank(user);
        usdc.approve(address(custodian), type(uint256).max);

        // deposit 100 USDC → 1% fee reduces assets considered to 99
        uint256 sharesOut = custodian.deposit(100e6, user);
        assertEq(sharesOut, custodian.convertToShares(99e6));

        // withdraw 50 USDC net → must pay fee, requiring more shares
        krwt.approve(address(custodian), type(uint256).max);
        uint256 sharesIn = custodian.withdraw(50e6, user, user);
        // compute expected via preview
        assertEq(sharesIn, custodian.previewWithdraw(50e6));
        vm.stopPrank();
    }

    function testMintCap_Enforced() public {
        vm.prank(owner);
        custodian.setMintCap(1_000e18);

        vm.startPrank(user);
        usdc.approve(address(custodian), type(uint256).max);

        // mint exactly up to cap
        custodian.mint(1_000e18, user);

        // now further minting should revert
        vm.expectRevert();
        custodian.mint(1, user);
        vm.stopPrank();
    }

    function testMaxViews_ReflectBalances() public {
        // Initially cap is max, so maxMint is large
        assertGt(custodian.maxMint(user), 0);
        // after setting a finite cap, values adjust
        vm.prank(owner);
        custodian.setMintCap(1_000e18);
        assertEq(custodian.maxMint(user), 1_000e18);

        // deposit some USDC so withdrawals have liquidity
        usdc.mint(address(custodian), 500e6);
        (uint256 md, uint256 mm, uint256 mw, uint256 mr) = custodian.mdwrComboView();
        assertEq(mw, 500e6);
        assertEq(mr, custodian.previewWithdraw(500e6));
        // md/mint are consistent
        assertEq(md, custodian.previewMint(mm));
    }

    function testInitialize_Reverts() public {
        // Base constructor sets wasInitialized = true, so initialize should revert
        vm.expectRevert(KRWTCustodian.InitializeFailed.selector);
        custodian.initialize(owner, 0, 0, 0);
    }

    function testViewsAndPricePerShareAndMaxes() public {
        // asset and supply/totalAssets views
        assertEq(custodian.asset(), address(usdc));
        assertEq(custodian.totalAssets(), 0);
        assertEq(custodian.totalSupply(), 0);

        // pricePerShare at start should be 1e6 assets per 1e18 shares for base (scaled)
        assertEq(custodian.pricePerShare(), custodian.convertToAssets(1e18));

        // maxDeposit/mint when nothing minted and cap is max
        assertGt(custodian.maxDeposit(user), 0);
        assertGt(custodian.maxMint(user), 0);

        // After funding contract with assets, maxWithdraw/maxRedeem reflect balances
        usdc.mint(address(custodian), 123e6);
        assertEq(custodian.maxWithdraw(user), 0); // user has no shares, so 0
        assertEq(custodian.maxRedeem(user), 0);
    }

    function testSetMintRedeemFee_RevertWhenBothTooHigh() public {
        vm.startPrank(owner);
        // both >= 1e18 should revert
        vm.expectRevert(bytes("Fee must be a fraction of underlying"));
        custodian.setMintRedeemFee(1e18, 1e18);
        vm.stopPrank();
    }

    function testRecoverERC20_OwnerOnly() public {
        // send some USDC to custodian then recover to owner
        usdc.mint(address(custodian), 55e6);
        uint256 ownerBefore = usdc.balanceOf(owner);
        vm.prank(owner);
        vm.expectEmit(true, false, false, true);
        emit KRWTCustodian.RecoveredERC20(address(usdc), 55e6);
        custodian.recoverERC20(address(usdc), 55e6);
        assertEq(usdc.balanceOf(owner), ownerBefore + 55e6);
    }
}
