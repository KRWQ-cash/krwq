// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console2 as console} from "forge-std/Test.sol";
import {KRWT} from "../src/KRWT.sol";
import {ERC20Permit, ERC20} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ITransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import {StorageSlot} from "@openzeppelin/contracts/utils/StorageSlot.sol";

/**
 * @title KRWT V2 Unprotected
 * @notice Variant without initialization guard
 */
contract KRWTV2Unprotected is ERC20Permit, ERC20Burnable, Ownable2Step {
    address[] public mintersArray;
    mapping(address => bool) public minters;

    constructor(address _ownerAddress, string memory _name, string memory _symbol)
        ERC20(_name, _symbol)
        ERC20Permit(_name)
        Ownable(_ownerAddress)
    {}

    modifier onlyMinters() {
        require(minters[msg.sender] == true, "Only minters");
        _;
    }

    function initializeV2(address _owner, string memory _name, string memory _symbol) public {
        _transferOwnership(_owner);
        StorageSlot.getBytesSlot(bytes32(uint256(3))).value = bytes(_name);
        StorageSlot.getBytesSlot(bytes32(uint256(4))).value = bytes(_symbol);
    }

    function minterBurnFrom(address burnAddress, uint256 burnAmount) public onlyMinters {
        super.burnFrom(burnAddress, burnAmount);
        emit TokenMinterBurned(burnAddress, msg.sender, burnAmount);
    }

    function minterMint(address mintAddress, uint256 mintAmount) public onlyMinters {
        super._mint(mintAddress, mintAmount);
        emit TokenMinterMinted(msg.sender, mintAddress, mintAmount);
    }

    function addMinter(address minterAddress) public onlyOwner {
        require(minterAddress != address(0), "Zero address detected");
        require(minters[minterAddress] == false, "Address already exists");
        minters[minterAddress] = true;
        mintersArray.push(minterAddress);
        emit MinterAdded(minterAddress);
    }

    function removeMinter(address minterAddress) public onlyOwner {
        require(minterAddress != address(0), "Zero address detected");
        require(minters[minterAddress] == true, "Address nonexistant");
        delete minters[minterAddress];
        for (uint256 i = 0; i < mintersArray.length; i++) {
            if (mintersArray[i] == minterAddress) {
                mintersArray[i] = address(0);
                break;
            }
        }
        emit MinterRemoved(minterAddress);
    }

    event Burn(address indexed account, uint256 amount);
    event Mint(address indexed account, uint256 amount);
    event MinterAdded(address minterAddress);
    event MinterRemoved(address minterAddress);
    event TokenMinterBurned(address indexed from, address indexed to, uint256 amount);
    event TokenMinterMinted(address indexed from, address indexed to, uint256 amount);
}

/**
 * @title KRWT V2 Protected
 * @notice Variant with updateTokenMetadata function
 */
contract KRWTV2Protected is ERC20Permit, ERC20Burnable, Ownable2Step {
    address[] public mintersArray;
    mapping(address => bool) public minters;

    constructor(address _ownerAddress, string memory _name, string memory _symbol)
        ERC20(_name, _symbol)
        ERC20Permit(_name)
        Ownable(_ownerAddress)
    {}

    modifier onlyMinters() {
        require(minters[msg.sender] == true, "Only minters");
        _;
    }

    function updateTokenMetadata(string memory _name, string memory _symbol) external onlyOwner {
        require(bytes(_name).length > 0, "Name cannot be empty");
        require(bytes(_symbol).length > 0, "Symbol cannot be empty");

        StorageSlot.getBytesSlot(bytes32(uint256(3))).value = bytes(_name);
        StorageSlot.getBytesSlot(bytes32(uint256(4))).value = bytes(_symbol);

        emit TokenMetadataUpdated(_name, _symbol);
    }

    function minterBurnFrom(address burnAddress, uint256 burnAmount) public onlyMinters {
        super.burnFrom(burnAddress, burnAmount);
        emit TokenMinterBurned(burnAddress, msg.sender, burnAmount);
    }

    function minterMint(address mintAddress, uint256 mintAmount) public onlyMinters {
        super._mint(mintAddress, mintAmount);
        emit TokenMinterMinted(msg.sender, mintAddress, mintAmount);
    }

    function addMinter(address minterAddress) public onlyOwner {
        require(minterAddress != address(0), "Zero address detected");
        require(minters[minterAddress] == false, "Address already exists");
        minters[minterAddress] = true;
        mintersArray.push(minterAddress);
        emit MinterAdded(minterAddress);
    }

    function removeMinter(address minterAddress) public onlyOwner {
        require(minterAddress != address(0), "Zero address detected");
        require(minters[minterAddress] == true, "Address nonexistant");
        delete minters[minterAddress];
        for (uint256 i = 0; i < mintersArray.length; i++) {
            if (mintersArray[i] == minterAddress) {
                mintersArray[i] = address(0);
                break;
            }
        }
        emit MinterRemoved(minterAddress);
    }

    event Burn(address indexed account, uint256 amount);
    event Mint(address indexed account, uint256 amount);
    event MinterAdded(address minterAddress);
    event MinterRemoved(address minterAddress);
    event TokenMinterBurned(address indexed from, address indexed to, uint256 amount);
    event TokenMinterMinted(address indexed from, address indexed to, uint256 amount);
    event TokenMetadataUpdated(string name, string symbol);
}

contract KRWTUpgradeForkTest is Test {
    // Mainnet deployed addresses
    address constant PROXY = 0xc00db6b41473d065027F5Ed6fAdA20fde75f142e;
    address constant CURRENT_IMPL = 0x00030dbD42E18C22a6E1909edD308F9BEeBBDe21;
    address constant PROXY_ADMIN = 0xff85d94faBB650c086C83b112e7126048A5e31bb;

    KRWT proxy;
    ProxyAdmin proxyAdmin;
    address owner;
    address thirdParty;
    address alice;
    address bob;

    function requireMainnetFork() internal view returns (bool) {
        return block.chainid == 1;
    }

    function setUp() public {
        if (!requireMainnetFork()) {
            console.log("Skipping: Not on mainnet fork");
            return;
        }

        proxy = KRWT(PROXY);
        proxyAdmin = ProxyAdmin(PROXY_ADMIN);
        owner = proxy.owner();
        thirdParty = makeAddr("thirdParty");
        alice = makeAddr("alice");
        bob = makeAddr("bob");

        console.log("=== Fork Test Configuration ===");
        console.log("Chain ID:", block.chainid);
        console.log("Block Number:", block.number);
        console.log("Proxy:", PROXY);
        console.log("Current Implementation:", CURRENT_IMPL);
        console.log("ProxyAdmin:", PROXY_ADMIN);
        console.log("Owner:", owner);
        console.log("Current Name:", proxy.name());
        console.log("Current Symbol:", proxy.symbol());
        console.log("Total Supply:", proxy.totalSupply());
    }

    function test_UnprotectedApproach() public {
        if (!requireMainnetFork()) return;

        console.log("\n=== Test: Unprotected Approach ===");

        KRWTV2Unprotected newImpl = new KRWTV2Unprotected(address(1), "", "");
        console.log("Deployed unprotected implementation:", address(newImpl));

        bytes memory initData = abi.encodeWithSelector(KRWTV2Unprotected.initializeV2.selector, owner, "KRWQ", "KRWQ");

        vm.prank(owner);
        proxyAdmin.upgradeAndCall(ITransparentUpgradeableProxy(PROXY), address(newImpl), initData);

        console.log("\nAfter upgrade:");
        console.log("  Name:", proxy.name());
        console.log("  Symbol:", proxy.symbol());
        console.log("  Owner:", proxy.owner());

        assertEq(proxy.name(), "KRWQ");
        assertEq(proxy.owner(), owner);

        console.log("\nAttacker attempts re-initialization:");
        vm.prank(thirdParty);
        KRWTV2Unprotected(PROXY).initializeV2(thirdParty, "Exploited Token", "HACK");

        console.log("  Name:", proxy.name());
        console.log("  Owner:", proxy.owner());

        assertEq(proxy.owner(), thirdParty, "Ownership stolen");
        assertEq(proxy.name(), "Exploited Token", "Name changed");

        vm.prank(owner);
        vm.expectRevert();
        proxy.addMinter(owner);

        console.log("  Result: Ownership stolen, original owner locked out");
    }

    /**
     * @notice Test protected upgrade approach
     */
    function test_ProtectedApproach() public {
        if (!requireMainnetFork()) return;

        console.log("\n=== Test: Protected Approach ===");

        KRWTV2Protected newImpl = new KRWTV2Protected(address(1), "", "");
        console.log("Deployed protected implementation:", address(newImpl));

        vm.prank(owner);
        proxyAdmin.upgradeAndCall(ITransparentUpgradeableProxy(PROXY), address(newImpl), "");

        console.log("Upgrade completed (no initialization)");

        vm.prank(owner);
        KRWTV2Protected(PROXY).updateTokenMetadata("Updated KRWT", "KRWT2");

        console.log("\nAfter metadata update:");
        console.log("  Name:", proxy.name());
        console.log("  Symbol:", proxy.symbol());
        console.log("  Owner:", proxy.owner());

        assertEq(proxy.name(), "Updated KRWT");
        assertEq(proxy.owner(), owner);

        console.log("\nSecurity verification:");
        vm.prank(thirdParty);
        vm.expectRevert();
        KRWTV2Protected(PROXY).updateTokenMetadata("Exploit", "HACK");
        console.log("  updateTokenMetadata() access control: verified");

        vm.prank(owner);
        proxy.addMinter(owner);
        assertTrue(proxy.minters(owner));
        console.log("  Owner access: maintained");

        console.log("  Result: Secure upgrade with no vulnerabilities");
    }

    /**
     * @notice Verify state preservation
     */
    function test_StatePreservation() public {
        if (!requireMainnetFork()) return;

        console.log("\n=== Test: State Preservation ===");

        vm.prank(owner);
        proxy.addMinter(address(this));

        uint256 aliceMint = 1_000 ether;
        uint256 bobMint = 2_000 ether;

        proxy.minterMint(alice, aliceMint);
        proxy.minterMint(bob, bobMint);

        uint256 supplyBefore = proxy.totalSupply();
        address ownerBefore = proxy.owner();
        string memory nameBefore = proxy.name();
        uint256 aliceBalanceBefore = proxy.balanceOf(alice);
        uint256 bobBalanceBefore = proxy.balanceOf(bob);

        console.log("State before upgrade:");
        console.log("  Total Supply:", supplyBefore);
        console.log("  Owner:", ownerBefore);
        console.log("  Name:", nameBefore);
        console.log("  Alice balance:", aliceBalanceBefore);
        console.log("  Bob balance:", bobBalanceBefore);

        KRWTV2Protected newImpl = new KRWTV2Protected(address(1), "", "");

        vm.prank(owner);
        proxyAdmin.upgradeAndCall(ITransparentUpgradeableProxy(PROXY), address(newImpl), "");

        vm.prank(owner);
        KRWTV2Protected(PROXY).updateTokenMetadata("New Name", "NEW");

        uint256 supplyAfter = proxy.totalSupply();
        uint256 aliceBalanceAfter = proxy.balanceOf(alice);
        uint256 bobBalanceAfter = proxy.balanceOf(bob);
        address ownerAfter = proxy.owner();
        string memory nameAfter = proxy.name();

        console.log("\nState after upgrade:");
        console.log("  Total Supply:", supplyAfter);
        console.log("  Owner:", ownerAfter);
        console.log("  Name:", nameAfter);
        console.log("  Alice balance:", aliceBalanceAfter);
        console.log("  Bob balance:", bobBalanceAfter);

        assertEq(supplyAfter, supplyBefore, "Supply preserved");
        assertEq(ownerAfter, ownerBefore, "Owner preserved");
        assertEq(nameAfter, "New Name", "Name updated");
        assertEq(aliceBalanceAfter, aliceBalanceBefore, "Alice balance preserved");
        assertEq(bobBalanceAfter, bobBalanceBefore, "Bob balance preserved");

        console.log("  Result: All state preserved correctly, including holder balances");
    }
}
