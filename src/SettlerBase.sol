// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {IERC20} from "forge-std/interfaces/IERC20.sol";

import {SafeTransferLib} from "./vendor/SafeTransferLib.sol";
import {FullMath} from "./vendor/FullMath.sol";

import {ISettlerActions} from "./ISettlerActions.sol";
import {
    revertConfusedDeputy
} from "./core/SettlerErrors.sol";
import {ISettlerBase} from "./interfaces/ISettlerBase.sol";
import {SettlerAbstract} from "./SettlerAbstract.sol";

import {ISignatureTransfer} from "@uniswap/permit2/interfaces/ISignatureTransfer.sol";
import {IAllowanceTransfer} from "@uniswap/permit2/interfaces/IAllowanceTransfer.sol";

/// @dev This library's ABIDeocding is more lax than the Solidity ABIDecoder. This library omits index bounds/overflow
/// checking when accessing calldata arrays for gas efficiency. It also omits checks against `calldatasize()`. This
/// means that it is possible that `args` will run off the end of calldata and be implicitly padded with zeroes. That we
/// don't check for overflow means that offsets can be negative. This can also result in `args` that alias other parts
/// of calldata, or even the `actions` array itself.
library CalldataDecoder {
    function decodeCall(bytes[] calldata data, uint256 i)
        internal
        pure
        returns (uint256 selector, bytes calldata args)
    {
        assembly ("memory-safe") {
            // initially, we set `args.offset` to the pointer to the length. this is 32 bytes before the actual start of data
            args.offset :=
                add(
                    data.offset,
                    // We allow the indirection/offset to `calls[i]` to be negative
                    calldataload(
                        add(shl(0x05, i), data.offset) // can't overflow; we assume `i` is in-bounds
                    )
                )
            // now we load `args.length` and set `args.offset` to the start of data
            args.length := calldataload(args.offset)
            args.offset := add(0x20, args.offset)

            // slice off the first 4 bytes of `args` as the selector
            selector := shr(0xe0, calldataload(args.offset))
            args.length := sub(args.length, 0x04)
            args.offset := add(0x04, args.offset)
        }
    }
}


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
    
    // `payer` must not be `address(0)`. This is not checked.
    // `witness` must not be `bytes32(0)`. This is not checked.
    function setPayerAndWitness(
        address payer,
        bytes32 tokenPermissions,
        bytes32 witness,
        bytes32 intentTypeHash
    ) internal {
        _makesureFirstTimeSet(_PAYER_SLOT);
        _makesureFirstTimeSet(_TOKEN_PERMISSIONS_SLOT);
        _makesureFirstTimeSet(_WITNESS_SLOT);
        _makesureFirstTimeSet(_INTENT_TYPE_HASH_SLOT);
       
        assembly ("memory-safe") {
            tstore(_PAYER_SLOT, payer)
            tstore(_TOKEN_PERMISSIONS_SLOT, tokenPermissions)
            tstore(_WITNESS_SLOT, witness)
            tstore(_INTENT_TYPE_HASH_SLOT, intentTypeHash)
        }
    }

    function _makesureFirstTimeSetPayer(bytes32 slot) private view {
        address currentPayer;
        assembly ("memory-safe") {
            currentPayer := tload(slot)
        }
        if (currentPayer != address(0)) {
            revertConfusedDeputy();
        }
    }

    function _makesureFirstTimeSet(bytes32 slot) private view {
        bytes32 currentValue;
        assembly ("memory-safe") {
            currentValue := tload(slot)
        }
        if (currentValue != bytes32(0)) {
            revertConfusedDeputy();
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
        _checkSpentAddress(_PAYER_SLOT);
        _checkSpentBytes32(_TOKEN_PERMISSIONS_SLOT);
        _checkSpentBytes32(_WITNESS_SLOT);
        _checkSpentBytes32(_INTENT_TYPE_HASH_SLOT);
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

    function clearTokenPermissionsHash() internal {
        assembly ("memory-safe") {
            tstore(_TOKEN_PERMISSIONS_SLOT, 0x00)
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

abstract contract SettlerBase is ISettlerBase, SettlerAbstract {
    using SafeTransferLib for IERC20;
    using SafeTransferLib for address payable;
    using FullMath for uint256;

    uint256 constant FEE_RATE_BASE = 10000;

    receive() external payable {}

    event GitCommit(bytes20 indexed);

    // When/if you change this, you must make corresponding changes to
    // `sh/deploy_new_chain.sh` and 'sh/common_deploy_settler.sh' to set
    // `constructor_args`.
    constructor(bytes20 gitCommit) {
        if (block.chainid != 31337) {
            emit GitCommit(gitCommit);
            // assert(IERC721Owner(DEPLOYER).ownerOf(_tokenId()) == address(this));
        } else {
            assert(gitCommit == bytes20(0));
        }
    }

    // function _msgSender() internal view virtual override(AbstractContext, Context) returns (address) {
    //     // return TransientStorage.getPayer();
    // }

    function _setTakeIntent(address payer, bytes32 tokenPermissions, bytes32 witness, bytes32 intentTypeHash) internal {
        TransientStorage.setPayerAndWitness(payer, tokenPermissions, witness, intentTypeHash);
    }

    function _checkTakeIntent() internal view {
        TransientStorage.checkSpentPayerAndWitness();
    }

    function getWitness() internal view returns (bytes32) {
        return TransientStorage.getWitness();
    }

    function getIntentTypeHash() internal view returns (bytes32) {
        return TransientStorage.getIntentTypeHash();
    }

    function getPayer() internal view returns (address) {
        return TransientStorage.getPayer();
    }

    function getTokenPermissionsHash() internal view returns (bytes32) {
        return TransientStorage.getTokenPermissionsHash();
    }

    function clearPayer(address expectedOldPayer) internal {
        TransientStorage.clearPayer(expectedOldPayer);
    }

    function clearTokenPermissionsHash() internal {
        TransientStorage.clearTokenPermissionsHash();
    }

    function getAndClearWitness() internal returns (bytes32) {
        return TransientStorage.getAndClearWitness();
    }

    function clearWitness() internal {
        TransientStorage.clearWitness();
    }

    function clearIntentTypeHash() internal {
        TransientStorage.clearIntentTypeHash();
    }

    /**
     * @notice Get the amount with fee for a given amount and fee rate
     * @param amount The amount to get the amount with fee for
     * @param feeRate The fee rate to get the amount with fee for (e.g. 1000 for 10%)
     * @return The amount with fee
     */
    function getAmountWithFee(uint256 amount, uint256 feeRate) public pure returns (uint256) {
        return amount.mulDivUp(FEE_RATE_BASE + feeRate, FEE_RATE_BASE);
    }

    /**
     * @notice Get the fee amount for a given amount and fee rate
     * @param amount The amount to get the fee for
     * @param feeRate The fee rate to get the fee for (e.g. 1000 for 10%)
     * @return The fee amount
     */
    function getFeeAmount(uint256 amount, uint256 feeRate) public pure returns (uint256) {
        return amount.mulDivUp(feeRate, FEE_RATE_BASE);
    }

    function _dispatchVIP(uint256 action, bytes calldata data) internal virtual returns (bool);

}
