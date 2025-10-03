// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {IERC20} from "forge-std/interfaces/IERC20.sol";

import {SafeTransferLib} from "./vendor/SafeTransferLib.sol";
import {uint512} from "./utils/512Math.sol";

import {ISettlerActions} from "./ISettlerActions.sol";
import {ISettlerBase} from "./interfaces/ISettlerBase.sol";

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

// abstract contract SettlerBase is ISettlerBase, Basic, RfqOrderSettlement, UniswapV3Fork, UniswapV2, Velodrome {
abstract contract SettlerBase is ISettlerBase {
    using SafeTransferLib for IERC20;
    using SafeTransferLib for address payable;

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

    function _div512to256(uint512 n, uint512 d) internal view virtual override returns (uint256) {
        return n.div(d);
    }


    function _dispatch(uint256, uint256 action, bytes calldata data) internal virtual override returns (bool) {
        //// NOTICE: This function has been largely copy/paste'd into
        //// `src/chains/Mainnet/Common.sol:MainnetMixin._dispatch`. If you make changes here, you
        //// need to make sure that corresponding changes are made to that function.

        if (action == uint32(ISettlerActions.BULK_SELL_PREMIT)) {
            // ISignatureTransfer.PermitTransferFrom memory permit;
            // (address recipient, permit) = CalldataDecoder.decodeCall(data, 0);
            // ISettlerActions(msg.sender).TRANSFER_FROM(recipient, permit, data[4:]);
            (
                IAllowanceTransfer.PermitSingle memory permitSingle, 
                ISettlerBase.IntentParams memory intentParams,
                bytes memory permitSig,
                bytes memory intentSig
            ) = abi.decode(data, (IAllowanceTransfer.PermitSingle, ISettlerBase.IntentParams, bytes, bytes));
            _bulkSellPermit(permitSingle, intentParams, permitSig, intentSig);
        } else if (action == uint32(ISettlerActions.BULK_SELL_INTENT)) {
            (
                ISettlerBase.IntentParams memory intentParams, 
                bytes memory intentSig
            ) = abi.decode(data, (ISettlerBase.IntentParams, bytes));

            _validateBulkSellIntent(intentParams, intentSig);
        } else if (action == uint32(ISettlerActions.TAKE_SELLER_INTENT)) {
            // ISignatureTransfer.PermitTransferFrom memory permit;
            // (address recipient, permit) = CalldataDecoder.decodeCall(data, 0);
            // ISettlerActions(msg.sender).METATXN_TRANSFER_FROM(recipient, permit);
            (
                ISettlerBase.EscrowParams memory escrowParams,
                bytes memory sig
            ) = abi.decode(data, (ISettlerBase.EscrowParams, bytes));
            _makeEscrowByBuyer(escrowParams, sig);

        } else if (action == uint32(ISettlerActions.TAKE_BUYER_INTENT0)) {
            (
                ISettlerBase.IntentParams memory intentParams,
                bytes memory sig
            ) = abi.decode(data, (ISettlerBase.IntentParams, bytes));
            _validatorBuyerIntent(intentParams, sig);
        } else if (action == uint32(ISettlerActions.TAKE_BUYER_INTENT1)) {
            (
                ISettlerBase.EscrowParams memory escrowParams,
                bytes memory sig
            ) = abi.decode(data, (ISettlerBase.EscrowParams, bytes));
            _makeEscrowBySerller(escrowParams, sig);
        } else if (action == uint32(ISettlerActions.SIGNATURE_TRANSFER_FROM_WITH_WITNESS)) {
            (
                address owner,
                address recipient,
                ISignatureTransfer.PermitTransferFrom memory permit,
                ISettlerBase.IntentParams memory witness,
                bytes memory sig
            ) = abi.decode(data, (address, address, ISignatureTransfer.PermitTransferFrom, ISettlerBase.IntentParams, bytes));

            _signatureTransferFromWithWitness(owner, recipient, permit, witness, sig);

        } else {
            revert("Unknown action");
        }
        return true;
    }

    // Virtual functions to be implemented by subclasses
    function _bulkSellPermit(
        IAllowanceTransfer.PermitSingle memory permitSingle, 
        ISettlerBase.IntentParams memory intentParams,
        bytes memory permitSig,
        bytes memory intentSig
    ) internal virtual;

    function _validateBulkSellIntent(
        ISettlerBase.IntentParams memory intentParams, 
        bytes memory intentSig
    ) internal virtual;

    function _makeEscrowByBuyer(
        ISettlerBase.EscrowParams memory escrowParams,
        bytes memory sig
    ) internal virtual;

    function _validatorBuyerIntent(
        ISettlerBase.IntentParams memory intentParams,
        bytes memory sig
    ) internal virtual;

    function _makeEscrowBySerller(
        ISettlerBase.EscrowParams memory escrowParams,
        bytes memory sig
    ) internal virtual;

    function _signatureTransferFromWithWitness(
        address owner,
        address recipient,
        ISignatureTransfer.PermitTransferFrom memory permit,
        ISettlerBase.IntentParams memory witness,
        bytes memory sig
    ) internal virtual;
}
