// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";

import {TlsnProofVerifier} from "../../TlsnProofVerifier.sol";
import {IEscrow} from "../../interfaces/IEscrow.sol";
import {LighterAccount} from "../../account/LighterAccount.sol";



contract PaymentTlsnProofVerifier is TlsnProofVerifier {

    bytes32 public immutable PAYMENT_METHOD;

    constructor( bytes32 paymentMethod, LighterAccount lighterAccount, address tlsnWitness, IEscrow escrow, address lighterRelayer, bytes20 gitCommit) 
    TlsnProofVerifier(tlsnWitness, lighterAccount, escrow, lighterRelayer, gitCommit)
    EIP712("PaymentTlsnProofVerifier", "1") {
        PAYMENT_METHOD = paymentMethod;
    }

    function _getPaymentMethod() internal view override returns (bytes32) {
        return PAYMENT_METHOD;
    }
}