// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {ISettlerBase} from "./ISettlerBase.sol";

interface ISettlerTakeIntent is ISettlerBase {
    function execute(address payer, bytes32 tokenPermissionsHash, bytes32 witness, bytes32 intentTypeHash, bytes[] calldata actions )
        external
        payable
        returns (bool);
    
}
