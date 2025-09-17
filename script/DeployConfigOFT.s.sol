// SPDX-License-Identifier: MIT
// @version 0.3.0
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {ILayerZeroEndpointV2} from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroEndpointV2.sol";
import {SetConfigParam} from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/IMessageLibManager.sol";
import {UlnConfig} from "@layerzerolabs/lz-evm-messagelib-v2/contracts/uln/UlnBase.sol";

interface IOAppCore {
    function setPeer(uint32 peerEid, bytes32 peer) external;
}

contract DeployConfigOFT is Script {
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
        ILayerZeroEndpointV2(BASE_ENDPOINT).setSendLibrary(BASE_OFT, ETH_EID, BASE_SEND_LIB);
        ILayerZeroEndpointV2(BASE_ENDPOINT).setReceiveLibrary(BASE_OFT, BASE_EID, BASE_RECEIVE_LIB, 0);

        // Peer mapping oft -> adapter
        IOAppCore(BASE_OFT).setPeer(ETH_EID, bytes32(uint256(uint160(ETH_ADAPTER))));

        // Receive config (ULN) on Base to accept from ETH
        _configureReceive(BASE_ENDPOINT, BASE_OFT, ETH_EID, BASE_RECEIVE_LIB);

        vm.stopBroadcast();
        console2.log("Base config complete: oft libraries, peer, and receive config set");
    }

    function _configureReceive(address endpoint, address oapp, uint32 srcEid, address receiveLib) internal {
        console2.log("  - Setting Receive Config (ULN)...");
        address[] memory requiredDVNs = new address[](2);
        requiredDVNs[0] = address(0x187cF227F81c287303ee765eE001e151347FAaA2);
        requiredDVNs[1] = address(0x9e059a54699a285714207b43B055483E78FAac25);
        UlnConfig memory uln = UlnConfig({
            confirmations: 15,
            requiredDVNCount: 2,
            optionalDVNCount: type(uint8).max,
            optionalDVNThreshold: 0,
            requiredDVNs: requiredDVNs,
            optionalDVNs: new address[](0)
        });
        SetConfigParam[] memory params = new SetConfigParam[](1);
        params[0] = SetConfigParam(srcEid, 2, abi.encode(uln));
        ILayerZeroEndpointV2(endpoint).setConfig(oapp, receiveLib, params);
    }
}
