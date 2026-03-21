// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";

import {TlsnProofVerifier} from "../../TlsnProofVerifier.sol";
import {IEscrow} from "../../interfaces/IEscrow.sol";
import {LighterAccount} from "../../account/LighterAccount.sol";
import {ISettlerBase} from "../../interfaces/ISettlerBase.sol";
import {ParamsHash} from "../../utils/ParamsHash.sol";
import {InvalidNullifier, InvalidPaymentMethod} from "../../core/SettlerErrors.sol";




contract WiseTlsnProofVerifier is TlsnProofVerifier {

    using ParamsHash for ISettlerBase.EscrowParams;

    bytes32 public constant PAYMENT_METHOD = bytes32("wise");

    mapping(bytes32 => bool) internal nullifiers;


    constructor( LighterAccount lighterAccount, address tlsnWitness, IEscrow escrow, address lighterRelayer, bytes20 gitCommit) 
    TlsnProofVerifier(tlsnWitness, lighterAccount, escrow, lighterRelayer, gitCommit)
    EIP712("WiseTlsnProofVerifier", "1") {
    }

    function _domainSeparator() internal view override returns (bytes32) {
        return _domainSeparatorV4();
    }

    function getDomainSeparator() public view returns (bytes32) {
        return _domainSeparatorV4();
    }

    function getEscrowTypedHash(ISettlerBase.EscrowParams memory params) public view returns (bytes32){
        bytes32 escrowHash = params.hash();
        return _hashTypedDataV4(escrowHash);
    }

    function _checkNullifier(bytes32 paymentId) internal view override {
        bytes32 nullifier = _hashNullifier(PAYMENT_METHOD, paymentId);
        if(nullifiers[nullifier]) revert InvalidNullifier();
    }

    function _nullifier(bytes32 paymentId) internal override {
        bytes32 nullifier = _hashNullifier(PAYMENT_METHOD, paymentId);
        nullifiers[nullifier] = true;
    }

    function _makesurePaymentParams(ISettlerBase.PaymentDetails calldata paymentParams) internal view override returns (ISettlerBase.PaymentDetails memory) {
        if(paymentParams.paymentMethod != PAYMENT_METHOD) revert InvalidPaymentMethod();
        return paymentParams;
    }

    modifier finalize(address sender, ISettlerBase.EscrowParams memory escrowParams) override {
        _;
    }
}