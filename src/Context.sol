// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {SignatureChecker} from "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

import {IEscrow} from "./interfaces/IEscrow.sol";
import {ISettlerBase} from "./interfaces/ISettlerBase.sol";
import {ParamsHash} from "./utils/ParamsHash.sol";
import {
    InvalidEscrowSignature, InvalidResolvedResultSignature
    } from "./core/SettlerErrors.sol";

abstract contract AbstractContext {
    
    function _msgSender() internal view virtual returns (address);
}

abstract contract Context is AbstractContext {

    using ParamsHash for ISettlerBase.EscrowParams;
    using ParamsHash for ISettlerBase.ResolvedResult;
    IEscrow internal escrow;
    address internal relayer;

    constructor(IEscrow escrow_, address lighterRelayer_) {
        escrow = escrow_;
        relayer = lighterRelayer_;
    }

    /**
     * @notice Calculate the EIP-712 typed data hash of escrow parameters
     * @param params Escrow transaction parameters
     * @param domainSeparator Domain separator
     * @return escrowHash Hash of escrow parameters
     * @return escrowTypedHash EIP-712 typed data hash of escrow parameters, used for signature verification
     */
    function getEscrowTypedHash(
        ISettlerBase.EscrowParams memory params, 
        bytes32 domainSeparator
    )internal pure returns (bytes32 escrowHash, bytes32 escrowTypedHash) {
        escrowHash = params.hash();
        escrowTypedHash = MessageHashUtils.toTypedDataHash(domainSeparator, escrowHash);
    }

    function getResolvedResultTypedHash(
        ISettlerBase.ResolvedResult memory resolvedResult,
        bytes32 domainSeparator
    )internal pure returns (bytes32 resolvedResultHash, bytes32 resolvedResultTypedHash) {
        resolvedResultHash = resolvedResult.hash();
        resolvedResultTypedHash = MessageHashUtils.toTypedDataHash(domainSeparator, resolvedResultHash);
    }

    function _msgSender() internal view virtual override returns (address) {
        return msg.sender;
    }

    /**
     * @notice Verify that the signature is valid. Supports EIP-1271 and EIP-2098 signatures
     * @param signer Signer address
     * @param hash Hash to verify
     * @param sig Signature
     * @return isValid Whether the signature is valid
     */
    function isValidSignature(address signer, bytes32 hash, bytes memory sig) internal view returns (bool){
        return SignatureChecker.isValidSignatureNow(signer, hash, sig);
    }

    /**
     * @notice Verify that escrow parameters are complete and valid
     * @param domainSeparator Domain separator
     * @param params Escrow transaction parameters
     * @param sig Signature of escrow parameters
     */
    function makesureEscrowParams(
        bytes32 domainSeparator, 
        ISettlerBase.EscrowParams memory params, 
        bytes memory sig
    ) internal view virtual returns (bytes32 escrowHash, bytes32 escrowTypedHash){
        (escrowHash, escrowTypedHash) = getEscrowTypedHash(params, domainSeparator);
        if(!isValidSignature(relayer, escrowTypedHash, sig)) revert InvalidEscrowSignature();
    }

    function makesureResolvedResult(
        bytes32 domainSeparator,
        bytes32 escrowHash,
        uint16 buyerThresholdBp,
        bytes memory sig
    ) internal view virtual returns (bytes32 resolvedResultHash, bytes32 resolvedResultTypedHash){
        ISettlerBase.ResolvedResult memory resolvedResult = ISettlerBase.ResolvedResult(escrowHash, buyerThresholdBp);
        (resolvedResultHash, resolvedResultTypedHash) = getResolvedResultTypedHash(resolvedResult, domainSeparator);
        if(!isValidSignature(relayer, resolvedResultTypedHash, sig)) revert InvalidResolvedResultSignature();
    }

}
