// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;


import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";

import {IEscrow} from "./interfaces/IEscrow.sol";
import {ISettlerBase} from "./interfaces/ISettlerBase.sol";
import {EscrowAlreadyExists, EscrowNotExists, EscrowStatusError, InsufficientBalance} from "./core/SettlerErrors.sol";


contract Escrow is Ownable, Pausable, IEscrow{

    // for trade(escrow data)
    mapping(bytes32 => ISettlerBase.EscrowData) internal allEscrow;
    // escrow for seller [token => [seller => amount]]
    mapping(address => mapping(address => uint256)) internal sellerEscrow;
    // credit for buyer [token => [buyer => amount]]
    mapping(address => mapping(address => uint256)) internal userCredit;
    // pending tx list [user => [tradeId...]]
    mapping(address => mapping(bytes32 => bool)) internal pendingTxList;

    constructor(address _owner) Ownable(_owner) {
    }

    function create(IERC20 token, address buyer, address seller, uint256 amount, bytes32 escrowHash, ISettlerBase.EscrowData memory escrowData) external{
        if(allEscrow[escrowHash].lastActionTs > 0) revert EscrowAlreadyExists(escrowHash);
        
        allEscrow[escrowHash] = escrowData;
        sellerEscrow[address(token)][seller] += amount;
        pendingTxList[seller][escrowHash] = true;
        pendingTxList[buyer][escrowHash] = true;

        emit Created(token, buyer, seller, escrowHash, amount);
    }

    function release(IERC20 token, address buyer, address seller, uint256 amount, bytes32 escrowHash, ISettlerBase.EscrowStatus status) external{
        // if(allEscrow[escrowHash].status != ISettlerBase.EscrowStatus.Escrowed) revert EscrowNotEscrowed(escrowHash);
        // if(allEscrow[escrowHash].lastActionTs > 0) revert EscrowAlreadyReleased(escrowHash);
        // if(allEscrow[escrowHash].lastActionTs + allEscrow[escrowHash].releaseSeconds < block.timestamp) revert EscrowReleased(escrowHash);
        if(allEscrow[escrowHash].lastActionTs == 0) revert EscrowNotExists(escrowHash);
        
        allEscrow[escrowHash].releaseSeconds = allEscrow[escrowHash].paidSeconds > 0 ? uint64(block.timestamp) - allEscrow[escrowHash].lastActionTs : 0;
        allEscrow[escrowHash].lastActionTs = uint64(block.timestamp);
        allEscrow[escrowHash].status = status;

        sellerEscrow[address(token)][seller] -= amount;
        userCredit[address(token)][buyer] += amount;
        delete pendingTxList[seller][escrowHash];
        delete pendingTxList[buyer][escrowHash];

        emit Released(token, buyer, seller, escrowHash, amount, status);
    }

    function cancel(IERC20 token, address buyer, address seller, uint256 amount, bytes32 escrowHash, ISettlerBase.EscrowStatus status) external{
        if(allEscrow[escrowHash].lastActionTs == 0) revert EscrowNotExists(escrowHash);
        if(allEscrow[escrowHash].status != ISettlerBase.EscrowStatus.BuyerCancelled && allEscrow[escrowHash].status != ISettlerBase.EscrowStatus.SellerRequestCancel) revert EscrowStatusError(escrowHash, ISettlerBase.EscrowStatus.SellerRequestCancel, allEscrow[escrowHash].status);
        
        allEscrow[escrowHash].lastActionTs = uint64(block.timestamp);
        allEscrow[escrowHash].status = status;

        sellerEscrow[address(token)][seller] -= amount;
        delete pendingTxList[seller][escrowHash];
        delete pendingTxList[buyer][escrowHash];

        emit Cancelled(token, buyer, seller, escrowHash, amount, status);
    }

    function claim(IERC20 token, address to, uint256 amount) external{
        if(userCredit[address(token)][to] < amount) revert InsufficientBalance(userCredit[address(token)][to]);
        userCredit[address(token)][to] -= amount;

        emit Claimed(token, to, amount);
    }

    function escrowOf(IERC20 token, address account) external view returns (uint256){
        return sellerEscrow[address(token)][account];
    }

    function creditOf(IERC20 token, address account) external view returns (uint256){
        return userCredit[address(token)][account];
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }
}