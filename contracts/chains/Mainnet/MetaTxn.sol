// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {MainnetMixin} from "./Common.sol";
import {SettlerMetaTxn} from "../../SettlerMetaTxn.sol";

import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {ISignatureTransfer} from "@uniswap/permit2/interfaces/ISignatureTransfer.sol";
import {ISettlerActions} from "../../ISettlerActions.sol";

import {SettlerAbstract} from "../../SettlerAbstract.sol";
import {SettlerBase} from "../../SettlerBase.sol";
import {AbstractContext} from "../../Context.sol";


contract MainnetSettlerMetaTxn is MainnetMixin, SettlerMetaTxn {

    constructor(bytes20 gitCommit) SettlerBase(gitCommit) {}

    function _dispatch(uint256 index, uint256 action, bytes calldata data) internal virtual override(SettlerAbstract, SettlerBase, MainnetMixin) returns (bool) {
        return super._dispatch(index, action, data);
    }

    function _dispatchVIP(uint256 action, bytes calldata data) internal virtual override(SettlerAbstract, SettlerBase) returns (bool) {
        if(super._dispatchVIP(action, data)) {
            return true;
        }
        else{
            return false;
        }
        return true;
    }

    function _msgSender() internal view virtual override(SettlerMetaTxn, AbstractContext) returns (address) {
        return super._msgSender();
    }
}