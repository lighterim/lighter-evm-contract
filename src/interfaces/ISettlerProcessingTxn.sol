// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {ISettlerBase} from "./ISettlerBase.sol";

interface ISettlerProcessingTxn is ISettlerBase {
    
    function executeEscrowTxn(
        // AllowedSlippage calldata slippage,
        bytes[] calldata actions,
        bytes32 /* zid & affiliate */,
        address msgSender,
        bytes calldata sig
    ) external returns (bool);
}
