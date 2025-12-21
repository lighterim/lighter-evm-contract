// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;


import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";

import {IEscrow} from "./interfaces/IEscrow.sol";
import {ISettlerBase} from "./interfaces/ISettlerBase.sol";
import {SafeTransferLib} from "./vendor/SafeTransferLib.sol";
import {FullMath} from "./vendor/FullMath.sol";
import {
    EscrowAlreadyExists, EscrowNotExists, InvalidEscrowStatus, InsufficientBalance, 
    TokenNotWhitelisted, UnauthorizedCreator, UnauthorizedExecutor, UnauthorizedVerifier
    } from "./core/SettlerErrors.sol";


contract Escrow is Ownable, Pausable, IEscrow{

    using SafeTransferLib for IERC20;
    using FullMath for uint256;

    // for trade(escrow data)
    mapping(bytes32 => ISettlerBase.EscrowData) internal allEscrow;
    // escrow for seller [seller => [token => amount]]
    mapping(address => mapping(address => uint256)) internal sellerEscrow;
    // credit for buyer [buyer => [token => amount]]
    mapping(address => mapping(address => uint256)) internal userCredit;

    mapping(address => bool) internal isTokenWhitelisted;

    mapping(address => bool) private _authorizedCreator;

    mapping(address => bool) private _authorizedExecutor;

    mapping(address => bool) private _authorizedVerifier;

    
    modifier onlyWhitelistedToken(address token){
        _onlyWhitelistedToken(token);
        _;
    }

    function _onlyWhitelistedToken(address token) private view {
        if(!isTokenWhitelisted[token]) revert TokenNotWhitelisted(token);
    }

    modifier onlyAuthorizedCreator(){
        _onlyAuthorizedCreator();
        _;
    }

    function _onlyAuthorizedCreator() private view {
        if(!_authorizedCreator[msg.sender]) revert UnauthorizedCreator(msg.sender);
    }

    modifier onlyAuthorizedExecutor(){
        _onlyAuthorizedExecutor();
        _;
    }

    function _onlyAuthorizedExecutor() private view {
        if(!_authorizedExecutor[msg.sender]) revert UnauthorizedExecutor(msg.sender);
    }

    modifier onlyAuthorizedVerifier(){
        _onlyAuthorizedVerifier();
        _;
    }

    function _onlyAuthorizedVerifier() private view {
        if(!_authorizedVerifier[msg.sender]) revert UnauthorizedVerifier(msg.sender);
    }

    constructor(address _owner) Ownable(_owner) {
    }

    function whitelistToken(address token, bool isWhitelisted) external onlyOwner{
        isTokenWhitelisted[token] = isWhitelisted;
        if(isWhitelisted) emit WhitelistedToken(token);
        else emit UnwhitelistedToken(token);
    }

    function authorizeCreator(address creator, bool isAuthorized) external onlyOwner{
        _authorizedCreator[creator] = isAuthorized;
        if(isAuthorized) emit AddAuthorizedCreator(creator);
        else emit RemoveAuthorizedCreator(creator);
    }

    function authorizeExecutor(address executor, bool isAuthorized) external onlyOwner{
        _authorizedExecutor[executor] = isAuthorized;
        if(isAuthorized) emit AddAuthorizedExecutor(executor);
        else emit RemoveAuthorizedExecutor(executor);
    }

    function authorizeVerifier(address verifier, bool isAuthorized) external onlyOwner{
        _authorizedVerifier[verifier] = isAuthorized;
        if(isAuthorized) emit AddAuthorizedVerifier(verifier);
        else emit RemoveAuthorizedVerifier(verifier);
    }

    function create(address token, address buyer, address seller, uint256 amount, bytes32 escrowHash, uint256 id, ISettlerBase.EscrowData memory escrowData) external 
        onlyWhitelistedToken(token) onlyAuthorizedCreator {
        
        if(allEscrow[escrowHash].lastActionTs > 0) revert EscrowAlreadyExists(escrowHash);

        // if(escrowData.status != ISettlerBase.EscrowStatus.Escrowed) revert InvalidEscrowStatus(escrowHash, escrowData.status);

        allEscrow[escrowHash] = escrowData;
        sellerEscrow[seller][token] += amount;

        emit Created(token, buyer, seller, escrowHash, id, amount);
    }

    function paid(bytes32 escrowHash, uint256 id, address token, address buyer) external onlyAuthorizedExecutor {
        if(allEscrow[escrowHash].lastActionTs == 0) revert EscrowNotExists(escrowHash);
        if(
            allEscrow[escrowHash].status != ISettlerBase.EscrowStatus.Escrowed 
            && allEscrow[escrowHash].status != ISettlerBase.EscrowStatus.SellerRequestCancel
        ) revert InvalidEscrowStatus(escrowHash, allEscrow[escrowHash].status);
        
        uint64 timestamp = uint64(block.timestamp);
        uint64 paidSeconds = timestamp - allEscrow[escrowHash].lastActionTs;
        allEscrow[escrowHash].paidSeconds = paidSeconds;
        allEscrow[escrowHash].lastActionTs = timestamp;
        allEscrow[escrowHash].status = ISettlerBase.EscrowStatus.Paid;

        emit Paid(token, buyer, escrowHash, paidSeconds, id);
    }

    function releaseByVerifier( bytes32 escrowHash, uint256 id, address token, address buyer, address seller, uint256 amount) external onlyAuthorizedVerifier{
        _release(escrowHash, id, token, buyer, seller, amount, ISettlerBase.EscrowStatus.ThresholdReachedReleased);
    }

    function releaseByExecutor( bytes32 escrowHash, uint256 id, address token, address buyer, address seller, uint256 amount) external onlyAuthorizedExecutor{
        _release(escrowHash, id, token, buyer, seller, amount, ISettlerBase.EscrowStatus.SellerReleased);
    }

    function _release(bytes32 escrowHash, uint256 id, address token, address buyer, address seller, uint256 amount, ISettlerBase.EscrowStatus status) internal{
        if(allEscrow[escrowHash].lastActionTs == 0) revert EscrowNotExists(escrowHash);

        allEscrow[escrowHash].releaseSeconds = allEscrow[escrowHash].paidSeconds > 0 ? uint64(block.timestamp) - allEscrow[escrowHash].lastActionTs : 0;
        allEscrow[escrowHash].lastActionTs = uint64(block.timestamp);
        allEscrow[escrowHash].status = status;

        sellerEscrow[seller][token] -= amount;
        userCredit[buyer][token] += amount;

        emit Released(token, buyer, seller, escrowHash, id, amount, status);
    }

    function cancel(bytes32 escrowHash, uint256 id, address token, address buyer, address seller, uint256 amount, ISettlerBase.EscrowStatus status) external onlyAuthorizedExecutor{
        if(allEscrow[escrowHash].lastActionTs == 0) revert EscrowNotExists(escrowHash);
        if(
            allEscrow[escrowHash].status != ISettlerBase.EscrowStatus.BuyerCancelled 
            && allEscrow[escrowHash].status != ISettlerBase.EscrowStatus.SellerRequestCancel
        ) revert InvalidEscrowStatus(escrowHash, allEscrow[escrowHash].status);
        
        allEscrow[escrowHash].lastActionTs = uint64(block.timestamp);
        allEscrow[escrowHash].status = status;

        sellerEscrow[seller][token] -= amount;
        IERC20(token).safeTransfer(seller, amount);

        emit Cancelled(token, buyer, seller, escrowHash, id, amount, status);
    }

    function claim(address token, address to, uint256 amount) external{
        if(userCredit[to][token] < amount) revert InsufficientBalance(userCredit[to][token]);
        userCredit[to][token] -= amount;

        IERC20(token).safeTransfer(to, amount);

        emit Claimed(token, to, amount);
    }

    function escrowOf(address token, address account) external view returns (uint256){
        return sellerEscrow[account][token];
    }

    function creditOf(address token, address account) external view returns (uint256){
        return userCredit[account][token];
    }

    function getEscrowData(bytes32 escrowHash) external view returns (ISettlerBase.EscrowData memory){
        return allEscrow[escrowHash];
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }
}