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

contract TransferOwnershipETH is Script {
    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");

        // Contract addresses
        address ETH_ADAPTER = vm.envAddress("ETH_ADAPTER");

        // New owner and delegate (using existing env vars)
        address NEW_OWNER_ETH = vm.envAddress("OWNER_ETH");
        address NEW_DELEGATE_ETH = vm.envAddress("OWNER_ETH"); // Use same address for delegate

        vm.startBroadcast(pk);

        // Transfer Ethereum Adapter ownership and delegate
        console2.log("=== Transferring Ethereum Adapter (KRWTOFTAdapter) ===");
        console2.log("Current owner:", IOwnable(ETH_ADAPTER).owner());
        console2.log("Current delegate:", IOAppCore(ETH_ADAPTER).delegate());

        IOAppCore(ETH_ADAPTER).setDelegate(NEW_DELEGATE_ETH);
        console2.log("New delegate set:", NEW_DELEGATE_ETH);

        IOwnable(ETH_ADAPTER).transferOwnership(NEW_OWNER_ETH);
        console2.log("New owner set:", NEW_OWNER_ETH);

        vm.stopBroadcast();
        console2.log("\n[SUCCESS] Ethereum Adapter ownership and delegate transfers completed successfully!");
    }
}
