
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {ISignatureTransfer} from "@uniswap/permit2/interfaces/ISignatureTransfer.sol";
import {IAllowanceTransfer} from "@uniswap/permit2/interfaces/IAllowanceTransfer.sol";
import {ISettlerTakeIntent} from "./interfaces/ISettlerTakeIntent.sol";
import {Permit2PaymentTakeIntent} from "./core/Permit2Payment.sol";

// import {PermitHash} from "@uniswap/permit2/libraries/PermitHash.sol";

import {CalldataDecoder} from "./SettlerBase.sol";
import {UnsafeMath} from "./utils/UnsafeMath.sol";

import {ISettlerActions} from "./ISettlerActions.sol";
import {ISettlerBase} from "./interfaces/ISettlerBase.sol";
import {ParamsHash} from "./utils/ParamsHash.sol";
import {
    revertActionInvalid, InvalidWitness, InvalidPayer, InvalidIntent
    } from "./core/SettlerErrors.sol";
// import {console} from "forge-std/console.sol";


abstract contract Settler is ISettlerTakeIntent, Permit2PaymentTakeIntent {

    using UnsafeMath for uint256;
    using CalldataDecoder for bytes[];
    using ParamsHash for ISettlerBase.IntentParams;
    using ParamsHash for ISettlerBase.EscrowParams;
    using ParamsHash for ISignatureTransfer.TokenPermissions;
    // // using PermitHash for ISignatureTransfer.PermitTransferFrom;
    
    error InvalidTokenPermissions();

    function _tokenId() internal pure override returns (uint256) {
        return 2;
    }

    // function _myAddress() internal view virtual returns (address);

    function _dispatch(uint256 index, uint256 action, bytes calldata data) internal virtual override returns (bool) {
        if(action == uint32(ISettlerActions.ESCROW_PARAMS_CHECK.selector)) {
            // console.logString("------------ESCROW_PARAMS_CHECK--------------------");
            (ISettlerBase.EscrowParams memory escrowParams, bytes memory sig) = abi.decode(data, (ISettlerBase.EscrowParams, bytes));
            // makesure escrow params come from relayer signature.
            (,bytes32 escrowTypedHash) = makesureEscrowParams(_domainSeparator(), escrowParams, sig);
            
            // escrow typed hash(takeIntent modifier) should be the same as the escrow typed hash in the escrow params.
            if (escrowTypedHash != getWitness()) {
                revert InvalidWitness();
            }
            clearWitness();
        }
        else if(action == uint32(ISettlerActions.SIGNATURE_TRANSFER_FROM.selector)) {
            // take buyer intent
            (
                ISignatureTransfer.PermitTransferFrom memory permit, 
                ISignatureTransfer.SignatureTransferDetails memory transferDetails,
                bytes memory sig
            ) = abi.decode(data, (ISignatureTransfer.PermitTransferFrom, ISignatureTransfer.SignatureTransferDetails, bytes));
            
            _makesureTokenPermissions(permit.permitted);
            
            address payer = getPayer();
            _transferFrom(permit, transferDetails, payer, sig);
            
            clearPayer(payer);
            clearTokenPermissionsHash();
        }
        else if(action == uint32(ISettlerActions.SIGNATURE_TRANSFER_FROM_WITH_WITNESS.selector)) {
            // take seller intent
            (
                ISignatureTransfer.PermitTransferFrom memory permit, 
                ISignatureTransfer.SignatureTransferDetails memory transferDetails, 
                ISettlerBase.IntentParams memory intentParams,
                bytes memory sig
            ) = abi.decode(data, (ISignatureTransfer.PermitTransferFrom, ISignatureTransfer.SignatureTransferDetails, ISettlerBase.IntentParams, bytes));
            // console.logString("------------SIGNATURE_TRANSFER_FROM_WITH_WITNESS--------------------");
            bytes32 intentParamsHash = intentParams.hash(); 
            bytes32 intentTypedHash = getIntentTypedHash(intentParams, _domainSeparator());
            if(intentTypedHash != getIntentTypeHash()) revert InvalidIntent();
            
            _makesureTokenPermissions(permit.permitted);

            address payer = getPayer();
            _transferFromIKnowWhatImDoing(permit, transferDetails, payer, intentParamsHash, ParamsHash._INTENT_WITNESS_TYPE_STRING, sig);
            // console.logString("--------------------------------");
            // console.logString("payer");
            // console.logAddress(payer);
            // console.logString("intentParamsHash");
            // console.logBytes32(intentParamsHash);
            // console.logString("intentTypedHash");
            // console.logBytes32(intentTypedHash);
            // console.logString("sig");
            // console.logBytes(sig);
            
            // // Use helper function to handle memory -> calldata conversion
            // bytes32 dataHash = _hashPermitWithWitness(permit, intentParamsHash);
            
            // // Debug: output Permit2 address and DOMAIN_SEPARATOR
            // console.logString("_PERMIT2 address");
            // console.logAddress(address(_PERMIT2));
            // bytes32 permit2DomainSeparator = _PERMIT2.DOMAIN_SEPARATOR();
            // console.logString("_PERMIT2.DOMAIN_SEPARATOR()");
            // console.logBytes32(permit2DomainSeparator);
            
            // bytes32 signatureForDataHash = keccak256(abi.encodePacked("\x19\x01", permit2DomainSeparator, dataHash));
            // console.logString("signatureForDataHash");
            // console.logBytes32(signatureForDataHash);
            // console.logString("dataHash");
            // console.logBytes32(dataHash);
            // _transferFromIKnowWhatImDoing(permit, transferDetails, payer, intentParamsHash, ParamsHash._INTENT_WITNESS_TYPE_STRING, sig);
            // console.logString("########################################################");
            clearPayer(payer);
            clearIntentTypeHash();
            clearTokenPermissionsHash();
        }
        else if (action == uint32(ISettlerActions.BULK_SELL_TRANSFER_FROM.selector)) {
            // take bulk sell intent
            (
                IAllowanceTransfer.AllowanceTransferDetails memory details,
                ISettlerBase.IntentParams memory intentParams,
                bytes memory sig
            ) = abi.decode(data, (IAllowanceTransfer.AllowanceTransferDetails, ISettlerBase.IntentParams, bytes));

            // Payer
            address payer = getPayer();
            if(details.from != payer) revert InvalidPayer();
            // Ensure intent params come from payer signature
            bytes32 intentTypeHash = makesureIntentParams(payer, _domainSeparator(), intentParams, sig);
            // Intent typed hash should be the same as the intent type hash in the intent params
            if(intentTypeHash != getIntentTypeHash()) revert InvalidIntent();

            _makesureTokenPermissions(ISignatureTransfer.TokenPermissions({
                token: details.token,
                amount: uint256(details.amount)
            }));

            // Do not verify spender allowance, as transferFrom will automatically verify allowance and call relationship
            _allowanceHolderTransferFrom(details.token, payer, details.to, details.amount);
            
            clearPayer(payer);
            clearIntentTypeHash();
            clearTokenPermissionsHash();
        } 
        else{
            return false;
        }
        return true;
    }

    function _makesureTokenPermissions(ISignatureTransfer.TokenPermissions memory tokenPermissions) internal view returns (bool) {
        bytes32 tokenPermissionsHash = tokenPermissions.hash();
        if(tokenPermissionsHash != getTokenPermissionsHash()) revert InvalidTokenPermissions();
        return true;
    }

    function execute(address payer, bytes32 tokenPermissionsHash, bytes32 escrowTypedHash, bytes32 intentTypeHash, bytes[] calldata actions)
        public
        payable
        override
        takeIntent(payer, tokenPermissionsHash, escrowTypedHash, intentTypeHash)
        returns (bool)
    {
        if (actions.length != 0) {
            (uint256 action, bytes calldata data) = actions.decodeCall(0);
            if (!_dispatchVIP(action, data)) {
                if (!_dispatch(0, action, data)) {
                    revertActionInvalid(0, action, data);
                }
            }
        }

        for (uint256 i = 1; i < actions.length; i = i.unsafeInc()) {
            (uint256 action, bytes calldata data) = actions.decodeCall(i);
            if (!_dispatch(i, action, data)) {
                revertActionInvalid(i, action, data);
            }
        }

        return true;
    }

}
