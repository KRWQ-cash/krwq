// SPDX-License-Identifier: MIT
// @version 0.2.8
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {console2 as console} from "forge-std/console2.sol";

import {KRWQ} from "../src/KRWQ.sol";

contract DeployKRWQImplementation is Script {
    /// @notice Deploy KRWQ behind a TransparentUpgradeableProxy
    /// @param owner msig owner and initial Ownable owner via constructor
    /// @param name Token name
    /// @param symbol Token symbol
    /// @return impl Address of KRWQ implementation
    function deployKRWQ(address owner, string memory name, string memory symbol) public returns (address impl) {
        KRWQ _impl = new KRWQ(owner, name, symbol);
        return address(_impl);
    }

    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        address owner = vm.envAddress("OWNER_ETH");

        string memory name = vm.envString("TOKEN_NAME"); // e.g., "KRWQ"
        string memory symbol = vm.envString("TOKEN_SYMBOL"); // e.g., "KRWQ"

        vm.startBroadcast(pk);
        address impl = deployKRWQ(owner, name, symbol);
        console.log("Impl:", impl);
        vm.stopBroadcast();
    }
}
