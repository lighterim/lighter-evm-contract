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
import {Revert} from "../utils/Revert.sol";
import {ParamsHash} from "../utils/ParamsHash.sol";

import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {IAllowanceTransfer} from "@uniswap/permit2/interfaces/IAllowanceTransfer.sol";
import {ISignatureTransfer} from "@uniswap/permit2/interfaces/ISignatureTransfer.sol";
import {IPermit2} from "@uniswap/permit2/interfaces/IPermit2.sol";


library TransientStorage {
    
    // bytes32((uint256(keccak256("witness slot")) - 1) & type(uint96).max)
    bytes32 private constant _WITNESS_SLOT = 0x0000000000000000000000000000000000000000c7aebfbc05485e093720deaa;
    // bytes32((uint256(keccak256("payer slot")) - 1) & type(uint96).max)
    bytes32 private constant _PAYER_SLOT = 0x0000000000000000000000000000000000000000cd1e9517bb0cb8d0d5cde893;

    // We assume (and our CI enforces) that internal function pointers cannot be
    // greater than 2 bytes. On chains not supporting the ViaIR pipeline, not
    // supporting EOF, and where the Spurious Dragon size limit is not enforced,
    // it might be possible to violate this assumption. However, our
    // `foundry.toml` enforces the use of the IR pipeline, so the point is moot.
    
    // `payer` must not be `address(0)`. This is not checked.
    // `witness` must not be `bytes32(0)`. This is not checked.
    function setPayerAndWitness(
        address payer,
        bytes32 witness
    ) internal {
        address currentSigner;
        assembly ("memory-safe") {
            currentSigner := tload(_PAYER_SLOT)
        }
        if (currentSigner != address(0)) {
            revertConfusedDeputy();
        }

        bytes32 currentWitness;
        assembly ("memory-safe") {
            currentWitness := tload(_WITNESS_SLOT)
        }
        if (currentWitness != bytes32(0)) {
            // It should be impossible to reach this error because the first thing a metatransaction
            // does on entry is to spend the `witness` (either directly or via a callback)
            assembly ("memory-safe") {
                mstore(0x00, 0x9936cbab) // selector for `ReentrantMetatransaction(bytes32)`
                mstore(0x20, currentWitness)
                revert(0x1c, 0x24)
            }
        }

        assembly ("memory-safe") {
            tstore(_PAYER_SLOT, and(0xffffffffffffffffffffffffffffffffffffffff, payer))
            tstore(_WITNESS_SLOT, witness)
        }
    }

    function checkSpentPayerAndWitness() internal view {
        bytes32 currentWitness;
        assembly ("memory-safe") {
            currentWitness := tload(_WITNESS_SLOT)
        }
        if (currentWitness != bytes32(0)) {
            assembly ("memory-safe") {
                mstore(0x00, 0xe25527c2) // selector for `WitnessNotSpent(bytes32)`
                mstore(0x20, currentWitness)
                revert(0x1c, 0x24)
            }
        }

        address currentPayer;
        assembly ("memory-safe") {
            currentPayer := tload(_PAYER_SLOT)
        }
        if (currentPayer != address(0)) {
            assembly ("memory-safe") {
                mstore(0x00, 0x9684be17) // selector for `PayerNotSpent()`
                revert(0x1c, 0x04)
            }
        }
    }

    function getAndClearWitness() internal returns (bytes32 witness) {
        assembly ("memory-safe") {
            witness := tload(_WITNESS_SLOT)
            tstore(_WITNESS_SLOT, 0x00)
        }
    }

    function getWitness() internal view returns (bytes32 witness) {
        assembly ("memory-safe") {
            witness := tload(_WITNESS_SLOT)
        }
    }

    function getPayer() internal view returns (address payer) {
        assembly ("memory-safe") {
            payer := tload(_PAYER_SLOT)
        }
    }

    function clearPayer(address expectedOldPayer) internal {
        address oldPayer;
        assembly ("memory-safe") {
            oldPayer := tload(_PAYER_SLOT)
        }
        if (oldPayer != expectedOldPayer) {
            assembly ("memory-safe") {
                mstore(0x00, 0x5149e795) // selector for `PayerSpent()`
                revert(0x1c, 0x04)
            }
        }
        assembly ("memory-safe") {
            tstore(_PAYER_SLOT, 0x00)
        }
    }
}

abstract contract Permit2PaymentBase is  SettlerAbstract {

    using Revert for bool;

    /// @dev Permit2 address
    IPermit2 internal constant _PERMIT2 = IPermit2(0x000000000022D473030F116dDEE9F6B43aC78BA3);
    
    IAllowanceHolder internal immutable _ALLOWANCE_HOLDER;

    constructor(IAllowanceHolder allowanceHolder) {
        _ALLOWANCE_HOLDER = allowanceHolder;
    }

    // function _msgSender() internal view virtual override(AbstractContext, Context) returns (address) {
    //     return TransientStorage.getPayer();
    // }

    function getWitness() internal view returns (bytes32) {
        return TransientStorage.getWitness();
    }

    function getPayer() internal view returns (address) {
        return TransientStorage.getPayer();
    }

    function clearPayer(address expectedOldPayer) internal {
        TransientStorage.clearPayer(expectedOldPayer);
    }

    function getAndClearWitness() internal returns (bytes32) {
        return TransientStorage.getAndClearWitness();
    }

}

abstract contract Permit2Payment is Permit2PaymentBase {
    

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
        _ALLOWANCE_HOLDER.transferFrom(token, owner, recipient, amount);
    }
}

// DANGER: the order of the base contracts here is very significant for the use of `super` below
// (and in derived contracts). Do not change this order.
abstract contract Permit2PaymentTakeIntent is Permit2Payment {
    using FullMath for uint256;
    using SafeTransferLib for IERC20;

    constructor(IAllowanceHolder allowanceHolder) Permit2PaymentBase(allowanceHolder) {
    }

    modifier takeIntent(address payer, bytes32 witness) override {
        TransientStorage.setPayerAndWitness(payer, witness);
        _;
        TransientStorage.checkSpentPayerAndWitness();
    }

    modifier metaTx(address msgSender, bytes32 witness) override {
        revert();
        _;
    }
}

// DANGER: the order of the base contracts here is very significant for the use of `super` below
// (and in derived contracts). Do not change this order.
abstract contract Permit2PaymentMetaTxn is Permit2Payment {
    constructor(IAllowanceHolder allowanceHolder) Permit2PaymentBase(allowanceHolder) {
        
    }

    function _witnessTypeSuffix() internal pure virtual returns (string memory) {
        return ParamsHash._INTENT_WITNESS_TYPE_STRING;
    }

    function _transferFrom(
        ISignatureTransfer.PermitTransferFrom memory permit,
        ISignatureTransfer.SignatureTransferDetails memory transferDetails,
        address owner,
        bytes memory sig
    ) internal override {
        //TODO: check witness where from!!!!
        bytes32 witness = TransientStorage.getWitness();
        if (witness == bytes32(0)) {
            revertConfusedDeputy();
        }
        _transferFromIKnowWhatImDoing(
            permit, transferDetails, owner, witness, _witnessTypeSuffix(), sig
        );
    }

    function _allowanceHolderTransferFrom(address, address, address, uint160) internal pure override {
        revertConfusedDeputy();
    }

    modifier takeIntent(address payer, bytes32 witness) override {
        revert();
        _;
    }

    modifier metaTx(address msgSender, bytes32 witness) override {
        TransientStorage.setPayerAndWitness(msgSender, witness);
        _;
        
        // It should not be possible for this check to revert because the very first thing that a
        // metatransaction does is spend the witness.
        TransientStorage.checkSpentPayerAndWitness();
    }

}

abstract contract Permit2PaymentIntent is Permit2PaymentMetaTxn {
    
}

