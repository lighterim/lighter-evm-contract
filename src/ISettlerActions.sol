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

    function ESCROW_PARAMS_CHECK(ISettlerBase.EscrowParams memory escrowParams, bytes memory sig) external;

    function ESCROW_AND_INTENT_CHECK(
        ISettlerBase.EscrowParams memory escrowParams, 
        ISettlerBase.IntentParams memory intentParams,
        bytes memory makerIntentSig
        ) external;
    
    function MAKE_PAYMENT(ISettlerBase.EscrowParams memory escrowParams, bytes memory sig) external;
    
    function CANCEL_BY_BUYER(ISettlerBase.EscrowParams memory escrowParams, bytes memory sig) external;

    function CANCEL_BY_SELLER(ISettlerBase.EscrowParams memory escrowParams, bytes memory sig) external;

    function REQUEST_CANCEL(ISettlerBase.EscrowParams memory escrowParams, bytes memory sig) external;

    function DISPUTE_BY_BUYER(ISettlerBase.EscrowParams memory escrowParams, bytes memory sig) external;

    function DISPUTE_BY_SELLER(ISettlerBase.EscrowParams memory escrowParams, bytes memory sig) external;

    function RELEASE_BY_SELLER(ISettlerBase.EscrowParams memory escrowParams, bytes memory sig) external;

    function RESOLVE(
        ISettlerBase.EscrowParams memory escrowParams,
        uint16 buyerThresholdBp, // buyer threshold in basis points
        address tbaArbitrator, 
        bytes memory sig, bytes memory arbitratorSig, bytes memory counterpartySig
        ) external;


    function RELEASE_BY_VERIFIER(ISettlerBase.EscrowParams memory escrowParams, bytes memory sig) external;

    
}
