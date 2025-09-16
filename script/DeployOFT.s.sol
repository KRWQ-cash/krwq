// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {console2 as console} from "forge-std/console2.sol";

import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import {KRWTOFT} from "../src/bridge/KRWTOFT.sol";

/// @notice Deploys KRWTOFT (OFTUpgradeable) behind a TransparentUpgradeableProxy
/// Env vars:
/// - PRIVATE_KEY: uint (hex without 0x)
/// - OFT_NAME: string
/// - OFT_SYMBOL: string
/// - LZ_ENDPOINT: address
/// - OWNER: address (delegate + ProxyAdmin owner)
contract DeployOFT is Script {
    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(pk);

        string memory name = vm.envString("OFT_NAME");
        string memory symbol = vm.envString("OFT_SYMBOL");
        address lzEndpoint = vm.envAddress("LZ_ENDPOINT");
        address owner = vm.envAddress("OWNER");

        vm.startBroadcast(pk);

        // 1) Implementation
        KRWTOFT impl = new KRWTOFT(lzEndpoint);
        console.log("KRWTOFT impl:", address(impl));

        // 2) ProxyAdmin (admin is OWNER)
        ProxyAdmin admin = new ProxyAdmin(owner);
        console.log("ProxyAdmin:", address(admin));

        // 3) Encode initializer
        bytes memory initData = abi.encodeWithSelector(
            KRWTOFT.initialize.selector,
            name,
            symbol,
            owner // delegate and Ownable owner
        );

        // 4) Transparent proxy
        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(address(impl), address(admin), initData);
        console.log("KRWTOFT proxy:", address(proxy));

        vm.stopBroadcast();
    }
}
