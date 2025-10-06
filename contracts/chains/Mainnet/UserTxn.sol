// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {IAllowanceTransfer} from "@uniswap/permit2/interfaces/IAllowanceTransfer.sol";
import {ISignatureTransfer} from "@uniswap/permit2/interfaces/ISignatureTransfer.sol";

import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";

import {InvalidSpender, InvalidAmount, SignatureExpired, InvalidSignature} from "../../core/SettlerErrors.sol";
import {ISettlerBase} from "../../interfaces/ISettlerBase.sol";
import {ParamsHash} from "../../utils/ParamsHash.sol";
import {SignatureVerification} from "../../utils/SignatureVerification.sol";



contract MainnetUserTxn is EIP712 {

    using SignatureVerification for bytes;
    using ParamsHash for ISettlerBase.IntentParams;
    using ParamsHash for ISettlerBase.EscrowParams;
    
    IAllowanceTransfer internal constant _PERMIT2_ALLOWANCE = IAllowanceTransfer(0x000000000022D473030F116dDEE9F6B43aC78BA3);

    address internal lighterRelayer;

    constructor(address lighterRelayer_) EIP712("MainnetUserTxn", "1") {
        lighterRelayer = lighterRelayer_;
        // assert(block.chainid == 1 || block.chainid == 31337);
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
        ) external  
    {
        if(address(permitSingle.details.token) != address(intentParams.token)) revert InvalidSpender();
        if(permitSingle.details.amount < intentParams.range.min || permitSingle.details.amount > intentParams.range.max) revert InvalidAmount();
        // if(permitSingle.sigDeadline > block.timestamp) revert SignatureExpired(permitSingle.sigDeadline);
        if (permitSingle.spender != address(this)) revert InvalidSpender(); 
        
        // EIP-712 signature verification for intentParams
        bytes32 intentParamsHash = intentParams.hash();
        bytes32 typedDataHash = _hashTypedDataV4(intentParamsHash);
        sig.verify(typedDataHash, msg.sender);

        _permit(msg.sender, permitSingle, permitSig); 

    }

    function _permit(address owner, IAllowanceTransfer.PermitSingle memory permitSingle, bytes memory signature) internal {
        _PERMIT2_ALLOWANCE.permit(owner, permitSingle, signature);
    }

}