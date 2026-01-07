// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;


import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {ISettlerBase} from "./ISettlerBase.sol";

/**
 * @title Escrow Holder Interface
 * @author Lighter.IM
 * @notice This interface defines the functions for the Escrow Holder contract.
 * @dev This interface is used to interact with the Escrow Holder contract.
 */
interface IEscrow {

    /**
     * amount of credit for the account on the token
     * @param token The token to get the credit of
     * @param account The account to get the credit of
     * @return The amount of credit for the account on the token
     */
    function creditOf(address token, address account) external view returns (uint256);

    /** pending escrow for the account */
    function escrowOf(address token, address account) external view returns (uint256);

    function getEscrowData(bytes32 escrowHash) external view returns (ISettlerBase.EscrowData memory);
    
    /**
     * create an escrow for the buyer and seller
     * @param token The token to create the escrow for
     * @param buyer The buyer of the escrow
     * @param seller The seller of the escrow
     * @param amount The amount of the escrow
     * @param sellerFee The fee of the seller
     * @param escrowHash The hash of the escrow data
     * @param id the id of escrow trade
     * @param escrowData The data of the escrow
     */
    function create(address token, address buyer, address seller, uint256 amount, uint256 sellerFee, bytes32 escrowHash, uint256 id, ISettlerBase.EscrowData memory escrowData) external;

    /**
     * mark the escrow as paid
     * @param escrowHash The hash of the escrow
     * @param id the id of escrow trade
     * @param token The token of the escrow
     * @param buyer The buyer of the escrow
     * @param paymentWindowSeconds The window seconds for the payment method
     */
    function paid(bytes32 escrowHash, uint256 id, address token, address buyer, uint64 paymentWindowSeconds) external;

    /**
     * release the escrow
     * @param escrowHash The hash of the escrow
     * @param id the id of escrow trade
     * @param token The token of the escrow
     * @param buyer The buyer of the escrow
     * @param buyerFee The fee of the buyer
     * @param seller The seller of the escrow
     * @param sellerFee The fee of the seller
     * @param amount The amount of the escrow
     */
    function releaseByVerifier(
        bytes32 escrowHash, uint256 id, address token,
        address buyer, uint256 buyerFee, address seller, uint256 sellerFee,
        uint256 amount
        ) external;

    /**
     * release the escrow by executor
     * @param escrowHash The hash of the escrow
     * @param id the id of escrow trade
     * @param token The token of the escrow
     * @param buyer The buyer of the escrow
     * @param buyerFee The fee of the buyer
     * @param seller The seller of the escrow
     * @param sellerFee The fee of the seller
     * @param amount The amount of the escrow
     */
    function releaseBySeller(
        bytes32 escrowHash, uint256 id, address token,
        address buyer, uint256 buyerFee, address seller, uint256 sellerFee,
        uint256 amount
        ) external;

    /**
     * cancel the escrow
     * @param escrowHash The hash of the escrow
     * @param escrowParams The parameters of the escrow
     * @param sellerFee The fee of the seller
     * @param windowSeconds The window seconds for the payment method
     */
    function cancel(bytes32 escrowHash, ISettlerBase.EscrowParams memory escrowParams, uint256 sellerFee, uint256 windowSeconds) external;

    /**
     * cancel the escrow by buyer
     * @param escrowHash The hash of the escrow
     * @param id the id of escrow trade
     * @param token The token of the escrow
     * @param buyer The buyer of the escrow
     * @param seller The seller of the escrow
     */
    function cancelByBuyer(bytes32 escrowHash, uint256 id, address token, address buyer, address seller) external;

    /**
     * request cancel the escrow
     * @param escrowHash The hash of the escrow
     * @param id the id of escrow trade
     * @param token The token of the escrow
     * @param buyer The buyer of the escrow
     * @param seller The seller of the escrow
     * @param windowSeconds The window seconds for the payment method
     */
    function requestCancel(bytes32 escrowHash, uint256 id, address token, address buyer, address seller, uint256 windowSeconds) external;

    /**
     * dispute the escrow
     * @param escrowHash The hash of the escrow
     * @param id the id of escrow trade
     * @param token The token of the escrow
     * @param buyer The buyer of the escrow
     * @param seller The seller of the escrow
     * @param status The status of the escrow
     */
    function dispute(bytes32 escrowHash, uint256 id, address token, address buyer, address seller, ISettlerBase.EscrowStatus status) external;

    function resolve(
        bytes32 escrowHash, ISettlerBase.EscrowParams memory escrowParams,
        uint256 buyerFee, uint256 sellerFee,
        uint16 buyerThresholdBp, address tbaArbitrator, bytes32 escrowTypedHash, bytes memory counterpartySig
    ) external;


    /**
     * claim token from credit of the buyer
     * @param token The token to claim
     * @param tba The tba of the claim
     * @param to The recipient of the claim
     * @param amount The amount of the claim
     */
    function claim(address token, address tba, address to, uint256 amount) external;

    /**
     * collect the fee from the fee collector   
     * @param token The token to collect the fee
     * @param to The recipient of the fee
     * @param amount The amount of the fee to collect
     */
    function collectFee(address token, address to, uint256 amount) external;

    //event
    event Created(address indexed token, address indexed buyer, address indexed seller, bytes32 escrowHash, uint256 id,uint256 amount);
    event Paid(address indexed token, address indexed buyer, bytes32 indexed escrowHash, uint64 paidSeconds, uint256 id);
    event Released(address indexed token, address indexed buyer, address indexed seller, bytes32 escrowHash,  uint256 id, uint256 amount, ISettlerBase.EscrowStatus status);
    event Cancelled(address indexed token, address indexed buyer, address indexed seller, bytes32 escrowHash,  uint256 id, uint256 amount, ISettlerBase.EscrowStatus status);
    event RequestCancelled(address indexed token, address indexed buyer, address indexed seller, bytes32 escrowHash, uint256 id);
    event CancelledByBuyer(address indexed token, address indexed buyer, address indexed seller, bytes32 escrowHash, uint256 id);
    event DisputedByBuyer(address indexed token, address indexed buyer, address indexed seller, bytes32 escrowHash, uint256 id);
    event DisputedBySeller(address indexed token, address indexed buyer, address indexed seller, bytes32 escrowHash, uint256 id);
    event Resolved(address indexed token, address indexed buyer, address indexed seller, bytes32 escrowHash, uint256 id, address tbaArbitrator, uint256 buyerThresholdBp);
    event Claimed(address indexed token, address indexed tba, address indexed to, uint256 amount);
    event CollectedFee(address indexed token, address indexed to, uint256 amount);


    event AddAuthorizedCreator(address indexed creator);
    event AddAuthorizedExecutor(address indexed executor);
    event AddAuthorizedVerifier(address indexed verifier);
    event WhitelistedToken(address indexed token);

    event RemoveAuthorizedCreator(address indexed creator);
    event RemoveAuthorizedExecutor(address indexed executor);
    event RemoveAuthorizedVerifier(address indexed verifier);
    event UnwhitelistedToken(address indexed token);

}