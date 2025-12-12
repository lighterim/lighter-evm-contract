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
     * @param escrowHash The hash of the escrow data
     * @param id the id of escrow trade
     * @param escrowData The data of the escrow
     */
    function create(address token, address buyer, address seller, uint256 amount, bytes32 escrowHash, uint256 id, ISettlerBase.EscrowData memory escrowData) external;

    /**
     * mark the escrow as paid
     * @param escrowHash The hash of the escrow
     * @param id the id of escrow trade
     * @param token The token of the escrow
     * @param buyer The buyer of the escrow
     */
    function paid(bytes32 escrowHash, uint256 id, address token, address buyer) external;

    /**
     * release the escrow
     * @param escrowHash The hash of the escrow
     * @param id the id of escrow trade
     * @param token The token of the escrow
     * @param buyer The buyer of the escrow
     * @param seller The seller of the escrow
     * @param amount The amount of the escrow
     */
    function releaseByVerifier(bytes32 escrowHash, uint256 id, address token, address buyer, address seller, uint256 amount) external;

    /**
     * release the escrow by executor
     * @param escrowHash The hash of the escrow
     * @param id the id of escrow trade
     * @param token The token of the escrow
     * @param buyer The buyer of the escrow
     * @param seller The seller of the escrow
     * @param amount The amount of the escrow
     */
    function releaseByExecutor(bytes32 escrowHash, uint256 id, address token, address buyer, address seller, uint256 amount) external;

    /**
     * cancel the escrow
     * @param escrowHash The hash of the escrow
     * @param id the id of escrow trade
     * @param token The token of the escrow
     * @param buyer The buyer of the escrow
     * @param seller The seller of the escrow
     * @param amount The amount of the escrow
     * @param status The status of the escrow
     */
    function cancel( bytes32 escrowHash, uint256 id, address token, address buyer, address seller, uint256 amount, ISettlerBase.EscrowStatus status) external;

    /**
     * claim token from credit of the buyer
     * @param token The token to claim
     * @param to The recipient of the claim
     * @param amount The amount of the claim
     */
    function claim(address token, address to, uint256 amount) external;


    //event
    event Created(address indexed token, address indexed buyer, address indexed seller, bytes32 escrowHash, uint256 id,uint256 amount);
    event Paid(address indexed token, address indexed buyer, bytes32 indexed escrowHash, uint64 paidSeconds, uint256 id);
    event Released(address indexed token, address indexed buyer, address indexed seller, bytes32 escrowHash,  uint256 id, uint256 amount, ISettlerBase.EscrowStatus status);
    event Cancelled(address indexed token, address indexed buyer, address indexed seller, bytes32 escrowHash,  uint256 id, uint256 amount, ISettlerBase.EscrowStatus status);
    event Claimed(address indexed token, address indexed to, uint256 amount);

    event AddAuthorizedCreator(address indexed creator);
    event AddAuthorizedExecutor(address indexed executor);
    event AddAuthorizedVerifier(address indexed verifier);
    event WhitelistedToken(address indexed token);

    event RemoveAuthorizedCreator(address indexed creator);
    event RemoveAuthorizedExecutor(address indexed executor);
    event RemoveAuthorizedVerifier(address indexed verifier);
    event UnwhitelistedToken(address indexed token);

}