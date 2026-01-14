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

/**
 * @title Escrow contract
 * @author Dust
 * @notice This contract is used to create, manage and release escrows.
   stateDiagram-v2
    [*] --> Escrowed
    
    Escrowed --> Paid: Buyer Paid
    Paid --> SellerReleased: Seller Manual Release
    Escrowed --> ThresholdReachedReleased: Auto Release (zkVerify/horizen)
    
    %% Cancel path
    Escrowed --> SellerRequestCancel: Buyer timeout / Seller Request
    SellerRequestCancel --> Paid: Buyer insisted
    SellerRequestCancel --> BuyerCancelled: Buyer acknowledges
    SellerRequestCancel --> SellerCancelled: Buyer timeout
    
    Escrowed --> BuyerCancelled: Buyer active cancel
    BuyerCancelled --> SellerCancelled: Finalize
    
    %% Dispute path
    Paid --> BuyerDisputed: Dispute initiated
    Paid --> SellerDisputed: Dispute initiated
    
    %% Improved Resolution Logic
    state Resolution_Process {
        [*] --> Arbitrated: Arbitrator signs
        Arbitrated --> Resolved: Counterparty signs (Immediate)
        Arbitrated --> Resolved: Timelock Expires (Configurable T)
    }
    
    BuyerDisputed --> Resolution_Process
    SellerDisputed --> Resolution_Process
    
    %% Final states
    SellerReleased --> [*]
    ThresholdReachedReleased --> [*]
    SellerCancelled --> [*]
    Resolved --> [*]
 */
contract Escrow is Ownable, Pausable, IEscrow, ReentrancyGuard{

    using SafeTransferLib for IERC20;
    using FullMath for uint256;

    /// @notice Basis points base (10000 = 100%)
    uint256 constant BASIS_POINTS_BASE = 10000;

    LighterAccount immutable lighterAccount;
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
        if(escrowData.status != ISettlerBase.EscrowStatus.Escrowed) revert InvalidEscrowStatus(escrowHash, escrowData.status);
        if(allEscrow[escrowHash].lastActionTs > 0) revert EscrowAlreadyExists(escrowHash);

        allEscrow[escrowHash] = escrowData;
        sellerEscrow[seller][token] += (amount + sellerFee);

        emit Created(token, buyer, seller, escrowHash, id, amount);
    }

    function paid(bytes32 escrowHash, uint256 id, address token, address buyer, uint32 paymentWindowSeconds) external onlyAuthorizedExecutor {
        ISettlerBase.EscrowData storage escrowData = allEscrow[escrowHash];
        uint64 lastActionTs = escrowData.lastActionTs;
        if(lastActionTs == 0) revert EscrowNotExists(escrowHash);

        ISettlerBase.EscrowStatus status = escrowData.status;
        if(status != ISettlerBase.EscrowStatus.Escrowed && status != ISettlerBase.EscrowStatus.SellerRequestCancel) {
            revert InvalidEscrowStatus(escrowHash, status);
        }
        
        uint64 timestamp = uint64(block.timestamp);
        // casting to 'uint32' is safe because difference between timestamps (both uint64)
        // will not exceed uint32 max (2^32 - 1 seconds ≈ 136 years), which is sufficient for escrow durations
        // forge-lint: disable-next-line(unsafe-typecast)
        uint32 paidSeconds = uint32(timestamp - lastActionTs);
        if(status == ISettlerBase.EscrowStatus.SellerRequestCancel){
            paidSeconds += paymentWindowSeconds;
        }
        _setStatus(escrowData, timestamp, ISettlerBase.EscrowStatus.Paid, paidSeconds, 0, 0);

        emit Paid(token, buyer, escrowHash, paidSeconds, id);
    }

    function releaseByVerifier(
        bytes32 escrowHash, uint256 id, address token, address buyer, uint256 buyerFee, address seller, 
        uint256 sellerFee, uint256 amount
        ) external nonReentrant onlyAuthorizedVerifier
        returns (uint32 paidSeconds, uint32 releaseSeconds) {

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
        ) external nonReentrant onlyAuthorizedExecutor 
        returns (uint32 paidSeconds, uint32 releaseSeconds) {
        ISettlerBase.EscrowStatus status = allEscrow[escrowHash].status;
        if(status != ISettlerBase.EscrowStatus.Paid) revert InvalidEscrowStatus(escrowHash, status);

        (paidSeconds, releaseSeconds) = _release(
            escrowHash, id, token, buyer, buyerFee, seller, sellerFee, amount, 
            ISettlerBase.EscrowStatus.SellerReleased
        );
    }

    function _release(bytes32 escrowHash, uint256 id, address token, 
        address buyer, uint256 buyerFee, address seller, uint256 sellerFee, uint256 amount, 
        ISettlerBase.EscrowStatus status) private 
        returns (uint32 paidSeconds, uint32 releaseSeconds) {
        ISettlerBase.EscrowData storage escrowData = allEscrow[escrowHash];
        uint64 lastActionTs = escrowData.lastActionTs;
        uint64 currentTs = uint64(block.timestamp);
        
        paidSeconds = escrowData.paidSeconds;
        // If paidSeconds is 0, the escrow was released directly via ThresholdReachedReleased without going through the Paid status. In this case, releaseSeconds is 0.
        // casting to 'uint32' is safe because time difference between timestamps (both uint64)
        // will not exceed uint32 max (2^32 - 1 seconds ≈ 136 years), which is sufficient for escrow durations
        // forge-lint: disable-next-line(unsafe-typecast)
        releaseSeconds = paidSeconds > 0 ? uint32(currentTs - lastActionTs) : 0;
        
        escrowData.status = status;
        escrowData.lastActionTs = currentTs;
        escrowData.releaseSeconds = releaseSeconds;
        
        uint256 buyerNet = amount - buyerFee;
        sellerEscrow[seller][token] -= (amount + sellerFee);
        userCredit[buyer][token] += buyerNet;
        userCredit[feeCollector][token] += (buyerFee + sellerFee);

        emit Released(token, buyer, seller, escrowHash, id, buyerNet, status);
    }

    function requestCancel(bytes32 escrowHash, uint256 id, address token, address buyer, address seller, uint256 windowSeconds) external onlyAuthorizedExecutor{
        ISettlerBase.EscrowData storage escrowData = allEscrow[escrowHash];
        uint64 lastActionTs = escrowData.lastActionTs;
        ISettlerBase.EscrowStatus status = allEscrow[escrowHash].status;

        if(lastActionTs == 0) revert EscrowNotExists(escrowHash);        
        if(status != ISettlerBase.EscrowStatus.Escrowed) revert InvalidEscrowStatus(escrowHash, status);
        
        uint256 canCancelTs = lastActionTs + windowSeconds;
        if(block.timestamp < canCancelTs) revert CancelWithinWindow(canCancelTs);
        
        uint64 currentTs = uint64(block.timestamp);
        _setStatus(escrowData, currentTs, ISettlerBase.EscrowStatus.SellerRequestCancel, 0, 0, currentTs);
        
        emit RequestCancelled(token, buyer, seller, escrowHash, id);
    }

    function cancelByBuyer(bytes32 escrowHash, uint256 id, address token, address buyer, address seller) external onlyAuthorizedExecutor{
        ISettlerBase.EscrowData storage escrowData = allEscrow[escrowHash];
        uint64 lastActionTs = escrowData.lastActionTs;
        ISettlerBase.EscrowStatus status = escrowData.status;
        if(lastActionTs == 0) revert EscrowNotExists(escrowHash);
        if(status != ISettlerBase.EscrowStatus.Escrowed && status != ISettlerBase.EscrowStatus.SellerRequestCancel) {
            revert InvalidEscrowStatus(escrowHash, status);
        }
    
        uint64 currentTs = uint64(block.timestamp);
        _setStatus(escrowData, currentTs, ISettlerBase.EscrowStatus.BuyerCancelled, 0, 0, currentTs);
        emit CancelledByBuyer(token, buyer, seller, escrowHash, id);
    }

    function cancel(
        bytes32 escrowHash, ISettlerBase.EscrowParams memory escrowParams, 
        uint256 sellerFee, uint256 windowSeconds
    ) external onlyAuthorizedExecutor nonReentrant{
        ISettlerBase.EscrowData storage escrowData = allEscrow[escrowHash];
        ISettlerBase.EscrowStatus status = escrowData.status;
        
        if(
            status != ISettlerBase.EscrowStatus.BuyerCancelled 
            && status != ISettlerBase.EscrowStatus.SellerRequestCancel
        ) revert InvalidEscrowStatus(escrowHash, status);
        
        if(status == ISettlerBase.EscrowStatus.SellerRequestCancel){
            uint256 canCancelTs = windowSeconds + escrowData.cancelTs;
            if(block.timestamp < canCancelTs) revert SellerCancelWithinWindow(canCancelTs);
        }
        
        uint256 refundAmount = escrowParams.volume + sellerFee;
        sellerEscrow[escrowParams.seller][escrowParams.token] -= refundAmount;
        escrowData.status = ISettlerBase.EscrowStatus.SellerCancelled;
        escrowData.lastActionTs = uint64(block.timestamp);
        
        IERC20(escrowParams.token).safeTransfer(escrowParams.payer, refundAmount);

        emit Cancelled(escrowParams.token, escrowParams.buyer, escrowParams.seller, escrowHash, escrowParams.id, escrowParams.volume);
    }

    function dispute(
        bytes32 escrowHash, uint256 id, address token, address buyer, address seller, 
        ISettlerBase.EscrowStatus targetStatus) external onlyAuthorizedExecutor{
        ISettlerBase.EscrowData storage escrowData = allEscrow[escrowHash];
        ISettlerBase.EscrowStatus status = escrowData.status;
        if(_invalidStatusForDispute(status, targetStatus)) revert InvalidEscrowStatus(escrowHash, status);
        
        _setStatus(escrowData, uint64(block.timestamp), targetStatus, 0, 0, 0);
        
        if(targetStatus == ISettlerBase.EscrowStatus.BuyerDisputed) {
            emit DisputedByBuyer(token, buyer, seller, escrowHash, id);
        } else {
            emit DisputedBySeller(token, buyer, seller, escrowHash, id);
        }
    }

    /**
     * @notice Invalid status for dispute
     * @dev The status is invalid if the status is not Paid or the target status is not BuyerDisputed or SellerDisputed
     * @param status The current status
     * @param targetStatus The target status
     * @return bool True if the status is invalid, false otherwise
     */
    function _invalidStatusForDispute(ISettlerBase.EscrowStatus status, ISettlerBase.EscrowStatus targetStatus) private pure returns (bool) {
        return status != ISettlerBase.EscrowStatus.Paid 
        || ( 
            targetStatus != ISettlerBase.EscrowStatus.BuyerDisputed 
            && targetStatus != ISettlerBase.EscrowStatus.SellerDisputed
        );
    }

    function resolve(
        bytes32 escrowHash,
        ISettlerBase.EscrowParams memory escrowParams,
        uint256 buyerFee, 
        uint256 sellerFee,
        uint32 disputeWindowSeconds,
        uint16 buyerThresholdBp, 
        address tbaArbitrator, 
        bytes32 escrowTypedHash, 
        bytes memory counterpartySig
    ) external onlyAuthorizedExecutor returns(bool isInitiatedByBuyer){

        ISettlerBase.EscrowData storage escrowData = allEscrow[escrowHash];
        ISettlerBase.EscrowStatus status = escrowData.status;
        if(
            status != ISettlerBase.EscrowStatus.BuyerDisputed
            && status != ISettlerBase.EscrowStatus.SellerDisputed
        ) revert InvalidEscrowStatus(escrowHash, status);

        isInitiatedByBuyer = (status == ISettlerBase.EscrowStatus.BuyerDisputed);
        uint256 currentTs = block.timestamp;
        uint64 lastActionTs = escrowData.lastActionTs;
        address token = escrowParams.token;
        uint256 volume = escrowParams.volume;
        address seller = escrowParams.seller;
        address buyer = escrowParams.buyer;

        // 1. Check time window first (Cheapest check - fails fast)
        if (currentTs < lastActionTs + disputeWindowSeconds) {
            // 2. Determine who the expected signer is based on dispute status
            // Logic: If Buyer disputed, we need Seller's sig. Otherwise, we need Buyer's sig.
            address expectedSigner = isInitiatedByBuyer ? seller : buyer;

            // 3. Verify signature (Most expensive check - performed only if time window is valid)
            if (!SignatureChecker.isValidSignatureNow(expectedSigner, escrowTypedHash, counterpartySig)) {
                revert InvalidCounterpartySignature();
            }
        }

        escrowData.status = ISettlerBase.EscrowStatus.Resolved;
        unchecked {
            // casting to 'uint64' is safe because block.timestamp (uint256) values are within uint64 range
            // until year 2106 (2^64 seconds ≈ 584 years), which is sufficient for all practical purposes
            // forge-lint: disable-next-line(unsafe-typecast)
            escrowData.lastActionTs = uint64(currentTs);
        }
        
        sellerEscrow[escrowParams.seller][token] -= (volume + sellerFee);
        userCredit[tbaArbitrator][token] += sellerFee;

        if(buyerThresholdBp == 0){
            IERC20(token).safeTransfer(escrowParams.payer, volume);
        }
        else {
            userCredit[feeCollector][token] += buyerFee;
            uint256 buyerNet = volume - buyerFee;
            if(buyerThresholdBp >= BASIS_POINTS_BASE){
                userCredit[buyer][token] += buyerNet;
            }
            else{
                uint256 buyerResolveAmount = buyerNet * buyerThresholdBp / BASIS_POINTS_BASE;
                userCredit[buyer][token] += buyerResolveAmount;
                IERC20(token).safeTransfer(escrowParams.payer, buyerNet - buyerResolveAmount);
            }
        }

        emit Resolved(token, buyer, seller, escrowHash, escrowParams.id, tbaArbitrator, buyerThresholdBp);
    }

    function _setStatus(
        ISettlerBase.EscrowData storage escrowData, 
        uint64 lastActionTs,
        ISettlerBase.EscrowStatus status, 
        uint32 paidSeconds, 
        uint32 releaseSeconds, 
        uint64 cancelTs) private {
        escrowData.lastActionTs = lastActionTs;
        escrowData.status = status;
        if(paidSeconds > 0) escrowData.paidSeconds = paidSeconds;
        if(releaseSeconds > 0) escrowData.releaseSeconds = releaseSeconds;
        if(cancelTs > 0) escrowData.cancelTs = cancelTs;
    }

    function claim(address token, address tba, address to, uint256 amount) external nonReentrant{
        if(!lighterAccount.isOwnerCall(tba, msg.sender)) revert UnauthorizedCaller(msg.sender);
        
        if(userCredit[tba][token] < amount) revert InsufficientBalance(userCredit[tba][token]);
        
        userCredit[tba][token] -= amount;
        IERC20(token).safeTransfer(to, amount);

        emit Claimed(token, tba, to, amount);
    }

    function collectFee(address token, address to, uint256 amount) external nonReentrant{
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