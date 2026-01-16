// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {ISettlerBase} from "../interfaces/ISettlerBase.sol";
import {Context} from "../Context.sol";

abstract contract VerifierAbstract is Context {
   
    function _releaseByVerifier(ISettlerBase.EscrowParams memory escrowParams) internal virtual;
    
    modifier finalize(address sender, ISettlerBase.EscrowParams memory escrowParams) virtual;
   
}