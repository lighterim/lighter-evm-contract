// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {ISettlerBase} from "./interfaces/ISettlerBase.sol";
import {ISignatureTransfer} from "@uniswap/permit2/interfaces/ISignatureTransfer.sol";
import {IAllowanceTransfer} from "@uniswap/permit2/interfaces/IAllowanceTransfer.sol";

interface ISettlerActions {


    /// @dev Signature transfer funds from msg.sender Permit2.
    function SIGNATURE_TRANSFER_FROM(
        ISignatureTransfer.PermitTransferFrom memory permit, 
        ISignatureTransfer.SignatureTransferDetails memory transferDetails, 
        bytes memory sig
        ) external;

    /// @dev Signature transfer funds from seller Permit2 with witness.
    function SIGNATURE_TRANSFER_FROM_WITH_WITNESS(
        ISignatureTransfer.PermitTransferFrom memory permit, 
        ISignatureTransfer.SignatureTransferDetails memory details,
        ISettlerBase.IntentParams memory intentParams,
        bytes memory sig
        ) external;
    
   
    function BULK_SELL_TRANSFER_FROM(
        IAllowanceTransfer.AllowanceTransferDetails memory details,
        ISettlerBase.IntentParams memory intentParams,
        bytes memory makerIntentSig
        ) external;

    ///@dev msgValue is interpreted as an upper bound on the expected msg.value, not as an exact specification
    function NATIVE_CHECK(uint256 deadline, uint256 msgValue) external;

    function ESCROW_PARAMS_CHECK(ISettlerBase.EscrowParams memory escrowParams, bytes memory sig) external;

    function ESCROW_AND_INTENT_CHECK(
        ISettlerBase.EscrowParams memory escrowParams, 
        ISettlerBase.IntentParams memory intentParams,
        bytes memory makerIntentSig
        ) external;
    
}
