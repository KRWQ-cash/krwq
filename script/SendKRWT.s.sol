// SPDX-License-Identifier: MIT
// @version 0.3.0
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {console2 as console} from "forge-std/console2.sol";

import {IOFT, SendParam, OFTReceipt} from "@layerzerolabs/oft-evm/contracts/interfaces/IOFT.sol";
import {
    MessagingFee,
    MessagingReceipt
} from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroEndpointV2.sol";
import {OptionsBuilder} from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OptionsBuilder.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @notice Sends KRWT cross-chain using LayerZero OFT (V2). Works with KRWTOFT (Base) or KRWTOFTAdapter (Ethereum).
/// Required env vars:
/// - PRIVATE_KEY: uint (hex without 0x)
/// - ETH_ADAPTER: address (KRWTOFTAdapter proxy on Ethereum) or BASE_OFT (KRWTOFT proxy on Base)
/// Optional env vars:
/// - DST_EID: uint (destination chain Endpoint ID; default 30184 for Base)
/// - TO: address (recipient on destination chain; default sender)
/// - AMOUNT: uint (amount in local decimals; default 1e18)
/// - MIN_BPS: uint (min amount basis points; default 9950 = 0.5% slippage)
/// - GAS_LIMIT: uint (executor lzReceive gas limit; default 80000)
/// - PAY_IN_LZ_TOKEN: bool (default false)
/// - REFUND: address (where excess native/LZ token fees are refunded; default msg.sender)
/// - AUTO_APPROVE: bool (default true) auto-approve adapter when required
/// - INFINITE_APPROVE: bool (default false) approve max allowance instead of amount
contract SendKRWT is Script {
    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        address sender = vm.addr(pk);

        address oft = vm.envAddress("BASE_OFT"); // ETH_ADAPTER / BASE_OFT
        uint32 dstEid = uint32(_tryEnvUint("DST_EID", 30101)); // 30101 ethereum / 30184 base
        address to = _tryEnvAddress("TO", sender);
        uint256 amountLd = _tryEnvUint("AMOUNT", 1e18);

        uint256 minBps = _tryEnvUint("MIN_BPS", 9950);
        uint256 minAmountLd = (amountLd * minBps) / 10_000;

        uint256 gasLimit = _tryEnvUint("GAS_LIMIT", 80_000);
        bool payInLzToken = _tryEnvBool("PAY_IN_LZ_TOKEN", false);
        address refund = _tryEnvAddress("REFUND", sender);
        bool autoApprove = _tryEnvBool("AUTO_APPROVE", true);
        bool infiniteApprove = _tryEnvBool("INFINITE_APPROVE", false);

        // Build LayerZero execution options (Type 3) with executor gas
        bytes memory options = OptionsBuilder.newOptions();
        options = OptionsBuilder.addExecutorLzReceiveOption(options, uint128(gasLimit), 0);

        // Auto-approve underlying token to adapter if required (Ethereum side)
        if (autoApprove) {
            vm.startBroadcast(pk);
            _maybeApprove(oft, sender, amountLd, infiniteApprove);
            vm.stopBroadcast();
        }

        // Build SendParam per LayerZero V2 OFT Quickstart
        SendParam memory sp = SendParam({
            dstEid: dstEid,
            to: bytes32(uint256(uint160(to))),
            amountLD: amountLd,
            minAmountLD: minAmountLd,
            extraOptions: options,
            composeMsg: bytes(""),
            oftCmd: bytes("")
        });

        vm.startBroadcast(pk);

        // Quote fee
        MessagingFee memory fee = IOFT(oft).quoteSend(sp, payInLzToken);
        console.log("quote nativeFee:", fee.nativeFee);
        console.log("quote lzTokenFee:", fee.lzTokenFee);

        // Execute send
        (MessagingReceipt memory receipt, OFTReceipt memory oftReceipt) =
            IOFT(oft).send{value: fee.nativeFee}(sp, fee, refund);
        console.log("send() submitted from:", sender);
        console.log("source OFT:", oft);
        console.log("dstEid:", dstEid);
        console.log("to:", to);
        console.log("amountLD:", amountLd);
        console.log("message guid:", vm.toString(receipt.guid));
        console.log("message nonce:", receipt.nonce);
        console.log("amount sent LD:", oftReceipt.amountSentLD);
        console.log("amount received LD:", oftReceipt.amountReceivedLD);

        vm.stopBroadcast();
    }

    function _tryEnvUint(string memory key, uint256 defaultValue) internal view returns (uint256 v) {
        try vm.envUint(key) returns (uint256 val) {
            return val;
        } catch {
            return defaultValue;
        }
    }

    function _tryEnvBool(string memory key, bool defaultValue) internal view returns (bool v) {
        try vm.envBool(key) returns (bool val) {
            return val;
        } catch {
            return defaultValue;
        }
    }

    function _tryEnvAddress(string memory key, address defaultValue) internal view returns (address v) {
        try vm.envAddress(key) returns (address val) {
            return val;
        } catch {
            return defaultValue;
        }
    }

    function _maybeApprove(address oft, address owner, uint256 amountLd, bool infiniteApprove) private {
        bool requiresApproval;
        try IOFT(oft).approvalRequired() returns (bool r) {
            requiresApproval = r;
        } catch {
            requiresApproval = false;
        }

        if (!requiresApproval) return;

        address underlying = IOFT(oft).token();
        uint256 approveAmount = infiniteApprove ? type(uint256).max : amountLd;
        uint256 currentAllowance;
        try IERC20(underlying).allowance(owner, oft) returns (uint256 a) {
            currentAllowance = a;
        } catch {
            currentAllowance = 0;
        }
        if (currentAllowance < approveAmount) {
            IERC20(underlying).approve(oft, approveAmount);
            console.log("approved underlying for adapter:", approveAmount);
        }
    }
}
