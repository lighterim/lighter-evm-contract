// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {AbstractContext} from "../Context.sol";

import {ISignatureTransfer} from "@uniswap/permit2/interfaces/ISignatureTransfer.sol";
import {IAllowanceTransfer} from "@uniswap/permit2/interfaces/IAllowanceTransfer.sol";

abstract contract Permit2PaymentAbstract is AbstractContext {
    
        
    function _isRestrictedTarget(address) internal pure virtual returns (bool);

    function _operator() internal view virtual returns (address);

    /**
     * signatureTransfer
     * @param permit ISignatureTransfer.PermitTransferFrom(
     * @param transferDetails ISignatureTransfer.SignatureTransferDetails
     * @param sig signature
     * @param isForwarded is forwarded
     */
    function _transferFrom(
        ISignatureTransfer.PermitTransferFrom memory permit,
        ISignatureTransfer.SignatureTransferDetails memory transferDetails,
        bytes memory sig,
        bool isForwarded
    ) internal virtual;

    function _transferFrom(
        ISignatureTransfer.PermitTransferFrom memory permit,
        ISignatureTransfer.SignatureTransferDetails memory transferDetails,
        bytes memory sig
    ) internal virtual;

    function _setOperatorAndCall(
        address target,
        bytes memory data,
        uint32 selector,
        function (bytes calldata) internal returns (bytes memory) callback
    ) internal virtual returns (bytes memory);
    

        /**
     * allowanceTransferWithPermit
     * @param token The token to transfer
     * @param owner The owner of the token
     * @param recipient The recipient of the transfer
     * @param amount The amount of tokens to transfer
     */
    function _allowanceHolderTransferFrom(address token, address owner, address recipient, uint256 amount)
        internal
        virtual;

    function _permit(address owner, IAllowanceTransfer.PermitSingle memory permitSingle, bytes memory signature)
        internal 
        virtual;

    modifier metaTx(address msgSender, bytes32 witness) virtual;

    modifier takerSubmitted() virtual;

}
