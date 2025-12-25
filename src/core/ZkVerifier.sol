// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IVerifyProofAggregation} from "../interfaces/IVerifyProofAggregation.sol";

contract ZkVerifier {
    // zkVerify contract address
    address public zkVerify;

    // Constructor, initialize zkVerify contract address and verification key
    constructor(address _zkVerify) {
        zkVerify = _zkVerify;
    }

    // Verify aggregation proof
    function verifyAggregation(
        uint256 _domainId,
        uint256 _aggregationId,
        bytes32 _leaf,
        bytes32[] calldata _merklePath,
        uint256 _leafCount,
        uint256 _index
    ) external view returns (bool) {
        IVerifyProofAggregation verifier = IVerifyProofAggregation(zkVerify);
        return verifier.verifyProofAggregation(
            _domainId,
            _aggregationId,
            _leaf,
            _merklePath,
            _leafCount,
            _index
        );
    }
}
