// SPDX-License-Identifier: MIT
// @version 0.2.8
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {console2 as console} from "forge-std/console2.sol";

import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import {KRWTOFT} from "../src/bridge/KRWTOFT.sol";

/// @notice Deploys KRWTOFT (OFTUpgradeable) behind a TransparentUpgradeableProxy
/// Env vars:
/// - PRIVATE_KEY: uint (hex without 0x)
/// - TOKEN_NAME: string
/// - TOKEN_SYMBOL: string
/// - LZ_ENDPOINT_BASE: address
/// - OWNER: address (proxy admin + delegate owner)
contract DeployOFT is Script {
    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(pk);

        string memory name = vm.envString("TOKEN_NAME");
        string memory symbol = vm.envString("TOKEN_SYMBOL");
        address lzEndpoint = vm.envAddress("LZ_ENDPOINT_BASE");

        vm.startBroadcast(pk);

        // 1) Implementation
        KRWTOFT impl = new KRWTOFT(lzEndpoint);
        console.log("KRWTOFT impl:", address(impl));

        // 2) Encode initializer
        bytes memory initData = abi.encodeWithSelector(
            KRWTOFT.initialize.selector,
            name,
            symbol,
            deployer // delegate and Ownable owner
        );

        // 3) Transparent proxy with owner as admin
        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(address(impl), deployer, initData);
        console.log("KRWTOFT proxy:", address(proxy));

        vm.stopBroadcast();
    }
}
