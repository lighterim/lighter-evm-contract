
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {ISignatureTransfer} from "@uniswap/permit2/interfaces/ISignatureTransfer.sol";
import {IAllowanceTransfer} from "@uniswap/permit2/interfaces/IAllowanceTransfer.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {ISettlerTakeIntent} from "./interfaces/ISettlerTakeIntent.sol";
import {Permit2PaymentTakeIntent} from "./core/Permit2Payment.sol";
import {Permit2PaymentAbstract} from "./core/Permit2PaymentAbstract.sol";
// import {PermitHash} from "@uniswap/permit2/libraries/PermitHash.sol";

import {CalldataDecoder, SettlerBase} from "./SettlerBase.sol";
import {UnsafeMath} from "./utils/UnsafeMath.sol";

import {ISettlerActions} from "./ISettlerActions.sol";
import {ISettlerBase} from "./interfaces/ISettlerBase.sol";
import {ParamsHash} from "./utils/ParamsHash.sol";
import {
    revertActionInvalid, SignatureExpired, MsgValueMismatch, InvalidWitness, InvalidToken, InvalidAmount, 
    InvalidPayment, InvalidPrice, InvalidPayer, InvalidIntent
    } from "./core/SettlerErrors.sol";
import {SettlerAbstract} from "./SettlerAbstract.sol";
// import {console} from "forge-std/console.sol";


abstract contract Settler is ISettlerTakeIntent, Permit2PaymentTakeIntent, SettlerBase {

    using UnsafeMath for uint256;
    using CalldataDecoder for bytes[];
    using ParamsHash for ISettlerBase.IntentParams;
    using ParamsHash for ISettlerBase.EscrowParams;
    // // using PermitHash for ISignatureTransfer.PermitTransferFrom;
    
    // // 辅助函数：直接计算 permit hash with witness（避免 memory -> calldata 转换问题）
    // function _hashPermitWithWitness(
    //     ISignatureTransfer.PermitTransferFrom memory permit,
    //     bytes32 witness
    // ) internal view returns (bytes32) {
    //     // 直接实现 hashWithWitness 的逻辑，使用 memory string
    //     string memory witnessTypeString = ParamsHash._INTENT_WITNESS_TYPE_STRING;
    //     bytes32 typeHash = keccak256(abi.encodePacked(
    //         PermitHash._PERMIT_TRANSFER_FROM_WITNESS_TYPEHASH_STUB,
    //         witnessTypeString
    //     ));
    //     console.logString("witness.typeHash");
    //     console.logBytes32(typeHash);

    //     bytes32 tokenPermissionsHash = keccak256(abi.encode(
    //         PermitHash._TOKEN_PERMISSIONS_TYPEHASH,
    //         permit.permitted
    //     ));
    //     console.logString("tokenPermissionsHash");
    //     console.logBytes32(tokenPermissionsHash);
    //     console.logString("myAddress");
    //     console.logAddress(_myAddress());
    //     console.logString("permit.nonce");
    //     console.logUint(permit.nonce);
    //     console.logString("permit.deadline");
    //     console.logUint(permit.deadline);
    //     console.logString("witness");
    //     console.logBytes32(witness);
    //     console.logString("keccak256(abi.encode(typeHash, tokenPermissionsHash, _myAddress(), permit.nonce, permit.deadline, witness))");
    //     bytes32 result = keccak256(abi.encode(
    //         typeHash,
    //         tokenPermissionsHash,
    //         _myAddress(),
    //         permit.nonce,
    //         permit.deadline,
    //         witness
    //     ));
    //     console.logString("result");
    //     console.logBytes32(result);
    //     return result;  
    // }
    

    function _tokenId() internal pure override returns (uint256) {
        return 2;
    }

    function _hasMetaTxn() internal pure override returns (bool) {
        return false;
    }

    function _domainSeparator() internal view virtual returns (bytes32);

    // function _myAddress() internal view virtual returns (address);

    function _dispatch(uint256 index, uint256 action, bytes calldata data) internal virtual override(SettlerBase,SettlerAbstract) returns (bool) {
        if(super._dispatch(index, action, data)) {
            return true;
        }
        else if(action == uint32(ISettlerActions.ESCROW_PARAMS_CHECK.selector)) {
            // console.logString("------------ESCROW_PARAMS_CHECK--------------------");
            (ISettlerBase.EscrowParams memory escrowParams, bytes memory sig) = abi.decode(data, (ISettlerBase.EscrowParams, bytes));
            // makesure escrow params come from relayer signature.
            bytes32 escrowTypedHash = makesureEscrowParams(_getRelayer(), _domainSeparator(), escrowParams, sig);
            
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
            
            address payer = getPayer();
            _transferFrom(permit, transferDetails, payer, sig);
            clearPayer(payer);
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
            
            // // 使用辅助函数来处理 memory -> calldata 转换
            // bytes32 dataHash = _hashPermitWithWitness(permit, intentParamsHash);
            
            // // 调试：输出 Permit2 地址和 DOMAIN_SEPARATOR
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
        }
        else if (action == uint32(ISettlerActions.BULK_SELL_TRANSFER_FROM.selector)) {
            // take bulk sell intent
            (
                IAllowanceTransfer.AllowanceTransferDetails memory details,
                ISettlerBase.IntentParams memory intentParams,
                bytes memory sig
            ) = abi.decode(data, (IAllowanceTransfer.AllowanceTransferDetails, ISettlerBase.IntentParams, bytes));

            // 付款方
            address payer = getPayer();
            if(details.from != payer) revert InvalidPayer();
            // makesure intent params come from payer signature.
            bytes32 intentTypeHash = makesureIntentParams(payer, _domainSeparator(), intentParams, sig);
            // intent typed hash should be the same as the intent type hash in the intent params.
            if(intentTypeHash != getIntentTypeHash()) revert InvalidIntent();

            // 不验证花费者额度，因为transferFrom将自动验证额度及调用关系。
            _allowanceHolderTransferFrom(details.token, payer, details.to, details.amount);
            
            clearPayer(payer);
            clearIntentTypeHash();
        } 
        else{
            return false;
        }
        return true;
    }

    function _dispatchVIP(uint256 action, bytes calldata data) internal virtual returns (bool);

    function execute(address payer, bytes32 escrowTypedHash, bytes32 intentTypeHash, bytes[] calldata actions)
        public
        payable
        override
        takeIntent(payer, escrowTypedHash, intentTypeHash)
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
