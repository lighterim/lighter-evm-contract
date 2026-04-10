// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {ISettlerWaypoint} from "./interfaces/ISettlerWaypoint.sol";
import {ISettlerBase} from "./interfaces/ISettlerBase.sol";
import {SettlerBase} from "./SettlerBase.sol";

import {ISettlerActions} from "./ISettlerActions.sol";
import {WaypointAbstract} from "./core/WaypointAbstract.sol";
import {InvalidResolvedResultSignature, InvalidEscrowSignature, InvalidArbitrationNonce} from "./core/SettlerErrors.sol";

import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {ParamsHash} from "./utils/ParamsHash.sol";

abstract contract SettlerWaypoint is ISettlerWaypoint, WaypointAbstract, SettlerBase {

    using ParamsHash for ISettlerBase.ResolvedResult;

    event ArbitrationUpdated(bytes32 indexed escrowHash, uint256 nonce, uint64 resolutionTs, uint16 buyerThresholdBp);

    mapping(bytes32 => uint256) internal _latestArbitrationNonce;
    

    function _tokenId() internal pure virtual override returns (uint256) {
        return 3;
    }

    function _dispatchVIP(uint256 action, bytes calldata data) internal virtual override returns (bool) {
        if(action == uint32(ISettlerActions.MAKE_PAYMENT.selector)) {
            (ISettlerBase.EscrowParams memory escrowParams, bytes memory sig) = abi.decode(data, (ISettlerBase.EscrowParams, bytes));
            _madePayment(_msgSender(), escrowParams, sig);
            return true;
        }
        else if(action == uint32(ISettlerActions.REQUEST_CANCEL.selector)) {
            (ISettlerBase.EscrowParams memory escrowParams, bytes memory sig) = abi.decode(data, (ISettlerBase.EscrowParams, bytes));
            _requestCancelBySeller(_msgSender(), escrowParams, sig);
            return true;
        }
        else if(action == uint32(ISettlerActions.CANCEL_BY_BUYER.selector)) {
            (ISettlerBase.EscrowParams memory escrowParams, bytes memory sig) = abi.decode(data, (ISettlerBase.EscrowParams, bytes));
            _cancelByBuyer(_msgSender(), escrowParams, sig);
            return true;
        }
        else if(action == uint32(ISettlerActions.CANCEL_BY_SELLER.selector)) {
            (ISettlerBase.EscrowParams memory escrowParams, bytes memory sig) = abi.decode(data, (ISettlerBase.EscrowParams, bytes));
            _cancelBySeller(_msgSender(), escrowParams, sig);
            return true;
        }
        else if(action == uint32(ISettlerActions.DISPUTE_BY_BUYER.selector)) {
            (ISettlerBase.EscrowParams memory escrowParams, bytes memory sig) = abi.decode(data, (ISettlerBase.EscrowParams, bytes));
            _disputeByBuyer(_msgSender(), escrowParams, sig);
            return true;
        }
        else if(action == uint32(ISettlerActions.DISPUTE_BY_SELLER.selector)) {
            (ISettlerBase.EscrowParams memory escrowParams, bytes memory sig) = abi.decode(data, (ISettlerBase.EscrowParams, bytes));
            _disputeBySeller(_msgSender(), escrowParams, sig);
            return true;
        }
        else if(action == uint32(ISettlerActions.RELEASE_BY_SELLER.selector)) {
            (ISettlerBase.EscrowParams memory escrowParams, bytes memory sig) = abi.decode(data, (ISettlerBase.EscrowParams, bytes));
            _releaseBySeller(_msgSender(), escrowParams, sig);
            return true;
        }
        else if(action == uint32(ISettlerActions.RESOLVE.selector)) {
            (
                ISettlerBase.EscrowParams memory escrowParams, 
                uint16 buyerThresholdBp,
                uint256 nonce,
                uint64 resolutionTs,
                address tbaArbitrator,
                bytes memory sig, 
                bytes memory arbitratorSig, 
                bytes memory counterpartySig
            ) = abi.decode(data, (ISettlerBase.EscrowParams, uint16, uint256, uint64, address, bytes, bytes, bytes));
            _resolve(
                _msgSender(), 
                escrowParams, 
                buyerThresholdBp, 
                nonce,
                resolutionTs,
                tbaArbitrator, 
                sig, 
                arbitratorSig, 
                counterpartySig
            );
            return true;
        }
        else if(action == uint32(ISettlerActions.UPDATE_ARBITRATION.selector)) {
            (
                ISettlerBase.ResolvedResult memory resolvedResult,
                address tbaArbitrator,
                bytes memory arbitratorSig,
                bytes memory sig
            ) = abi.decode(data, (ISettlerBase.ResolvedResult, address, bytes, bytes));
            _updateArbitration(_msgSender(), resolvedResult, tbaArbitrator, arbitratorSig, sig);
            return true;
        }
        return false;
    }

    function _dispatch(uint256 /*i*/, uint256 /*action*/, bytes calldata /*data*/) internal virtual override returns (bool) { 
        return false;
    }

    function getResolvedResultTypedHash(
        ISettlerBase.ResolvedResult memory resolvedResult,
        bytes32 domainSeparator
    )public pure returns (bytes32 resolvedResultTypedHash) {
        bytes32 resolvedResultHash = resolvedResult.hash();
        resolvedResultTypedHash = MessageHashUtils.toTypedDataHash(domainSeparator, resolvedResultHash);
    }

    function makesureResolvedResult(
        bytes32 domainSeparator,
        bytes32 escrowHash,
        uint256 nonce,
        uint64 resolutionTs,
        uint16 buyerThresholdBp,
        address tbaArbitrator,
        bytes memory sig
    ) internal view virtual returns (bytes32 resolvedResultTypedHash){
        ISettlerBase.ResolvedResult memory resolvedResult = ISettlerBase.ResolvedResult(escrowHash, nonce, resolutionTs, buyerThresholdBp);
        resolvedResultTypedHash = getResolvedResultTypedHash(resolvedResult, domainSeparator);
        if(!isValidSignature(tbaArbitrator, resolvedResultTypedHash, sig)) revert InvalidResolvedResultSignature();
    }

    function _updateArbitration(bytes32 domainSeparator, ISettlerBase.ResolvedResult memory resolvedResult, address tbaArbitrator, bytes memory arbitratorSig, bytes memory sig) internal {
        bytes32 resolvedResultTypedHash = getResolvedResultTypedHash(resolvedResult, domainSeparator);
        // verify the arbitrator signature
        if(!isValidSignature(tbaArbitrator, resolvedResultTypedHash, arbitratorSig)) revert InvalidResolvedResultSignature();
        // verify the relayer signature
        if(!isValidSignature(relayer, resolvedResultTypedHash, sig)) revert InvalidEscrowSignature();
        
        _updateArbitrationNonce(resolvedResult.escrowHash, resolvedResult.nonce);
        
        emit ArbitrationUpdated(resolvedResult.escrowHash, resolvedResult.nonce, resolvedResult.resolutionTs, resolvedResult.buyerThresholdBp);
    }

    function _updateArbitrationNonce(bytes32 escrowHash, uint256 nonce) internal {
        if(nonce <= _latestArbitrationNonce[escrowHash]) revert InvalidArbitrationNonce();
        _latestArbitrationNonce[escrowHash] = nonce;
    }

    function _useArbitrationNonce(bytes32 escrowHash, uint256 nonce) internal {
        if(nonce < _latestArbitrationNonce[escrowHash]) revert InvalidArbitrationNonce();
        _latestArbitrationNonce[escrowHash] = nonce;
    }

    function arbitrationNonce(bytes32 escrowHash) public view returns (uint256) {
        return _latestArbitrationNonce[escrowHash];
    }


    // /**
    //  * processing escrow transaction
    //  * @param escrowTypedHash escrow typed hash
    //  */
    // modifier placeWaypoint(address sender, bytes32 escrowTypedHash) virtual override{
    //     _;
    // }
    

    function execute(
        bytes32 /*escrowTypedDataHash*/,
        bytes[] calldata actions
    ) external payable override
        //placeWaypoint(msg.sender, escrowTypedDataHash)
        returns (bool) {
        return _generateDispatch(actions);
    }

}
