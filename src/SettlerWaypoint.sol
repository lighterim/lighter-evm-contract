// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {ISignatureTransfer} from "@uniswap/permit2/interfaces/ISignatureTransfer.sol";
import {ISettlerWaypoint} from "./interfaces/ISettlerWaypoint.sol";

import {Permit2PaymentWaypoint} from "./core/Permit2Payment.sol";
import {SettlerAbstract} from "./SettlerAbstract.sol";

import {CalldataDecoder, SettlerBase} from "./SettlerBase.sol";
import {UnsafeMath} from "./utils/UnsafeMath.sol";

import {ISettlerActions} from "./ISettlerActions.sol";
import {revertActionInvalid} from "./core/SettlerErrors.sol";

abstract contract SettlerWaypoint is ISettlerWaypoint, Permit2PaymentWaypoint, SettlerBase {
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

    function _dispatch(uint256 index, uint256 action, bytes calldata data) internal virtual override(SettlerBase,SettlerAbstract) returns (bool) {
        if(super._dispatch(index, action, data)) {
            return true;
        }
        else if(action == uint32(ISettlerActions.NATIVE_CHECK.selector)) {
            (address recipient, ISignatureTransfer.PermitTransferFrom memory permit) =
                abi.decode(data, (address, ISignatureTransfer.PermitTransferFrom));
                return true;
        }
        return false;
    }

    function _dispatchVIP(uint256 action, bytes calldata data) internal virtual returns (bool);
    

    function _executeWaypoint(bytes[] calldata actions)
        internal
        returns (bool)
    {
        if(actions.length == 0) revertActionInvalid(0, 0, msg.data[0:0]);

        (uint256 action, bytes calldata data) = actions.decodeCall(0);
        if (!_dispatchVIP(action, data)) {
            revertActionInvalid(0, action, data);
        }

        for (uint256 i = 1; i < actions.length; i = i.unsafeInc()) {
            (uint256 action, bytes calldata data) = actions.decodeCall(i);
            if (!_dispatch(i, action, data)) {
                revertActionInvalid(i, action, data);
            }
        }

        return true;
    }

    function executeWaypoint(
        bytes32 escrowTypedDataHash,
        bytes[] calldata actions,
        bytes32 /*affiliate*/
    )
        public payable override
        placeWaypoint(escrowTypedDataHash)
        returns (bool) {
        return _executeWaypoint(actions);
    }

}
