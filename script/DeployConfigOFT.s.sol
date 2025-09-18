// SPDX-License-Identifier: MIT
// @version 0.3.0
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {LZConfigUtils} from "./utils/LZConfigUtils.sol";

interface IOAppCore {
    function setPeer(uint32 peerEid, bytes32 peer) external;
}

contract DeployConfigOFT is Script, LZConfigUtils {
    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");

        // Base side params
        address baseEndpoint = vm.envAddress("LZ_ENDPOINT_BASE");
        uint32 baseEid = uint32(vm.envUint("BASE_EID"));
        uint32 ethEid = uint32(vm.envUint("ETH_EID"));
        address baseSendLib = vm.envAddress("BASE_SEND_LIB");
        address baseReceiveLib = vm.envAddress("BASE_RECEIVE_LIB");

        // OApps
        address baseOft = vm.envAddress("BASE_OFT"); // KRWTOFT proxy on Base
        address ethAdapter = vm.envAddress("ETH_ADAPTER"); // KRWTOFTAdapter proxy on Ethereum

        vm.startBroadcast(pk);

        // Libraries for OFT on Base
        _setLibraries(baseEndpoint, baseOft, ethEid, baseEid, baseSendLib, baseReceiveLib);

        // Peer mapping oft -> adapter
        IOAppCore(baseOft).setPeer(ethEid, bytes32(uint256(uint160(ethAdapter))));

        // Receive config (ULN) on Base to accept from ETH - use Base DVNs
        _configureReceive(baseEndpoint, baseOft, ethEid, baseReceiveLib, 10, false);

        // Send config (ULN + Executor) on Base to send to ETH - use Ethereum DVNs
        _configureSend(baseEndpoint, baseOft, ethEid, baseSendLib, 10, true);

        // Set enforced options (BASE -> ETH) with 80000 gas
        _setEnforcedOptions(baseOft, ethEid);

        vm.stopBroadcast();
        console2.log("Base config complete: oft libraries, peer, receive config, send config, and enforced options set");
    }
}
