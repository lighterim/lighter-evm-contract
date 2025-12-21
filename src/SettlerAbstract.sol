// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

import {Context} from "./Context.sol";
import {ParamsHash} from "./utils/ParamsHash.sol";
import {ISettlerBase} from "./interfaces/ISettlerBase.sol";

import {
    InvalidIntentSignature, IntentExpired, InvalidToken, InvalidAmount, InvalidPayment, InvalidPrice
    } from "./core/SettlerErrors.sol";

abstract contract SettlerAbstract is Context {

    using ParamsHash for ISettlerBase.IntentParams;
    
    IERC20 internal constant ETH_ADDRESS = IERC20(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE);

    function _tokenId() internal pure virtual returns (uint256);

    function _domainSeparator() internal view virtual returns (bytes32);

    function _getRelayer() internal view virtual returns (address);

    function _dispatch(uint256 i, uint256 action, bytes calldata data) internal virtual returns (bool);


    // /** 
    //  * 计算受托意向参数的EIP-712类型化数据哈希。
    //  * @param params 受托意向参数
    //  * @param domainSeparator 域分隔符
    //  * @return intentTypedHash 受托意向参数的EIP-712类型化数据哈希
    //  */ 
    // function getIntentTypedHash(ISettlerBase.IntentParams memory params, bytes32 domainSeparator) internal pure returns (bytes32 intentTypedHash) {
    //     bytes32 intentHash = params.hash();
    //     intentTypedHash = MessageHashUtils.toTypedDataHash(domainSeparator, intentHash);
    // }

    // /**
    //  * 确认受托意向是否完整有效。
    //  * @param signer 可信的签名者地址
    //  * @param domainSeparator 域分隔符
    //  * @param params 受托意向参数
    //  * @param sig 受托意向参数的签名
    //  */
    // function makesureIntentParams(
    //     address signer, 
    //     bytes32 domainSeparator, 
    //     ISettlerBase.IntentParams memory params, 
    //     bytes memory sig
    //     ) internal view virtual returns (bytes32 intentTypedHash){
    //     if(block.timestamp > params.expiryTime) revert IntentExpired(params.expiryTime);
    //     intentTypedHash = getIntentTypedHash(params, domainSeparator);
    //     if(!isValidSignature(signer, intentTypedHash, sig)) revert InvalidIntentSignature();
    // }

    // /**
    //  * 确认成交参数是否符合受托意向，它们通常分别是买家意向和卖家提交 或 买家提交和卖家意向。
    //  * @param escrowParams 提交的担保交易参数
    //  * @param intentParams 提交的受托意向参数
    //  */
    // function makesureTradeValidation(ISettlerBase.EscrowParams memory escrowParams, ISettlerBase.IntentParams memory intentParams) internal view virtual{
    //     if(block.timestamp > intentParams.expiryTime) revert IntentExpired(intentParams.expiryTime);
    //     if(escrowParams.token != intentParams.token) revert InvalidToken();
    //     if(escrowParams.volume < intentParams.range.min || (intentParams.range.max > 0 && escrowParams.volume > intentParams.range.max)) revert InvalidAmount();
    //     if(escrowParams.currency != intentParams.currency || escrowParams.paymentMethod != intentParams.paymentMethod || escrowParams.payeeDetails != intentParams.payeeDetails) revert InvalidPayment();
    //     if(intentParams.price > 0 && escrowParams.price != intentParams.price) revert InvalidPrice();
    // }

    
}