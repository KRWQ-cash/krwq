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
|                  "*8*                         *$       KRWT  |
+--------------------------------------------------------------+
*/

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {KRWT} from "./KRWT.sol";

contract KRWTCustodian is Ownable2Step, ReentrancyGuard {
    using Math for uint256;

    // STATE VARIABLES
    // ===================================================

    /// @notice KRWT token = share
    KRWT public immutable KRWT_TOKEN;

    /// @notice Custodian token = asset
    IERC20 public immutable CUSTODIAN_TKN;

    /// @notice Decimals for the KRWT
    uint8 public immutable KRWT_DECIMALS;

    /// @notice Decimals for the custodian token
    uint8 public immutable CUSTODIAN_TKN_DECIMALS;

    /// @notice If the contract was initialized
    bool public wasInitialized;

    /// @notice Fee for minting. 18 decimals
    uint256 public mintFee;

    /// @notice Fee for redeeming. 18 decimals
    uint256 public redeemFee;

    /// @notice Mint cap for KRWT minting
    uint256 public mintCap;

    /// @notice KRWT minted accounting
    uint256 public krwtMinted;

    // CONSTRUCTOR & INITIALIZER
    // ===================================================

    /// @notice Contract constructor
    constructor(address _krwt, address _custodianTkn) Ownable(msg.sender) {
        // Set the contract as initialized
        wasInitialized = true;

        // Set token addresses
        KRWT_TOKEN = KRWT(_krwt);
        CUSTODIAN_TKN = IERC20(_custodianTkn);

        // Set decimals
        KRWT_DECIMALS = KRWT_TOKEN.decimals();
        CUSTODIAN_TKN_DECIMALS = ERC20(_custodianTkn).decimals();
    }

    /**
     * @notice Initialize contract
     * @param _owner The owner of this contract
     * @param _mintCap The mint cap for KRWT minting
     * @param _mintFee The mint fee
     * @param _redeemFee The redeem fee
     */
    function initialize(address _owner, uint256 _mintCap, uint256 _mintFee, uint256 _redeemFee) public {
        // Make sure the contract wasn't already initialized
        if (wasInitialized) revert InitializeFailed();

        // Set owner for Ownable
        _transferOwnership(_owner);

        // Set the mint cap
        mintCap = _mintCap;

        // Set the mint/redeem fee
        mintFee = _mintFee;
        redeemFee = _redeemFee;

        // Set the contract as initialized
        wasInitialized = true;
    }

    // ERC4626 PUBLIC/EXTERNAL VIEWS
    // ===================================================

    /// @notice Return the underlying asset
    /// @return _custodianTkn The custodianTkn asset
    function asset() public view returns (address _custodianTkn) {
        _custodianTkn = address(CUSTODIAN_TKN);
    }

    /// @notice Share balance of the supplied address
    /// @param _addr The address to test
    /// @return _balance Total amount of shares
    function balanceOf(address _addr) public view returns (uint256 _balance) {
        return KRWT_TOKEN.balanceOf(_addr);
    }

    /// @notice Total amount of underlying asset available
    /// @param _assets Amount of underlying tokens
    /// @dev See {IERC4626-totalAssets}
    function totalAssets() public view returns (uint256 _assets) {
        return CUSTODIAN_TKN.balanceOf(address(this));
    }

    /// @notice Total amount of shares
    /// @return _supply Total amount of shares
    function totalSupply() public view returns (uint256 _supply) {
        return KRWT_TOKEN.totalSupply();
    }

    /// @notice Returns the amount of shares that the contract would exchange for the amount of assets provided
    /// @param _assets Amount of underlying tokens
    /// @return _shares Amount of shares that the underlying _assets represents
    /// @dev See {IERC4626-convertToShares}
    function convertToShares(uint256 _assets) public view returns (uint256 _shares) {
        _shares = _convertToShares(_assets, Math.Rounding.Floor);
    }

    /// @notice Returns the amount of assets that the contract would exchange for the amount of shares provided
    /// @param _shares Amount of shares
    /// @return _assets Amount of underlying asset that _shares represents
    /// @dev See {IERC4626-convertToAssets}
    function convertToAssets(uint256 _shares) public view returns (uint256 _assets) {
        _assets = _convertToAssets(_shares, Math.Rounding.Floor);
    }

    /// @notice Returns the maximum amount of the underlying asset that can be deposited into the contract for the receiver, through a deposit call. Includes fee.
    /// @param _addr The address to test
    /// @return _maxAssetsIn The max amount that can be deposited
    /**
     * @dev See {IERC4626-maxDeposit}
     * Contract KRWT -> custodianTkn needed
     */
    function maxDeposit(address /* _addr */ ) public view returns (uint256 _maxAssetsIn) {
        // See how much custodianTkn you would need to exchange for 100% of the KRWT available under the cap
        if (krwtMinted >= mintCap) _maxAssetsIn = 0;
        else _maxAssetsIn = previewMint(mintCap - krwtMinted);
    }

    /// @notice Returns the maximum amount of shares that can be minted for the receiver, through a mint call. Includes fee.
    /// @param _addr The address to test
    /// @return _maxSharesOut The max amount that can be minted
    /**
     * @dev See {IERC4626-maxMint}
     * Contract KRWT balance
     */
    function maxMint(address /* _addr */ ) public view returns (uint256 _maxSharesOut) {
        // See how much KRWT is actually available in the contract
        if (krwtMinted >= mintCap) _maxSharesOut = 0;
        else _maxSharesOut = mintCap - krwtMinted;
    }

    /// @notice Returns the maximum amount of the underlying asset that can be withdrawn from the owner balance in the contract, through a withdraw call. Includes fee.
    /// @param _owner The address to check
    /// @return _maxAssetsOut The maximum amount of underlying asset that can be withdrawn
    /**
     * @dev See {IERC4626-maxWithdraw}
     * Lesser of
     *     a) User KRWT -> custodianTkn amount
     *     b) Contract custodianTkn balance
     */
    function maxWithdraw(address _owner) public view returns (uint256 _maxAssetsOut) {
        // See how much custodianTkn the user could possibly withdraw with 100% of his KRWT
        uint256 _maxAssetsUser = previewRedeem(KRWT_TOKEN.balanceOf(address(_owner)));

        // See how much custodianTkn is actually available in the contract
        uint256 _assetBalanceContract = CUSTODIAN_TKN.balanceOf(address(this));

        // Return the lesser of the two
        _maxAssetsOut = ((_assetBalanceContract > _maxAssetsUser) ? _maxAssetsUser : _assetBalanceContract);
    }

    /// @notice Returns the maximum amount of shares that can be redeemed from the owner balance in the contract, through a redeem call. Includes fee.
    /// @param _owner The address to check
    /// @return _maxSharesIn The maximum amount of shares that can be redeemed
    /**
     * @dev See {IERC4626-maxRedeem}
     * Lesser of
     *     a) User KRWT
     *     b) Contract custodianTkn -> KRWT amount
     */
    function maxRedeem(address _owner) public view returns (uint256 _maxSharesIn) {
        // See how much KRWT the contract could honor if 100% of its custodianTkn was redeemed
        uint256 _maxSharesContract = previewWithdraw(CUSTODIAN_TKN.balanceOf(address(this)));

        // See how much KRWT the user has
        uint256 _sharesBalanceUser = KRWT_TOKEN.balanceOf(address(_owner));

        // Return the lesser of the two
        _maxSharesIn = ((_maxSharesContract > _sharesBalanceUser) ? _sharesBalanceUser : _maxSharesContract);
    }

    /// @notice Allows an on-chain or off-chain user to simulate the effects of their deposit at the current block, given current on-chain conditions.
    /// @param _assetsIn Amount of underlying you want to deposit
    /// @return _sharesOut The amount of output shares expected
    /// @dev See {IERC4626-previewDeposit}
    function previewDeposit(uint256 _assetsIn) public view returns (uint256 _sharesOut) {
        uint256 fee = mintFee;
        if (fee > 0) _assetsIn = Math.mulDiv(_assetsIn, (1e18 - fee), 1e18, Math.Rounding.Floor);
        _sharesOut = _convertToShares(_assetsIn, Math.Rounding.Floor);
    }

    /// @notice Allows an on-chain or off-chain user to simulate the effects of their mint at the current block, given current on-chain conditions.
    /// @param _sharesOut Amount of shares you want to mint
    /// @return _assetsIn The amount of input assets needed
    /// @dev See {IERC4626-previewMint}
    function previewMint(uint256 _sharesOut) public view returns (uint256 _assetsIn) {
        uint256 fee = mintFee;
        _assetsIn = _convertToAssets(_sharesOut, Math.Rounding.Ceil);
        if (fee > 0) _assetsIn = Math.mulDiv(_assetsIn, 1e18, (1e18 - fee), Math.Rounding.Ceil);
    }

    /// @notice Allows an on-chain or off-chain user to simulate the effects of their withdrawal at the current block, given current on-chain conditions.
    /// @param _assetsOut Amount of underlying tokens you want to get back
    /// @return _sharesIn Amount of shares needed
    /// @dev See {IERC4626-previewWithdraw}
    function previewWithdraw(uint256 _assetsOut) public view returns (uint256 _sharesIn) {
        uint256 fee = redeemFee;
        if (fee > 0) _assetsOut = Math.mulDiv(_assetsOut, 1e18, (1e18 - fee), Math.Rounding.Ceil);
        _sharesIn = _convertToShares(_assetsOut, Math.Rounding.Ceil);
    }

    /// @notice Allows an on-chain or off-chain user to simulate the effects of their redeemption at the current block, given current on-chain conditions.
    /// @param _sharesIn Amount of shares you want to redeem
    /// @return _assetsOut Amount of output asset expected
    /// @dev See {IERC4626-previewRedeem}
    function previewRedeem(uint256 _sharesIn) public view returns (uint256 _assetsOut) {
        uint256 fee = redeemFee;
        _assetsOut = _convertToAssets(_sharesIn, Math.Rounding.Floor);
        if (fee > 0) _assetsOut = Math.mulDiv((1e18 - fee), _assetsOut, 1e18, Math.Rounding.Floor);
    }

    // ERC4626 INTERNAL VIEWS
    // ===================================================

    /// @dev Internal conversion function (from assets to shares) with support for rounding direction.
    /// @param _assets Amount of underlying tokens to convert to shares
    /// @param _rounding Math.Rounding rounding direction
    /// @return _shares Amount of shares represented by the given underlying tokens
    function _convertToShares(uint256 _assets, Math.Rounding _rounding)
        internal
        view
        virtual
        returns (uint256 _shares)
    {
        _shares = Math.mulDiv(_assets, uint256(10 ** KRWT_DECIMALS), uint256(10 ** CUSTODIAN_TKN_DECIMALS), _rounding);
    }

    /// @dev Internal conversion function (from shares to assets) with support for rounding direction
    /// @param _shares Amount of shares to convert to underlying tokens
    /// @param _rounding Math.Rounding rounding direction
    /// @return _assets Amount of underlying tokens represented by the given number of shares
    function _convertToAssets(uint256 _shares, Math.Rounding _rounding)
        internal
        view
        virtual
        returns (uint256 _assets)
    {
        _assets = Math.mulDiv(_shares, uint256(10 ** CUSTODIAN_TKN_DECIMALS), uint256(10 ** KRWT_DECIMALS), _rounding);
    }

    /// @notice Price of 1E18 shares, in asset tokens
    /// @return _pricePerShare How many underlying asset tokens per 1E18 shares
    function pricePerShare() external view returns (uint256 _pricePerShare) {
        _pricePerShare = _convertToAssets(1e18, Math.Rounding.Floor);
    }

    // ADDITIONAL PUBLIC VIEWS
    // ===================================================

    /// @notice Helper view for max deposit, mint, withdraw, and redeem inputs
    /// @return _maxAssetsDepositable Max amount of underlying asset you can deposit
    /// @return _maxSharesMintable Max number of shares that can be minted
    /// @return _maxAssetsWithdrawable Max amount of underlying asset withdrawable
    /// @return _maxSharesRedeemable Max number of shares redeemable
    function mdwrComboView()
        public
        view
        returns (
            uint256 _maxAssetsDepositable,
            uint256 _maxSharesMintable,
            uint256 _maxAssetsWithdrawable,
            uint256 _maxSharesRedeemable
        )
    {
        uint256 _maxMint = maxMint(address(this));
        return (
            previewMint(_maxMint),
            _maxMint,
            CUSTODIAN_TKN.balanceOf(address(this)),
            previewWithdraw(CUSTODIAN_TKN.balanceOf(address(this)))
        );
    }

    // ERC4626 INTERNAL MUTATORS
    // ===================================================

    /// @notice Deposit/mint common workflow.
    /// @param _caller The caller
    /// @param _receiver Reciever of the shares
    /// @param _assets Amount of assets taken in
    /// @param _shares Amount of shares given out
    function _deposit(address _caller, address _receiver, uint256 _assets, uint256 _shares) internal nonReentrant {
        // If _asset is ERC-777, `transferFrom` can trigger a reentrancy BEFORE the transfer happens through the
        // `tokensToSend` hook. On the other hand, the `tokenReceived` hook, that is triggered after the transfer,
        // calls the vault, which is assumed not malicious.
        //
        // Conclusion: we need to do the transfer beforehand so that any reentrancy would happen before the
        // _assets are transferred and before the _shares are minted, which is a valid state.
        // slither-disable-next-line reentrancy-no-eth

        // Take in the assets
        // User will need to approve _caller -> address(this) first
        SafeERC20.safeTransferFrom(IERC20(address(CUSTODIAN_TKN)), _caller, address(this), _assets);

        // Transfer out the shares / mint KRWT
        KRWT_TOKEN.minterMint(_receiver, _shares);

        // KRWT minted accounting
        krwtMinted += _shares;
        if (krwtMinted > mintCap) revert MintCapExceeded(_receiver, _shares, mintCap);

        emit Deposit(_caller, _receiver, _assets, _shares);
    }

    /// @notice Withdraw/redeem common workflow.
    /// @param _caller The caller
    /// @param _receiver Reciever of the assets
    /// @param _owner The owner of the shares
    /// @param _assets Amount of assets given out
    /// @param _shares Amount of shares taken in
    function _withdraw(address _caller, address _receiver, address _owner, uint256 _assets, uint256 _shares)
        internal
        nonReentrant
    {
        // If _asset is ERC-777, `transfer` can trigger a reentrancy AFTER the transfer happens through the
        // `tokensReceived` hook. On the other hand, the `tokensToSend` hook, that is triggered before the transfer,
        // calls the vault, which is assumed not malicious.
        //
        // Conclusion: we need to do the transfer afterwards so that any reentrancy would happen after the
        // _shares are burned and after the _assets are transferred, which is a valid state.

        // Take in the shares / burn KRWT
        // User will need to approve owner -> address(this) first
        KRWT_TOKEN.minterBurnFrom(_caller, _shares);

        // KRWT minted accounting
        if (krwtMinted < _shares) krwtMinted = 0;
        else krwtMinted -= _shares;

        // Transfer out the assets
        SafeERC20.safeTransfer(IERC20(address(CUSTODIAN_TKN)), _receiver, _assets);

        emit Withdraw(_caller, _receiver, _owner, _assets, _shares);
    }

    // ERC4626 PUBLIC/EXTERNAL MUTATIVE
    // ===================================================

    /// @notice Deposit a specified amount of underlying tokens and generate shares. Make sure to approve msg.sender's assets to this contract first.
    /// @param _assetsIn Amount of underlying tokens you are depositing
    /// @param _receiver Recipient of the generated shares
    /// @return _sharesOut Amount of shares generated by the deposit
    /// @dev See {IERC4626-deposit}
    function deposit(uint256 _assetsIn, address _receiver) public virtual returns (uint256 _sharesOut) {
        // See how many asset tokens the user can deposit
        uint256 _maxAssets = maxDeposit(_receiver);

        // Revert if the user is trying to deposit too many asset tokens
        if (_assetsIn > _maxAssets) {
            revert ERC4626ExceededMaxDeposit(_receiver, _assetsIn, _maxAssets);
        }

        // See how many shares would be generated with the specified number of asset tokens
        _sharesOut = previewDeposit(_assetsIn);

        // Do the deposit
        _deposit(msg.sender, _receiver, _assetsIn, _sharesOut);
    }

    /// @notice Mint a specified amount of shares using underlying asset tokens. Make sure to approve msg.sender's assets to this contract first.
    /// @param _sharesOut Amount of shares you want to mint
    /// @param _receiver Recipient of the minted shares
    /// @return _assetsIn Amount of assets used to generate the shares
    /// @dev See {IERC4626-mint}
    function mint(uint256 _sharesOut, address _receiver) public virtual returns (uint256 _assetsIn) {
        // See how many shares the user's can mint
        uint256 _maxShares = maxMint(_receiver);

        // Revert if you are trying to mint too many shares
        if (_sharesOut > _maxShares) {
            revert ERC4626ExceededMaxMint(_receiver, _sharesOut, _maxShares);
        }

        // See how many asset tokens are needed to generate the specified amount of shares
        _assetsIn = previewMint(_sharesOut);

        // Do the minting
        _deposit(msg.sender, _receiver, _assetsIn, _sharesOut);
    }

    /// @notice Withdraw a specified amount of underlying tokens. Make sure to approve _owner's shares to this contract first
    /// @param _assetsOut Amount of asset tokens you want to withdraw
    /// @param _receiver Recipient of the asset tokens
    /// @param _owner Owner of the shares. Must be msg.sender
    /// @return _sharesIn Amount of shares used for the withdrawal
    /// @dev See {IERC4626-withdraw}. Leaving _owner param for ABI compatibility
    function withdraw(uint256 _assetsOut, address _receiver, address _owner)
        public
        virtual
        returns (uint256 _sharesIn)
    {
        // Make sure _owner is msg.sender
        if (_owner != msg.sender) revert TokenOwnerShouldBeSender();

        // See how much assets the owner can withdraw
        uint256 _maxAssets = maxWithdraw(_owner);

        // Revert if you are trying to withdraw too many asset tokens
        if (_assetsOut > _maxAssets) {
            revert ERC4626ExceededMaxWithdraw(_owner, _assetsOut, _maxAssets);
        }

        // See how many shares are needed
        _sharesIn = previewWithdraw(_assetsOut);

        // Do the withdrawal
        _withdraw(msg.sender, _receiver, _owner, _assetsOut, _sharesIn);
    }

    /// @notice Redeem a specified amount of shares for the underlying tokens. Make sure to approve _owner's shares to this contract first.
    /// @param _sharesIn Number of shares to redeem
    /// @param _receiver Recipient of the underlying asset tokens
    /// @param _owner Owner of the shares being redeemed. Must be msg.sender.
    /// @return _assetsOut Amount of underlying tokens out
    /// @dev See {IERC4626-redeem}. Leaving _owner param for ABI compatibility
    function redeem(uint256 _sharesIn, address _receiver, address _owner) public virtual returns (uint256 _assetsOut) {
        // Make sure _owner is msg.sender
        if (_owner != msg.sender) revert TokenOwnerShouldBeSender();

        // See how many shares the owner can redeem
        uint256 _maxShares = maxRedeem(_owner);

        // Revert if you are trying to redeem too many shares
        if (_sharesIn > _maxShares) {
            revert ERC4626ExceededMaxRedeem(_owner, _sharesIn, _maxShares);
        }

        // See how many asset tokens are expected
        _assetsOut = previewRedeem(_sharesIn);

        // Do the redemption
        _withdraw(msg.sender, _receiver, _owner, _assetsOut, _sharesIn);
    }

    // RESTRICTED FUNCTIONS
    // ===================================================

    /// @notice Set the fee for the contract on mint|deposit/redeem|withdraw flow
    /// @param _mintFee The mint fee
    /// @param _redeemFee The redeem fee
    function setMintRedeemFee(uint256 _mintFee, uint256 _redeemFee) public onlyOwner {
        require(_mintFee < 1e18 || _redeemFee < 1e18, "Fee must be a fraction of underlying");
        mintFee = _mintFee;
        redeemFee = _redeemFee;
    }

    /// @notice Added to support tokens
    /// @param _tokenAddress The token to recover
    /// @param _tokenAmount The amount to recover
    function recoverERC20(address _tokenAddress, uint256 _tokenAmount) external onlyOwner {
        // Only the owner address can ever receive the recovery withdrawal
        SafeERC20.safeTransfer(IERC20(_tokenAddress), owner(), _tokenAmount);
        emit RecoveredERC20(_tokenAddress, _tokenAmount);
    }

    /// @notice Set the mint cap for KRWT minting
    /// @param _mintCap The new mint cap
    function setMintCap(uint256 _mintCap) public onlyOwner {
        mintCap = _mintCap;
        emit MintCapSet(_mintCap);
    }

    // EVENTS
    // ===================================================

    /// @notice When a deposit/mint has occured
    /// @param sender The transaction sender
    /// @param owner The owner of the assets
    /// @param assets Amount of assets taken in
    /// @param shares Amount of shares given out
    event Deposit(address indexed sender, address indexed owner, uint256 assets, uint256 shares);

    /// @notice When ERC20 tokens were recovered
    /// @param token Token address
    /// @param amount Amount of tokens collected
    event RecoveredERC20(address token, uint256 amount);

    /// @notice When a withdrawal/redemption has occured
    /// @param sender The transaction sender
    /// @param receiver Reciever of the assets
    /// @param owner The owner of the shares
    /// @param assets Amount of assets given out
    /// @param shares Amount of shares taken in
    event Withdraw(
        address indexed sender, address indexed receiver, address indexed owner, uint256 assets, uint256 shares
    );

    /// @notice When the mint cap is set
    /// @param mintCap The new mint cap
    event MintCapSet(uint256 mintCap);

    // ERRORS
    // ===================================================

    /// @notice Attempted to deposit more assets than the max amount for `receiver`
    /// @param receiver The intended recipient of the shares
    /// @param assets The amount of underlying that was attempted to be deposited
    /// @param max Max amount of underlying depositable
    error ERC4626ExceededMaxDeposit(address receiver, uint256 assets, uint256 max);

    /// @notice Attempted to mint more shares than the mint cap
    /// @param receiver The intended recipient of the shares
    /// @param shares The number of shares that was attempted to be minted
    /// @param mintCap The mint cap
    error MintCapExceeded(address receiver, uint256 shares, uint256 mintCap);

    /// @notice Attempted to mint more shares than the max amount for `receiver`
    /// @param receiver The intended recipient of the shares
    /// @param shares The number of shares that was attempted to be minted
    /// @param max Max number of shares mintable
    error ERC4626ExceededMaxMint(address receiver, uint256 shares, uint256 max);

    /// @notice Attempted to withdraw more assets than the max amount for `receiver`
    /// @param owner The owner of the shares
    /// @param assets The amount of underlying that was attempted to be withdrawn
    /// @param max Max amount of underlying withdrawable
    error ERC4626ExceededMaxWithdraw(address owner, uint256 assets, uint256 max);

    /// @notice Attempted to redeem more shares than the max amount for `receiver`
    /// @param owner The owner of the shares
    /// @param shares The number of shares that was attempted to be redeemed
    /// @param max Max number of shares redeemable
    error ERC4626ExceededMaxRedeem(address owner, uint256 shares, uint256 max);

    /// @notice Cannot initialize twice
    error InitializeFailed();

    /// @notice When you are attempting to pull tokens from an owner address that is not msg.sender
    error TokenOwnerShouldBeSender();
}
