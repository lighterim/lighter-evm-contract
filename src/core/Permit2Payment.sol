// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Permit2PaymentAbstract} from "./Permit2PaymentAbstract.sol";
import {revertConfusedDeputy} from "./SettlerErrors.sol";
import {SettlerAbstract} from "../SettlerAbstract.sol";
import {IAllowanceHolder} from "../allowanceholder/IAllowanceHolder.sol";
import {AllowanceHolder} from "../allowanceholder/AllowanceHolder.sol";
import {FullMath} from "../vendor/FullMath.sol";
import {SafeTransferLib} from "../vendor/SafeTransferLib.sol";
import {Panic} from "../utils/Panic.sol";
import {ParamsHash} from "../utils/ParamsHash.sol";
import {SettlerBase} from "../SettlerBase.sol";
import {Context} from "../Context.sol";
import {IEscrow} from "../interfaces/IEscrow.sol";
import {LighterAccount} from "../account/LighterAccount.sol";

import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {IAllowanceTransfer} from "@uniswap/permit2/interfaces/IAllowanceTransfer.sol";
import {ISignatureTransfer} from "@uniswap/permit2/interfaces/ISignatureTransfer.sol";
import {IPermit2} from "@uniswap/permit2/interfaces/IPermit2.sol";



abstract contract Permit2PaymentTakeIntent is SettlerBase, Permit2PaymentAbstract {
    /// @dev Permit2 address
    IPermit2 internal constant _PERMIT2 = IPermit2(0x000000000022D473030F116dDEE9F6B43aC78BA3);
    
    IAllowanceHolder internal immutable allowanceHolder;

    constructor(IAllowanceHolder allowanceHolder_) {
        allowanceHolder = allowanceHolder_;
    }

    function _permit(address owner, IAllowanceTransfer.PermitSingle memory permitSingle, bytes memory signature) internal virtual override(Permit2PaymentAbstract) {
        _PERMIT2.permit(owner, permitSingle, signature);
    }
    
    /**
     * TODO: 是否支持转发？ 应该支持转发。
     */
    function _transferFromIKnowWhatImDoing(
        ISignatureTransfer.PermitTransferFrom memory permit,
        ISignatureTransfer.SignatureTransferDetails memory transferDetails,
        address from,
        bytes32 witness,
        string memory witnessTypeString,
        bytes memory sig
    ) internal virtual override(Permit2PaymentAbstract) {
        // This is effectively
        /*
        _PERMIT2.permitWitnessTransferFrom(permit, transferDetails, from, witness, witnessTypeString, sig);
        */
        // but it's written in assembly for contract size reasons. This produces a non-strict ABI
        // encoding (https://docs.soliditylang.org/en/v0.8.25/abi-spec.html#strict-encoding-mode),
        // but it's fine because Solidity's ABI *decoder* will handle anything that is validly
        // encoded, strict or not.

        // Solidity won't let us reference the constant `_PERMIT2` in assembly, but this compiles
        // down to just a single PUSH opcode just before the CALL, with optimization turned on.
        ISignatureTransfer __PERMIT2 = _PERMIT2;
        assembly ("memory-safe") {
            let ptr := mload(0x40)
            mstore(ptr, 0x137c29fe) // selector for `permitWitnessTransferFrom(((address,uint256),uint256,uint256),(address,uint256),address,bytes32,string,bytes)`

            // The layout of nested structs in memory is different from that in calldata. We have to
            // chase the pointer to `permit.permitted`.
            mcopy(add(0x20, ptr), mload(permit), 0x40)
            // The rest of the members of `permit` are laid out linearly,
            mcopy(add(0x60, ptr), add(0x20, permit), 0x40)
            // as are the members of `transferDetails.
            mcopy(add(0xa0, ptr), transferDetails, 0x40)
            // Because we're passing `from` on the stack, it must be cleaned.
            mstore(add(0xe0, ptr), and(0xffffffffffffffffffffffffffffffffffffffff, from))
            mstore(add(0x100, ptr), witness)
            mstore(add(0x120, ptr), 0x140) // Offset to `witnessTypeString` (the end of of the non-dynamic types)
            let witnessTypeStringLength := mload(witnessTypeString)
            mstore(add(0x140, ptr), add(0x160, witnessTypeStringLength)) // Offset to `sig` (past the end of `witnessTypeString`)

            // Now we encode the 2 dynamic objects, `witnessTypeString` and `sig`.
            mcopy(add(0x160, ptr), witnessTypeString, add(0x20, witnessTypeStringLength))
            let sigLength := mload(sig)
            mcopy(add(0x180, add(ptr, witnessTypeStringLength)), sig, add(0x20, sigLength))

            // We don't need to check that Permit2 has code, and it always signals failure by
            // reverting.
            if iszero(
                call(
                    gas(),
                    __PERMIT2,
                    0x00,
                    add(0x1c, ptr),
                    add(0x184, add(witnessTypeStringLength, sigLength)),
                    0x00,
                    0x00
                )
            ) {
                let ptr_ := mload(0x40)
                returndatacopy(ptr_, 0x00, returndatasize())
                revert(ptr_, returndatasize())
            }
        }
    }

    function _transferFrom(
        ISignatureTransfer.PermitTransferFrom memory permit,
        ISignatureTransfer.SignatureTransferDetails memory transferDetails,
        address owner,
        bytes memory sig
    ) internal virtual override(Permit2PaymentAbstract) {
        // This is effectively
        /*
        _PERMIT2.permitTransferFrom(permit, transferDetails, _msgSender(), sig);
        */
        // but it's written in assembly for contract size reasons. This produces a non-strict
        // ABI encoding
        // (https://docs.soliditylang.org/en/v0.8.25/abi-spec.html#strict-encoding-mode), but
        // it's fine because Solidity's ABI *decoder* will handle anything that is validly
        // encoded, strict or not.

        // Solidity won't let us reference the constant `_PERMIT2` in assembly, but this
        // compiles down to just a single PUSH opcode just before the CALL, with optimization
        // turned on.
        ISignatureTransfer __PERMIT2 = _PERMIT2;
        address from = owner;
        assembly ("memory-safe") {
            let ptr := mload(0x40)
            mstore(ptr, 0x30f28b7a) // selector for `permitTransferFrom(((address,uint256),uint256,uint256),(address,uint256),address,bytes)`

            // The layout of nested structs in memory is different from that in calldata. We
            // have to chase the pointer to `permit.permitted`.
            mcopy(add(0x20, ptr), mload(permit), 0x40)
            // The rest of the members of `permit` are laid out linearly,
            mcopy(add(0x60, ptr), add(0x20, permit), 0x40)
            // as are the members of `transferDetails.
            mcopy(add(0xa0, ptr), transferDetails, 0x40)
            // Because we're passing `from` on the stack, it must be cleaned.
            mstore(add(0xe0, ptr), and(0xffffffffffffffffffffffffffffffffffffffff, from))
            mstore(add(0x100, ptr), 0x100) // Offset to `sig` (the end of the non-dynamic types)

            // Encode the dynamic object `sig`
            let sigLength := mload(sig)
            mcopy(add(0x120, ptr), sig, add(0x20, sigLength))

            // We don't need to check that Permit2 has code, and it always signals failure by
            // reverting.
            if iszero(call(gas(), __PERMIT2, 0x00, add(0x1c, ptr), add(0x124, sigLength), 0x00, 0x00)) {
                let ptr_ := mload(0x40)
                returndatacopy(ptr_, 0x00, returndatasize())
                revert(ptr_, returndatasize())
            }
        }
    }

    function _allowanceHolderTransferFrom(address token, address owner, address recipient, uint160 amount) internal virtual override(Permit2PaymentAbstract) {
        allowanceHolder.transferFrom(token, owner, recipient, amount);
    }

    modifier takeIntent(address payer, bytes32 tokenPermissions, bytes32 witness, bytes32 intentTypeHash) override {
        _setTakeIntent(payer, tokenPermissions, witness, intentTypeHash);
        _;
        _checkTakeIntent();
    }
}