// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

import {Context} from "./Context.sol";
import {ParamsHash} from "./utils/ParamsHash.sol";
import {ISettlerBase} from "./interfaces/ISettlerBase.sol";

import {
    InvalidIntentSignature, IntentExpired, InvalidToken, InvalidAmount, InvalidPayment, InvalidPrice
    } from "./core/SettlerErrors.sol";

abstract contract SettlerAbstract is Context {

    using ParamsHash for ISettlerBase.IntentParams;
    
    IERC20 internal constant ETH_ADDRESS = IERC20(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE);

    function _tokenId() internal pure virtual returns (uint256);

    function _domainSeparator() internal view virtual returns (bytes32);

    function _dispatch(uint256 i, uint256 action, bytes calldata data) internal virtual returns (bool);


    // /** 
    //  * @notice Calculate the EIP-712 typed data hash of intent parameters
    //  * @param params Intent parameters
    //  * @param domainSeparator Domain separator
    //  * @return intentTypedHash EIP-712 typed data hash of intent parameters
    //  */ 
    // function getIntentTypedHash(ISettlerBase.IntentParams memory params, bytes32 domainSeparator) internal pure returns (bytes32 intentTypedHash) {
    //     bytes32 intentHash = params.hash();
    //     intentTypedHash = MessageHashUtils.toTypedDataHash(domainSeparator, intentHash);
    // }

    // /**
    //  * @notice Verify that the intent parameters are complete and valid
    //  * @param signer Trusted signer address
    //  * @param domainSeparator Domain separator
    //  * @param params Intent parameters
    //  * @param sig Signature of intent parameters
    //  */
    // function makesureIntentParams(
    //     address signer, 
    //     bytes32 domainSeparator, 
    //     ISettlerBase.IntentParams memory params, 
    //     bytes memory sig
    //     ) internal view virtual returns (bytes32 intentTypedHash){
    //     if(block.timestamp > params.expiryTime) revert IntentExpired(params.expiryTime);
    //     intentTypedHash = getIntentTypedHash(params, domainSeparator);
    //     if(!isValidSignature(signer, intentTypedHash, sig)) revert InvalidIntentSignature();
    // }

    // /**
    //  * @notice Verify that escrow parameters match the intent parameters
    //  * @dev They are typically buyer intent and seller submission, or buyer submission and seller intent
    //  * @param escrowParams Submitted escrow transaction parameters
    //  * @param intentParams Submitted intent parameters
    //  */
    // function makesureTradeValidation(ISettlerBase.EscrowParams memory escrowParams, ISettlerBase.IntentParams memory intentParams) internal view virtual{
    //     if(block.timestamp > intentParams.expiryTime) revert IntentExpired(intentParams.expiryTime);
    //     if(escrowParams.token != intentParams.token) revert InvalidToken();
    //     if(escrowParams.volume < intentParams.range.min || (intentParams.range.max > 0 && escrowParams.volume > intentParams.range.max)) revert InvalidAmount();
    //     if(escrowParams.currency != intentParams.currency || escrowParams.paymentMethod != intentParams.paymentMethod || escrowParams.payeeDetails != intentParams.payeeDetails) revert InvalidPayment();
    //     if(intentParams.price > 0 && escrowParams.price != intentParams.price) revert InvalidPrice();
    // }

    
}