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

contract DeployConfigOFT is Script, LZConfigUtils {
    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");

        // Base side params
        address BASE_ENDPOINT = vm.envAddress("LZ_ENDPOINT_BASE");
        uint32 BASE_EID = uint32(vm.envUint("BASE_EID"));
        uint32 ETH_EID = uint32(vm.envUint("ETH_EID"));
        address BASE_SEND_LIB = vm.envAddress("BASE_SEND_LIB");
        address BASE_RECEIVE_LIB = vm.envAddress("BASE_RECEIVE_LIB");

        // OApps
        address BASE_OFT = vm.envAddress("BASE_OFT"); // KRWTOFT proxy on Base
        address ETH_ADAPTER = vm.envAddress("ETH_ADAPTER"); // KRWTOFTAdapter proxy on Ethereum

        vm.startBroadcast(pk);

        // Libraries for OFT on Base
        _setLibraries(BASE_ENDPOINT, BASE_OFT, ETH_EID, BASE_EID, BASE_SEND_LIB, BASE_RECEIVE_LIB);

        // Peer mapping oft -> adapter
        IOAppCore(BASE_OFT).setPeer(ETH_EID, bytes32(uint256(uint160(ETH_ADAPTER))));

        // Receive config (ULN) on Base to accept from ETH
        _configureReceive(BASE_ENDPOINT, BASE_OFT, ETH_EID, BASE_RECEIVE_LIB, 10);

        // Send config (ULN + Executor) on Base to send to ETH
        _configureSend(BASE_ENDPOINT, BASE_OFT, ETH_EID, BASE_SEND_LIB, 10);

        // Set enforced options (BASE -> ETH) with 80000 gas
        _setEnforcedOptions(BASE_OFT, ETH_EID);

        vm.stopBroadcast();
        console2.log("Base config complete: oft libraries, peer, receive config, send config, and enforced options set");
    }
}
