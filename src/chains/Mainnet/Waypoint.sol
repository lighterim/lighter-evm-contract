// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;


import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {ISignatureTransfer} from "@uniswap/permit2/interfaces/ISignatureTransfer.sol";
import {IAllowanceHolder} from "../../allowanceholder/IAllowanceHolder.sol";
import {Permit2PaymentWaypoint} from "../../core/Permit2Payment.sol";
import {MainnetMixin} from "./Common.sol";
import {SettlerWaypoint} from "../../SettlerWaypoint.sol";
import {ISettlerActions} from "../../ISettlerActions.sol";
import {EscrowAbstract} from "../../core/EscrowAbstract.sol";

import {SettlerAbstract} from "../../SettlerAbstract.sol";
import {SettlerBase} from "../../SettlerBase.sol";
import {Context} from "../../Context.sol";
import {IEscrow} from "../../interfaces/IEscrow.sol";
import {LighterAccount} from "../../account/LighterAccount.sol";


contract MainnetWaypoint is MainnetMixin, SettlerWaypoint {

    constructor(address lighterRelayer, IEscrow escrow, LighterAccount lighterAccount, bytes20 gitCommit, IAllowanceHolder allowanceHolder) 
    MainnetMixin(lighterRelayer, escrow, lighterAccount, gitCommit)
    Permit2PaymentWaypoint(allowanceHolder)
    {

    }

    
    function _dispatch(uint256 i, uint256 action, bytes calldata data) internal virtual override(MainnetMixin, SettlerWaypoint) returns (bool) {
        return super._dispatch(i, action, data);
    }

    function _dispatchVIP(uint256 action, bytes calldata data) internal virtual override(SettlerWaypoint) returns (bool) {
        return false;
    }

}