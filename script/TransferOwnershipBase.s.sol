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
        address BASE_OFT = vm.envAddress("BASE_OFT");

        // New owner and delegate (using existing env vars)
        address NEW_OWNER_BASE = vm.envAddress("OWNER_BASE");
        address NEW_DELEGATE_BASE = vm.envAddress("OWNER_BASE"); // Use same address for delegate

        vm.startBroadcast(pk);

        // Transfer Base OFT ownership and delegate
        console2.log("=== Transferring Base OFT (KRWTOFT) ===");
        console2.log("Current owner:", IOwnable(BASE_OFT).owner());
        console2.log("Current delegate:", IOAppCore(BASE_OFT).delegate());

        IOAppCore(BASE_OFT).setDelegate(NEW_DELEGATE_BASE);
        console2.log("New delegate set:", NEW_DELEGATE_BASE);

        IOwnable(BASE_OFT).transferOwnership(NEW_OWNER_BASE);
        console2.log("New owner set:", NEW_OWNER_BASE);

        vm.stopBroadcast();
        console2.log("\n[SUCCESS] Base OFT ownership and delegate transfers completed successfully!");
    }
}
