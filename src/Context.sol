// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {SignatureChecker} from "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

import {IEscrow} from "./interfaces/IEscrow.sol";
import {ISettlerBase} from "./interfaces/ISettlerBase.sol";
import {ParamsHash} from "./utils/ParamsHash.sol";
import {
    InvalidEscrowSignature
    } from "./core/SettlerErrors.sol";

abstract contract AbstractContext {
    
    function _msgSender() internal view virtual returns (address);

    function _msgData() internal view virtual returns (bytes calldata);

    function _isForwarded() internal view virtual returns (bool);
}

abstract contract Context is AbstractContext {

    using ParamsHash for ISettlerBase.EscrowParams;
    
    IEscrow internal escrow;
    address internal relayer;

    constructor(IEscrow escrow_, address lighterRelayer_) {
        escrow = escrow_;
        relayer = lighterRelayer_;
    }

    /**
     * 计算担保交易参数的EIP-712类型化数据哈希。
     * @param params 担保交易参数
     * @param domainSeparator 域分隔符
     * @return escrowHash 是担保交易参数的哈希, escrowTypedHash 是担保交易参数的EIP-712类型化数据哈希，用于验证签名
     */
    function getEscrowTypedHash(ISettlerBase.EscrowParams memory params, bytes32 domainSeparator)
    internal pure returns (bytes32 escrowHash, bytes32 escrowTypedHash) {
        escrowHash = params.hash();
        escrowTypedHash = MessageHashUtils.toTypedDataHash(domainSeparator, escrowHash);
    }

    function _msgSender() internal view virtual override returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual override returns (bytes calldata) {
        return msg.data;
    }

    function _isForwarded() internal view virtual override returns (bool) {
        return false;
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

    /**
     * 确认担保交易参数是否完整有效。
     * @param domainSeparator 域分隔符
     * @param params 担保交易参数
     * @param sig 担保交易参数的签名
     */
    function makesureEscrowParams(
        bytes32 domainSeparator, 
        ISettlerBase.EscrowParams memory params, 
        bytes memory sig
    ) internal view virtual returns (bytes32 escrowHash, bytes32 escrowTypedHash){
        (escrowHash, escrowTypedHash) = getEscrowTypedHash(params, domainSeparator);
        // console.logString("escrowHash=");
        // console.logBytes32(escrowHash);
        // console.logString("escrowTypedHash=");
        // console.logBytes32(escrowTypedHash);
        // console.logString("sig=");
        // console.logBytes(sig);
        // console.logString("relayer=");
        // console.logAddress(relayer);
        if(!isValidSignature(relayer, escrowTypedHash, sig)) revert InvalidEscrowSignature();
    }

    function getEscrow() internal view returns (IEscrow) {
        return escrow;
    }

    function _getRelayer() internal view returns (address) {
        return relayer;
    }

}
