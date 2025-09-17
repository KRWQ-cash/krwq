// SPDX-License-Identifier: MIT
// @version 0.3.0
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {ILayerZeroEndpointV2} from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroEndpointV2.sol";
import {SetConfigParam} from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/IMessageLibManager.sol";
import {UlnConfig} from "@layerzerolabs/lz-evm-messagelib-v2/contracts/uln/UlnBase.sol";
import {ExecutorConfig} from "@layerzerolabs/lz-evm-messagelib-v2/contracts/SendLibBase.sol";

interface IOAppCore {
    function setPeer(uint32 peerEid, bytes32 peer) external;
}

contract DeployConfig is Script {
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

        // Libraries for adapter on ETH
        ILayerZeroEndpointV2(ETH_ENDPOINT).setSendLibrary(ETH_ADAPTER, BASE_EID, ETH_SEND_LIB);
        ILayerZeroEndpointV2(ETH_ENDPOINT).setReceiveLibrary(ETH_ADAPTER, ETH_EID, ETH_RECEIVE_LIB, 0);

        // Peer mapping adapter -> oft
        IOAppCore(ETH_ADAPTER).setPeer(BASE_EID, bytes32(uint256(uint160(BASE_OFT))));

        // Send config (ULN + Executor)
        _configureSend(ETH_ENDPOINT, ETH_ADAPTER, BASE_EID, ETH_SEND_LIB);

        vm.stopBroadcast();
        console2.log("ETH config complete: adapter libraries, peer, and send config set");
    }

    function _configureSend(address endpoint, address oapp, uint32 dstEid, address sendLib) internal {
        console2.log("  - Setting Send Config (ULN + Executor)...");
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
        ExecutorConfig memory exec =
            ExecutorConfig({maxMessageSize: 10_000, executor: address(0x2CCA08ae69E0C44b18a57Ab2A87644234dAebaE4)});
        SetConfigParam[] memory params = new SetConfigParam[](2);
        params[0] = SetConfigParam(dstEid, 1, abi.encode(exec));
        params[1] = SetConfigParam(dstEid, 2, abi.encode(uln));
        ILayerZeroEndpointV2(endpoint).setConfig(oapp, sendLib, params);
    }
}
