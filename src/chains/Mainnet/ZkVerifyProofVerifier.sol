pragma solidity ^0.8.20;

import {IVerifyProofAggregation} from "../../interfaces/IVerifyProofAggregation.sol";
import {IProofVerifier} from "../../interfaces/IProofVerifier.sol";
import {IEscrow} from "../../interfaces/IEscrow.sol";
import {ISettlerBase} from "../../interfaces/ISettlerBase.sol";
// import {MainnetUserTxn} from "./UserTxn.sol";
import {InvalidSender, InvalidZkProof, InvalidPayment, InvalidPaymentId} from "../../core/SettlerErrors.sol";
import {ParamsHash} from "../../utils/ParamsHash.sol";


contract ZkVerifyProofVerifier is IProofVerifier {

    using ParamsHash for ISettlerBase.EscrowParams;

    address public zkVerify;
    IEscrow escrow;
    // MainnetUserTxn userTxn;
    mapping(bytes32 => mapping(bytes32 => bool)) internal submittedTx;


    constructor(IEscrow _escrow, address _zkVerify){
        zkVerify = _zkVerify;
        escrow = _escrow;
        // userTxn = _userTxn;
    }

    function releaseAfterProofVerify(
        ISettlerBase.EscrowParams calldata escrowParams, 
        ISettlerBase.PaymentDetails calldata payment,
        ZkVerifyProof calldata zkProof,
        bytes calldata sig
    ) external returns (bool){
        if(submittedTx[payment.method][payment.paymentId]) revert InvalidPaymentId();
        submittedTx[payment.method][payment.paymentId] = true;
        // bytes32 escrowTypedHash = userTxn.makesureEscrowParams(escrowParams, sig);
        if(escrowParams.buyer != msg.sender) revert InvalidSender();
        if(escrowParams.paymentMethod != payment.method 
        || escrowParams.currency != payment.currency 
        || escrowParams.payeeDetails != payment.payeeDetails) revert InvalidPayment();
        bool isValid = IVerifyProofAggregation(zkVerify).verifyProofAggregation(
            zkProof.domainId,
            zkProof.aggregationId,
            zkProof.leaf,
            zkProof.merklePath,
            zkProof.leafCount,
            zkProof.index
        );
        if(!isValid) revert InvalidZkProof();

        escrow.releaseByVerifier(
            bytes32(""), 
            escrowParams.id, 
            address(escrowParams.token), 
            escrowParams.buyer, 
            escrowParams.seller, 
            escrowParams.volume
            );
        return true;
    }


    
}