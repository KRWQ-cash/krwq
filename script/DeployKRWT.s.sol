// SPDX-License-Identifier: MIT
// @version 0.2.8
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {console2 as console} from "forge-std/console2.sol";

import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import {KRWT} from "../src/KRWT.sol";

contract DeployKRWT is Script {
    /// @notice Deploy KRWT behind a TransparentUpgradeableProxy
    /// @param owner msig owner and initial Ownable owner via constructor
    /// @param delegate Address passed to initialize() as new owner/delegate
    /// @param name Token name
    /// @param symbol Token symbol
    /// @return impl Address of KRWT implementation
    /// @return proxy Address of TransparentUpgradeableProxy
    function deployKRWT(address owner, address delegate, string memory name, string memory symbol)
        external
        returns (address impl, address proxy)
    {
        KRWT _impl = new KRWT(owner, name, symbol);
        bytes memory initData = abi.encodeWithSelector(KRWT.initialize.selector, delegate, name, symbol);
        TransparentUpgradeableProxy _proxy = new TransparentUpgradeableProxy(address(_impl), owner, initData);
        return (address(_impl), address(_proxy));
    }

    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(pk);
        address owner = vm.envAddress("OWNER_ETH");

        string memory name = vm.envString("TOKEN_NAME"); // e.g., "KRWT"
        string memory symbol = vm.envString("TOKEN_SYMBOL"); // e.g., "KRWT"

        vm.startBroadcast(pk);
        (address impl, address proxy) = this.deployKRWT(owner, deployer, name, symbol);
        console.log("Impl:", impl);
        console.log("Proxy:", proxy);

        vm.stopBroadcast();
    }
}
