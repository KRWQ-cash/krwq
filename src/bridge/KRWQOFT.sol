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
|                  "*8*                         *$       KRWQ  |
+--------------------------------------------------------------+
*/

import {OFTUpgradeable} from "@layerzerolabs/oft-evm-upgradeable/contracts/oft/OFTUpgradeable.sol";

contract KRWQOFT is OFTUpgradeable {
    constructor(address _lzEndpoint) OFTUpgradeable(_lzEndpoint) {
        _disableInitializers();
    }

    function initialize(string memory _name, string memory _symbol, address _delegate) public initializer {
        __OFT_init(_name, _symbol, _delegate);
        __Ownable_init(_delegate);
    }
}
