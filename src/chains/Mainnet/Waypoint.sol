// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;


import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {ISignatureTransfer} from "@uniswap/permit2/interfaces/ISignatureTransfer.sol";
import {IAllowanceHolder} from "../../allowanceholder/IAllowanceHolder.sol";
import {MainnetMixin} from "./Common.sol";
import {SettlerWaypoint} from "../../SettlerWaypoint.sol";
import {ISettlerActions} from "../../ISettlerActions.sol";
import {IPaymentMethodRegistry} from "../../interfaces/IPaymentMethodRegistry.sol";


import {SettlerAbstract} from "../../SettlerAbstract.sol";
import {SettlerBase} from "../../SettlerBase.sol";
import {ISettlerBase} from "../../interfaces/ISettlerBase.sol";
import {Context} from "../../Context.sol";
import {IEscrow} from "../../interfaces/IEscrow.sol";
import {LighterAccount} from "../../account/LighterAccount.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import {ParamsHash} from "../../utils/ParamsHash.sol";
import {UnauthorizedCaller} from "../../core/SettlerErrors.sol";


contract MainnetWaypoint is MainnetMixin, SettlerWaypoint, EIP712 {

    using ParamsHash for ISettlerBase.EscrowParams;

    IPaymentMethodRegistry public paymentMethodRegistry;

    constructor(address lighterRelayer, IEscrow escrow, LighterAccount lighterAccount, bytes20 gitCommit, IPaymentMethodRegistry paymentMethodRegistry_) 
    MainnetMixin(lighterRelayer, escrow, lighterAccount, gitCommit)
    EIP712("MainnetWaypoint", "1")
    {
        paymentMethodRegistry = paymentMethodRegistry_;
    } 

    function getDomainSeparator() public view returns (bytes32) {
        return _domainSeparatorV4();
    }

    /**
     * @dev Returns the EIP-712 domain separator for this contract
     */
    function _domainSeparator() internal view override returns (bytes32) {
        return _domainSeparatorV4();
    }

    function getEscrowTypedHash(ISettlerBase.EscrowParams memory params) public view returns (bytes32){
        bytes32 escrowHash = params.hash();
        return _hashTypedDataV4(escrowHash);
    }

    /**
     * The payment has been made by the buyer
     * @param sender sender
     * @param escrowParams escrow parameters
     */
    function _madePayment(address sender, ISettlerBase.EscrowParams memory escrowParams, bytes memory sig) internal virtual override{
        (bytes32 escrowHash,) = makesureEscrowParams(_domainSeparator(), escrowParams, sig);
        if(!lighterAccount.isOwnerCall(escrowParams.buyer, sender)) revert UnauthorizedCaller(sender);

        escrow.paid(escrowHash, escrowParams.id, escrowParams.token, escrowParams.buyer);
    }

    /**
     * The seller requests to cancel the escrow
     * @param sender sender
     * @param escrowParams escrow parameters
     */
    function _requestCancelBySeller(address sender, ISettlerBase.EscrowParams memory escrowParams, bytes memory sig) internal virtual override{
        (bytes32 escrowHash,) = makesureEscrowParams(_domainSeparator(), escrowParams, sig);
        if(!lighterAccount.isOwnerCall(escrowParams.seller, sender)) revert UnauthorizedCaller(sender);

        ISettlerBase.PaymentMethodConfig memory cfg = paymentMethodRegistry.getPaymentMethodConfig(escrowParams.paymentMethod);
        escrow.requestCancel(escrowHash, escrowParams.id, escrowParams.token, escrowParams.buyer, escrowParams.seller, cfg.windowSeconds);
    }

    /**
     * The buyer cancels the escrow
     * @param sender sender
     * @param escrowParams escrow parameters
     */
    function _cancelByBuyer(address sender, ISettlerBase.EscrowParams memory escrowParams, bytes memory sig) internal virtual override{
        (bytes32 escrowHash,) = makesureEscrowParams(_domainSeparator(), escrowParams, sig);
        if(!lighterAccount.isOwnerCall(escrowParams.buyer, sender)) revert UnauthorizedCaller(sender);
        
        escrow.cancelByBuyer(escrowHash, escrowParams.id, escrowParams.token, escrowParams.buyer, escrowParams.seller);

    }

    /**
     * The seller cancels the escrow
     * @param sender sender
     * @param escrowParams escrow parameters
     */
    function _cancelBySeller(address sender, ISettlerBase.EscrowParams memory escrowParams, bytes memory sig) internal virtual override{
        (bytes32 escrowHash,) = makesureEscrowParams(_domainSeparator(), escrowParams, sig);
        if(!lighterAccount.isOwnerCall(escrowParams.seller, sender)) revert UnauthorizedCaller(sender);
        
        ISettlerBase.PaymentMethodConfig memory cfg = paymentMethodRegistry.getPaymentMethodConfig(escrowParams.paymentMethod);
        uint256 sellerFee = getFeeAmount(escrowParams.volume, escrowParams.sellerFeeRate);
        escrow.cancel(
            escrowHash, escrowParams.id, escrowParams.token, escrowParams.buyer, escrowParams.seller,
            escrowParams.volume, sellerFee, cfg.windowSeconds
        );

    }

    /**
     * The buyer disputes the escrow
     * @param sender sender
     * @param escrowParams escrow parameters
     */
    function _disputeByBuyer(address sender, ISettlerBase.EscrowParams memory escrowParams, bytes memory sig) internal virtual override{
        (bytes32 escrowHash,) = makesureEscrowParams(_domainSeparator(), escrowParams, sig);
        if(!lighterAccount.isOwnerCall(escrowParams.buyer, sender)) revert UnauthorizedCaller(sender);
        
        escrow.dispute(escrowHash, escrowParams.id, escrowParams.token, escrowParams.buyer, escrowParams.seller, ISettlerBase.EscrowStatus.BuyerDisputed);

    }

    /**
     * The seller disputes the escrow
     * @param sender sender
     * @param escrowParams escrow parameters
     */
    function _disputeBySeller(address sender, ISettlerBase.EscrowParams memory escrowParams, bytes memory sig) internal virtual override{
        (bytes32 escrowHash,) = makesureEscrowParams(_domainSeparator(), escrowParams, sig);
        if(!lighterAccount.isOwnerCall(escrowParams.seller, sender)) revert UnauthorizedCaller(sender);

        escrow.dispute(escrowHash, escrowParams.id, escrowParams.token, escrowParams.buyer, escrowParams.seller, ISettlerBase.EscrowStatus.SellerDisputed);

    }

    function _releaseBySeller(address sender, ISettlerBase.EscrowParams memory escrowParams, bytes memory sig) internal virtual override{
        (bytes32 escrowHash,) = makesureEscrowParams(_domainSeparator(), escrowParams, sig);
        if(!lighterAccount.isOwnerCall(escrowParams.seller, sender)) revert UnauthorizedCaller(sender);

        uint256 sellerFee = getFeeAmount(escrowParams.volume, escrowParams.sellerFeeRate);
        uint256 buyerFee = getFeeAmount(escrowParams.volume, escrowParams.buyerFeeRate);

        escrow.releaseBySeller(escrowHash, escrowParams.id, escrowParams.token, escrowParams.buyer, buyerFee, escrowParams.seller, sellerFee, escrowParams.volume);

    }
    
    function _resolve(address sender, ISettlerBase.EscrowParams memory escrowParams, bytes memory sig) internal virtual override{
        (bytes32 escrowHash,) = makesureEscrowParams(_domainSeparator(), escrowParams, sig);
        //TODO: check sender.

        escrow.resolve(escrowHash, escrowParams.id, escrowParams.token, escrowParams.buyer, escrowParams.seller);
    }
}