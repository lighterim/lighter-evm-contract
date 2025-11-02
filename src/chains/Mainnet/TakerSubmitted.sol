// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;


import {MainnetMixin} from "./Common.sol";
import {Settler} from "../../Settler.sol";

import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {ISignatureTransfer} from "@uniswap/permit2/interfaces/ISignatureTransfer.sol";
import {IAllowanceTransfer} from "@uniswap/permit2/interfaces/IAllowanceTransfer.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import {SignatureChecker} from "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";
import {ISettlerActions} from "../../ISettlerActions.sol";
import {ISettlerBase} from "../../interfaces/ISettlerBase.sol";
import {InvalidSpender, InvalidSignature} from "../../core/SettlerErrors.sol";

import {SettlerAbstract} from "../../SettlerAbstract.sol";
import {SettlerBase} from "../../SettlerBase.sol";
import {AbstractContext} from "../../Context.sol";
import {ParamsHash} from "../../utils/ParamsHash.sol";
import {Permit2PaymentAbstract} from "../../core/Permit2PaymentAbstract.sol";
import {FreeMemory} from "../../utils/FreeMemory.sol";
import {Permit2PaymentTakerSubmitted} from "../../core/Permit2Payment.sol";
import {IAllowanceHolder} from "../../allowanceholder/IAllowanceHolder.sol";

contract MainnetSettler is Settler, MainnetMixin, FreeMemory, EIP712 {

    using ParamsHash for ISettlerBase.IntentParams;
    using ParamsHash for ISettlerBase.EscrowParams;
    
    
    constructor(address lighterRelayer, bytes20 gitCommit, IAllowanceHolder allowanceHolder) 
        MainnetMixin(lighterRelayer, gitCommit)
        Permit2PaymentTakerSubmitted(allowanceHolder)
        EIP712("MainnetSettler", "1") 
    {

    }

    /**
     * @dev Returns the EIP-712 domain separator for this contract
     */
    function _domainSeparator() internal view override returns (bytes32) {
        return keccak256(
            abi.encode(
                ParamsHash.EIP712_DOMAIN_TYPEHASH,
                keccak256(bytes("MainnetSettler")),
                keccak256(bytes("1")),
                block.chainid,
                address(this)
            )
        );
    }

    function _dispatch(uint256 index, uint256 action, bytes calldata data) internal virtual override(MainnetMixin, SettlerAbstract) returns (bool) {
        return true;
    }

    function _dispatchVIP(uint256 action, bytes calldata data) internal virtual override returns (bool) {
        if(action == uint32(ISettlerActions.BULK_SELL.selector)) {
            (
                IAllowanceTransfer.PermitSingle memory permitSingle, 
                ISettlerBase.IntentParams memory intentParams, 
                bytes memory permitSig, 
                bytes memory sig
            ) = abi.decode(data, (IAllowanceTransfer.PermitSingle, ISettlerBase.IntentParams, bytes, bytes));
            
            _bulkSell(permitSingle, intentParams, permitSig, sig);
        }
        else if(action == uint32(ISettlerActions.TAKE_BULK_SELL_INTENT.selector)) {
            (
                ISettlerBase.EscrowParams memory escrowParams, 
                ISettlerBase.IntentParams memory intentParams, 
                bytes memory sig, 
                bytes memory intentSig
            ) = abi.decode(data, (ISettlerBase.EscrowParams, ISettlerBase.IntentParams, bytes, bytes));
            
            _takeBulkSellIntent(escrowParams, intentParams, sig, intentSig);
        }
        else if(action == uint32(ISettlerActions.TAKE_SELLER_INTENT.selector)) {
            (
                ISignatureTransfer.PermitTransferFrom memory permit, 
                ISignatureTransfer.SignatureTransferDetails memory transferDetails,
                ISettlerBase.IntentParams memory intentParams, 
                ISettlerBase.EscrowParams memory escrowParams, 
                bytes memory permitSig, 
                bytes memory sig
            ) = abi.decode(
                data, (
                    ISignatureTransfer.PermitTransferFrom, 
                    ISignatureTransfer.SignatureTransferDetails,
                    ISettlerBase.IntentParams, 
                    ISettlerBase.EscrowParams, 
                    bytes, 
                    bytes
                    )
            );

            _takeSellerIntent(permit, transferDetails, intentParams, escrowParams, permitSig, sig);
        }
        else if(action == uint32(ISettlerActions.TAKE_BUYER_INTENT.selector)) {
            (
                ISignatureTransfer.PermitTransferFrom memory permit, 
                ISignatureTransfer.SignatureTransferDetails memory transferDetails,
                ISettlerBase.IntentParams memory intentParams, 
                ISettlerBase.EscrowParams memory escrowParams, 
                bytes memory permitSig, 
                bytes memory intentSig, 
                bytes memory sig
            ) = abi.decode(
                data, (
                    ISignatureTransfer.PermitTransferFrom, 
                    ISignatureTransfer.SignatureTransferDetails,
                    ISettlerBase.IntentParams, 
                    ISettlerBase.EscrowParams, 
                    bytes, 
                    bytes, 
                    bytes
                    )
            );
            
            _takeBuyerIntent(permit, transferDetails, intentParams, escrowParams, permitSig, intentSig, sig);
        }
        else{
            return false;
        }
        return true;
    }

    /**
     * 买家确认卖家出售意图。
     * 1. 卖家授权合约转移担保交易相关的资金，其中卖家意图作为witness，使用_transferFromIKnowWhatImDoing接收卖家资金，并通过签名验证。
     * 2. 验证担保交易参数及其签名。
     * 3. 创建担保交易。
     * @param permit 卖家授权转出代币的permit
     * @param transferDetails 合约接收代币的详细信息
     * @param intentParams 卖家出售意图参数
     * @param escrowParams 担保交易参数
     * @param permitSig 卖家授权转出代币的签名
     * @param sig 担保交易参数的签名
     */
    function _takeSellerIntent(
        ISignatureTransfer.PermitTransferFrom memory permit, 
        ISignatureTransfer.SignatureTransferDetails memory transferDetails,
        ISettlerBase.IntentParams memory intentParams, 
        ISettlerBase.EscrowParams memory escrowParams, 
        bytes memory permitSig, 
        bytes memory sig
    ) internal {
        require(address(permit.permitted.token) == address(intentParams.token), "Invalid token");
        require(permit.permitted.amount >= intentParams.range.min && permit.permitted.amount >= intentParams.range.max, "Invalid amount");
        require(permit.deadline < block.timestamp, "Invalid expiry time");
        if(transferDetails.to != address(this)) revert InvalidSpender();
        require(transferDetails.requestedAmount == escrowParams.volume, "Invalid amount");

        bytes32 escrowParamsHash = escrowParams.hash();
        bytes32 escrowTypedDataHash = _hashTypedDataV4(escrowParamsHash);
        if (!SignatureChecker.isValidSignatureNow(lighterRelayer, escrowTypedDataHash, sig)) revert InvalidSignature();

        bytes32 intentParamsHash = intentParams.hash(); 
        bytes32 typedDataHash = _hashTypedDataV4(intentParamsHash);
        _transferFromIKnowWhatImDoing(permit, transferDetails, escrowParams.seller, typedDataHash, ParamsHash._INTENT_WITNESS_TYPE_STRING, permitSig);

        _makeEscrow(escrowTypedDataHash, escrowParams, 0, 0);
    }

    /**
     * 卖家确认买家购买意图。
     * 1. 验证买家意图及其签名。
     * 2. 验证担保交易参数及其签名。
     * 3. 从卖家账户中转出代币，基于ISignatureTransfer（PermitTransferFrom, SignatureTransferDetails）。
     * 4. 创建担保交易。
     * @param permit 卖家授权转出代币的permit
     * @param transferDetails 合约接收代币的详细信息
     * @param intentParams 买家购买意图参数
     * @param escrowParams 担保交易参数
     * @param permitSig 卖家授权转出代币的签名
     * @param intentSig 买家购买意图参数的签名
     * @param sig 担保交易参数的签名
     */
    function _takeBuyerIntent(
        ISignatureTransfer.PermitTransferFrom memory permit, 
        ISignatureTransfer.SignatureTransferDetails memory transferDetails,
        ISettlerBase.IntentParams memory intentParams, 
        ISettlerBase.EscrowParams memory escrowParams, 
        bytes memory permitSig, 
        bytes memory intentSig, 
        bytes memory sig
    ) internal {
        require(address(permit.permitted.token) == address(intentParams.token), "Invalid token");
        require(transferDetails.to == address(this), "Invalid spender");
        require(transferDetails.requestedAmount == escrowParams.volume, "Invalid amount");

        bytes32 escrowParamsHash = escrowParams.hash();
        bytes32 escrowTypedDataHash = _hashTypedDataV4(escrowParamsHash);
        SignatureChecker.isValidSignatureNow(lighterRelayer,escrowTypedDataHash, sig);

        bytes32 intentParamsHash = intentParams.hash();
        bytes32 intentTypedDataHash = _hashTypedDataV4(intentParamsHash);
        SignatureChecker.isValidSignatureNow(escrowParams.buyer, intentTypedDataHash,  intentSig);

        _transferFrom(permit, transferDetails, permitSig);

        _makeEscrow(escrowTypedDataHash, escrowParams, 0, 0);
    }



    /**
     * 大宗出售。由卖方发起。卖方在提交大宗出售意图时，会使用permitSingle授权本合约在指定时间内从卖方账户中转出指定数量的代币。
     * 卖方可以指定转出代币的数量范围，并且可以指定转出代币的过期时间。
     * @param permitSingle 授权转出代币的permitSingle
     * @param intentParams 大宗出售意图参数
     * @param permitSig 授权转出代币的签名
     * @param sig 大宗出售意图的签名
     */
    function _bulkSell(
        IAllowanceTransfer.PermitSingle memory permitSingle, 
        ISettlerBase.IntentParams memory intentParams, 
        bytes memory permitSig, 
        bytes memory sig
        ) internal view
    {
        require(address(permitSingle.details.token) == address(intentParams.token), "Invalid token");
        require(permitSingle.details.amount > intentParams.range.min && permitSingle.details.amount >= intentParams.range.max, "Invalid amount");
        require(permitSingle.sigDeadline < block.timestamp, "Invalid expiry time");
        if (permitSingle.spender != address(this)) revert InvalidSpender(); 
        
        // EIP-712 signature verification for intentParams
        bytes32 intentParamsHash = intentParams.hash();
        bytes32 typedDataHash = _hashTypedDataV4(intentParamsHash);
        if (!SignatureChecker.isValidSignatureNow(msg.sender, typedDataHash, sig)) revert InvalidSignature();
        

        // Call permit2 directly
        // _permit(msg.sender, permitSingle, permitSig); 

    }

    /**
     * 买家确认大宗出售意图。买家在确认大宗出售意图时，会使用escrowParams和intentParams签名。
     * @param escrowParams 被确认的担保交易参数
     * @param intentParams  大宗出售意图参数
     * @param sig 担保交易参数的签名
     * @param intentSig 大宗出售意图参数的签名
     */
    function _takeBulkSellIntent(
        ISettlerBase.EscrowParams memory escrowParams, 
        ISettlerBase.IntentParams memory intentParams, 
        bytes memory sig, 
        bytes memory intentSig
    ) internal {
        address tokenAddress = address(escrowParams.token);
        require(tokenAddress == address(intentParams.token), "Invalid token");
        require(escrowParams.volume >= intentParams.range.min && escrowParams.volume <= intentParams.range.max, "Invalid amount");
        require(intentParams.expiryTime < block.timestamp, "Invalid expiry time");
        
        // EIP-712 signature verification for intentParams
        bytes32 intentParamsHash = intentParams.hash();
        bytes32 typedDataHash = _hashTypedDataV4(intentParamsHash);
        if (!SignatureChecker.isValidSignatureNow(escrowParams.seller, typedDataHash, intentSig)) revert InvalidSignature();
        
        bytes32 escrowParamsHash = escrowParams.hash();
        bytes32 escrowTypedDataHash = _hashTypedDataV4(escrowParamsHash);
        if (!SignatureChecker.isValidSignatureNow(lighterRelayer, escrowTypedDataHash, sig)) revert InvalidSignature();
        

        _allowanceHolderTransferFrom(tokenAddress, escrowParams.seller, address(this), escrowParams.volume);
        _makeEscrow(escrowTypedDataHash, escrowParams, 0, 0);
    }



    function _isRestrictedTarget(address target)
        internal
        pure
        override(Permit2PaymentAbstract, Settler)
        returns (bool)
    {
        return super._isRestrictedTarget(target);
    }

    // function _dispatch(uint256 i, uint256 action, bytes calldata data)
    //     internal
    //     override(Settler, MainnetMixin)
    //     returns (bool)
    // {
    //     return super._dispatch(i, action, data);
    // }

    function _msgSender() internal view override(Settler, AbstractContext) returns (address) {
        return super._msgSender();
    }
}