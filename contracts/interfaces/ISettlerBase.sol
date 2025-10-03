// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {IERC20} from "forge-std/interfaces/IERC20.sol";

interface ISettlerBase {

    struct Range {
        uint256 min;                                // Minimum value
        uint256 max;                                // Maximum value
    }

    struct IntentParams {
        IERC20 token;
        Range range;
        uint64 expiryTime;
        bytes32 currency;
        bytes32 paymentMethod;
        bytes32 payeeDetails;           // payee details(payee id and account) for payment method
        uint256 price;
    }
    
    struct EscrowParams {
        uint256 id;
        IERC20 token;
        uint256 volume;
        uint256 price;
        uint256 usdRate;

        address seller;
        address sellerFeeRate;
        bytes32 paymentMethod;
        bytes32 currency;        
        bytes32 payeeId;
        bytes32 payeeAccount;

        address buyer;
        address buyerFeeRate;
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

}
