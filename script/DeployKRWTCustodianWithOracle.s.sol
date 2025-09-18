// SPDX-License-Identifier: MIT
// @version 0.2.8
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {console2 as console} from "forge-std/console2.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {KRWTCustodianWithOracle} from "../src/KRWTCustodianWithOracle.sol";

contract DeployKRWTCustodianWithOracle is Script {
    /// @notice Deploy KRWTCustodianWithOracle behind a TransparentUpgradeableProxy
    /// @param adminOwner Proxy owner
    /// @param delegateOwner Address passed as initializer first param (temporary owner/delegate)
    /// @param krwt Address of KRWT proxy/token
    /// @param custodianTkn Custodian token address
    /// @param custodianOracle Oracle address
    /// @param maximumOracleDelay Max oracle delay
    /// @param mintCap Cap
    /// @param mintFee Fee
    /// @param redeemFee Fee
    /// @return impl Address of implementation
    /// @return proxy Address of TransparentUpgradeableProxy
    function deployCustodianWithOracle(
        address adminOwner,
        address delegateOwner,
        address krwt,
        address custodianTkn,
        address custodianOracle,
        uint256 maximumOracleDelay,
        uint256 mintCap,
        uint256 mintFee,
        uint256 redeemFee
    ) external returns (address impl, address proxy) {
        KRWTCustodianWithOracle _impl = new KRWTCustodianWithOracle(krwt, custodianTkn);
        bytes memory initData = abi.encodeWithSelector(
            KRWTCustodianWithOracle.initialize.selector,
            delegateOwner,
            custodianOracle,
            maximumOracleDelay,
            mintCap,
            mintFee,
            redeemFee
        );
        TransparentUpgradeableProxy _proxy = new TransparentUpgradeableProxy(address(_impl), adminOwner, initData);
        return (address(_impl), address(_proxy));
    }

    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(pk);
        address owner = vm.envAddress("OWNER_ETH");

        address krwt = vm.envAddress("KRWT_ADDRESS");
        address custodianTkn = vm.envAddress("CUSTODIAN_TOKEN_ADDRESS");

        address custodianOracle = vm.envAddress("CUSTODIAN_ORACLE_ADDRESS");
        uint256 maximumOracleDelay = vm.envUint("MAX_ORACLE_DELAY");

        uint256 mintCap = vm.envUint("MINT_CAP");
        uint256 mintFee = vm.envUint("MINT_FEE");
        uint256 redeemFee = vm.envUint("REDEEM_FEE");

        vm.startBroadcast(pk);

        (address impl, address proxy) = this.deployCustodianWithOracle(
            owner, deployer, krwt, custodianTkn, custodianOracle, maximumOracleDelay, mintCap, mintFee, redeemFee
        );
        console.log("Impl:", impl);
        console.log("Proxy:", proxy);

        vm.stopBroadcast();
    }
}
