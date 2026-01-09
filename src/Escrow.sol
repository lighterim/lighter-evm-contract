// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;


import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {SignatureChecker} from "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";

import {IEscrow} from "./interfaces/IEscrow.sol";
import {ISettlerBase} from "./interfaces/ISettlerBase.sol";
import {SafeTransferLib} from "./vendor/SafeTransferLib.sol";
import {FullMath} from "./vendor/FullMath.sol";
import {LighterAccount} from "./account/LighterAccount.sol";
import {
    EscrowAlreadyExists, EscrowNotExists, InvalidEscrowStatus, InsufficientBalance, 
    TokenNotWhitelisted, UnauthorizedCreator, UnauthorizedExecutor, UnauthorizedVerifier, 
    UnauthorizedCaller, CancelWithinWindow, SellerCancelWithinWindow, InvalidCounterpartySignature,
    ZeroAddress
    } from "./core/SettlerErrors.sol";


contract Escrow is Ownable, Pausable, IEscrow, ReentrancyGuard{

    using SafeTransferLib for IERC20;
    using FullMath for uint256;

    /// @notice Basis points base (10000 = 100%)
    uint256 public constant BASIS_POINTS_BASE = 10000;

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

    constructor(LighterAccount lighterAccount_, address feeCollector_) Ownable(msg.sender) {
        if(feeCollector_ == address(0)) revert ZeroAddress();

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
        uint256 sellerAmount = amount + sellerFee;
        sellerEscrow[seller][token] += sellerAmount;

        emit Created(token, buyer, seller, escrowHash, id, amount);
    }

    function paid(bytes32 escrowHash, uint256 id, address token, address buyer, uint32 paymentWindowSeconds) external onlyAuthorizedExecutor {
        uint64 lastActionTs = allEscrow[escrowHash].lastActionTs;
        if(lastActionTs == 0) revert EscrowNotExists(escrowHash);
        ISettlerBase.EscrowStatus status = allEscrow[escrowHash].status;
        if(_invalidStatusForPaid(status)) revert InvalidEscrowStatus(escrowHash, status);
        
        uint64 timestamp = uint64(block.timestamp);
        uint32 paidSeconds = uint32(timestamp - lastActionTs);
        if(status == ISettlerBase.EscrowStatus.SellerRequestCancel){
            paidSeconds += paymentWindowSeconds;
        }
        _setStatus(escrowHash, timestamp, ISettlerBase.EscrowStatus.Paid, paidSeconds, 0, 0);

        emit Paid(token, buyer, escrowHash, paidSeconds, id);
    }

    function _invalidStatusForPaid(ISettlerBase.EscrowStatus status) private pure returns (bool) {
        return !(status == ISettlerBase.EscrowStatus.Escrowed || status == ISettlerBase.EscrowStatus.SellerRequestCancel);
    }

    function releaseByVerifier(
        bytes32 escrowHash, uint256 id, address token, address buyer, uint256 buyerFee, address seller, 
        uint256 sellerFee, uint256 amount
        ) external nonReentrant onlyAuthorizedVerifier returns (uint32 paidSeconds, uint32 releaseSeconds) {

        ISettlerBase.EscrowStatus status = allEscrow[escrowHash].status;
        if(status != ISettlerBase.EscrowStatus.Escrowed) revert InvalidEscrowStatus(escrowHash, status);
        (paidSeconds, releaseSeconds) = _release(
            escrowHash, id, token, buyer, buyerFee, seller, sellerFee, amount, 
            ISettlerBase.EscrowStatus.ThresholdReachedReleased
        );
    }

    function releaseBySeller(
        bytes32 escrowHash, uint256 id, address token, address buyer, uint256 buyerFee,
        address seller, uint256 sellerFee, uint256 amount
        ) external nonReentrant onlyAuthorizedExecutor returns (uint32 paidSeconds, uint32 releaseSeconds) {

        ISettlerBase.EscrowStatus status = allEscrow[escrowHash].status;
        if(status != ISettlerBase.EscrowStatus.Paid) revert InvalidEscrowStatus(escrowHash, status);

        (paidSeconds, releaseSeconds) = _release(
            escrowHash, id, token, buyer, buyerFee, seller, sellerFee, amount, 
            ISettlerBase.EscrowStatus.SellerReleased
        );
    }

    function _release(bytes32 escrowHash, uint256 id, address token, 
        address buyer, uint256 buyerFee, address seller, uint256 sellerFee, uint256 amount, 
        ISettlerBase.EscrowStatus status) private returns (uint32 paidSeconds, uint32 releaseSeconds) {

        uint64 currentTs = uint64(block.timestamp);
        ISettlerBase.EscrowData storage escrowData = allEscrow[escrowHash];
        uint64 lastActionTs = escrowData.lastActionTs;
        uint sellerAmount = amount + sellerFee;
        uint buyerAmount = amount - buyerFee;
        uint feeAmount = buyerFee + sellerFee;
        
        paidSeconds = escrowData.paidSeconds;
        releaseSeconds = paidSeconds > 0 ? uint32(currentTs - lastActionTs) : 0;
        
        escrowData.status = status;
        escrowData.lastActionTs = currentTs;
        escrowData.releaseSeconds = releaseSeconds;
        
        sellerEscrow[seller][token] -= sellerAmount;
        userCredit[buyer][token] += buyerAmount;
        userCredit[feeCollector][token] += feeAmount;

        emit Released(token, buyer, seller, escrowHash, id, amount, status);
    }

    function requestCancel(bytes32 escrowHash, uint256 id, address token, address buyer, address seller, uint256 windowSeconds) external onlyAuthorizedExecutor{

        uint64 lastActionTs = allEscrow[escrowHash].lastActionTs;
        if(lastActionTs == 0) revert EscrowNotExists(escrowHash);

        ISettlerBase.EscrowStatus status = allEscrow[escrowHash].status;
        if(status != ISettlerBase.EscrowStatus.Escrowed) revert InvalidEscrowStatus(escrowHash, status);
        
        uint256 canCancelTs = lastActionTs + windowSeconds;
        if(block.timestamp < canCancelTs) revert CancelWithinWindow(canCancelTs);
        
        uint64 currentTs = uint64(block.timestamp);
        _setStatus(escrowHash, currentTs, ISettlerBase.EscrowStatus.SellerRequestCancel, 0, 0, currentTs);
        
        emit RequestCancelled(token, buyer, seller, escrowHash, id);
    }

    function cancelByBuyer(bytes32 escrowHash, uint256 id, address token, address buyer, address seller) external onlyAuthorizedExecutor{
        if(allEscrow[escrowHash].lastActionTs == 0) revert EscrowNotExists(escrowHash);
        ISettlerBase.EscrowStatus status = allEscrow[escrowHash].status;
        if(status != ISettlerBase.EscrowStatus.Escrowed) revert InvalidEscrowStatus(escrowHash, status);
        
        uint64 currentTs = uint64(block.timestamp);
        _setStatus(escrowHash, currentTs, ISettlerBase.EscrowStatus.BuyerCancelled, 0, 0, currentTs);

        emit CancelledByBuyer(token, buyer, seller, escrowHash, id);
    }

    function cancel(
        bytes32 escrowHash, ISettlerBase.EscrowParams memory escrowParams, 
        uint256 sellerFee, uint256 windowSeconds
    ) external onlyAuthorizedExecutor nonReentrant{
        ISettlerBase.EscrowStatus status = allEscrow[escrowHash].status;
        if(
            status != ISettlerBase.EscrowStatus.BuyerCancelled 
            && status != ISettlerBase.EscrowStatus.SellerRequestCancel
        ) revert InvalidEscrowStatus(escrowHash, status);
        
        if(status == ISettlerBase.EscrowStatus.SellerRequestCancel){
            uint256 canCancelTs = windowSeconds + allEscrow[escrowHash].cancelTs;
            if(block.timestamp < canCancelTs) revert SellerCancelWithinWindow(canCancelTs);
        }
        
        uint256 refundAmount = escrowParams.volume + sellerFee;
        sellerEscrow[escrowParams.seller][escrowParams.token] -= refundAmount;
        IERC20(escrowParams.token).safeTransfer(escrowParams.payer, refundAmount);

        _setStatus(escrowHash, uint64(block.timestamp), ISettlerBase.EscrowStatus.SellerCancelled, 0, 0, 0);

        emit Cancelled(escrowParams.token, escrowParams.buyer, escrowParams.seller, escrowHash, escrowParams.id, escrowParams.volume);
    }

    function dispute(
        bytes32 escrowHash, uint256 id, address token, address buyer, address seller, 
        ISettlerBase.EscrowStatus targetStatus) external onlyAuthorizedExecutor{
        ISettlerBase.EscrowStatus status = allEscrow[escrowHash].status;
        if(
            status != ISettlerBase.EscrowStatus.Paid 
            || (
                targetStatus != ISettlerBase.EscrowStatus.BuyerDisputed 
                && targetStatus != ISettlerBase.EscrowStatus.SellerDisputed
            )
        ) revert InvalidEscrowStatus(escrowHash, status);
        
        _setStatus(escrowHash, uint64(block.timestamp), targetStatus, 0, 0, 0);
        
        if(targetStatus == ISettlerBase.EscrowStatus.BuyerDisputed) {
            emit DisputedByBuyer(token, buyer, seller, escrowHash, id);
        } else {
            emit DisputedBySeller(token, buyer, seller, escrowHash, id);
        }
    }

    function resolve(
        bytes32 escrowHash, ISettlerBase.EscrowParams memory escrowParams,
        uint256 buyerFee, uint256 sellerFee,
        uint16 buyerThresholdBp, address tbaArbitrator, bytes32 escrowTypedHash, bytes memory counterpartySig
    ) external onlyAuthorizedExecutor returns(bool isDisputedByBuyer){
        ISettlerBase.EscrowStatus status = allEscrow[escrowHash].status;
        if(
            status != ISettlerBase.EscrowStatus.BuyerDisputed
            && status != ISettlerBase.EscrowStatus.SellerDisputed
        ) revert InvalidEscrowStatus(escrowHash, status);
        if(
            status == ISettlerBase.EscrowStatus.BuyerDisputed 
            && !SignatureChecker.isValidSignatureNow(escrowParams.seller, escrowTypedHash, counterpartySig)
        ) revert InvalidCounterpartySignature();
        if (
            status == ISettlerBase.EscrowStatus.SellerDisputed 
            && !SignatureChecker.isValidSignatureNow(escrowParams.buyer, escrowTypedHash, counterpartySig)
        ) revert InvalidCounterpartySignature();

        isDisputedByBuyer = status == ISettlerBase.EscrowStatus.BuyerDisputed;

        sellerEscrow[escrowParams.seller][escrowParams.token] -= (escrowParams.volume + sellerFee);
        userCredit[tbaArbitrator][escrowParams.token] += sellerFee;
        if(buyerThresholdBp == 0){
            IERC20(escrowParams.token).safeTransfer(escrowParams.payer, escrowParams.volume);
        }
        else {
            userCredit[feeCollector][escrowParams.token] += buyerFee;
            uint256 buyerAmount = escrowParams.volume - buyerFee;
            if(buyerThresholdBp >= BASIS_POINTS_BASE){
                userCredit[escrowParams.buyer][escrowParams.token] += buyerAmount;
            }
            else{
                uint256 buyerResolveAmount = buyerAmount * buyerThresholdBp / BASIS_POINTS_BASE;
                userCredit[escrowParams.payer][escrowParams.token] += buyerResolveAmount;
                IERC20(escrowParams.token).safeTransfer(escrowParams.payer, buyerAmount - buyerResolveAmount);
            }
        }
        _setStatus(escrowHash, uint64(block.timestamp), ISettlerBase.EscrowStatus.Resolved, 0, 0, 0);

        emit Resolved(escrowParams.token, escrowParams.buyer, escrowParams.seller, escrowHash, escrowParams.id, tbaArbitrator, buyerThresholdBp);
    }

    function _setStatus(bytes32 escrowHash, uint64 timestamp, ISettlerBase.EscrowStatus status, uint32 paidSeconds, uint32 releaseSeconds, uint64 cancelTs) private {
        allEscrow[escrowHash].lastActionTs = timestamp;
        allEscrow[escrowHash].status = status;
        if(paidSeconds > 0) allEscrow[escrowHash].paidSeconds = paidSeconds;
        if(releaseSeconds > 0) allEscrow[escrowHash].releaseSeconds = releaseSeconds;
        if(cancelTs > 0) allEscrow[escrowHash].cancelTs = cancelTs;
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