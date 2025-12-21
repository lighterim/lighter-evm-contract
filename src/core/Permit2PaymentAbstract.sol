// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;


import {ISignatureTransfer} from "@uniswap/permit2/interfaces/ISignatureTransfer.sol";
import {IAllowanceTransfer} from "@uniswap/permit2/interfaces/IAllowanceTransfer.sol";

abstract contract Permit2PaymentAbstract {
    
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
     * take intent with payer and witness
     * @param payer payer
     * @param witness witness
     * @param intentTypeHash intent type hash
     */
    modifier takeIntent(address payer, bytes32 tokenPermissionsHash, bytes32 witness, bytes32 intentTypeHash) virtual;

}
