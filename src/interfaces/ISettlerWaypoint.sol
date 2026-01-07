// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {ISettlerBase} from "./ISettlerBase.sol";

interface ISettlerWaypoint is ISettlerBase {
    
    function execute(
        bytes32 escrowTypedDataHash,
        bytes[] calldata actions
    ) external payable returns (bool);
}
