// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {MainnetMixin} from "./Common.sol";
import {SettlerMetaTxn} from "../../SettlerMetaTxn.sol";

import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {ISignatureTransfer} from "@uniswap/permit2/interfaces/ISignatureTransfer.sol";
import {ISettlerActions} from "../../ISettlerActions.sol";

import {SettlerAbstract} from "../../SettlerAbstract.sol";
import {SettlerBase} from "../../SettlerBase.sol";
import {Context} from "../../Context.sol";


contract MainnetSettlerMetaTxn is MainnetMixin, SettlerMetaTxn {

    constructor(address lighterRelayer, bytes20 gitCommit) MainnetMixin(lighterRelayer, gitCommit) {}

    function _dispatch(uint256 index, uint256 action, bytes calldata data) internal virtual override returns (bool) {
        // return super._dispatch(index, action, data);
        return true;
    }

    

    function _msgSender() internal view virtual override(SettlerMetaTxn) returns (address) {
        return super._msgSender();
    }
}