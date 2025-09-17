// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {console2 as console} from "forge-std/console2.sol";

import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import {KRWT} from "../src/KRWT.sol";

contract DeployKRWT is Script {
    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        address owner = vm.envAddress("OWNER");

        string memory name = vm.envString("TOKEN_NAME"); // e.g., "KRWT"
        string memory symbol = vm.envString("TOKEN_SYMBOL"); // e.g., "KRWT"

        vm.startBroadcast(pk);
        // 1) Implementation
        KRWT impl = new KRWT(owner, name, symbol);
        console.log("Impl:", address(impl));

        // 2) ProxyAdmin (admin is owner)
        ProxyAdmin admin = new ProxyAdmin(owner);
        console.log("ProxyAdmin:", address(admin));

        // 3) Encode initializer
        bytes memory initData = abi.encodeWithSelector(
            KRWT.initialize.selector,
            owner,
            name,
            symbol
        );

        // 4) Transparent proxy
        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(address(impl), address(admin), initData);
        console.log("Proxy:", address(proxy));

        vm.stopBroadcast();
    }
}
