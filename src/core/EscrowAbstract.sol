// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {SignatureChecker} from "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

import {ISettlerBase} from "../interfaces/ISettlerBase.sol";
import {SettlerAbstract} from "../SettlerAbstract.sol";
import {ParamsHash} from "../utils/ParamsHash.sol";

import {
    InvalidEscrowSignature, InvalidIntentSignature, InvalidAmount, IntentExpired, InvalidToken,
    InvalidPayment, InvalidPrice
    } from "./SettlerErrors.sol";


abstract contract EscrowAbstract is SettlerAbstract {

    using ParamsHash for ISettlerBase.EscrowParams;
    using ParamsHash for ISettlerBase.IntentParams;

    /**
     * 计算担保交易参数的EIP-712类型化数据哈希。
     * @param params 担保交易参数
     * @param domainSeparator 域分隔符
     * @return escrowTypedHash 担保交易参数的EIP-712类型化数据哈希
     */
    function getEscrowTypedHash(ISettlerBase.EscrowParams memory params, bytes32 domainSeparator) internal pure returns (bytes32 escrowTypedHash) {
        bytes32 escrowHash = params.hash();
        escrowTypedHash = MessageHashUtils.toTypedDataHash(domainSeparator, escrowHash);
    }

    /**
     * 确认担保交易参数是否完整有效。
     * @param relayer 可信的签名者地址
     * @param domainSeparator 域分隔符
     * @param params 担保交易参数
     * @param sig 担保交易参数的签名
     */
    function makesureEscrowParams(address relayer, bytes32 domainSeparator, ISettlerBase.EscrowParams memory params, bytes memory sig) internal view virtual returns (bytes32 escrowTypedHash){
        escrowTypedHash = getEscrowTypedHash(params, domainSeparator);
        if(!isValidSignature(relayer, escrowTypedHash, sig)) revert InvalidEscrowSignature();
    }

    /**
     * 确认受托意向是否完整有效。
     * @param relayer 可信的签名者地址
     * @param domainSeparator 域分隔符
     * @param params 受托意向参数
     * @param sig 受托意向参数的签名
     */
    function makesureIntentParams(address relayer, bytes32 domainSeparator, ISettlerBase.IntentParams memory params, bytes memory sig) internal view virtual returns (bytes32 intentTypedHash){
        if(block.timestamp > params.expiryTime) revert IntentExpired(params.expiryTime);
        bytes32 intentHash = params.hash();
        intentTypedHash = MessageHashUtils.toTypedDataHash(domainSeparator, intentHash);
        if(!isValidSignature(relayer, intentTypedHash, sig)) revert InvalidIntentSignature();
    }

    /**
     * 确认成交参数是否符合受托意向，它们通常分别是买家意向和卖家提交 或 买家提交和卖家意向。
     * @param escrowParams 提交的担保交易参数
     * @param intentParams 提交的受托意向参数
     */
    function makesureTradeValidation(ISettlerBase.EscrowParams memory escrowParams, ISettlerBase.IntentParams memory intentParams) internal view virtual{
        if(block.timestamp > intentParams.expiryTime) revert IntentExpired(intentParams.expiryTime);
        if(escrowParams.token != intentParams.token) revert InvalidToken();
        if(escrowParams.volume < intentParams.range.min || (intentParams.range.max > 0 && escrowParams.volume > intentParams.range.max)) revert InvalidAmount();
        if(escrowParams.currency != intentParams.currency || escrowParams.paymentMethod != intentParams.paymentMethod || escrowParams.payeeDetails != intentParams.payeeDetails) revert InvalidPayment();
        if(intentParams.price > 0 && escrowParams.price != intentParams.price) revert InvalidPrice();
    }

    /**
     * 确认签名是否有效。支持EIP-1271和EIP-2098签名。
     * @param signer 签名者地址
     * @param hash 要验证的哈希
     * @param sig 签名
     * @return isValid 签名是否有效
     */
    function isValidSignature(address signer, bytes32 hash, bytes memory sig) internal view returns (bool){
        return SignatureChecker.isValidSignatureNow(signer, hash, sig);
    }

}