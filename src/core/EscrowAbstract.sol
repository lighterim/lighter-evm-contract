// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {SignatureChecker} from "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

import {ISettlerBase} from "../interfaces/ISettlerBase.sol";
import {SettlerAbstract} from "../SettlerAbstract.sol";
import {ParamsHash} from "../utils/ParamsHash.sol";

import {
    InvalidEscrowSignature, InvalidIntentSignature, InvalidAmount, IntentExpired, InvalidToken,
    InvalidPayment, InvalidPrice
    } from "./SettlerErrors.sol";


abstract contract EscrowAbstract is SettlerAbstract {

    using ParamsHash for ISettlerBase.EscrowParams;
    using ParamsHash for ISettlerBase.IntentParams;

    function getEscrowTypedHash(ISettlerBase.EscrowParams memory params, bytes32 domainSeparator) internal pure returns (bytes32 escrowTypedHash) {
        bytes32 escrowHash = params.hash();
        escrowTypedHash = MessageHashUtils.toTypedDataHash(domainSeparator, escrowHash);
    }

    function makesureEscrowParams(address relayer, bytes32 domainSeparator, ISettlerBase.EscrowParams memory params, bytes memory sig) internal view virtual returns (bytes32 escrowTypedHash){
        bytes32 escrowHash = params.hash();
        escrowTypedHash = MessageHashUtils.toTypedDataHash(domainSeparator, escrowHash);
        if(!isValidSignature(relayer, escrowTypedHash, sig)) revert InvalidEscrowSignature();
    }

    function makesureIntentParams(address relayer, bytes32 domainSeparator, ISettlerBase.IntentParams memory params, bytes memory sig) internal view virtual returns (bytes32 intentTypedHash){
        if(block.timestamp > params.expiryTime) revert IntentExpired(params.expiryTime);
        bytes32 intentHash = params.hash();
        intentTypedHash = MessageHashUtils.toTypedDataHash(domainSeparator, intentHash);
        if(!isValidSignature(relayer, intentTypedHash, sig)) revert InvalidIntentSignature();
    }

    function makesureTradeValidation(ISettlerBase.EscrowParams memory escrowParams, ISettlerBase.IntentParams memory intentParams) internal view virtual{
        if(block.timestamp > intentParams.expiryTime) revert IntentExpired(intentParams.expiryTime);
        if(escrowParams.token != intentParams.token) revert InvalidToken();
        if(escrowParams.volume < intentParams.range.min || (intentParams.range.max > 0 && escrowParams.volume > intentParams.range.max)) revert InvalidAmount();
        if(escrowParams.currency != intentParams.currency || escrowParams.paymentMethod != intentParams.paymentMethod || escrowParams.payeeDetails != intentParams.payeeDetails) revert InvalidPayment();
        if(intentParams.price > 0 &&escrowParams.price != intentParams.price) revert InvalidPrice();
    }

    function isValidSignature(address signer, bytes32 hash, bytes memory sig) internal view returns (bool){
        return SignatureChecker.isValidSignatureNow(signer, hash, sig);
    }

    // function _hashTypedDataEscrowParams(bytes32 hash) internal view virtual returns (bytes32);

    // function _hashTypedDataIntentParams(bytes32 hash) internal view virtual returns (bytes32);

}