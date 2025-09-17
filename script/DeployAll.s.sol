// SPDX-License-Identifier: MIT
// @version 0.2.8
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {console2 as console} from "forge-std/console2.sol";

import {DeployKRWT} from "./DeployKRWT.s.sol";
import {DeployKRWTCustodianWithOracle} from "./DeployKRWTCustodianWithOracle.s.sol";
import {DeployOFTAdapter} from "./DeployOFTAdapter.s.sol";
import {KRWT} from "../src/KRWT.sol";

interface IWhitelistOwnable {
    function addToWhitelist(address _address) external;
    function transferOwnership(address newOwner) external;
}

/// @notice Orchestrates KRWT + KRWTCustodianWithOracle deployment and wiring
contract DeployAll is Script {
    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(pk);
        address owner = vm.envAddress("OWNER_ETH");

        string memory name = vm.envString("TOKEN_NAME");
        string memory symbol = vm.envString("TOKEN_SYMBOL");

        address custodianTkn = vm.envAddress("CUSTODIAN_TOKEN_ADDRESS");
        address custodianOracle = vm.envAddress("CUSTODIAN_ORACLE_ADDRESS");
        uint256 maximumOracleDelay = vm.envUint("MAX_ORACLE_DELAY");
        uint256 mintCap = vm.envUint("MINT_CAP");
        uint256 mintFee = vm.envUint("MINT_FEE");
        uint256 redeemFee = vm.envUint("REDEEM_FEE");

        vm.startBroadcast(pk);

        // 1) Deploy KRWT via its script helper (limit locals via scope and discard unused)
        address krwtProxy;
        {
            DeployKRWT d = new DeployKRWT();
            (,, krwtProxy) = d.deployKRWT(owner, deployer, name, symbol);
            console.log("KRWT Proxy:", krwtProxy);
        }

        // 2) Deploy Custodian via its script helper
        address custProxy;
        {
            DeployKRWTCustodianWithOracle d = new DeployKRWTCustodianWithOracle();
            // Initialize custodian with deployer as owner so we can whitelist and wire, then hand over ownership to OWNER_ETH
            (,, custProxy) = d.deployCustodianWithOracle(
                owner, // ProxyAdmin owner
                deployer, // delegate/temporary owner for custodian contract
                krwtProxy,
                custodianTkn,
                custodianOracle,
                maximumOracleDelay,
                mintCap,
                mintFee,
                redeemFee
            );
            console.log("Custodian Proxy:", custProxy);
        }

        // 3) Wire: add custodian as minter of KRWT (KRWT owner is deployer right now)
        KRWT(krwtProxy).addMinter(custProxy);
        console.log("Added custodian as KRWT minter");

        // 4) Whitelist OWNER_ETH in the custodian (onlyOwner = deployer right now)
        //    This allows the final owner to interact when public is false
        IWhitelistOwnable(custProxy).addToWhitelist(owner);
        console.log("Whitelisted OWNER_ETH in custodian");

        // 5) Deploy OFTAdapter (admin owner = OWNER_ETH, delegate = deployer)
        //    Uses KRWT proxy as underlying token and requires LZ endpoint from env
        address lzEndpoint = vm.envAddress("LZ_ENDPOINT");
        {
            DeployOFTAdapter d = new DeployOFTAdapter();
            (,, address oftAdapterProxy) = d.deployOFTAdapter(owner, deployer, krwtProxy, lzEndpoint);
            console.log("OFTAdapter Proxy:", oftAdapterProxy);
        }

        // 5) Transfer ownership of both contracts to OWNER_ETH (two-step Ownable)
        KRWT(krwtProxy).transferOwnership(owner);
        IWhitelistOwnable(custProxy).transferOwnership(owner);
        console.log("Ownership transfer initiated to OWNER_ETH for KRWT and Custodian");

        vm.stopBroadcast();
    }
}
