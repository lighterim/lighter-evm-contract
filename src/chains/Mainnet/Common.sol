// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {SettlerBase} from "../../SettlerBase.sol";
import {ISettlerBase} from "../../interfaces/ISettlerBase.sol";

import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {SafeTransferLib} from "../../vendor/SafeTransferLib.sol";
import {ISettlerActions} from "../../ISettlerActions.sol";
import {ISignatureTransfer} from "@uniswap/permit2/interfaces/ISignatureTransfer.sol";
import {SettlerAbstract} from "../../SettlerAbstract.sol";
import {Permit2PaymentBase} from "../../core/Permit2Payment.sol";
import {FreeMemory} from "../../utils/FreeMemory.sol";


abstract contract MainnetMixin is SettlerBase, FreeMemory{

    using SafeTransferLib for IERC20;
    using SafeTransferLib for address payable;

    address internal lighterRelayer;

    constructor(address lighterRelayer_, bytes20 gitCommit) SettlerBase(gitCommit) {
        lighterRelayer = lighterRelayer_;
    }

    function _getRelayer() internal view override returns (address) {
        return lighterRelayer;
    }

    function _dispatch(uint256 i, uint256 action, bytes calldata data) internal virtual override(SettlerBase) DANGEROUS_freeMemory returns (bool) {
        return super._dispatch(i, action, data);
    }

    function _makeEscrow(bytes32 escrowTypedDataHash, ISettlerBase.EscrowParams memory escrowParams, uint256 gasSpentForBuyer, uint256 gasSpentForSeller) internal {
        
    }
}
