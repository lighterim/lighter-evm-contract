// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {AbstractContext} from "../Context.sol";

import {ISignatureTransfer} from "@uniswap/permit2/interfaces/ISignatureTransfer.sol";

abstract contract Permit2PaymentAbstract is AbstractContext {
    
    string internal constant TOKEN_PERMISSIONS_TYPE = "TokenPermissions(address token,uint256 amount)";

    function _isRestrictedTarget(address) internal view virtual returns (bool);

    function _operator() internal view virtual returns (address);

    function _permitToSellAmountCalldata(ISignatureTransfer.PermitTransferFrom calldata permit)
        internal
        view
        virtual
        returns (uint256 sellAmount);

    function _permitToSellAmount(ISignatureTransfer.PermitTransferFrom memory permit)
        internal
        view
        virtual
        returns (uint256 sellAmount);

    function _permitToTransferDetails(ISignatureTransfer.PermitTransferFrom memory permit, address recipient)
        internal
        view
        virtual
        returns (ISignatureTransfer.SignatureTransferDetails memory transferDetails, uint256 sellAmount);

    /**
     * signatureTransferWithWitness SignatureTransfer technique with extra witness data
     * @param permit ISignatureTransfer.PermitTransferFrom(
     * @param transferDetails ISignatureTransfer.SignatureTransferDetails
     * @param from The address from which the transfer is made
     * @param witness The witness of the transfer
     * @param witnessTypeString The type of witness
     * @param sig signature
     * @param isForwarded is forwarded
     */
    function _transferFromIKnowWhatImDoing(
        ISignatureTransfer.PermitTransferFrom memory permit,
        ISignatureTransfer.SignatureTransferDetails memory transferDetails,
        address from,
        bytes32 witness,
        string memory witnessTypeString,
        bytes memory sig,
        bool isForwarded
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

    modifier metaTx(address msgSender, bytes32 witness) virtual;

    modifier takerSubmitted() virtual;

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
}
