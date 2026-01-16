// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;


import {
    revertConfusedDeputy,
    InvalidWitness, InvalidIntent, InvalidTokenPermissions
} from "../core/SettlerErrors.sol";

library TransientStorage {
    // bytes32((uint256(keccak256("witness slot")) - 1) & type(uint96).max)
    bytes32 private constant _WITNESS_SLOT = 0x0000000000000000000000000000000000000000c7aebfbc05485e093720deaa;
    // bytes32((uint256(keccak256("intentTypeHash slot")) - 1) & type(uint96).max)
    bytes32 private constant _INTENT_TYPE_HASH_SLOT = 0x0000000000000000000000000000000000000000fd2291a0d36415a67d469179;
    // bytes32((uint256(keccak256("tokenPermissions slot")) - 1) & type(uint96).max)
    bytes32 private constant _TOKEN_PERMISSIONS_SLOT = 0x0000000000000000000000000000000000000000d21f836d66efe83f61e75834;
    // bytes32((uint256(keccak256("payer slot")) - 1) & type(uint96).max)
    bytes32 private constant _PAYER_SLOT = 0x0000000000000000000000000000000000000000cd1e9517bb0cb8d0d5cde893;

    // We assume (and our CI enforces) that internal function pointers cannot be
    // greater than 2 bytes. On chains not supporting the ViaIR pipeline, not
    // supporting EOF, and where the Spurious Dragon size limit is not enforced,
    // it might be possible to violate this assumption. However, our
    // `foundry.toml` enforces the use of the IR pipeline, so the point is moot.
    
    /// @notice Sets payer and witness in transient storage for reentrancy protection
    /// @dev This function ensures each slot can only be set once per transaction,
    ///      and that the slots are not already spent.
    /// @param payer The address of the payer (must not be zero)
    /// @param tokenPermissions Hash of token permissions (must not be zero)
    /// @param witness The witness hash for escrow validation
    /// @param intentTypeHash Hash of the intent type
    function setPayerAndWitness(
        address payer,
        bytes32 tokenPermissions,
        bytes32 witness,
        bytes32 intentTypeHash
    ) internal {
        _makesureFirstTimeSetPayer(payer);

        if (witness == bytes32(0)) revert InvalidWitness();
        if (intentTypeHash == bytes32(0)) revert InvalidIntent();
        if (tokenPermissions == bytes32(0)) revert InvalidTokenPermissions();

        _makesureFirstTimeSet(_TOKEN_PERMISSIONS_SLOT, tokenPermissions);
        _makesureFirstTimeSet(_WITNESS_SLOT, witness);
        _makesureFirstTimeSet(_INTENT_TYPE_HASH_SLOT, intentTypeHash);
    }

    function _makesureFirstTimeSetPayer(address payer) private {
        assembly ("memory-safe") {
            if iszero(shl(0x60, payer)) {
                mstore(0x00, 0xe758b8d5) // selector for `ConfusedDeputy()`
                revert(0x1c, 0x04)
            }
            let slotValue := tload(_PAYER_SLOT)
            if shl(0x60, slotValue) {
                mstore(0x14, slotValue)
                mstore(0x00, 0x7407c0f8000000000000000000000000) // selector for `ReentrantPayer(address)` with `oldPayer`'s padding
                revert(0x10, 0x24)
            }

            tstore(_PAYER_SLOT, and(0xffffffffffffffffffffffffffffffffffffffff, payer))
        }
    }

    function _makesureFirstTimeSet(bytes32 slot, bytes32 newValue) private {
        assembly ("memory-safe") {
            let slotValue := tload(slot)
            if slotValue {
                // It should be impossible to reach this error because the first thing a
                // transaction does on entry is to spend the slot value
                mstore(0x00, 0x9936cbab) // selector for `ReentrantMetatransaction(bytes32)`
                mstore(0x20, slotValue)
                revert(0x1c, 0x24)
            }

            tstore(slot, newValue)
        }
    }

    function _checkSpentBytes32(bytes32 slot) private view {
        bytes32 currentValue;
        assembly ("memory-safe") {
            currentValue := tload(slot)
        }
        if (currentValue != bytes32(0)) {
            revertConfusedDeputy();
        }
    }

    function _checkSpentAddress(bytes32 slot) private view {
        address currentValue;
        assembly ("memory-safe") {
            currentValue := tload(slot)
        }
        if (currentValue != address(0)) {
            revertConfusedDeputy();
        }
    }

    function checkSpentPayerAndWitness() internal view {
        // _checkSpentAddress(_PAYER_SLOT);
        // _checkSpentBytes32(_TOKEN_PERMISSIONS_SLOT);
        // _checkSpentBytes32(_WITNESS_SLOT);
        // _checkSpentBytes32(_INTENT_TYPE_HASH_SLOT);
        assembly ("memory-safe") {
            if or(
                tload(_PAYER_SLOT),
                or(
                    tload(_TOKEN_PERMISSIONS_SLOT),
                    or(
                        tload(_WITNESS_SLOT),
                        tload(_INTENT_TYPE_HASH_SLOT)
                    )
                )
            ) {
                mstore(0x00, 0xe758b8d5) // ConfusedDeputy()
                revert(0x1c, 0x04)
            }
        }
    }

    function getWitness() internal view returns (bytes32 witness) {
        assembly ("memory-safe") {
            witness := tload(_WITNESS_SLOT)
        }
    }

    function getAndClearWitness() internal returns (bytes32 witness) {
        assembly ("memory-safe") {
            witness := tload(_WITNESS_SLOT)
            tstore(_WITNESS_SLOT, 0x00)
        }
    }

    function clearWitness() internal {
        assembly ("memory-safe") {
            tstore(_WITNESS_SLOT, 0x00)
        }
    }

    function getIntentTypeHash() internal view returns (bytes32 intentTypeHash) {
        assembly ("memory-safe") {
            intentTypeHash := tload(_INTENT_TYPE_HASH_SLOT)
        }
    }

    function clearIntentTypeHash() internal {
        assembly ("memory-safe") {
            tstore(_INTENT_TYPE_HASH_SLOT, 0x00)
        }
    }

    function getPayer() internal view returns (address payer) {
        assembly ("memory-safe") {
            payer := tload(_PAYER_SLOT)
        }
    }

    function getTokenPermissionsHash() internal view returns (bytes32 tokenPermissions) {
        assembly ("memory-safe") {
            tokenPermissions := tload(_TOKEN_PERMISSIONS_SLOT)
        }
    }

    function clearPayerAndTokenPermissionsHash(address expectedOldPayer) internal {
        _makesureOldPayer(expectedOldPayer);
        assembly ("memory-safe") {
            tstore(_PAYER_SLOT, 0x00)
            tstore(_TOKEN_PERMISSIONS_SLOT, 0x00)
        }
    }

    function cleanupButKeepWitness(address expectedOldPayer) internal {
        _makesureOldPayer(expectedOldPayer);
        assembly ("memory-safe") {
            tstore(_PAYER_SLOT, 0x00)
            tstore(_TOKEN_PERMISSIONS_SLOT, 0x00)
            tstore(_INTENT_TYPE_HASH_SLOT, 0x00)
        }
    }

    function _makesureOldPayer(address expectedOldPayer) private view {
        address oldPayer;
        assembly ("memory-safe") {
            oldPayer := tload(_PAYER_SLOT)
        }
        if (oldPayer != expectedOldPayer) {
            assembly ("memory-safe") {
                mstore(0x00, 0x8eb5b891) // selector for `InvalidPayer()`
                revert(0x1c, 0x04)
            }
        }
    }
}