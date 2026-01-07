// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {ISignatureTransfer} from "@uniswap/permit2/interfaces/ISignatureTransfer.sol";
import {ISettlerWaypoint} from "./interfaces/ISettlerWaypoint.sol";
import {ISettlerBase} from "./interfaces/ISettlerBase.sol";

import {SettlerAbstract} from "./SettlerAbstract.sol";

import {CalldataDecoder, SettlerBase} from "./SettlerBase.sol";
import {UnsafeMath} from "./utils/UnsafeMath.sol";

import {ISettlerActions} from "./ISettlerActions.sol";
import {WaypointAbstract} from "./core/WaypointAbstract.sol";
import {revertActionInvalid} from "./core/SettlerErrors.sol";

abstract contract SettlerWaypoint is ISettlerWaypoint, WaypointAbstract, SettlerBase {
    using UnsafeMath for uint256;
    using CalldataDecoder for bytes[];

    function _tokenId() internal pure virtual override returns (uint256) {
        return 3;
    }

    function _dispatchVIP(uint256 action, bytes calldata data) internal virtual override returns (bool) {
        if(action == uint32(ISettlerActions.MAKE_PAYMENT.selector)) {
            (ISettlerBase.EscrowParams memory escrowParams, bytes memory sig) = abi.decode(data, (ISettlerBase.EscrowParams, bytes));
            _madePayment(_msgSender(), escrowParams, sig);
            return true;
        }
        else if(action == uint32(ISettlerActions.REQUEST_CANCEL.selector)) {
            (ISettlerBase.EscrowParams memory escrowParams, bytes memory sig) = abi.decode(data, (ISettlerBase.EscrowParams, bytes));
            _requestCancelBySeller(_msgSender(), escrowParams, sig);
            return true;
        }
        else if(action == uint32(ISettlerActions.CANCEL_BY_BUYER.selector)) {
            (ISettlerBase.EscrowParams memory escrowParams, bytes memory sig) = abi.decode(data, (ISettlerBase.EscrowParams, bytes));
            _cancelByBuyer(_msgSender(), escrowParams, sig);
            return true;
        }
        else if(action == uint32(ISettlerActions.CANCEL_BY_SELLER.selector)) {
            (ISettlerBase.EscrowParams memory escrowParams, bytes memory sig) = abi.decode(data, (ISettlerBase.EscrowParams, bytes));
            _cancelBySeller(_msgSender(), escrowParams, sig);
            return true;
        }
        else if(action == uint32(ISettlerActions.DISPUTE_BY_BUYER.selector)) {
            (ISettlerBase.EscrowParams memory escrowParams, bytes memory sig) = abi.decode(data, (ISettlerBase.EscrowParams, bytes));
            _disputeByBuyer(_msgSender(), escrowParams, sig);
            return true;
        }
        else if(action == uint32(ISettlerActions.DISPUTE_BY_SELLER.selector)) {
            (ISettlerBase.EscrowParams memory escrowParams, bytes memory sig) = abi.decode(data, (ISettlerBase.EscrowParams, bytes));
            _disputeBySeller(_msgSender(), escrowParams, sig);
            return true;
        }
        else if(action == uint32(ISettlerActions.RELEASE_BY_SELLER.selector)) {
            (ISettlerBase.EscrowParams memory escrowParams, bytes memory sig) = abi.decode(data, (ISettlerBase.EscrowParams, bytes));
            _releaseBySeller(_msgSender(), escrowParams, sig);
            return true;
        }
        else if(action == uint32(ISettlerActions.RESOLVE.selector)) {
            (
                ISettlerBase.EscrowParams memory escrowParams, 
                uint16 buyerThresholdBp,
                address tbaArbitrator,
                bytes memory sig, 
                bytes memory arbitratorSig, 
                bytes memory counterpartySig
            ) = abi.decode(data, (ISettlerBase.EscrowParams, uint16, address, bytes, bytes, bytes));
            _resolve(
                _msgSender(), 
                escrowParams, 
                buyerThresholdBp, 
                tbaArbitrator, 
                sig, 
                arbitratorSig, 
                counterpartySig
            );
            return true;
        }
        return false;
    }

    function _dispatch(uint256 i, uint256 action, bytes calldata data) internal virtual override returns (bool) { 
        return false;
    }


    // /**
    //  * processing escrow transaction
    //  * @param escrowTypedHash escrow typed hash
    //  */
    // modifier placeWaypoint(address sender, bytes32 escrowTypedHash) virtual override{
    //     _;
    // }
    
    

    function _executeWaypoint(bytes[] calldata actions)
        internal
        returns (bool){   
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

    function execute(
        bytes32 /*escrowTypedDataHash*/,
        bytes[] calldata actions
    ) external payable override
        //placeWaypoint(msg.sender, escrowTypedDataHash)
        returns (bool) {
        return _executeWaypoint(actions);
    }

}
