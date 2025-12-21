// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;


import {Context} from "../Context.sol";

abstract contract WaypointAbstract is Context {
    
    /**
     * The payment has been made by the buyer
     * @param escrowTypedHash 
     */
    function _madePayment(bytes32 escrowTypedHash) internal virtual;

    /**
     * The seller requests to cancel the escrow
     * @param escrowTypedHash 
     */
    function requestCancelBySeller(bytes32 escrowTypedHash) internal virtual;

    /**
     * The buyer cancels the escrow
     * @param escrowTypedHash 
     */
    function cancelByBuyer(bytes32 escrowTypedHash) internal virtual;

    /**
     * The seller cancels the escrow
     * @param escrowTypedHash 
     */
    function cancelBySeller(bytes32 escrowTypedHash) internal virtual;

    /**
     * The buyer disputes the escrow
     * @param escrowTypedHash 
     */
    function disputeByBuyer(bytes32 escrowTypedHash) internal virtual;

    /**
     * The seller disputes the escrow
     * @param escrowTypedHash 
     */
    function disputeBySeller(bytes32 escrowTypedHash) internal virtual;

    /**
     * processing escrow transaction
     * @param escrowTypedHash escrow typed hash
     */
    modifier placeWaypoint(address sender, bytes32 escrowTypedHash) virtual;
    
}