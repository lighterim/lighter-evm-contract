// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;


import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";

import {IEscrow} from "./interfaces/IEscrow.sol";
import {ISettlerBase} from "./interfaces/ISettlerBase.sol";
import {SafeTransferLib} from "./vendor/SafeTransferLib.sol";
import {EscrowAlreadyExists, EscrowNotExists, EscrowStatusError, InsufficientBalance} from "./core/SettlerErrors.sol";


contract Escrow is Ownable, Pausable, IEscrow{

    using SafeTransferLib for IERC20;

    // for trade(escrow data)
    mapping(bytes32 => ISettlerBase.EscrowData) internal allEscrow;
    // escrow for seller [token => [seller => amount]]
    mapping(address => mapping(address => uint256)) internal sellerEscrow;
    // credit for buyer [token => [buyer => amount]]
    mapping(address => mapping(address => uint256)) internal userCredit;
    

    constructor(address _owner) Ownable(_owner) {
    }

    function create(address token, address buyer, address seller, uint256 amount, bytes32 escrowHash, uint256 id, ISettlerBase.EscrowData memory escrowData) external{
        if(allEscrow[escrowHash].lastActionTs > 0) revert EscrowAlreadyExists(escrowHash);
        
        allEscrow[escrowHash] = escrowData;
        sellerEscrow[token][seller] += amount;

        emit Created(token, buyer, seller, escrowHash, id, amount);
    }

    function paid(bytes32 escrowHash, uint256 id, address token, address buyer) external{
        if(allEscrow[escrowHash].lastActionTs == 0) revert EscrowNotExists(escrowHash);
        if(allEscrow[escrowHash].status != ISettlerBase.EscrowStatus.Escrowed && allEscrow[escrowHash].status != ISettlerBase.EscrowStatus.SellerRequestCancel) revert EscrowStatusError(escrowHash, ISettlerBase.EscrowStatus.Escrowed, allEscrow[escrowHash].status);
        
        uint64 timestamp = uint64(block.timestamp);
        uint64 paidSeconds = timestamp - allEscrow[escrowHash].lastActionTs;
        allEscrow[escrowHash].paidSeconds = paidSeconds;
        allEscrow[escrowHash].lastActionTs = timestamp;
        allEscrow[escrowHash].status = ISettlerBase.EscrowStatus.Paid;

        emit Paid(token, buyer, escrowHash, paidSeconds, id);
    }

    function release( bytes32 escrowHash, uint256 id, address token, address buyer, address seller, uint256 amount, ISettlerBase.EscrowStatus status) external{
        // if(allEscrow[escrowHash].status != ISettlerBase.EscrowStatus.Escrowed) revert EscrowNotEscrowed(escrowHash);
        // if(allEscrow[escrowHash].lastActionTs > 0) revert EscrowAlreadyReleased(escrowHash);
        // if(allEscrow[escrowHash].lastActionTs + allEscrow[escrowHash].releaseSeconds < block.timestamp) revert EscrowReleased(escrowHash);
        if(allEscrow[escrowHash].lastActionTs == 0) revert EscrowNotExists(escrowHash);
        
        allEscrow[escrowHash].releaseSeconds = allEscrow[escrowHash].paidSeconds > 0 ? uint64(block.timestamp) - allEscrow[escrowHash].lastActionTs : 0;
        allEscrow[escrowHash].lastActionTs = uint64(block.timestamp);
        allEscrow[escrowHash].status = status;

        sellerEscrow[token][seller] -= amount;
        userCredit[token][buyer] += amount;

        emit Released(token, buyer, seller, escrowHash, id, amount, status);
    }

    function cancel(bytes32 escrowHash, uint256 id, address token, address buyer, address seller, uint256 amount, ISettlerBase.EscrowStatus status) external{
        if(allEscrow[escrowHash].lastActionTs == 0) revert EscrowNotExists(escrowHash);
        if(allEscrow[escrowHash].status != ISettlerBase.EscrowStatus.BuyerCancelled && allEscrow[escrowHash].status != ISettlerBase.EscrowStatus.SellerRequestCancel) revert EscrowStatusError(escrowHash, ISettlerBase.EscrowStatus.SellerRequestCancel, allEscrow[escrowHash].status);
        
        allEscrow[escrowHash].lastActionTs = uint64(block.timestamp);
        allEscrow[escrowHash].status = status;

        sellerEscrow[token][seller] -= amount;

        emit Cancelled(token, buyer, seller, escrowHash, id, amount, status);
    }

    function claim(address token, address to, uint256 amount) external{
        if(userCredit[token][to] < amount) revert InsufficientBalance(userCredit[address(token)][to]);
        userCredit[address(token)][to] -= amount;

        IERC20(token).safeTransfer(to, amount);

        emit Claimed(token, to, amount);
    }

    function escrowOf(address token, address account) external view returns (uint256){
        return sellerEscrow[address(token)][account];
    }

    function creditOf(address token, address account) external view returns (uint256){
        return userCredit[address(token)][account];
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }
}