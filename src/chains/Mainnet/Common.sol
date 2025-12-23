// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {SettlerBase} from "../../SettlerBase.sol";
import {ISettlerBase} from "../../interfaces/ISettlerBase.sol";


import {FreeMemory} from "../../utils/FreeMemory.sol";
import {IEscrow} from "../../interfaces/IEscrow.sol";
import {Context} from "../../Context.sol";
import {LighterAccount} from "../../account/LighterAccount.sol";
// import {console} from "forge-std/console.sol";


abstract contract MainnetMixin is SettlerBase, FreeMemory{

    // using SafeTransferLib for IERC20;
    // using SafeTransferLib for address payable;

    LighterAccount internal lighterAccount;

    constructor(address lighterRelayer_, IEscrow escrow_, LighterAccount lighterAccount_, bytes20 gitCommit)
        SettlerBase(gitCommit)
        Context(escrow_, lighterRelayer_) {
        // assert(block.chainid == 1 || block.chainid == 31337);
        lighterAccount = lighterAccount_;
    }

    function getLighterAccount() public view returns (LighterAccount) {
        return lighterAccount;
    }


}
