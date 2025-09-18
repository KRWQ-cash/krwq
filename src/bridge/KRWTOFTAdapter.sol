// SPDX-License-Identifier: MIT
// @version 0.2.8
pragma solidity ^0.8.24;

/*
+--------------------------------------------------------------+
|             $*                         *8*                   |
|            88   $*                      "*8"  .              |
|           88   88   $*               *8*     8 *,            |
|          88   88   88                 "*8 *   "*8*           |
|         88   88   88              *8 *   "*8 * ,             |
|        *$   88   88                " *8" .  "*8*             |
|            *$   88        .-888-.        8 * ,               |
|                *$       .888red888.       "*8*               |
|                        ,888888.*;;*.                         |
|                        888888*;;;;;`                         |
|                        888888*;;;;;j                         |
|                        `*00*";;;;;.'                         |
|               *8*       `;;;blue;;'        $*                |
|                "*8 *      `-;;;-'         88   $*            |
|             *8*   "*8 *,                 "*   88   $*        |
|              "*8" .  "*8*               *.   "*   88         |
|          *8 *     8 * ,                88   *.   "*          |
|           " *8 *   "*8*               *$   88   *.           |
|               "*8 * ,                     *$   88            |
|                  "*8*                         *$       KRWT  |
+--------------------------------------------------------------+
*/

import {OFTAdapterUpgradeable} from "@layerzerolabs/oft-evm-upgradeable/contracts/oft/OFTAdapterUpgradeable.sol";

contract KRWTOFTAdapter is OFTAdapterUpgradeable {
    constructor(address _token, address _lzEndpoint) OFTAdapterUpgradeable(_token, _lzEndpoint) {
        _disableInitializers();
    }

    function initialize(address _delegate) public initializer {
        __OFTAdapter_init(_delegate);
        __Ownable_init(_delegate);
    }
}
