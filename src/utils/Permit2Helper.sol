// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {ISignatureTransfer} from "@uniswap/permit2/interfaces/ISignatureTransfer.sol";
import {IPermit2} from "@uniswap/permit2/interfaces/IPermit2.sol";
import {PermitHash} from "@uniswap/permit2/libraries/PermitHash.sol";

import {ISettlerBase} from "../interfaces/ISettlerBase.sol";
import {ParamsHash} from "./ParamsHash.sol";


contract Permit2Helper {

    using ParamsHash for ISettlerBase.IntentParams;

    address immutable TAKE_INTENT;
    IPermit2 constant PERMIT2 = IPermit2(0x000000000022D473030F116dDEE9F6B43aC78BA3);

    constructor(address takeIntent_) {
        TAKE_INTENT = takeIntent_;
    }

    function getPermitTransferFromHash(
        ISignatureTransfer.PermitTransferFrom calldata permit
    ) public view returns (bytes32) {
        bytes32 typedHash = getTransferFromTypedHash(permit);
        return _permit2HashTypedData(typedHash);
    }

    function getPermitWitnessTransferFromHash(
        ISettlerBase.IntentParams calldata intentParams,
        ISignatureTransfer.PermitTransferFrom calldata permit
    ) public view returns (bytes32) {
        bytes32 intentParamsHash = intentParams.hash();
        bytes32 typedHash = hashWithWitness(permit, intentParamsHash, ParamsHash._INTENT_WITNESS_TYPE_STRING);
        return _permit2HashTypedData(typedHash);
    }


    /// @notice Creates an EIP-712 typed data hash
    function _permit2HashTypedData(bytes32 dataHash) internal view returns (bytes32) {
        return keccak256(
            abi.encodePacked(
                "\x19\x01",
                PERMIT2.DOMAIN_SEPARATOR(), 
                dataHash
            )
        );
    }

    function hashWithWitness(
        ISignatureTransfer.PermitTransferFrom memory permit,
        bytes32 witness,
        string memory witnessTypeString
    ) internal view returns (bytes32) {
        bytes32 typeHash = keccak256(abi.encodePacked(PermitHash._PERMIT_TRANSFER_FROM_WITNESS_TYPEHASH_STUB, witnessTypeString));

        bytes32 tokenPermissionsHash = _hashTokenPermissions(permit.permitted);
        return keccak256(abi.encode(typeHash, tokenPermissionsHash, TAKE_INTENT, permit.nonce, permit.deadline, witness));
    }

    function getTransferFromTypedHash(ISignatureTransfer.PermitTransferFrom memory permit) internal view returns (bytes32) {
        bytes32 tokenPermissionsHash = _hashTokenPermissions(permit.permitted);
        return keccak256(
            abi.encode(
                PermitHash._PERMIT_TRANSFER_FROM_TYPEHASH, 
                tokenPermissionsHash, 
                TAKE_INTENT, 
                permit.nonce, 
                permit.deadline
            )
        );
    }

    function _hashTokenPermissions(ISignatureTransfer.TokenPermissions memory permitted)
        private
        pure
        returns (bytes32)
    {
        return keccak256(abi.encode(PermitHash._TOKEN_PERMISSIONS_TYPEHASH, permitted));
    }
}