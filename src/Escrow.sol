// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;


import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import {IEscrow} from "./interfaces/IEscrow.sol";
import {ISettlerBase} from "./interfaces/ISettlerBase.sol";
import {SafeTransferLib} from "./vendor/SafeTransferLib.sol";
import {FullMath} from "./vendor/FullMath.sol";
import {LighterAccount} from "./account/LighterAccount.sol";
import {
    EscrowAlreadyExists, EscrowNotExists, InvalidEscrowStatus, InsufficientBalance, 
    TokenNotWhitelisted, UnauthorizedCreator, UnauthorizedExecutor, UnauthorizedVerifier, 
    UnauthorizedCaller
    } from "./core/SettlerErrors.sol";


contract Escrow is Ownable, Pausable, IEscrow, ReentrancyGuard{

    using SafeTransferLib for IERC20;
    using FullMath for uint256;

    LighterAccount public immutable lighterAccount;
    address public feeCollector;

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


    modifier onlyAuthorizedCreator(){
        _onlyAuthorizedCreator();
        _;
    }

    modifier onlyAuthorizedExecutor(){
        _onlyAuthorizedExecutor();
        _;
    }

    modifier onlyAuthorizedVerifier(){
        _onlyAuthorizedVerifier();
        _;
    }

    constructor(address owner_, LighterAccount lighterAccount_, address feeCollector_) Ownable(owner_) {
        lighterAccount = lighterAccount_;
        feeCollector = feeCollector_;
    }

    function _onlyAuthorizedCreator() private view {
        if(!_authorizedCreator[msg.sender]) revert UnauthorizedCreator(msg.sender);
    }
    
    function _onlyWhitelistedToken(address token) private view {
        if(!isTokenWhitelisted[token]) revert TokenNotWhitelisted(token);
    }

    function _onlyAuthorizedExecutor() private view {
        if(!_authorizedExecutor[msg.sender]) revert UnauthorizedExecutor(msg.sender);
    }

    function _onlyAuthorizedVerifier() private view {
        if(!_authorizedVerifier[msg.sender]) revert UnauthorizedVerifier(msg.sender);
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


    function create(address token, address buyer, address seller, uint256 amount, 
        uint256 sellerFee,
        bytes32 escrowHash, uint256 id, ISettlerBase.EscrowData memory escrowData) external 
        onlyWhitelistedToken(token) onlyAuthorizedCreator whenNotPaused {
        
        if(allEscrow[escrowHash].lastActionTs > 0) revert EscrowAlreadyExists(escrowHash);

        if(escrowData.status != ISettlerBase.EscrowStatus.Escrowed) revert InvalidEscrowStatus(escrowHash, escrowData.status);

        allEscrow[escrowHash] = escrowData;
        sellerEscrow[seller][token] += amount + sellerFee;

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
        _setStatus(escrowHash, timestamp, ISettlerBase.EscrowStatus.Paid);

        emit Paid(token, buyer, escrowHash, paidSeconds, id);
    }

    function releaseByVerifier( bytes32 escrowHash, uint256 id, address token, address buyer, uint256 buyerFee, address seller, uint256 sellerFee, uint256 amount) external nonReentrant onlyAuthorizedVerifier{
        _release(escrowHash, id, token, buyer, buyerFee, seller, sellerFee, amount, ISettlerBase.EscrowStatus.ThresholdReachedReleased);
    }

    function releaseByExecutor( bytes32 escrowHash, uint256 id, address token, address buyer, uint256 buyerFee, address seller, uint256 sellerFee, uint256 amount) external nonReentrant onlyAuthorizedExecutor{
        _release(escrowHash, id, token, buyer, buyerFee, seller, sellerFee, amount, ISettlerBase.EscrowStatus.SellerReleased);
    }

    function _release(bytes32 escrowHash, uint256 id, address token, 
        address buyer, uint256 buyerFee, address seller, uint256 sellerFee, uint256 amount, 
        ISettlerBase.EscrowStatus status) private {
        
        if(allEscrow[escrowHash].lastActionTs == 0) revert EscrowNotExists(escrowHash);

        allEscrow[escrowHash].releaseSeconds = allEscrow[escrowHash].paidSeconds > 0 ? uint64(block.timestamp) - allEscrow[escrowHash].lastActionTs : 0;
        _setStatus(escrowHash, uint64(block.timestamp), status);

        // uint256 sellerFee = amount * sellerFeeRate / 10000;
        sellerEscrow[seller][token] -= (amount + sellerFee);
        // uint256 buyerFee = amount * buyerFeeRate / 10000;
        userCredit[buyer][token] += (amount - buyerFee);
        userCredit[feeCollector][token] += (buyerFee + sellerFee);

        emit Released(token, buyer, seller, escrowHash, id, amount, status);
    }

    function requestCancel(bytes32 escrowHash, uint256 id, address token, address buyer, address seller) external onlyAuthorizedExecutor{
        if(allEscrow[escrowHash].lastActionTs == 0) revert EscrowNotExists(escrowHash);
        if(allEscrow[escrowHash].status != ISettlerBase.EscrowStatus.Escrowed) revert InvalidEscrowStatus(escrowHash, allEscrow[escrowHash].status);
        
        _setStatus(escrowHash, uint64(block.timestamp), ISettlerBase.EscrowStatus.SellerRequestCancel);
        
        emit RequestCancelled(token, buyer, seller, escrowHash, id);
    }

    function cancelByBuyer(bytes32 escrowHash, uint256 id, address token, address buyer, address seller) external onlyAuthorizedExecutor{
        if(allEscrow[escrowHash].lastActionTs == 0) revert EscrowNotExists(escrowHash);
        if(allEscrow[escrowHash].status != ISettlerBase.EscrowStatus.Escrowed) revert InvalidEscrowStatus(escrowHash, allEscrow[escrowHash].status);
        
        _setStatus(escrowHash, uint64(block.timestamp), ISettlerBase.EscrowStatus.BuyerCancelled);

        emit CancelledByBuyer(token, buyer, seller, escrowHash, id);
    }

    function cancel(bytes32 escrowHash, uint256 id, address token, address buyer, address seller, uint256 amount, 
        uint256 sellerFee,
        ISettlerBase.EscrowStatus status) external onlyAuthorizedExecutor nonReentrant{
        if(allEscrow[escrowHash].lastActionTs == 0) revert EscrowNotExists(escrowHash);
        if(
            allEscrow[escrowHash].status != ISettlerBase.EscrowStatus.BuyerCancelled 
            && allEscrow[escrowHash].status != ISettlerBase.EscrowStatus.SellerRequestCancel
        ) revert InvalidEscrowStatus(escrowHash, allEscrow[escrowHash].status);
        
        _setStatus(escrowHash, uint64(block.timestamp), status);

        uint256 refundAmount = amount + sellerFee;
        sellerEscrow[seller][token] -= refundAmount;
        IERC20(token).safeTransfer(seller, refundAmount);

        emit Cancelled(token, buyer, seller, escrowHash, id, amount, status);
    }

    function dispute(bytes32 escrowHash, uint256 id, address token, address buyer, address seller, ISettlerBase.EscrowStatus status) external onlyAuthorizedExecutor{
        if(allEscrow[escrowHash].lastActionTs == 0) revert EscrowNotExists(escrowHash);

        if(
            allEscrow[escrowHash].status != ISettlerBase.EscrowStatus.Paid 
            || (
                status != ISettlerBase.EscrowStatus.BuyerDisputed 
                && status != ISettlerBase.EscrowStatus.SellerDisputed
                )
        ) revert InvalidEscrowStatus(escrowHash, allEscrow[escrowHash].status);
        
        _setStatus(escrowHash, uint64(block.timestamp), status);

        if(status == ISettlerBase.EscrowStatus.BuyerDisputed) {
            emit DisputedByBuyer(token, buyer, seller, escrowHash, id);
        } else {
            emit DisputedBySeller(token, buyer, seller, escrowHash, id);
        }
    }

    function _setStatus(bytes32 escrowHash, uint64 timestamp, ISettlerBase.EscrowStatus status) private {
        allEscrow[escrowHash].lastActionTs = timestamp;
        allEscrow[escrowHash].status = status;
    }

    function claim(address token, address tba, address to, uint256 amount) external nonReentrant{
        if(!lighterAccount.isOwnerCall(tba, msg.sender)) revert UnauthorizedCaller(msg.sender);
        
        if(userCredit[tba][token] < amount) revert InsufficientBalance(userCredit[tba][token]);
        
        userCredit[tba][token] -= amount;
        IERC20(token).safeTransfer(to, amount);

        emit Claimed(token, tba, to, amount);
    }

    function collectFee(address token, address to, uint256 amount) external onlyAuthorizedExecutor{
        if (msg.sender != feeCollector) revert UnauthorizedCaller(msg.sender);
        
        if(userCredit[feeCollector][token] < amount) revert InsufficientBalance(userCredit[feeCollector][token]);
        userCredit[feeCollector][token] -= amount;
        IERC20(token).safeTransfer(to, amount);

        emit CollectedFee(token, to, amount);
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