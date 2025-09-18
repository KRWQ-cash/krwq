// SPDX-License-Identifier: MIT
// @version 0.3.0
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {LZConfigUtils} from "./utils/LZConfigUtils.sol";

interface IOAppCore {
    function setPeer(uint32 peerEid, bytes32 peer) external;
}

contract DeployConfig is Script, LZConfigUtils {
    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");

        // ETH side params
        address ethEndpoint = vm.envAddress("LZ_ENDPOINT");
        uint32 ethEid = uint32(vm.envUint("ETH_EID"));
        uint32 baseEid = uint32(vm.envUint("BASE_EID"));
        address ethSendLib = vm.envAddress("ETH_SEND_LIB");
        address ethReceiveLib = vm.envAddress("ETH_RECEIVE_LIB");

        // OApps
        address ethAdapter = vm.envAddress("ETH_ADAPTER"); // KRWTOFTAdapter proxy on Ethereum
        address baseOft = vm.envAddress("BASE_OFT"); // KRWTOFT proxy on Base

        vm.startBroadcast(pk);

        // Libraries for adapter on ETH (send to Base, receive on ETH)
        _setLibraries(ethEndpoint, ethAdapter, baseEid, ethEid, ethSendLib, ethReceiveLib);

        // Receive config (ULN) on ETH to accept from Base - use Ethereum DVNs
        _configureReceive(ethEndpoint, ethAdapter, baseEid, ethReceiveLib, 15, true);

        // Peer mapping adapter -> oft
        _setPeer(ethAdapter, baseEid, baseOft);

        // Send config (ULN + Executor) on ETH to send to Base - use Base DVNs
        _configureSend(ethEndpoint, ethAdapter, baseEid, ethSendLib, 15, false);

        // Set enforced options (ETH -> Base) with 80000 gas
        _setEnforcedOptions(ethAdapter, baseEid);

        vm.stopBroadcast();
        console2.log("ETH config complete: adapter libraries, peer, send/receive configs, and enforced options set");
    }
}
