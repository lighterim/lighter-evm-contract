// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;


import {ISignatureTransfer} from "@uniswap/permit2/interfaces/ISignatureTransfer.sol";
import {IAllowanceTransfer} from "@uniswap/permit2/interfaces/IAllowanceTransfer.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {ISettlerBase} from "../interfaces/ISettlerBase.sol";
import {ParamsHash} from "../utils/ParamsHash.sol";
import {Context} from "../Context.sol";

import {
    InvalidIntentSignature, IntentExpired, InvalidToken, InvalidAmount, InvalidPayment, InvalidPrice
    } from "./SettlerErrors.sol";

abstract contract Permit2PaymentAbstract is Context {

    using ParamsHash for ISettlerBase.IntentParams;
    
    /**
     * signatureTransfer
     * @param permit ISignatureTransfer.PermitTransferFrom(
     * @param transferDetails ISignatureTransfer.SignatureTransferDetails
     * @param sig signature
     */
    function _transferFrom(
        ISignatureTransfer.PermitTransferFrom memory permit,
        ISignatureTransfer.SignatureTransferDetails memory transferDetails,
        address owner,
        bytes memory sig
    ) internal virtual;

    function _transferFromIKnowWhatImDoing(
        ISignatureTransfer.PermitTransferFrom memory permit,
        ISignatureTransfer.SignatureTransferDetails memory transferDetails,
        address from,
        bytes32 witness,
        string memory witnessTypeString,
        bytes memory sig
    ) internal virtual;

        /**
     * allowanceTransferWithPermit
     * @param token The token to transfer
     * @param owner The owner of the token
     * @param recipient The recipient of the transfer
     * @param amount The amount of tokens to transfer
     */
    function _allowanceHolderTransferFrom(address token, address owner, address recipient, uint160 amount) 
        internal
        virtual;

    /**
     * allowance transfer with permit(compatible with Permit2)
     * @param owner owner of the token
     * @param permitSingle permit single
     * @param signature signature
     */
    function _permit(address owner, IAllowanceTransfer.PermitSingle memory permitSingle, bytes memory signature)
        internal 
        virtual;
    
    /**
     * @notice Calculate the EIP-712 typed data hash of intent parameters
     * @param params Intent parameters
     * @param domainSeparator Domain separator
     * @return intentTypedHash EIP-712 typed data hash of intent parameters
     */ 
    function getIntentTypedHash(ISettlerBase.IntentParams memory params, bytes32 domainSeparator) internal pure returns (bytes32 intentTypedHash) {
        bytes32 intentHash = params.hash();
        intentTypedHash = MessageHashUtils.toTypedDataHash(domainSeparator, intentHash);
    }

    /**
     * @notice Verify that the intent parameters are complete and valid
     * @param signer Trusted signer address
     * @param domainSeparator Domain separator
     * @param params Intent parameters
     * @param sig Signature of intent parameters
     */
    function makesureIntentParams(
        address signer, 
        bytes32 domainSeparator, 
        ISettlerBase.IntentParams memory params, 
        bytes memory sig
        ) internal view virtual returns (bytes32 intentTypedHash){
        if(block.timestamp > params.expiryTime) revert IntentExpired(params.expiryTime);
        intentTypedHash = getIntentTypedHash(params, domainSeparator);
        if(!isValidSignature(signer, intentTypedHash, sig)) revert InvalidIntentSignature();
    }

     /**
     * @notice Verify that escrow parameters match the intent parameters
     * @dev They are typically buyer intent and seller submission, or buyer submission and seller intent
     * @param escrowParams Submitted escrow transaction parameters
     * @param intentParams Submitted intent parameters
     */
    function makesureTradeValidation(
        ISettlerBase.EscrowParams memory escrowParams, 
        ISettlerBase.IntentParams memory intentParams,
        bool isInitiatedByBuyer
        ) internal view virtual{
        if(block.timestamp > intentParams.expiryTime) revert IntentExpired(intentParams.expiryTime);
        if(escrowParams.token != intentParams.token) revert InvalidToken();
        if(
            escrowParams.volume < intentParams.range.min 
            || (intentParams.range.max > 0 && escrowParams.volume > intentParams.range.max)
        ) revert InvalidAmount();
        if(
            escrowParams.currency != intentParams.currency 
            || escrowParams.paymentMethod != intentParams.paymentMethod 
            || (isInitiatedByBuyer && escrowParams.payeeDetails != intentParams.payeeDetails)
        ) revert InvalidPayment();
        if(intentParams.price > 0 && escrowParams.price != intentParams.price) revert InvalidPrice();
    }


    /**
     * take intent with payer and witness
     * @param payer payer
     * @param witness witness
     * @param intentTypeHash intent type hash
     */
    modifier takeIntent(address payer, bytes32 tokenPermissionsHash, bytes32 witness, bytes32 intentTypeHash) virtual;

}
