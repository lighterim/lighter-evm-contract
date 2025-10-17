// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {ISignatureTransfer} from "@uniswap/permit2/interfaces/ISignatureTransfer.sol";
import {ISettlerMetaTxn} from "./interfaces/ISettlerMetaTxn.sol";

import {Permit2PaymentMetaTxn} from "./core/Permit2Payment.sol";

import {Context, AbstractContext} from "./Context.sol";
import {CalldataDecoder, SettlerBase} from "./SettlerBase.sol";
import {UnsafeMath} from "./utils/UnsafeMath.sol";

import {ISettlerActions} from "./ISettlerActions.sol";
import {revertActionInvalid} from "./core/SettlerErrors.sol";

abstract contract SettlerMetaTxn is ISettlerMetaTxn, Permit2PaymentMetaTxn, SettlerBase {
    using UnsafeMath for uint256;
    using CalldataDecoder for bytes[];

    function _tokenId() internal pure virtual override returns (uint256) {
        return 3;
    }

    function _hasMetaTxn() internal pure override returns (bool) {
        return true;
    }

    function _hashArrayOfBytes(bytes[] calldata actions) internal pure returns (bytes32 result) {
        // This function deliberately does no bounds checking on `actions` for
        // gas efficiency. We assume that `actions` will get used elsewhere in
        // this context and any OOB or other malformed calldata will result in a
        // revert later.
        assembly ("memory-safe") {
            let ptr := mload(0x40)
            let hashesLength := shl(0x05, actions.length)
            for {
                let i := actions.offset
                let dst := ptr
                let end := add(i, hashesLength)
            } lt(i, end) {
                i := add(0x20, i)
                dst := add(0x20, dst)
            } {
                let src := add(calldataload(i), actions.offset)
                let length := calldataload(src)
                calldatacopy(dst, add(0x20, src), length)
                mstore(dst, keccak256(dst, length))
            }
            result := keccak256(ptr, hashesLength)
        }
    }

    function _hashActionsAndSlippage(bytes[] calldata actions)
        internal
        pure
        returns (bytes32 result)
    {
        // This function does not check for or clean any dirty bits that might
        // exist in `slippage`. We assume that `slippage` will be used elsewhere
        // in this context and that if there are dirty bits it will result in a
        // revert later.
        bytes32 arrayOfBytesHash = _hashArrayOfBytes(actions);
        assembly ("memory-safe") {
            let ptr := mload(0x40)
            // mstore(ptr, SLIPPAGE_AND_ACTIONS_TYPEHASH)
            // calldatacopy(add(0x20, ptr), slippage, 0x60)
            mstore(add(0x80, ptr), arrayOfBytesHash)
            result := keccak256(ptr, 0xa0)
        }
    }

    function _dispatchVIP(uint256 action, bytes calldata data, bytes calldata sig) internal virtual returns (bool) {
        if (action == uint32(ISettlerActions.NATIVE_CHECK.selector)) {
            (address recipient, ISignatureTransfer.PermitTransferFrom memory permit) =
                abi.decode(data, (address, ISignatureTransfer.PermitTransferFrom));
            // (ISignatureTransfer.SignatureTransferDetails memory transferDetails,) =
                // _permitToTransferDetails(permit, recipient);

            // We simultaneously transfer-in the taker's tokens and authenticate the
            // metatransaction.
            // _transferFrom(permit, transferDetails, sig);
        } else {
            return false;
        }
        return true;
    }

    function _executeMetaTxn(/*AllowedSlippage calldata slippage,*/ bytes[] calldata actions, bytes calldata sig)
        internal
        returns (bool)
    {
        require(actions.length != 0);
        {
            (uint256 action, bytes calldata data) = actions.decodeCall(0);

            // By forcing the first action to be one of the witness-aware
            // actions, we ensure that the entire sequence of actions is
            // authorized. `msgSender` is the signer of the metatransaction.
            if (!_dispatchVIP(action, data, sig)) {
                revertActionInvalid(0, action, data);
            }
        }

        for (uint256 i = 1; i < actions.length; i = i.unsafeInc()) {
            (uint256 action, bytes calldata data) = actions.decodeCall(i);
            if (!_dispatch(i, action, data)) {
                revertActionInvalid(i, action, data);
            }
        }

        // _checkSlippageAndTransfer(slippage);
        return true;
    }

    function executeMetaTxn(
        bytes[] calldata actions,
        bytes32 /* zid & affiliate */,
        address msgSender,
        bytes calldata sig
    ) public virtual override metaTx(msgSender, _hashActionsAndSlippage(actions)) returns (bool) {
        return _executeMetaTxn(actions, sig);
    }

    // Solidity inheritance is stupid
    function _msgSender() internal view virtual override(Permit2PaymentMetaTxn) returns (address) {
        return super._msgSender();
    }
}
