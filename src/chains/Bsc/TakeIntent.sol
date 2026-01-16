// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;


import {ISignatureTransfer} from "@uniswap/permit2/interfaces/ISignatureTransfer.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";

import {MainnetMixin} from "./Common.sol";
import {Settler} from "../../Settler.sol";
import {SettlerAbstract} from "../../SettlerAbstract.sol";
import {ISettlerActions} from "../../ISettlerActions.sol";
import {ISettlerBase} from "../../interfaces/ISettlerBase.sol";
import {InvalidWitness, InvalidIntent, InvalidTokenPermissions} from "../../core/SettlerErrors.sol";

import {ParamsHash} from "../../utils/ParamsHash.sol";
import {Permit2PaymentTakeIntent} from "../../core/Permit2Payment.sol";
import {IPaymentMethodRegistry} from "../../interfaces/IPaymentMethodRegistry.sol";
import {IAllowanceHolder} from "../../allowanceholder/IAllowanceHolder.sol";
import {IEscrow} from "../../interfaces/IEscrow.sol";
import {LighterAccount} from "../../account/LighterAccount.sol";
// import {console} from "forge-std/console.sol";

contract MainnetTakeIntent is Settler, MainnetMixin,  EIP712 {

    using ParamsHash for ISettlerBase.EscrowParams;
    using ParamsHash for ISettlerBase.IntentParams;
    using ParamsHash for ISignatureTransfer.TokenPermissions;
    
    constructor(
        address lighterRelayer, IEscrow escrow, LighterAccount lighterAccount,
        IPaymentMethodRegistry paymentMethodRegistry, bytes20 gitCommit, IAllowanceHolder allowanceHolder
        ) 
        MainnetMixin(lighterRelayer, escrow, lighterAccount, paymentMethodRegistry, gitCommit)
        Permit2PaymentTakeIntent( allowanceHolder)
        EIP712("MainnetTakeIntent", "1") 
    {

    }

    function getEscrowTypedHash(ISettlerBase.EscrowParams memory params) public view returns (bytes32){
        bytes32 escrowHash = params.hash();
        return _hashTypedDataV4(escrowHash);
    }

    function getIntentTypedHash(ISettlerBase.IntentParams memory params) public view returns (bytes32){
        bytes32 intentHash = params.hash();
        return _hashTypedDataV4(intentHash);
    }

    function getTokenPermissionsHash(ISignatureTransfer.TokenPermissions memory tokenPermissions) public pure returns (bytes32) {   
        return tokenPermissions.hash();
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

    function _dispatch(uint256 i, uint256 action, bytes calldata data)
        internal
        override(Settler, SettlerAbstract) DANGEROUS_freeMemory
        returns (bool){
        return super._dispatch(i, action, data);
    }


    function _dispatchVIP(uint256 action, bytes calldata data) internal virtual override DANGEROUS_freeMemory returns (bool) {
        if(action == uint32(ISettlerActions.ESCROW_AND_INTENT_CHECK.selector)) {
            (
                ISettlerBase.EscrowParams memory escrowParams, 
                ISettlerBase.IntentParams memory intentParams,
                bytes memory makerIntentSig
            ) = abi.decode(data, (ISettlerBase.EscrowParams, ISettlerBase.IntentParams, bytes));
            // console.logString("------------ESCROW_AND_INTENT_CHECK--------------------");
            (bytes32 escrowHash, bytes32 escrowTypedHash) = getEscrowTypedHash(escrowParams, _domainSeparator());
            // escrow typed hash(takeIntent modifier) should be the same as the escrow typed hash in the escrow params.
            if (escrowTypedHash != getWitness()) {
                revert InvalidWitness();
            }

            // intent typed hash should be the same as the intent type hash in the intent params.
            // TODO: takeSellerIntent: intentParamsHash VS getIntentTypeHash()?
            bytes32 intentParamsHash = getIntentTypedHash(intentParams, _domainSeparator());
            if (intentParamsHash != getIntentTypeHash()) {
                revert InvalidIntent();
            }

            ISignatureTransfer.TokenPermissions memory tokenPermissions = ISignatureTransfer.TokenPermissions({
                token: escrowParams.token,
                amount: getAmountWithFee(escrowParams.volume, escrowParams.sellerFeeRate)
            });

            bytes32 tokenPermissionsHash = tokenPermissions.hash();
            if (tokenPermissionsHash != getTokenPermissionsHash()) {
                revert InvalidTokenPermissions();
            }

            bool isInitiatedBySeller = lighterAccount.isOwnerCall(escrowParams.seller, _msgSender());
            /**
             * @dev Intent verification logic:
             * 1. takeBulkSell: maker is seller(tba), maker intent signature from seller tba, checked in _dispatch(transferFrom)
             * 2. takeSellerIntent: maker is seller(tba), checked in permit2 transferFrom
             * 3. takeBuyerIntent: maker is buyer(tba), maker intent signature from buyer tba
             */
            if(isInitiatedBySeller){
                /// the caller is from seller ==> 3. takeBuyerIntent
                /// verify buyer intent signature
                makesureIntentParams(escrowParams.buyer, _domainSeparator(), intentParams, makerIntentSig);
                clearIntentTypeHash();
            }

            makesureTradeValidation(escrowParams, intentParams, !isInitiatedBySeller); // isInitiatedByBuyer
            _makeEscrow(escrowHash, escrowParams);
            return true;
        }

        return false;
    }

    function _makeEscrow(
        bytes32 escrowHash,
        ISettlerBase.EscrowParams memory escrowParams
    ) internal {
        address buyer = escrowParams.buyer;
        address seller = escrowParams.seller;
        uint256 volume = escrowParams.volume;
        
        lighterAccount.addPendingTx(buyer, seller);
        
        uint256 sellerFee = getFeeAmount(volume, escrowParams.sellerFeeRate);
        escrow.create(
            escrowParams.token, 
            buyer, 
            seller, 
            volume,
            sellerFee, 
            escrowHash, 
            escrowParams.id,
            ISettlerBase.EscrowData({
                status: ISettlerBase.EscrowStatus.Escrowed,
                paidSeconds: 0,
                releaseSeconds: 0,
                cancelTs: 0,
                lastActionTs: uint64(block.timestamp)
            })
        );
    }
}