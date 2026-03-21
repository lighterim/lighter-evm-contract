// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {ISettlerBase} from "./ISettlerBase.sol";

interface ITlsnProofVerifier {
    
    function releaseAfterProofVerify(
        ISettlerBase.EscrowParams calldata escrowParams, 
        ISettlerBase.PaymentDetails calldata paymentParams,
        bytes calldata tlsnProofSig,
        bytes calldata sig
    ) external returns (bool);
}