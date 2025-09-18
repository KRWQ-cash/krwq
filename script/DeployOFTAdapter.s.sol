// SPDX-License-Identifier: MIT
// @version 0.2.8
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {console2 as console} from "forge-std/console2.sol";

import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import {KRWTOFTAdapter} from "../src/bridge/KRWTOFTAdapter.sol";

/// @notice Deploys KRWTOFTAdapter (OFTAdapterUpgradeable) behind a TransparentUpgradeableProxy
/// Env vars:
/// - PRIVATE_KEY: uint (hex without 0x)
/// - KRWT_ADDRESS: address
/// - LZ_ENDPOINT: address
/// - OWNER: address (proxy admin + delegate owner)
contract DeployOFTAdapter is Script {
    /// @notice Deploy KRWTOFTAdapter behind a TransparentUpgradeableProxy
    /// @param adminOwner Proxy admin/owner address
    /// @param delegateOwner Address to be set as initial owner via initialize
    /// @param token Underlying KRWT token (proxy address)
    /// @param lzEndpoint LayerZero endpoint
    /// @return impl Address of implementation
    /// @return proxy Address of TransparentUpgradeableProxy
    function deployOFTAdapter(address adminOwner, address delegateOwner, address token, address lzEndpoint)
        external
        returns (address impl, address proxy)
    {
        KRWTOFTAdapter _impl = new KRWTOFTAdapter(token, lzEndpoint);
        bytes memory initData = abi.encodeWithSelector(KRWTOFTAdapter.initialize.selector, delegateOwner);
        TransparentUpgradeableProxy _proxy = new TransparentUpgradeableProxy(address(_impl), adminOwner, initData);
        return (address(_impl), address(_proxy));
    }

    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(pk);

        address token = vm.envAddress("KRWT_ADDRESS");
        address lzEndpoint = vm.envAddress("LZ_ENDPOINT");
        address owner = vm.envAddress("OWNER_ETH");

        vm.startBroadcast(pk);

        (, address proxy) = this.deployOFTAdapter(owner, deployer, token, lzEndpoint);
        console.log("KRWTOFTAdapter proxy:", proxy);

        vm.stopBroadcast();
    }
}
