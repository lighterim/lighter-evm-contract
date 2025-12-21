// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;


abstract contract FinalizeAbstract {
   
    function _releaseByVerifier(ISettlerBase.EscrowParams memory escrowParams) internal virtual;

    function _releaseByExecutor(ISettlerBase.EscrowParams memory escrowParams) internal virtual;

    function _resolve(ISettlerBase.EscrowParams memory escrowParams, uint16 percentage) internal virtual;
    
    modifier _finalize(address sender, ISettlerBase.EscrowParams memory escrowParams) virtual;
   
}