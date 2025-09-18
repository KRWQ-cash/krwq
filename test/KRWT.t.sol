// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";

import {KRWT} from "../src/KRWT.sol"; // adjust path if needed
import {IERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";

contract KRWTTest is Test {
    // --- Test actors / keys
    uint256 internal ownerPk;
    address internal owner;

    uint256 internal minterPk;
    address internal minter;

    uint256 internal userPk;
    address internal user;

    KRWT internal token;

    string internal constant NAME = "KRWT";
    string internal constant SYMBOL = "KRWT";

    // EIP-2612 Permit typehash
    bytes32 internal constant PERMIT_TYPEHASH =
        keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");

    function setUp() public {
        // deterministic private keys for test accounts
        ownerPk = uint256(keccak256("owner"));
        owner = vm.addr(ownerPk);

        minterPk = uint256(keccak256("minter"));
        minter = vm.addr(minterPk);

        userPk = uint256(keccak256("user"));
        user = vm.addr(userPk);

        vm.prank(owner);
        token = new KRWT(owner, NAME, SYMBOL);
    }

    // --- Helpers ---

    function _domainSeparator() internal view returns (bytes32) {
        // OZ ERC20Permit exposes DOMAIN_SEPARATOR() in recent versions
        // If your OZ version doesn’t, replace with manual EIP712 domain build.
        // solhint-disable-next-line func-name-mixedcase
        (bool ok, bytes memory data) = address(token).staticcall(abi.encodeWithSignature("DOMAIN_SEPARATOR()"));
        require(ok && data.length == 32, "DOMAIN_SEPARATOR() not found");
        return abi.decode(data, (bytes32));
    }

    function _permitDigest(address owner_, address spender_, uint256 value_, uint256 nonce_, uint256 deadline_)
        internal
        view
        returns (bytes32)
    {
        bytes32 structHash = keccak256(abi.encode(PERMIT_TYPEHASH, owner_, spender_, value_, nonce_, deadline_));
        return keccak256(abi.encodePacked("\x19\x01", _domainSeparator(), structHash));
    }

    // --- Tests ---

    function testConstructor_SetsOwnerNameSymbol() public view {
        assertEq(token.owner(), owner);
        assertEq(token.name(), NAME);
        assertEq(token.symbol(), SYMBOL);
    }

    function testInitialize_RevertsOnRegularDeployment() public {
        // Because Ownable(owner) in constructor already set owner,
        // initialize() must revert with "Already initialized"
        vm.expectRevert(bytes("Already initialized"));
        token.initialize(owner, "X", "Y");
    }

    function testOnlyOwner_AddMinter_Works() public {
        // Non-owner cannot add
        vm.prank(minter);
        vm.expectRevert(); // Ownable revert
        token.addMinter(minter);

        // Owner adds
        vm.prank(owner);
        vm.expectEmit(true, false, false, true);
        emit KRWT.MinterAdded(minter);
        token.addMinter(minter);

        // Duplicate add reverts
        vm.prank(owner);
        vm.expectRevert(bytes("Address already exists"));
        token.addMinter(minter);

        // Zero addr reverts
        vm.prank(owner);
        vm.expectRevert(bytes("Zero address detected"));
        token.addMinter(address(0));

        assertTrue(token.minters(minter));
        // Check it’s present in the array (position 0 in first add)
        (bool found, uint256 idx) = _findInMintersArray(minter);
        assertTrue(found);
        assertEq(idx, 0);
    }

    function testOnlyOwner_RemoveMinter_WorksAndLeavesHole() public {
        // Setup: add two minters
        address m1 = minter;
        address m2 = vm.addr(uint256(keccak256("minter2")));
        vm.startPrank(owner);
        token.addMinter(m1);
        token.addMinter(m2);
        vm.stopPrank();

        // Non-owner cannot remove
        vm.prank(m2);
        vm.expectRevert();
        token.removeMinter(m1);

        // Remove m1 as owner
        vm.prank(owner);
        vm.expectEmit(true, false, false, true);
        emit KRWT.MinterRemoved(m1);
        token.removeMinter(m1);

        // Mapping cleared
        assertFalse(token.minters(m1));

        // Array has a hole (address(0)) where m1 used to be
        (bool foundM1,) = _findInMintersArray(m1);
        assertTrue(!foundM1);
        // Confirm hole - since m1 was the first added (index 0), it should be address(0)
        address[] memory arr = _readMintersArray();
        assertEq(arr[0], address(0));

        // Removing non-existent reverts
        vm.prank(owner);
        vm.expectRevert(bytes("Address nonexistant"));
        token.removeMinter(m1);
    }

    function testOnlyMinters_Guard() public {
        // Not a minter → revert
        vm.startPrank(user);
        vm.expectRevert(bytes("Only minters"));
        token.minterMint(user, 1);
        vm.stopPrank();
    }

    function testMinterMint_EmitsAndBalances() public {
        // add minter
        vm.prank(owner);
        token.addMinter(minter);

        vm.prank(minter);
        vm.expectEmit(true, true, false, true);
        emit KRWT.TokenMinterMinted(minter, user, 123);
        token.minterMint(user, 123);

        assertEq(token.balanceOf(user), 123);
        assertEq(token.totalSupply(), 123);
    }

    function testMinterBurnFrom_WithPermit() public {
        // add minter
        vm.prank(owner);
        token.addMinter(minter);

        // mint to user (by minter)
        vm.prank(minter);
        token.minterMint(user, 1_000 ether);
        assertEq(token.balanceOf(user), 1_000 ether);

        // user signs permit to allow minter to burnFrom
        uint256 value = 600 ether;
        uint256 nonce = token.nonces(user);
        uint256 deadline = block.timestamp + 1 days;

        bytes32 digest = _permitDigest(user, minter, value, nonce, deadline);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(userPk, digest);

        // Call permit
        vm.prank(user);
        IERC20Permit(address(token)).permit(user, minter, value, deadline, v, r, s);

        // minter burns from user using burnFrom
        vm.prank(minter);
        vm.expectEmit(true, true, false, true);
        emit KRWT.TokenMinterBurned(user, minter, 200 ether);
        token.minterBurnFrom(user, 200 ether);

        assertEq(token.balanceOf(user), 800 ether);
        assertEq(token.allowance(user, minter), 400 ether); // 600 - 200
        assertEq(token.totalSupply(), 800 ether);
    }

    function testPermit_NameMatches() public view {
        // sanity: the ERC20Permit domain uses name as ERC20 name
        // (This doesn’t call external funcs; it’s a doc-check / invariant idea)
        assertEq(token.name(), NAME);
    }

    function testAddRemoveMinter_ZeroAddressReverts() public {
        vm.startPrank(owner);
        vm.expectRevert(bytes("Zero address detected"));
        token.addMinter(address(0));

        // Add a valid
        token.addMinter(minter);

        vm.expectRevert(bytes("Zero address detected"));
        token.removeMinter(address(0));
        vm.stopPrank();
    }

    // --- Internal helpers to peek into mintersArray ---

    function _readMintersArray() internal view returns (address[] memory out) {
        uint256 N = 8;
        out = new address[](N);
        for (uint256 i = 0; i < N; i++) {
            try this.mintersArrayAt(address(token), i) returns (address a) {
                out[i] = a;
            } catch {
                break;
            }
        }
    }

    function mintersArrayAt(address t, uint256 i) external view returns (address a) {
        return KRWT(t).mintersArray(i);
    }

    function _findInMintersArray(address who) internal view returns (bool found, uint256 idx) {
        for (uint256 i = 0; i < 8; i++) {
            try this.mintersArrayAt(address(token), i) returns (address a) {
                if (a == who) return (true, i);
            } catch {
                break;
            }
        }
        return (false, type(uint256).max);
    }
}
