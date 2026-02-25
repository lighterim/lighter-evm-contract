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

    /**
     * @notice the ticket type
     * @dev the ticket type GENESIS1 is used to identify the user group for genesis1
     * @dev the ticket type GENESIS2 is used to identify the user group for genesis2
     * @dev the ticket type LIGHTER_USER is used to identify the user group for lighter user
     */
    enum TicketType {
        GENESIS1, // the user group for genesis1
        GENESIS2, // the user group for genesis2
        LIGHTER_USER // the user group for lighter user
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
        uint256 clientId;
        uint256 accumulatedUsd;
        uint32 completedRatioBp;
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
        uint32 paidSeconds;
        uint32 releaseSeconds;
        uint64 cancelTs;
        uint64 lastActionTs;
    }

    struct ResolvedResult {
        bytes32 escrowHash;
        uint16 buyerThresholdBp;
    }

    struct PaymentMethodConfig {
        uint32 windowSeconds;
        uint32 disputeWindowSeconds;
        bool isEnabled;
    }

    struct PaymentDetails {
        bytes32 paymentId;
        bytes32 method;
        bytes32 currency;
        bytes32 payeeDetails;
        uint256 amount;
    }

    /**
     * @notice User honor/reputation tracking structure
     * @dev Tracks transaction history, dispute records, and performance metrics for reputation system
     */
    struct Honour {
        /// @notice Accumulated transaction volume in USD
        uint256 accumulatedUsd;
        /// @notice Total number of completed transactions (excludes cancelled, includes disputed)
        uint32 count;
        /// @notice Number of pending (in-progress) transactions
        uint32 pendingCount;
        /// @notice Number of cancelled transactions (typically by buyer)
        uint32 cancelledCount;
       

        /**
         * @dev PASSIVE DISPUTES (Incoming):
         * Number of times a counterparty has opened a dispute against this user.
         */
        /// @notice Number of disputes received as buyer (when current user's role is buyer)
        uint32 disputesReceivedAsBuyer;
        /// @notice Number of disputes received as seller (when current user's role is seller)
        uint32 disputesReceivedAsSeller;
        /// @notice Total number of adverse rulings against the current user in dispute resolutions
        uint32 totalAdverseRulings;

        /**
         * @dev ACTIVE DISPUTES (Outgoing):
         * Number of times this user has initiated a dispute process against a counterparty.
         */
        /// @notice Times this user initiated a dispute while acting as a Buyer
        uint32 disputesInitiatedAsBuyer;
        /// @notice Times this user initiated a dispute while acting as a Seller
        uint32 disputesInitiatedAsSeller;
        /// @notice Number of disputes initiated by this user that were ruled in favor of the counterparty
        uint32 failedInitiations;
        

        /// @notice Average release time in seconds (from payment to release completion)
        uint32 avgReleaseSeconds;
        /// @notice Average payment time in seconds
        uint32 avgPaidSeconds;
    }

}
