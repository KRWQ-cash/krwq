// SPDX-License-Identifier: MIT
// @version 0.2.8
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {console2 as console} from "forge-std/console2.sol";

import {KRWQOFT} from "../src/bridge/KRWQOFT.sol";

/// @notice Deploys KRWQOFT (OFTUpgradeable) behind a TransparentUpgradeableProxy
/// Env vars:
/// - PRIVATE_KEY: uint (hex without 0x)
/// - TOKEN_NAME: string
/// - TOKEN_SYMBOL: string
/// - LZ_ENDPOINT_BASE: address
/// - OWNER: address (proxy admin + delegate owner)
contract DeployOFT is Script {
    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        string memory name = vm.envString("TOKEN_NAME");
        string memory symbol = vm.envString("TOKEN_SYMBOL");
        address lzEndpoint = vm.envAddress("LZ_ENDPOINT_BASE");
        address owner = vm.envAddress("OWNER_BASE");

        vm.startBroadcast(pk);

        // 1) Implementation
        KRWQOFT impl = new KRWQOFT(lzEndpoint);

        // 2) Encode initializer
        console.log("KRWQOFT impl:", address(impl));
        vm.stopBroadcast();
    }
}
