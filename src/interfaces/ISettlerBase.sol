// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

interface ISettlerBase {

    enum Stage{
        MANUAL,
        ZK_TLS,
        ZK_MAIL,
        OPT1,
        OPT2,
        OPT3
    }

    enum TicketType {
        GENESIS1,
        GENESIS2,
        LIGHTER_USER
    }

    struct Range {
        uint256 min;                                // Minimum value
        uint256 max;                                // Maximum value
    }

    struct IntentParams {
        address token;
        Range range;
        uint64 expiryTime;
        bytes32 currency;
        bytes32 paymentMethod;
        bytes32 payeeDetails;           // payee details(payee id and account) for payment method
        uint256 price;
    }
    
    struct EscrowParams {
        uint256 id;
        address token;
        uint256 volume;
        uint256 price;
        uint256 usdRate;

        address payer;
        address seller;
        uint256 sellerFeeRate;
        bytes32 paymentMethod;
        bytes32 currency;        
        bytes32 payeeDetails;

        address buyer;
        uint256 buyerFeeRate;
    }

    enum EscrowStatus {
        Escrowed,
        SellerRequestCancel,
        Paid,
        SellerCancelled,
        BuyerCancelled,
        BuyerDisputed,
        SellerDisputed,
        Resolved,
        ThresholdReachedReleased,
        SellerReleased
    }

    struct EscrowData{
        EscrowStatus status;
        uint64 paidSeconds;
        uint64 releaseSeconds;
        uint64 cancelTs;
        uint64 lastActionTs;
        uint256 gasSpentForBuyer;
        uint256 gasSpentForSeller;
    } 

    struct PaymentMethodConfig {
        uint32 windowSeconds;
        bool isEnabled;
    }

    struct PaymentDetails {
        bytes32 paymentId;
        bytes32 method;
        bytes32 currency;
        bytes32 payeeDetails;
        uint256 amount;
    }

    struct Honour {
        uint256 accumulatedUsd;
    
        uint32 count;
        uint32 pendingCount;
        uint32 cancelledCount;
        uint32 disputedAsBuyer;
        uint32 disputedAsSeller;
        uint32 lostDisputeCount;
        
        uint32 avgReleaseSeconds;
        uint32 avgPaidSeconds;
    }

}
