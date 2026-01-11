// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;


import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {ISignatureTransfer} from "@uniswap/permit2/interfaces/ISignatureTransfer.sol";
import {IAllowanceHolder} from "../../allowanceholder/IAllowanceHolder.sol";
import {MainnetMixin} from "./Common.sol";
import {SettlerWaypoint} from "../../SettlerWaypoint.sol";
import {ISettlerActions} from "../../ISettlerActions.sol";
import {IPaymentMethodRegistry} from "../../interfaces/IPaymentMethodRegistry.sol";


import {SettlerAbstract} from "../../SettlerAbstract.sol";
import {SettlerBase} from "../../SettlerBase.sol";
import {ISettlerBase} from "../../interfaces/ISettlerBase.sol";
import {Context} from "../../Context.sol";
import {IEscrow} from "../../interfaces/IEscrow.sol";
import {LighterAccount} from "../../account/LighterAccount.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import {ParamsHash} from "../../utils/ParamsHash.sol";
import {UnauthorizedCaller, InvalidArbitratorTicket, InvalidArbitratorSignature} from "../../core/SettlerErrors.sol";


contract MainnetWaypoint is MainnetMixin, SettlerWaypoint, EIP712 {

    using ParamsHash for ISettlerBase.EscrowParams;

    constructor(
        address lighterRelayer, IEscrow escrow, LighterAccount lighterAccount, 
        IPaymentMethodRegistry paymentMethodRegistry, bytes20 gitCommit
        )
        MainnetMixin(lighterRelayer, escrow, lighterAccount, paymentMethodRegistry, gitCommit)
        EIP712("MainnetWaypoint", "1")
    {
    } 

    function getDomainSeparator() public view returns (bytes32) {
        return _domainSeparatorV4();
    }

    /**
     * @dev Returns the EIP-712 domain separator for this contract
     */
    function _domainSeparator() internal view override returns (bytes32) {
        return _domainSeparatorV4();
    }

    function getEscrowTypedHash(ISettlerBase.EscrowParams memory params) public view returns (bytes32){
        bytes32 escrowHash = params.hash();
        return _hashTypedDataV4(escrowHash);
    }

    /**
     * The payment has been made by the buyer
     * @param sender sender
     * @param escrowParams escrow parameters
     */
    function _madePayment(address sender, ISettlerBase.EscrowParams memory escrowParams, bytes memory sig) internal virtual override{
        (bytes32 escrowHash,) = makesureEscrowParams(_domainSeparator(), escrowParams, sig);
        if(!lighterAccount.isOwnerCall(escrowParams.buyer, sender)) revert UnauthorizedCaller(sender);

        ISettlerBase.PaymentMethodConfig memory cfg = _getPaymentMethodConfig(escrowParams.paymentMethod);
        escrow.paid(escrowHash, escrowParams.id, escrowParams.token, escrowParams.buyer, cfg.windowSeconds);
    }

    /**
     * The seller requests to cancel the escrow
     * @param sender sender
     * @param escrowParams escrow parameters
     */
    function _requestCancelBySeller(address sender, ISettlerBase.EscrowParams memory escrowParams, bytes memory sig) internal virtual override{
        (bytes32 escrowHash,) = makesureEscrowParams(_domainSeparator(), escrowParams, sig);
        if(!lighterAccount.isOwnerCall(escrowParams.seller, sender)) revert UnauthorizedCaller(sender);

        ISettlerBase.PaymentMethodConfig memory cfg = _getPaymentMethodConfig(escrowParams.paymentMethod);
        escrow.requestCancel(escrowHash, escrowParams.id, escrowParams.token, escrowParams.buyer, escrowParams.seller, cfg.windowSeconds);
    }

    /**
     * The buyer cancels the escrow
     * @param sender sender
     * @param escrowParams escrow parameters
     */
    function _cancelByBuyer(address sender, ISettlerBase.EscrowParams memory escrowParams, bytes memory sig) internal virtual override{
        (bytes32 escrowHash,) = makesureEscrowParams(_domainSeparator(), escrowParams, sig);
        if(!lighterAccount.isOwnerCall(escrowParams.buyer, sender)) revert UnauthorizedCaller(sender);
        
        escrow.cancelByBuyer(escrowHash, escrowParams.id, escrowParams.token, escrowParams.buyer, escrowParams.seller);

    }

    /**
     * The seller cancels the escrow
     * @param sender sender
     * @param escrowParams escrow parameters
     */
    function _cancelBySeller(address sender, ISettlerBase.EscrowParams memory escrowParams, bytes memory sig) internal virtual override{
        (bytes32 escrowHash,) = makesureEscrowParams(_domainSeparator(), escrowParams, sig);
        if(!lighterAccount.isOwnerCall(escrowParams.seller, sender)) revert UnauthorizedCaller(sender);
        
        ISettlerBase.PaymentMethodConfig memory cfg = _getPaymentMethodConfig(escrowParams.paymentMethod);
        uint256 sellerFee = getFeeAmount(escrowParams.volume, escrowParams.sellerFeeRate);
        escrow.cancel(
            escrowHash, escrowParams, sellerFee, cfg.windowSeconds
        );
        lighterAccount.cancelPendingTx(escrowParams.seller, false);
        lighterAccount.cancelPendingTx(escrowParams.buyer, true);
    }

    /**
     * The buyer disputes the escrow
     * @param sender sender
     * @param escrowParams escrow parameters
     */
    function _disputeByBuyer(address sender, ISettlerBase.EscrowParams memory escrowParams, bytes memory sig) internal virtual override{
        (bytes32 escrowHash,) = makesureEscrowParams(_domainSeparator(), escrowParams, sig);
        if(!lighterAccount.isOwnerCall(escrowParams.buyer, sender)) revert UnauthorizedCaller(sender);
        
        escrow.dispute(escrowHash, escrowParams.id, escrowParams.token, escrowParams.buyer, escrowParams.seller, ISettlerBase.EscrowStatus.BuyerDisputed);
        
        lighterAccount.disputePendingTx(escrowParams.buyer, escrowParams.seller, true);
    }

    /**
     * The seller disputes the escrow
     * @param sender sender
     * @param escrowParams escrow parameters
     */
    function _disputeBySeller(address sender, ISettlerBase.EscrowParams memory escrowParams, bytes memory sig) internal virtual override{
        (bytes32 escrowHash,) = makesureEscrowParams(_domainSeparator(), escrowParams, sig);
        if(!lighterAccount.isOwnerCall(escrowParams.seller, sender)) revert UnauthorizedCaller(sender);

        escrow.dispute(escrowHash, escrowParams.id, escrowParams.token, escrowParams.buyer, escrowParams.seller, ISettlerBase.EscrowStatus.SellerDisputed);

        lighterAccount.disputePendingTx(escrowParams.buyer, escrowParams.seller, false);

    }

    function _releaseBySeller(address sender, ISettlerBase.EscrowParams memory escrowParams, bytes memory sig) internal virtual override{
        (bytes32 escrowHash,) = makesureEscrowParams(_domainSeparator(), escrowParams, sig);
        if(!lighterAccount.isOwnerCall(escrowParams.seller, sender)) revert UnauthorizedCaller(sender);

        uint256 sellerFee = getFeeAmount(escrowParams.volume, escrowParams.sellerFeeRate);
        uint256 buyerFee = getFeeAmount(escrowParams.volume, escrowParams.buyerFeeRate);

        (uint32 paidSeconds, uint32 releaseSeconds) = escrow.releaseBySeller(
            escrowHash, escrowParams.id, escrowParams.token, escrowParams.buyer, buyerFee, 
            escrowParams.seller, sellerFee, escrowParams.volume
        );

        uint8 tokenDecimals = IERC20(escrowParams.token).decimals();
        uint256 amountUsd = _calcAmountUsd(escrowParams.volume, tokenDecimals, escrowParams.price, escrowParams.usdRate);
        lighterAccount.releasePendingTx(escrowParams.buyer, escrowParams.seller, amountUsd, paidSeconds, releaseSeconds);
    }
    
    function _resolve(
        address sender, 
        ISettlerBase.EscrowParams memory escrowParams, 
        uint16 buyerThresholdBp, 
        address tbaArbitrator, 
        bytes memory sig, 
        bytes memory arbitratorSig, 
        bytes memory counterpartySig
    ) internal virtual override{
        if(lighterAccount.getTicketType(tbaArbitrator) != ISettlerBase.TicketType.GENESIS2) revert InvalidArbitratorTicket();
        (bytes32 escrowHash, bytes32 escrowTypedHash) = makesureEscrowParams(_domainSeparator(), escrowParams, sig);
        if(!isValidSignature(tbaArbitrator, escrowTypedHash, arbitratorSig)) revert InvalidArbitratorSignature();
        if(
            !lighterAccount.isOwnerCall(escrowParams.buyer, sender) 
            && !lighterAccount.isOwnerCall(escrowParams.seller, sender)
            && !lighterAccount.isOwnerCall(tbaArbitrator, sender)
        ) revert UnauthorizedCaller(sender);

        uint32 disputeWindowSeconds = paymentMethodRegistry.getPaymentMethodConfig(escrowParams.paymentMethod).disputeWindowSeconds;
        uint256 sellerFee = getFeeAmount(escrowParams.volume, escrowParams.sellerFeeRate);
        uint256 buyerFee = getFeeAmount(escrowParams.volume, escrowParams.buyerFeeRate);
        bool isDisputedByBuyer = escrow.resolve(
            escrowHash, escrowParams, 
            buyerFee, sellerFee,
            disputeWindowSeconds,
            buyerThresholdBp, tbaArbitrator, escrowTypedHash, counterpartySig
        );

        uint256 buyerAmount = 0;
        uint256 sellerAmount = 0;
        bool isBuyerLoseDispute = true;
        bool isSellerLoseDispute = true;
        uint8 tokenDecimals = IERC20(escrowParams.token).decimals();
        uint256 amountUsd = _calcAmountUsd(escrowParams.volume, tokenDecimals, escrowParams.price, escrowParams.usdRate);
        if(buyerThresholdBp >= BASIS_POINTS_BASE) {
            buyerAmount = amountUsd;
            isBuyerLoseDispute = false;
        } else {
            if(buyerThresholdBp == 0) {
                sellerAmount = amountUsd;
                isSellerLoseDispute = false;
            } else {
                buyerAmount = amountUsd * buyerThresholdBp / BASIS_POINTS_BASE;
                sellerAmount = amountUsd - buyerAmount;
                if(isDisputedByBuyer) {
                    isBuyerLoseDispute = false;
                } else {
                    isSellerLoseDispute = false;
                }
            }
        }
        
        lighterAccount.resolvePendingTx(escrowParams.buyer, buyerAmount, isBuyerLoseDispute);
        lighterAccount.resolvePendingTx(escrowParams.seller, sellerAmount, isSellerLoseDispute);
    }

    /**
     * @notice Calculates the USD value of a given token amount.
     * @dev Formula: (tokenAmount * price * usdRate) / 10^(tokenDecimals + PRICE_DECIMALS + USD_RATE_DECIMALS - USD_DECIMALS)
     * @param tokenAmount The raw amount of the token (in its smallest unit)
     * @param tokenDecimals The decimals of the token
     * @param price The price of the token (scaled by PRICE_DECIMALS)
     * @param usdRate The conversion rate to USD (scaled by USD_RATE_DECIMALS)
     * @return amountUsd The total value in USD (scaled by USD_DECIMALS)
     */
    function _calcAmountUsd(
        uint256 tokenAmount,
        uint8 tokenDecimals,
        uint256 price,
        uint256 usdRate
    ) internal pure returns (uint256 amountUsd) {
        // Optimization: Calculate the shared exponent once.
        // Small uint8 operations are safe from overflow in this context.
        uint256 exponent;
        unchecked {
            exponent = uint256(tokenDecimals) + PRICE_DECIMALS + USD_RATE_DECIMALS - USD_DECIMALS;
        }

        amountUsd = (tokenAmount * price * usdRate) / (10 ** exponent);
    }
}