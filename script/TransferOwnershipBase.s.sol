// SPDX-License-Identifier: MIT
// @version 0.3.0
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";

interface IOAppCore {
    function delegate() external view returns (address);
    function setDelegate(address _delegate) external;
}

interface IOwnable {
    function owner() external view returns (address);
    function transferOwnership(address newOwner) external;
}

contract TransferOwnershipBase is Script {
    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");

        // Contract addresses
        address baseOft = vm.envAddress("BASE_OFT");

        // New owner and delegate (using existing env vars)
        address newOwnerBase = vm.envAddress("OWNER_BASE");
        address newDelegateBase = vm.envAddress("OWNER_BASE"); // Use same address for delegate

        vm.startBroadcast(pk);

        // Transfer Base OFT ownership and delegate
        console2.log("=== Transferring Base OFT (KRWTOFT) ===");
        console2.log("Current owner:", IOwnable(baseOft).owner());
        console2.log("Current delegate:", IOAppCore(baseOft).delegate());

        IOAppCore(baseOft).setDelegate(newDelegateBase);
        console2.log("New delegate set:", newDelegateBase);

        IOwnable(baseOft).transferOwnership(newOwnerBase);
        console2.log("New owner set:", newOwnerBase);

        vm.stopBroadcast();
        console2.log("\n[SUCCESS] Base OFT ownership and delegate transfers completed successfully!");
    }
}
