// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {ISettlerBase} from "./ISettlerBase.sol";

interface ISettlerWaypoint is ISettlerBase {
    
    function executeWaypoint(
        bytes32 escrowTypedDataHash,
        bytes[] calldata actions
    ) external payable returns (bool);
}
