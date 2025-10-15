// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {IAllowanceTransfer} from "@uniswap/permit2/interfaces/IAllowanceTransfer.sol";
import {ISignatureTransfer} from "@uniswap/permit2/interfaces/ISignatureTransfer.sol";
import {PermitHash} from "@uniswap/permit2/libraries/PermitHash.sol";

import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {SignatureChecker} from "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";

import {InvalidSpender, InvalidAmount, SignatureExpired, InvalidSignature, InvalidToken, InvalidSender, InsufficientQuota} from "../../core/SettlerErrors.sol";
import {ISettlerBase} from "../../interfaces/ISettlerBase.sol";
import {IEscrow} from "../../interfaces/IEscrow.sol";
import {LighterAccount} from "../../account/LighterAccount.sol";
import {ParamsHash} from "../../utils/ParamsHash.sol";
import {IAllowanceHolder} from "../../allowanceholder/IAllowanceHolder.sol";

import {console} from "forge-std/console.sol";


contract MainnetUserTxn is EIP712 {
    using ParamsHash for ISettlerBase.IntentParams;
    using ParamsHash for ISettlerBase.EscrowParams;
    using PermitHash for ISignatureTransfer.PermitTransferFrom;
    using PermitHash for ISignatureTransfer.TokenPermissions;
    
    IAllowanceTransfer internal constant _PERMIT2_ALLOWANCE = IAllowanceTransfer(0x000000000022D473030F116dDEE9F6B43aC78BA3);
    ISignatureTransfer internal constant _PERMIT2_SIGNATURE = ISignatureTransfer(0x000000000022D473030F116dDEE9F6B43aC78BA3);
    IAllowanceHolder internal constant _ALLOWANCE_HOLDER = IAllowanceHolder(0x0000000000001fF3684f28c67538d4D072C22734);

    address internal lighterRelayer;
    IEscrow internal escrow;
    LighterAccount internal lighterAccount;

    constructor(address lighterRelayer_, IEscrow escrow_, LighterAccount lighterAccount_) EIP712("MainnetUserTxn", "1") {
        lighterRelayer = lighterRelayer_;
        // assert(block.chainid == 1 || block.chainid == 31337);
        escrow = escrow_;
        lighterAccount = lighterAccount_;
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
        bytes memory permitSig, 
        bytes memory sig
        ) external  
    {
        if(address(permitSingle.details.token) != address(intentParams.token)) revert InvalidToken();
        if(permitSingle.details.amount < intentParams.range.min || permitSingle.details.amount > intentParams.range.max) revert InvalidAmount();
        // if(permitSingle.sigDeadline > block.timestamp) revert SignatureExpired(permitSingle.sigDeadline);
        if (permitSingle.spender != address(this)) revert InvalidSpender(); 
        
        // EIP-712 signature verification for intentParams
        bytes32 intentParamsHash = intentParams.hash();
        bytes32 typedDataHash = _hashTypedDataV4(intentParamsHash);
        // sig.verify(typedDataHash, msg.sender);
        SignatureChecker.isValidSignatureNow(msg.sender, typedDataHash, sig);

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
        bytes memory sig, 
        bytes memory intentSig
    ) external {
        if(escrowParams.buyer != msg.sender) revert InvalidSender();
        if(!lighterAccount.hasAvailableQuota(escrowParams.buyer)) revert InsufficientQuota();
        if(!lighterAccount.hasAvailableQuota(escrowParams.seller)) revert InsufficientQuota();
        address tokenAddress = address(escrowParams.token);
        if(tokenAddress != address(intentParams.token)) revert InvalidToken();
        if(escrowParams.volume < intentParams.range.min || (intentParams.range.max > 0 && escrowParams.volume > intentParams.range.max)) revert InvalidAmount();
        if(intentParams.expiryTime < block.timestamp) revert SignatureExpired(intentParams.expiryTime);
        
        // EIP-712 signature verification for intentParams
        bytes32 intentHash = intentParams.hash();
        bytes32 intentTypedHash = _hashTypedDataV4(intentHash);
        SignatureChecker.isValidSignatureNow(escrowParams.seller, intentTypedHash, intentSig);

        bytes32 escrowHash = escrowParams.hash();
        bytes32 escrowTypedHash = _hashTypedDataV4(escrowHash);
        SignatureChecker.isValidSignatureNow(lighterRelayer, escrowTypedHash, sig);
        
        // _allowanceHolderTransferFrom(tokenAddress, escrowParams.seller, address(escrow), escrowParams.volume);
        _PERMIT2_ALLOWANCE.transferFrom(escrowParams.seller, address(escrow), uint160(escrowParams.volume), tokenAddress);

        _makeEscrow(escrowTypedHash, escrowParams, 0, 0);
    }

    /**
     *  买家确认卖家意图。买家在确认卖家意图时，
     * 1. 使用permit&transferDetails授权买家从卖家账户中转出指定数量的代币。
     * 2. 验证escrowParams的签名。
     * 3. 创建escrow交易。
     * @param permit ISignatureTransfer.PermitTransferFrom(
     * @param transferDetails ISignatureTransfer.SignatureTransferDetails(
     * @param intentParams ISettlerBase.IntentParams(
     * @param escrowParams ISettlerBase.EscrowParams(
     * @param permitSig bytes
     * @param sig bytes 
     */
    function takeSellerIntent(
        ISignatureTransfer.PermitTransferFrom memory permit, 
        ISignatureTransfer.SignatureTransferDetails memory transferDetails,
        ISettlerBase.IntentParams memory intentParams, 
        ISettlerBase.EscrowParams memory escrowParams, 
        bytes memory permitSig, 
        bytes memory sig
    ) external {
        if (permit.deadline < block.timestamp) revert SignatureExpired(permit.deadline);
        if(transferDetails.to != address(this)) revert InvalidSpender();

        address tokenAddress = address(permit.permitted.token);
        if (address(escrowParams.token) != address(intentParams.token) || tokenAddress != address(escrowParams.token)) revert InvalidToken();
        if (
            permit.permitted.amount < escrowParams.volume 
            || (intentParams.range.min > 0 && escrowParams.volume < intentParams.range.min)
            || (intentParams.range.max > 0 && escrowParams.volume > intentParams.range.max)
            || transferDetails.requestedAmount != escrowParams.volume
        ) revert InvalidAmount();
        

        bytes32 escrowParamsHash = escrowParams.hash();
        // console.logBytes32(escrowParamsHash);
        bytes32 escrowTypedDataHash = _hashTypedDataV4(escrowParamsHash);
        // console.logBytes32(escrowTypedDataHash);
        // console.logBytes(sig);
        if (!SignatureChecker.isValidSignatureNow(lighterRelayer, escrowTypedDataHash, sig)) revert InvalidSignature();

        bytes32 intentParamsHash = intentParams.hash(); 
        
        _transferFromIKnowWhatImDoing(permit, transferDetails, escrowParams.seller, intentParamsHash, ParamsHash._INTENT_WITNESS_TYPE_STRING, permitSig);
        //TODO: 这里需要修改，使用permit2的transferFrom, only for unit test
        IERC20(address(intentParams.token)).transferFrom(escrowParams.seller, address(escrow), escrowParams.volume);

        _makeEscrow(escrowTypedDataHash, escrowParams, 0, 0);
    }

    function paid(ISettlerBase.EscrowParams calldata escrowParams, bytes memory sig) external {
        if(escrowParams.buyer != msg.sender) revert InvalidSender();

        bytes32 escrowHash = escrowParams.hash();
        bytes32 escrowTypedHash = _hashTypedDataV4(escrowHash);
        SignatureChecker.isValidSignatureNow(lighterRelayer, escrowTypedHash, sig);

        escrow.paid(escrowTypedHash, address(escrowParams.token), escrowParams.buyer);
    }

    function release(ISettlerBase.EscrowParams calldata escrowParams, bytes calldata sig) external {
        if(escrowParams.seller != msg.sender) revert InvalidSender();

        bytes32 escrowHash = escrowParams.hash();
        bytes32 escrowTypedHash = _hashTypedDataV4(escrowHash);
        SignatureChecker.isValidSignatureNow(lighterRelayer, escrowTypedHash, sig);

        escrow.release(address(escrowParams.token), escrowParams.buyer, escrowParams.seller, escrowParams.volume, escrowTypedHash, ISettlerBase.EscrowStatus.SellerReleased);
        
        lighterAccount.removePendingTx(escrowParams.buyer);
        lighterAccount.removePendingTx(escrowParams.seller);
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

        lighterAccount.addPendingTx(escrowParams.buyer);
        lighterAccount.addPendingTx(escrowParams.seller);
    }


    function _permit(address owner, IAllowanceTransfer.PermitSingle memory permitSingle, bytes memory signature) internal {
        _PERMIT2_ALLOWANCE.permit(owner, permitSingle, signature);
    }

    function _allowanceHolderTransferFrom(address token, address owner, address recipient, uint256 amount)
        internal
    {
       _PERMIT2_ALLOWANCE.transferFrom(owner, recipient, uint160(amount), token);
    }

    function _transferFromIKnowWhatImDoing(
        ISignatureTransfer.PermitTransferFrom memory permit,
        ISignatureTransfer.SignatureTransferDetails memory transferDetails,
        address from,
        bytes32 witnessHash,
        string memory witnessTypeString,
        bytes memory sig,
        bool isForwarded
    ) internal {
        if (isForwarded) {
            assembly ("memory-safe") {
                mstore(0x00, 0x1c500e5c) // selector for `ForwarderNotAllowed()`
                revert(0x1c, 0x04)
            }
        }

        bytes32 typeHash = keccak256(abi.encodePacked(PermitHash._PERMIT_TRANSFER_FROM_WITNESS_TYPEHASH_STUB, witnessTypeString));
        console.logBytes32(typeHash);
        bytes32 tokenPermissionsHash = keccak256(abi.encode(PermitHash._TOKEN_PERMISSIONS_TYPEHASH, permit.permitted));
        console.logBytes32(tokenPermissionsHash);
        bytes32 permitHash = keccak256(abi.encode(typeHash, tokenPermissionsHash, address(this), permit.nonce, permit.deadline, witnessHash));
        console.logBytes32(permitHash);
        console.logBytes(sig);

        // This is effectively
        /*
        _PERMIT2.permitWitnessTransferFrom(permit, transferDetails, from, witnessHash, witnessTypeString, sig);
        */
        // but it's written in assembly for contract size reasons. This produces a non-strict ABI
        // encoding (https://docs.soliditylang.org/en/v0.8.25/abi-spec.html#strict-encoding-mode),
        // but it's fine because Solidity's ABI *decoder* will handle anything that is validly
        // encoded, strict or not.

        // Solidity won't let us reference the constant `_PERMIT2` in assembly, but this compiles
        // down to just a single PUSH opcode just before the CALL, with optimization turned on.
        ISignatureTransfer __PERMIT2 = _PERMIT2_SIGNATURE;
        assembly ("memory-safe") {
            let ptr := mload(0x40)
            /* selector for `permitWitnessTransferFrom(
             ((address,uint256),uint256,uint256), //PermitTransferFrom:{TokenPermissions:{token, amount}, nonce, deadline}
             (address,uint256), //SignatureTransferDetails:{to, requestedAmount}
             address, // owner
             bytes32, // witness hash
             string, // witness type string
             bytes //signature
             )` => 0x137c29fe
            */
            mstore(ptr, 0x137c29fe) 

            // The layout of nested structs in memory is different from that in calldata. We have to
            // chase the pointer to `permit.permitted`.
            mcopy(add(0x20, ptr), mload(permit), 0x40) 
            // The rest of the members of `permit` are laid out linearly,
            mcopy(add(0x60, ptr), add(0x20, permit), 0x40)
            // as are the members of `transferDetails.
            mcopy(add(0xa0, ptr), transferDetails, 0x40)
            // Because we're passing `from` on the stack, it must be cleaned.
            mstore(add(0xe0, ptr), and(0xffffffffffffffffffffffffffffffffffffffff, from))
            mstore(add(0x100, ptr), witnessHash)
            mstore(add(0x120, ptr), 0x140) // Offset to `witnessTypeString` (the end of of the non-dynamic types)
            let witnessTypeStringLength := mload(witnessTypeString)
            mstore(add(0x140, ptr), add(0x160, witnessTypeStringLength)) // Offset to `sig` (past the end of `witnessTypeString`)

            // Now we encode the 2 dynamic objects, `witnessTypeString` and `sig`.
            mcopy(add(0x160, ptr), witnessTypeString, add(0x20, witnessTypeStringLength))
            let sigLength := mload(sig)
            mcopy(add(0x180, add(ptr, witnessTypeStringLength)), sig, add(0x20, sigLength))

            // We don't need to check that Permit2 has code, and it always signals failure by
            // reverting.
            if iszero(
                call(
                    gas(),
                    __PERMIT2,
                    0x00,
                    add(0x1c, ptr),
                    add(0x184, add(witnessTypeStringLength, sigLength)),
                    0x00,
                    0x00
                )
            ) {
                let ptr_ := mload(0x40)
                returndatacopy(ptr_, 0x00, returndatasize())
                revert(ptr_, returndatasize())
            }
        }
    }

    // See comment in above overload; don't use this function
    function _transferFromIKnowWhatImDoing(
        ISignatureTransfer.PermitTransferFrom memory permit,
        ISignatureTransfer.SignatureTransferDetails memory transferDetails,
        address from,
        bytes32 witnessHash,
        string memory witnessTypeString,
        bytes memory sig
    ) internal {
        _transferFromIKnowWhatImDoing(permit, transferDetails, from, witnessHash, witnessTypeString, sig, _isForwarded());
    }

    function _isForwarded() internal pure returns (bool) {
        return false;
    }

}