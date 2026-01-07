// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;


import {Context} from "../Context.sol";
import {ISettlerBase} from "../interfaces/ISettlerBase.sol";

abstract contract WaypointAbstract is Context {
    
    /**
     * The payment has been made by the buyer
     * @param sender sender
     * @param escrowParams escrow parameters
     */
    function _madePayment(address sender, ISettlerBase.EscrowParams memory escrowParams, bytes memory sig) internal virtual;

    /**
     * The seller requests to cancel the escrow
     * @param sender sender
     * @param escrowParams escrow parameters
     */
    function _requestCancelBySeller(address sender, ISettlerBase.EscrowParams memory escrowParams, bytes memory sig) internal virtual;

    /**
     * The buyer cancels the escrow
     * @param sender sender
     * @param escrowParams escrow parameters
     */
    function _cancelByBuyer(address sender, ISettlerBase.EscrowParams memory escrowParams, bytes memory sig) internal virtual;

    /**
     * The seller cancels the escrow
     * @param sender sender
     * @param escrowParams escrow parameters
     */
    function _cancelBySeller(address sender, ISettlerBase.EscrowParams memory escrowParams, bytes memory sig) internal virtual;

    /**
     * The buyer disputes the escrow
     * @param sender sender
     * @param escrowParams escrow parameters
     */
    function _disputeByBuyer(address sender, ISettlerBase.EscrowParams memory escrowParams, bytes memory sig) internal virtual;

    /**
     * The seller disputes the escrow
     * @param sender sender
     * @param escrowParams escrow parameters
     */
    function _disputeBySeller(address sender, ISettlerBase.EscrowParams memory escrowParams, bytes memory sig) internal virtual;

    /**
     * The seller releases the escrow
     * @param sender sender
     * @param escrowParams escrow parameters
     */
    function _releaseBySeller(address sender, ISettlerBase.EscrowParams memory escrowParams, bytes memory sig) internal virtual;

    /**
     * The resolver resolves the escrow
     * @param sender sender
     * @param escrowParams escrow parameters
     * @param buyerThresholdBp buyer threshold in basis points
     * @param tbaArbitrator tba arbitrator
     * @param sig signature of the sender
     * @param arbitratorSig signature of the arbitrator
     * @param counterpartySig signature of the counterparty
     */
    function _resolve(
        address sender, 
        ISettlerBase.EscrowParams memory escrowParams, 
        uint16 buyerThresholdBp, 
        address tbaArbitrator, 
        bytes memory sig, 
        bytes memory arbitratorSig, 
        bytes memory counterpartySig
    ) internal virtual;

    // /**
    //  * processing escrow transaction
    //  * @param escrowTypedHash escrow typed hash
    //  */
    // modifier placeWaypoint(address sender, bytes32 escrowTypedHash) virtual;
    
}