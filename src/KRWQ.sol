// SPDX-License-Identifier: MIT
// @version 0.2.8
pragma solidity ^0.8.24;

/*
+--------------------------------------------------------------+
|             $*                         *8*                   |
|            88   $*                      "*8"  .              |
|           88   88   $*               *8*     8 *,            |
|          88   88   88                 "*8 *   "*8*           |
|         88   88   88              *8 *   "*8 * ,             |
|        *$   88   88                " *8" .  "*8*             |
|            *$   88        .-888-.        8 * ,               |
|                *$       .888red888.       "*8*               |
|                        ,888888.*;;*.                         |
|                        888888*;;;;;`                         |
|                        888888*;;;;;j                         |
|                        `*00*";;;;;.'                         |
|               *8*       `;;;blue;;'        $*                |
|                "*8 *      `-;;;-'         88   $*            |
|             *8*   "*8 *,                 "*   88   $*        |
|              "*8" .  "*8*               *.   "*   88         |
|          *8 *     8 * ,                88   *.   "*          |
|           " *8 *   "*8*               *$   88   *.           |
|               "*8 * ,                     *$   88            |
|                  "*8*                         *$       KRWQ  |
+--------------------------------------------------------------+
*/

import {ERC20Permit, ERC20} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {StorageSlot} from "@openzeppelin/contracts/utils/StorageSlot.sol";

/// @title KRWQ
/**
 * @notice Combines Openzeppelin's ERC20Permit, ERC20Burnable and Ownable2Step.
 *     Also includes a list of authorized minters
 */
/// @dev KRWQ adheres to EIP-712/EIP-2612 and can use permits
contract KRWQ is ERC20Permit, ERC20Burnable, Ownable2Step {
    /// @notice Array of the non-bridge minters
    address[] public mintersArray;

    /// @notice Mapping of the minters
    /// @dev Mapping is used for faster verification
    mapping(address => bool) public minters;

    /* ========== CONSTRUCTOR ========== */
    /// @param _ownerAddress The initial owner
    /// @param _name ERC20 name
    /// @param _symbol ERC20 symbol
    constructor(address _ownerAddress, string memory _name, string memory _symbol)
        ERC20(_name, _symbol)
        ERC20Permit(_name)
        Ownable(_ownerAddress)
    {}

    /* ========== INITIALIZER ========== */
    /// @dev Used to initialize the contract when it is behind a proxy
    function initialize(address _owner, string memory _name, string memory _symbol) public {
        require(owner() == address(0), "Already initialized");
        _transferOwnership(_owner);
        StorageSlot.getBytesSlot(bytes32(uint256(3))).value = bytes(_name);
        StorageSlot.getBytesSlot(bytes32(uint256(4))).value = bytes(_symbol);
    }

    /// @notice Update token name and symbol metadata
    /// @dev Can be called by owner at any time to update token metadata
    /// @param _name New ERC20 name
    /// @param _symbol New ERC20 symbol
    function updateMetadata(string memory _name, string memory _symbol) public onlyOwner {
        StorageSlot.getBytesSlot(bytes32(uint256(3))).value = bytes(_name);
        StorageSlot.getBytesSlot(bytes32(uint256(4))).value = bytes(_symbol);
        emit MetadataUpdated(_name, _symbol);
    }

    /* ========== MODIFIERS ========== */

    /// @notice A modifier that only allows a minters to call
    modifier onlyMinters() {
        require(minters[msg.sender] == true, "Only minters");
        _;
    }

    /* ========== RESTRICTED FUNCTIONS [MINTERS] ========== */

    /// @notice Used by minters to burn tokens
    /// @param burnAddress Address of the account to burn from
    /// @param burnAmount Amount of tokens to burn
    function minterBurnFrom(address burnAddress, uint256 burnAmount) public onlyMinters {
        super.burnFrom(burnAddress, burnAmount);
        emit TokenMinterBurned(burnAddress, msg.sender, burnAmount);
    }

    /// @notice Used by minters to mint new tokens
    /// @param mintAddress Address of the account to mint to
    /// @param mintAmount Amount of tokens to mint
    function minterMint(address mintAddress, uint256 mintAmount) public onlyMinters {
        super._mint(mintAddress, mintAmount);
        emit TokenMinterMinted(msg.sender, mintAddress, mintAmount);
    }

    /* ========== RESTRICTED FUNCTIONS [OWNER] ========== */
    /// @notice Adds a minter
    /// @param minterAddress Address of minter to add
    function addMinter(address minterAddress) public onlyOwner {
        require(minterAddress != address(0), "Zero address detected");

        require(minters[minterAddress] == false, "Address already exists");
        minters[minterAddress] = true;
        mintersArray.push(minterAddress);

        emit MinterAdded(minterAddress);
    }

    /// @notice Removes a non-bridge minter
    /// @param minterAddress Address of minter to remove
    function removeMinter(address minterAddress) public onlyOwner {
        require(minterAddress != address(0), "Zero address detected");
        require(minters[minterAddress] == true, "Address nonexistant");

        // Delete from the mapping
        delete minters[minterAddress];

        // 'Delete' from the array by setting the address to 0x0
        for (uint256 i = 0; i < mintersArray.length; i++) {
            if (mintersArray[i] == minterAddress) {
                mintersArray[i] = address(0); // This will leave a null in the array and keep the indices the same
                break;
            }
        }

        emit MinterRemoved(minterAddress);
    }

    /* ========== EVENTS ========== */

    /// @notice Emitted whenever the bridge burns tokens from an account
    /// @param account Address of the account tokens are being burned from
    /// @param amount  Amount of tokens burned
    event Burn(address indexed account, uint256 amount);

    /// @notice Emitted whenever the bridge mints tokens to an account
    /// @param account Address of the account tokens are being minted for
    /// @param amount  Amount of tokens minted.
    event Mint(address indexed account, uint256 amount);

    /// @notice Emitted when a non-bridge minter is added
    /// @param minterAddress Address of the new minter
    event MinterAdded(address minterAddress);

    /// @notice Emitted when a non-bridge minter is removed
    /// @param minterAddress Address of the removed minter
    event MinterRemoved(address minterAddress);

    /// @notice Emitted when a non-bridge minter burns tokens
    /// @param from The account whose tokens are burned
    /// @param to The minter doing the burning
    /// @param amount Amount of tokens burned
    event TokenMinterBurned(address indexed from, address indexed to, uint256 amount);

    /// @notice Emitted when a non-bridge minter mints tokens
    /// @param from The minter doing the minting
    /// @param to The account that gets the newly minted tokens
    /// @param amount Amount of tokens minted
    event TokenMinterMinted(address indexed from, address indexed to, uint256 amount);

    /// @notice Emitted when token metadata (name/symbol) is updated
    /// @param name New token name
    /// @param symbol New token symbol
    event MetadataUpdated(string name, string symbol);
}
