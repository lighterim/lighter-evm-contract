// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {ISettlerBase} from "./ISettlerBase.sol";

interface IProofVerifier{

    struct ZkVerifyProof{
        uint256 domainId;
        uint256 aggregationId;
        uint256 index;
        bytes32 leaf;
        uint256 leafCount;
        bytes32[] merklePath;
    }

    function releaseAfterProofVerify(
        ISettlerBase.EscrowParams calldata escrowParams, 
        ISettlerBase.PaymentDetails calldata payment,
        ZkVerifyProof calldata zkProof,
        bytes calldata sig
    ) external returns (bool);
}