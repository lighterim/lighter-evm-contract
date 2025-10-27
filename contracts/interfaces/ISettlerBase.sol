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

}
