// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {IAllowanceTransfer} from "@uniswap/permit2/interfaces/IAllowanceTransfer.sol";
import {ISignatureTransfer} from "@uniswap/permit2/interfaces/ISignatureTransfer.sol";

import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";

import {InvalidSpender, InvalidAmount, SignatureExpired, InvalidSignature, InvalidToken, InvalidSender} from "../../core/SettlerErrors.sol";
import {ISettlerBase} from "../../interfaces/ISettlerBase.sol";
import {IEscrow} from "../../interfaces/IEscrow.sol";
import {ParamsHash} from "../../utils/ParamsHash.sol";
import {IAllowanceHolder} from "../../allowanceholder/IAllowanceHolder.sol";
import {SignatureVerification} from "../../utils/SignatureVerification.sol";



contract MainnetUserTxn is EIP712 {

    using SignatureVerification for bytes;
    using ParamsHash for ISettlerBase.IntentParams;
    using ParamsHash for ISettlerBase.EscrowParams;
    
    IAllowanceTransfer internal constant _PERMIT2_ALLOWANCE = IAllowanceTransfer(0x000000000022D473030F116dDEE9F6B43aC78BA3);
    IAllowanceHolder internal constant _ALLOWANCE_HOLDER = IAllowanceHolder(0x0000000000001fF3684f28c67538d4D072C22734);

    address internal lighterRelayer;
    IEscrow internal escrow;

    constructor(address lighterRelayer_, IEscrow escrow_) EIP712("MainnetUserTxn", "1") {
        lighterRelayer = lighterRelayer_;
        // assert(block.chainid == 1 || block.chainid == 31337);
        escrow = escrow_;
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
        IAllowanceTransfer.PermitSingle calldata permitSingle, 
        ISettlerBase.IntentParams calldata intentParams, 
        bytes calldata permitSig, 
        bytes calldata sig
        ) external  
    {
        if(address(permitSingle.details.token) != address(intentParams.token)) revert InvalidSpender();
        if(permitSingle.details.amount < intentParams.range.min || permitSingle.details.amount > intentParams.range.max) revert InvalidAmount();
        // if(permitSingle.sigDeadline > block.timestamp) revert SignatureExpired(permitSingle.sigDeadline);
        if (permitSingle.spender != address(escrow)) revert InvalidSpender(); 
        
        // EIP-712 signature verification for intentParams
        bytes32 intentParamsHash = intentParams.hash();
        bytes32 typedDataHash = _hashTypedDataV4(intentParamsHash);
        sig.verify(typedDataHash, msg.sender);

        _permit(msg.sender, permitSingle, permitSig); 

    }

    /**
     * 买家确认大宗出售意图。买家在确认大宗出售意图时，会使用escrowParams和intentParams签名。
     * @param escrowParams 被确认的担保交易参数
     * @param intentParams  大宗出售意图参数
     * @param sig 担保交易参数的签名
     * @param intentSig 大宗出售意图参数的签名
     */
    function _takeBulkSellIntent(
        ISettlerBase.EscrowParams calldata escrowParams, 
        ISettlerBase.IntentParams calldata intentParams, 
        bytes calldata sig, 
        bytes calldata intentSig
    ) external {
        address tokenAddress = address(escrowParams.token);
        if(tokenAddress == address(intentParams.token)) revert InvalidToken();
        if(escrowParams.volume < intentParams.range.min || (intentParams.range.max > 0 && escrowParams.volume > intentParams.range.max)) revert InvalidAmount();
        if(intentParams.expiryTime < block.timestamp) revert SignatureExpired(intentParams.expiryTime);
        
        // EIP-712 signature verification for intentParams
        bytes32 intentHash = intentParams.hash();
        bytes32 intentTypedHash = _hashTypedDataV4(intentHash);
        intentSig.verify(intentTypedHash, escrowParams.seller);

        bytes32 escrowHash = escrowParams.hash();
        bytes32 escrowTypedHash = _hashTypedDataV4(escrowHash);
        sig.verify(escrowTypedHash, lighterRelayer);
        
        _allowanceHolderTransferFrom(tokenAddress, escrowParams.seller, address(escrow), escrowParams.volume);

        _makeEscrow(escrowTypedHash, escrowParams, 0, 0);
    }

    function paid(ISettlerBase.EscrowParams calldata escrowParams, bytes calldata sig) external {
        if(escrowParams.buyer != msg.sender) revert InvalidSender();

        bytes32 escrowHash = escrowParams.hash();
        bytes32 escrowTypedHash = _hashTypedDataV4(escrowHash);
        sig.verify(escrowTypedHash, lighterRelayer);

        escrow.paid(escrowTypedHash, address(escrowParams.token), escrowParams.buyer);
    }

    function release(ISettlerBase.EscrowParams calldata escrowParams, bytes calldata sig) external {
        if(escrowParams.seller != msg.sender) revert InvalidSender();

        bytes32 escrowHash = escrowParams.hash();
        bytes32 escrowTypedHash = _hashTypedDataV4(escrowHash);
        sig.verify(escrowTypedHash, lighterRelayer);

        escrow.release(address(escrowParams.token), escrowParams.buyer, escrowParams.seller, escrowParams.volume, escrowTypedHash, ISettlerBase.EscrowStatus.SellerReleased);
    }



    function _makeEscrow(bytes32 escrowTypedDataHash, ISettlerBase.EscrowParams memory escrowParams, uint256 gasSpentForBuyer, uint256 gasSpentForSeller) internal {
        
        escrow.create(
            address(escrowParams.token), 
            escrowParams.buyer, 
            escrowParams.seller, 
            escrowParams.volume, 
            escrowTypedDataHash, 
            ISettlerBase.EscrowData({
            status: ISettlerBase.EscrowStatus.Escrowed,
            paidSeconds: 0,
            releaseSeconds: 0,
            cancelTs: 0,
            lastActionTs: uint64(block.timestamp),
            gasSpentForBuyer: gasSpentForBuyer,
            gasSpentForSeller: gasSpentForSeller
            })
        );
    }


    function _permit(address owner, IAllowanceTransfer.PermitSingle memory permitSingle, bytes memory signature) internal {
        _PERMIT2_ALLOWANCE.permit(owner, permitSingle, signature);
    }

    function _allowanceHolderTransferFrom(address token, address owner, address recipient, uint256 amount)
        internal
    {
        // `owner` is always `_msgSender()`
        // This is effectively
        /*
        _ALLOWANCE_HOLDER.transferFrom(token, owner, recipient, amount);
        */
        // but it's written in assembly for contract size reasons.

        // Solidity won't let us reference the constant `_ALLOWANCE_HOLDER` in assembly, but this
        // compiles down to just a single PUSH opcode just before the CALL, with optimization turned
        // on.
        address __ALLOWANCE_HOLDER = address(_ALLOWANCE_HOLDER);
        assembly ("memory-safe") {
            let ptr := mload(0x40)
            mstore(add(0x80, ptr), amount)
            mstore(add(0x60, ptr), recipient)
            mstore(add(0x4c, ptr), shl(0x60, owner)) // clears `recipient`'s padding
            mstore(add(0x2c, ptr), shl(0x60, token)) // clears `owner`'s padding
            mstore(add(0x0c, ptr), 0x15dacbea000000000000000000000000) // selector for `transferFrom(address,address,address,uint256)` with `token`'s padding

            // Although `transferFrom` returns `bool`, we don't need to bother checking the return
            // value because `AllowanceHolder` always either reverts or returns `true`. We also
            // don't need to check that it has code.
            if iszero(call(gas(), __ALLOWANCE_HOLDER, 0x00, add(0x1c, ptr), 0x84, 0x00, 0x00)) {
                let ptr_ := mload(0x40)
                returndatacopy(ptr_, 0x00, returndatasize())
                revert(ptr_, returndatasize())
            }
        }
    }

}