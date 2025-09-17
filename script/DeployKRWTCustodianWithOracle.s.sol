// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {console2 as console} from "forge-std/console2.sol";

import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import {KRWTCustodianWithOracle} from "../src/KRWTCustodianWithOracle.sol";

contract DeployKRWTCustodianWithOracle is Script {
    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        // address deployer = vm.addr(pk);
        address owner = vm.envAddress("OWNER");

        address krwt = vm.envAddress("KRWT_ADDRESS");
        address custodianTkn = vm.envAddress("CUSTODIAN_TOKEN_ADDRESS");

        address custodianOracle = vm.envAddress("CUSTODIAN_ORACLE_ADDRESS");
        uint256 maximumOracleDelay = vm.envUint("MAX_ORACLE_DELAY");

        uint256 mintCap = vm.envUint("MINT_CAP");
        uint256 mintFee = vm.envUint("MINT_FEE");
        uint256 redeemFee = vm.envUint("REDEEM_FEE");

        vm.startBroadcast(pk);

        // 1) Implementation (constructor wires immutable token addresses)
        KRWTCustodianWithOracle impl = new KRWTCustodianWithOracle(krwt, custodianTkn);
        console.log("Impl:", address(impl));

        // 2) ProxyAdmin (admin is owner)
        ProxyAdmin admin = new ProxyAdmin(owner);
        console.log("ProxyAdmin:", address(admin));

        // 3) Encode initializer
        bytes memory initData = abi.encodeWithSelector(
            KRWTCustodianWithOracle.initialize.selector,
            owner,
            custodianOracle,
            maximumOracleDelay,
            mintCap,
            mintFee,
            redeemFee
        );

        // 4) Transparent proxy
        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(address(impl), address(admin), initData);
        console.log("Proxy:", address(proxy));

        vm.stopBroadcast();
    }
}
