// SPDX-License-Identifier: MIT
// @version 0.3.0
pragma solidity ^0.8.24;

import {ILayerZeroEndpointV2} from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroEndpointV2.sol";
import {SetConfigParam} from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/IMessageLibManager.sol";
import {UlnConfig} from "@layerzerolabs/lz-evm-messagelib-v2/contracts/uln/UlnBase.sol";
import {ExecutorConfig} from "@layerzerolabs/lz-evm-messagelib-v2/contracts/SendLibBase.sol";
import {
    IOAppOptionsType3,
    EnforcedOptionParam
} from "@layerzerolabs/oapp-evm/contracts/oapp/interfaces/IOAppOptionsType3.sol";
import {OptionsBuilder} from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OptionsBuilder.sol";

interface IOAppCore {
    function setPeer(uint32 peerEid, bytes32 peer) external;
}

abstract contract LZConfigUtils {
    using OptionsBuilder for bytes;

    function _setLibraries(
        address endpoint,
        address oapp,
        uint32 sendDstEid,
        uint32 receiveLocalEid,
        address sendLib,
        address receiveLib
    ) internal {
        ILayerZeroEndpointV2(endpoint).setSendLibrary(oapp, sendDstEid, sendLib);
        ILayerZeroEndpointV2(endpoint).setReceiveLibrary(oapp, receiveLocalEid, receiveLib, 0);
    }

    function _setPeer(address oapp, uint32 peerEid, address peer) internal {
        IOAppCore(oapp).setPeer(peerEid, bytes32(uint256(uint160(peer))));
    }

    function _configureReceive(address endpoint, address oapp, uint32 srcEid, address receiveLib, uint16 confirmations)
        internal
    {
        UlnConfig memory uln = _buildUlnConfig(confirmations);
        SetConfigParam[] memory params = new SetConfigParam[](1);
        params[0] = SetConfigParam(srcEid, 2, abi.encode(uln));
        ILayerZeroEndpointV2(endpoint).setConfig(oapp, receiveLib, params);
    }

    function _configureSend(address endpoint, address oapp, uint32 dstEid, address sendLib, uint16 confirmations)
        internal
    {
        UlnConfig memory uln = _buildUlnConfig(confirmations);
        ExecutorConfig memory exec = _buildExecutorConfig();
        SetConfigParam[] memory params = new SetConfigParam[](2);
        params[0] = SetConfigParam(dstEid, 1, abi.encode(exec));
        params[1] = SetConfigParam(dstEid, 2, abi.encode(uln));
        ILayerZeroEndpointV2(endpoint).setConfig(oapp, sendLib, params);
    }

    function _buildUlnConfig(uint16 confirmations) internal pure returns (UlnConfig memory uln) {
        address[] memory requiredDVNs = new address[](2);
        requiredDVNs[0] = address(0x187cF227F81c287303ee765eE001e151347FAaA2);
        requiredDVNs[1] = address(0x9e059a54699a285714207b43B055483E78FAac25);
        uln = UlnConfig({
            confirmations: confirmations,
            requiredDVNCount: 2,
            optionalDVNCount: type(uint8).max,
            optionalDVNThreshold: 0,
            requiredDVNs: requiredDVNs,
            optionalDVNs: new address[](0)
        });
    }

    function _buildExecutorConfig() internal pure returns (ExecutorConfig memory exec) {
        exec = ExecutorConfig({maxMessageSize: 10_000, executor: address(0x2CCA08ae69E0C44b18a57Ab2A87644234dAebaE4)});
    }

    function _setEnforcedOptions(address oapp, uint32 eid) internal {
        // Encode LZ_RECEIVE with 80000 gas for msgType 1
        bytes memory options = OptionsBuilder.newOptions().addExecutorLzReceiveOption(80_000, 0);
        EnforcedOptionParam[] memory params = new EnforcedOptionParam[](1);
        params[0] = EnforcedOptionParam({eid: eid, msgType: 1, options: options});
        IOAppOptionsType3(oapp).setEnforcedOptions(params);
    }
}
