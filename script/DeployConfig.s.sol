// SPDX-License-Identifier: MIT
// @version 0.3.0
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {ILayerZeroEndpointV2} from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroEndpointV2.sol";
import {SetConfigParam} from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/IMessageLibManager.sol";
import {UlnConfig} from "@layerzerolabs/lz-evm-messagelib-v2/contracts/uln/UlnBase.sol";
import {ExecutorConfig} from "@layerzerolabs/lz-evm-messagelib-v2/contracts/SendLibBase.sol";
import {IOAppOptionsType3} from "@layerzerolabs/oapp-evm/contracts/oapp/interfaces/IOAppOptionsType3.sol";
import {LZConfigUtils} from "./utils/LZConfigUtils.sol";

interface IOAppCore {
    function setPeer(uint32 peerEid, bytes32 peer) external;
}

contract DeployConfig is Script, LZConfigUtils {
    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");

        // ETH side params
        address ETH_ENDPOINT = vm.envAddress("LZ_ENDPOINT");
        uint32 ETH_EID = uint32(vm.envUint("ETH_EID"));
        uint32 BASE_EID = uint32(vm.envUint("BASE_EID"));
        address ETH_SEND_LIB = vm.envAddress("ETH_SEND_LIB");
        address ETH_RECEIVE_LIB = vm.envAddress("ETH_RECEIVE_LIB");

        // OApps
        address ETH_ADAPTER = vm.envAddress("ETH_ADAPTER"); // KRWTOFTAdapter proxy on Ethereum
        address BASE_OFT = vm.envAddress("BASE_OFT"); // KRWTOFT proxy on Base

        vm.startBroadcast(pk);

        // Libraries for adapter on ETH (send to Base, receive on ETH)
        _setLibraries(ETH_ENDPOINT, ETH_ADAPTER, BASE_EID, ETH_EID, ETH_SEND_LIB, ETH_RECEIVE_LIB);

        // Receive config (ULN) on ETH to accept from Base
        _configureReceive(ETH_ENDPOINT, ETH_ADAPTER, BASE_EID, ETH_RECEIVE_LIB, 15);

        // Peer mapping adapter -> oft
        _setPeer(ETH_ADAPTER, BASE_EID, BASE_OFT);

        // Send config (ULN + Executor) on ETH to send to Base
        _configureSend(ETH_ENDPOINT, ETH_ADAPTER, BASE_EID, ETH_SEND_LIB, 15);

        // Set enforced options (ETH -> Base) with 80000 gas
        _setEnforcedOptions(ETH_ADAPTER, BASE_EID);

        vm.stopBroadcast();
        console2.log("ETH config complete: adapter libraries, peer, send/receive configs, and enforced options set");
    }
}
