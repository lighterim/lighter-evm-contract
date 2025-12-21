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

    /**
     * The payment has been made by the buyer
     * @param sender sender
     * @param escrowParams escrow parameters
     */
    function _madePayment(address sender, ISettlerBase.EscrowParams memory escrowParams) internal virtual override{

    }

    /**
     * The seller requests to cancel the escrow
     * @param sender sender
     * @param escrowParams escrow parameters
     */
    function _requestCancelBySeller(address sender, ISettlerBase.EscrowParams memory escrowParams) internal virtual override{

    }

    /**
     * The buyer cancels the escrow
     * @param sender sender
     * @param escrowParams escrow parameters
     */
    function _cancelByBuyer(address sender, ISettlerBase.EscrowParams memory escrowParams) internal virtual override{

    }

    /**
     * The seller cancels the escrow
     * @param sender sender
     * @param escrowParams escrow parameters
     */
    function _cancelBySeller(address sender, ISettlerBase.EscrowParams memory escrowParams) internal virtual override{

    }

    /**
     * The buyer disputes the escrow
     * @param sender sender
     * @param escrowParams escrow parameters
     */
    function _disputeByBuyer(address sender, ISettlerBase.EscrowParams memory escrowParams) internal virtual override{

    }

    /**
     * The seller disputes the escrow
     * @param sender sender
     * @param escrowParams escrow parameters
     */
    function _disputeBySeller(address sender, ISettlerBase.EscrowParams memory escrowParams) internal virtual override{

    }

    /**
     * processing escrow transaction
     * @param escrowTypedHash escrow typed hash
     */
    modifier placeWaypoint(address sender, bytes32 escrowTypedHash) virtual override{
        _;
    }
    
    

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
        placeWaypoint(msg.sender, escrowTypedDataHash)
        returns (bool) {
        return _executeWaypoint(actions);
    }

}
