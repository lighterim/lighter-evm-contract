
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {ISignatureTransfer} from "@uniswap/permit2/interfaces/ISignatureTransfer.sol";
import {IAllowanceTransfer} from "@uniswap/permit2/interfaces/IAllowanceTransfer.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {ISettlerTakeIntent} from "./interfaces/ISettlerTakeIntent.sol";
import {Permit2PaymentTakeIntent} from "./core/Permit2Payment.sol";
import {Permit2PaymentAbstract} from "./core/Permit2PaymentAbstract.sol";

import {CalldataDecoder, SettlerBase} from "./SettlerBase.sol";
import {UnsafeMath} from "./utils/UnsafeMath.sol";

import {ISettlerActions} from "./ISettlerActions.sol";
import {ISettlerBase} from "./interfaces/ISettlerBase.sol";
import {ParamsHash} from "./utils/ParamsHash.sol";
import {
    revertActionInvalid, SignatureExpired, MsgValueMismatch, InvalidWitness, InvalidToken, InvalidAmount, 
    InvalidPayment, InvalidPrice, InvalidPayer
    } from "./core/SettlerErrors.sol";
import {SettlerAbstract} from "./SettlerAbstract.sol";


abstract contract Settler is ISettlerTakeIntent, Permit2PaymentTakeIntent, SettlerBase {

    using UnsafeMath for uint256;
    using CalldataDecoder for bytes[];
    using ParamsHash for ISettlerBase.IntentParams;
    using ParamsHash for ISettlerBase.EscrowParams;
    

    function _tokenId() internal pure override returns (uint256) {
        return 2;
    }

    function _hasMetaTxn() internal pure override returns (bool) {
        return false;
    }

    function _domainSeparator() internal view virtual returns (bytes32);

    function _dispatch(uint256 index, uint256 action, bytes calldata data) internal virtual override(SettlerBase,SettlerAbstract) returns (bool) {
        if(super._dispatch(index, action, data)) {
            return true;
        }
        else if(action == uint32(ISettlerActions.ESCROW_PARAMS_CHECK.selector)) {
            (ISettlerBase.EscrowParams memory escrowParams, bytes memory sig) = abi.decode(data, (ISettlerBase.EscrowParams, bytes));
            bytes32 escrowTypedHash = makesureEscrowParams(_getRelayer(), _domainSeparator(), escrowParams, sig);
            if (escrowTypedHash != getWitness()) {
                revert InvalidWitness();
            }
        }
        else if(action == uint32(ISettlerActions.SIGNATURE_TRANSFER_FROM.selector)) {
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
            (
                ISignatureTransfer.PermitTransferFrom memory permit, 
                ISignatureTransfer.SignatureTransferDetails memory transferDetails, 
                ISettlerBase.IntentParams memory intentParams,
                bytes memory sig
            ) = abi.decode(data, (ISignatureTransfer.PermitTransferFrom, ISignatureTransfer.SignatureTransferDetails, ISettlerBase.IntentParams, bytes));
            bytes32 intentParamsHash = intentParams.hash(); 
            address payer = getPayer();
            _transferFromIKnowWhatImDoing(permit, transferDetails, payer,intentParamsHash, ParamsHash._INTENT_WITNESS_TYPE_STRING, sig);
            clearPayer(payer);
        }
        else if (action == uint32(ISettlerActions.BULK_SELL_TRANSFER_FROM.selector)) {
            (
                IAllowanceTransfer.AllowanceTransferDetails memory details
            ) = abi.decode(data, (IAllowanceTransfer.AllowanceTransferDetails));
            address payer = getPayer();
            if(details.from != payer) revert InvalidPayer();
            _allowanceHolderTransferFrom(details.token, payer, details.to, details.amount);
            clearPayer(payer);
        } 
        else{
            return false;
        }
        return true;
    }

    function _dispatchVIP(uint256 action, bytes calldata data) internal virtual returns (bool);

    function execute(address payer, bytes32 escrowTypedHash, bytes[] calldata actions)
        public
        payable
        override
        takeIntent(payer, escrowTypedHash)
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
