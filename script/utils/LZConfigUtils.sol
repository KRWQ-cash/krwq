// SPDX-License-Identifier: MIT
// @version 0.3.0
pragma solidity ^0.8.24;

/**
 * @title LZConfigUtils
 * @notice Enhanced LayerZero configuration utilities with enum-based constants
 * @dev Uses LayerZero library constants instead of magic numbers for better maintainability
 */
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
    // These match the constants from SendUln302.sol
    uint32 private constant CONFIG_TYPE_EXECUTOR = 1;
    uint32 private constant CONFIG_TYPE_ULN = 2;
    uint16 private constant SEND_MSG_TYPE = 1;

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

    function _configureReceive(
        address endpoint,
        address oapp,
        uint32 srcEid,
        address receiveLib,
        uint16 confirmations,
        bool isEthereum
    ) internal {
        UlnConfig memory uln = _buildUlnConfig(confirmations, isEthereum);
        SetConfigParam[] memory params = new SetConfigParam[](1);
        params[0] = SetConfigParam(srcEid, CONFIG_TYPE_ULN, abi.encode(uln));
        ILayerZeroEndpointV2(endpoint).setConfig(oapp, receiveLib, params);
    }

    function _configureSend(
        address endpoint,
        address oapp,
        uint32 dstEid,
        address sendLib,
        uint16 confirmations,
        bool isEthereum
    ) internal {
        UlnConfig memory uln = _buildUlnConfig(confirmations, isEthereum);
        ExecutorConfig memory exec = _buildExecutorConfig(isEthereum);
        SetConfigParam[] memory params = new SetConfigParam[](2);
        params[0] = SetConfigParam(dstEid, CONFIG_TYPE_EXECUTOR, abi.encode(exec));
        params[1] = SetConfigParam(dstEid, CONFIG_TYPE_ULN, abi.encode(uln));
        ILayerZeroEndpointV2(endpoint).setConfig(oapp, sendLib, params);
    }

    function _buildUlnConfig(uint16 confirmations, bool isEthereum) internal pure returns (UlnConfig memory uln) {
        address[] memory requiredDvns = new address[](3);

        if (isEthereum) {
            // Use Ethereum DVN addresses (sorted ascending by hex)
            requiredDvns[0] = 0x373a6E5c0C4E89E24819f00AA37ea370917AAfF4; // Deutsche Telekom
            requiredDvns[1] = 0x38654142F5E672Ae86a1b21523AAfC765E6A1e08; // frax
            requiredDvns[2] = 0xa4fE5A5B9A846458a70Cd0748228aED3bF65c2cd; // canary
        } else {
            // Use Base DVN addresses (sorted ascending by hex)
            requiredDvns[0] = 0x187cF227F81c287303ee765eE001e151347FAaA2; // frax base
            requiredDvns[1] = 0x554833698Ae0FB22ECC90B01222903fD62CA4B47; // canary base
            requiredDvns[2] = 0xc2A0C36f5939A14966705c7Cec813163FaEEa1F0; // Deutsche Telekom base
        }

        uln = UlnConfig({
            confirmations: confirmations,
            requiredDVNCount: 3,
            optionalDVNCount: type(uint8).max,
            optionalDVNThreshold: 0,
            requiredDVNs: requiredDvns,
            optionalDVNs: new address[](0)
        });
    }

    function _buildExecutorConfig(bool isEthereum) internal pure returns (ExecutorConfig memory exec) {
        // Ethereum uses its own executor; others (e.g., Base) keep existing executor
        address executorAddress = isEthereum
            ? address(0x173272739Bd7Aa6e4e214714048a9fE699453059)
            : address(0x2CCA08ae69E0C44b18a57Ab2A87644234dAebaE4);
        exec = ExecutorConfig({maxMessageSize: 10_000, executor: executorAddress});
    }

    function _setEnforcedOptions(address oapp, uint32 eid) internal {
        bytes memory options = OptionsBuilder.newOptions();
        options = OptionsBuilder.addExecutorLzReceiveOption(options, 80000, 0);
        EnforcedOptionParam[] memory params = new EnforcedOptionParam[](1);
        params[0] = EnforcedOptionParam({eid: eid, msgType: SEND_MSG_TYPE, options: options});
        IOAppOptionsType3(oapp).setEnforcedOptions(params);
    }
}
