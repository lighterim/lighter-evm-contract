// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;


import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {ISignatureTransfer} from "@uniswap/permit2/interfaces/ISignatureTransfer.sol";
import {IAllowanceHolder} from "../../allowanceholder/IAllowanceHolder.sol";
import {Permit2PaymentMetaTxn} from "../../core/Permit2Payment.sol";
import {MainnetMixin} from "./Common.sol";
import {SettlerMetaTxn} from "../../SettlerMetaTxn.sol";
import {AbstractContext} from "../../Context.sol";
import {ISettlerActions} from "../../ISettlerActions.sol";
import {EscrowAbstract} from "../../core/EscrowAbstract.sol";

import {SettlerAbstract} from "../../SettlerAbstract.sol";
import {SettlerBase} from "../../SettlerBase.sol";
import {Context} from "../../Context.sol";


contract MainnetSettlerMetaTxn is MainnetMixin, SettlerMetaTxn {

    constructor(address lighterRelayer, bytes20 gitCommit, IAllowanceHolder allowanceHolder)
     MainnetMixin(lighterRelayer, gitCommit)
      Permit2PaymentMetaTxn(allowanceHolder){

      }

    


    
    function _msgSender() internal view virtual override(SettlerMetaTxn, AbstractContext) returns (address) {
        return super._msgSender();
    }
}