
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {ISignatureTransfer} from "@uniswap/permit2/interfaces/ISignatureTransfer.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {ISettlerTakerSubmitted} from "./interfaces/ISettlerTakerSubmitted.sol";
import {Permit2PaymentTakerSubmitted} from "./core/Permit2Payment.sol";
import {Permit2PaymentAbstract} from "./core/Permit2PaymentAbstract.sol";

import {AbstractContext} from "./Context.sol";
import {CalldataDecoder, SettlerBase} from "./SettlerBase.sol";
import {UnsafeMath} from "./utils/UnsafeMath.sol";

import {ISettlerActions} from "./ISettlerActions.sol";
import {ISettlerBase} from "./interfaces/ISettlerBase.sol";
import {revertActionInvalid, SignatureExpired, MsgValueMismatch} from "./core/SettlerErrors.sol";
import {SettlerAbstract} from "./SettlerAbstract.sol";


abstract contract Settler is ISettlerTakerSubmitted, Permit2PaymentTakerSubmitted, SettlerBase {

    using UnsafeMath for uint256;
    using CalldataDecoder for bytes[];

    function _tokenId() internal pure override returns (uint256) {
        return 2;
    }

    function _hasMetaTxn() internal pure override returns (bool) {
        return false;
    }

    function _domainSeparator() internal view virtual returns (bytes32);

    // function _dispatch(uint256 index, uint256 action, bytes calldata data) internal virtual override(SettlerAbstract/*, SettlerBase*/) returns (bool) {
    //     if(super._dispatch(index, action, data)) {
    //         return true;
    //     }
    //     else if(action == uint32(ISettlerActions.NATIVE_CHECK.selector)) {
    //         (uint256 deadline, uint256 msgValue) = abi.decode(data, (uint256, uint256));
    //         if (block.timestamp > deadline) {
    //             assembly ("memory-safe") {
    //                 mstore(0x00, 0xcd21db4f) // selector for `SignatureExpired(uint256)`
    //                 mstore(0x20, deadline)
    //                 revert(0x1c, 0x24)
    //             }
    //         }
    //         if (msg.value < msgValue) {
    //             assembly ("memory-safe") {
    //                 mstore(0x00, 0x4a094431) // selector for `MsgValueMismatch(uint256,uint256)`
    //                 mstore(0x20, msgValue)
    //                 mstore(0x40, callvalue())
    //                 revert(0x1c, 0x44)
    //             }
    //         }
    //     }
    //     else{
    //         return false;
    //     }
    //     return true;
    // }

    function _dispatchVIP(uint256 action, bytes calldata data) internal virtual returns (bool);

    function execute(bytes[] calldata actions, bytes32 /* zid & affiliate */ )
        public
        payable
        override
        takerSubmitted
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

    // Solidity inheritance is stupid
    function _msgSender()
        internal
        view
        virtual
        override(Permit2PaymentTakerSubmitted, AbstractContext)
        returns (address)
    {
        return super._msgSender();
    }

    function _isRestrictedTarget(address target)
        internal
        pure
        virtual
        override(Permit2PaymentTakerSubmitted, Permit2PaymentAbstract)
        returns (bool)
    {
        return super._isRestrictedTarget(target);
    }
}
