// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {ISettlerBase} from "../interfaces/ISettlerBase.sol";

/// @notice Thrown when an offset is not the expected value
error InvalidOffset();

/// @notice Thrown when a validating a target contract to avoid certain types of targets
error ConfusedDeputy();

function revertConfusedDeputy() pure {
    assembly ("memory-safe") {
        mstore(0x00, 0xe758b8d5) // selector for `ConfusedDeputy()`
        revert(0x1c, 0x04)
    }
}

// error RelayerNotAuthorized();

// function revertRelayerNotAuthorized() pure {
//     assembly ("memory-safe") {
//         mstore(0x00, 0x1c500e5c) // selector for `RelayerNotAuthorized()`
//         revert(0x1c, 0x04)
//     }
// }

error TokenNotWhitelisted(address token);
error UnauthorizedCreator(address creator);
error UnauthorizedExecutor(address executor);
error UnauthorizedVerifier(address verifier);
error UnauthorizedCaller(address caller);

error InsufficientPayment(uint256 required, uint256 provided);
error InvalidCount();
error InvalidRecipient();

error InvalidWitness();
error InvalidTokenPermissions();
error InvalidIntent();

/// @notice Thrown when validating the caller against the expected caller
error InvalidSender();

error InvalidPayer();

error InvalidZkProof();

error AccountAlreadyCreated();

error InvalidArbitratorTicket();

error InvalidArbitratorSignature();

error InvalidCounterpartySignature();

error HasPendingTx(address account);

error NoPendingTx(address account);

error InvalidRentPrice();

error InsufficientQuota(address account);

error EscrowAlreadyExists(bytes32 escrowHash);

error EscrowNotExists(bytes32 escrowHash);

error InvalidEscrowStatus(bytes32 escrowHash, ISettlerBase.EscrowStatus actual);

error InvalidEscrowSignature();

error InvalidIntentSignature();

error InvalidPayment();

error InvalidPaymentId();

error InvalidPrice();

error InvalidAccountAddress();

error IntentExpired(uint256 expiryTime);

error InvalidPaymentMethod();

error CancelWithinWindow(uint256 canCancelTs);

error SellerCancelWithinWindow(uint256 canCancelTs);

error InvalidActionsLength();
/// @notice Thrown when a byte array that is supposed to encode a function from ISettlerActions is
///         not recognized in context.
error ActionInvalid(uint256 i, bytes4 action, bytes data);

function revertActionInvalid(uint256 i, uint256 action, bytes calldata data) pure {
    assembly ("memory-safe") {
        let ptr := mload(0x40)
        mstore(ptr, 0x3c74eed6) // selector for `ActionInvalid(uint256,bytes4,bytes)`
        mstore(add(0x20, ptr), i)
        mstore(add(0x40, ptr), shl(0xe0, action)) // align as `bytes4`
        mstore(add(0x60, ptr), 0x60) // offset to the length slot of the dynamic value `data`
        mstore(add(0x80, ptr), data.length)
        calldatacopy(add(0xa0, ptr), data.offset, data.length)
        revert(add(0x1c, ptr), add(0x84, data.length))
    }
}

/// @notice Thrown when the encoded fork ID as part of UniswapV3 fork path is not on the list of
///         recognized forks for this chain.
error UnknownForkId(uint8 forkId);

function revertUnknownForkId(uint8 forkId) pure {
    assembly ("memory-safe") {
        mstore(0x00, 0xd3b1276d) // selector for `UnknownForkId(uint8)`
        mstore(0x20, and(0xff, forkId))
        revert(0x1c, 0x24)
    }
}

/// @notice Thrown when a metatransaction has reentrancy.
error ReentrantMetatransaction(bytes32 oldWitness);

/// @notice Thrown when any transaction has reentrancy, not just taker-submitted or metatransaction.
error ReentrantPayer(address oldPayer);


/// @notice An internal error that should never be thrown. Thrown when the payer is unset
///         unexpectedly.
error PayerSpent();

error ZeroAddress();
error InvalidToken();
error InvalidTokenId();
error InvalidAmount();
error InsufficientBalance(uint256 amount);
