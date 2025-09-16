// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {console2 as console} from "forge-std/console2.sol";

import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import {KRWTOFTAdapter} from "../src/bridge/KRWTOFTAdapter.sol";

/// @notice Deploys KRWTOFTAdapter (OFTAdapterUpgradeable) behind a TransparentUpgradeableProxy
/// Env vars:
/// - PRIVATE_KEY: uint (hex without 0x)
/// - UNDERLYING_TOKEN: address
/// - LZ_ENDPOINT: address
/// - OWNER: address (delegate + ProxyAdmin owner)
contract DeployOFTAdapter is Script {
    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(pk);

        address token = vm.envAddress("UNDERLYING_TOKEN");
        address lzEndpoint = vm.envAddress("LZ_ENDPOINT");
        address owner = vm.envAddress("OWNER");

        vm.startBroadcast(pk);

        // 1) Implementation
        KRWTOFTAdapter impl = new KRWTOFTAdapter(token, lzEndpoint);
        console.log("KRWTOFTAdapter impl:", address(impl));

        // 2) ProxyAdmin (admin is OWNER)
        ProxyAdmin admin = new ProxyAdmin(owner);
        console.log("ProxyAdmin:", address(admin));

        // 3) Encode initializer
        bytes memory initData = abi.encodeWithSelector(
            KRWTOFTAdapter.initialize.selector,
            owner // delegate and Ownable owner
        );

        // 4) Transparent proxy
        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(address(impl), address(admin), initData);
        console.log("KRWTOFTAdapter proxy:", address(proxy));

        vm.stopBroadcast();
    }
}
