// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {IAllowanceTransfer} from "@uniswap/permit2/interfaces/IAllowanceTransfer.sol";
import {ISignatureTransfer} from "@uniswap/permit2/interfaces/ISignatureTransfer.sol";
import {IPermit2} from "@uniswap/permit2/interfaces/IPermit2.sol";
import {PermitHash} from "@uniswap/permit2/libraries/PermitHash.sol";

import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {SignatureChecker} from "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

import {InvalidSpender, InvalidAmount, SignatureExpired, InvalidSignature, InvalidToken, IntentExpired,
InvalidSender, InsufficientQuota, InvalidEscrowSignature, InvalidIntentSignature, InvalidPayment, InvalidPrice,
InvalidRecipient
} from "../../core/SettlerErrors.sol";
import {ISettlerBase} from "../../interfaces/ISettlerBase.sol";
import {IEscrow} from "../../interfaces/IEscrow.sol";
import {LighterAccount} from "../../account/LighterAccount.sol";
import {ParamsHash} from "../../utils/ParamsHash.sol";
import {IAllowanceHolder} from "../../allowanceholder/IAllowanceHolder.sol";
// import {console} from "forge-std/console.sol";



contract MainnetUserTxn is EIP712 {
    using ParamsHash for ISettlerBase.IntentParams;
    using ParamsHash for ISettlerBase.EscrowParams;
    using PermitHash for ISignatureTransfer.PermitTransferFrom;
    using PermitHash for ISignatureTransfer.TokenPermissions;
    
    IPermit2 public constant _PERMIT2 = IPermit2(0x000000000022D473030F116dDEE9F6B43aC78BA3);

    address public lighterRelayer;
    IEscrow internal escrow;
    LighterAccount internal lighterAccount;
    IAllowanceHolder public _ALLOWANCE_HOLDER;

    constructor(address lighterRelayer_, IEscrow escrow_, LighterAccount lighterAccount_, IAllowanceHolder allowanceHolder_) EIP712("MainnetUserTxn", "1") {
        lighterRelayer = lighterRelayer_;
        // assert(block.chainid == 1 || block.chainid == 31337);
        escrow = escrow_;
        lighterAccount = lighterAccount_;
        _ALLOWANCE_HOLDER = allowanceHolder_;
    }

    function setLighterRelayer(address lighterRelayer_) external {
        lighterRelayer = lighterRelayer_;
    }

    function hashEscrowParams(ISettlerBase.EscrowParams memory escrowParams) public view returns (bytes32) {
        bytes32 escrowHash = escrowParams.hash();
        return _hashTypedDataV4(escrowHash);
    }

    function hashIntentParams(ISettlerBase.IntentParams memory intentParams) public view returns (bytes32) {
        bytes32 intentHash = intentParams.hash();
        return _hashTypedDataV4(intentHash);
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
        if (permitSingle.spender != address(_ALLOWANCE_HOLDER)) revert InvalidSpender();
        // sigDeadline check in permit2
        _PERMIT2.permit(msg.sender, permitSingle, permitSig);

        if(address(permitSingle.details.token) != address(intentParams.token)) revert InvalidToken();
        if(permitSingle.details.amount < intentParams.range.min || permitSingle.details.amount > intentParams.range.max) revert InvalidAmount();
        
        // EIP-712 signature verification for intentParams
        bytes32 intentParamsHash = intentParams.hash();
        bytes32 typedDataHash = _hashTypedDataV4(intentParamsHash);
        // sig.verify(typedDataHash, msg.sender);
        SignatureChecker.isValidSignatureNow(msg.sender, typedDataHash, sig);
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
        // if(escrowParams.buyer != msg.sender) revert InvalidSender();
        // if(!lighterAccount.hasAvailableQuota(escrowParams.buyer)) revert InsufficientQuota();
        // if(!lighterAccount.hasAvailableQuota(escrowParams.seller)) revert InsufficientQuota();
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
        
        _ALLOWANCE_HOLDER.transferFrom(tokenAddress, escrowParams.seller, address(escrow), uint160(escrowParams.volume));

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
        if(transferDetails.to != address(escrow)) revert InvalidRecipient();

        address tokenAddress = address(permit.permitted.token);
        if (address(escrowParams.token) != address(intentParams.token) || tokenAddress != address(escrowParams.token)) revert InvalidToken();
        if (
            /*permit.permitted.amount < escrowParams.volume // check in permit2
            ||*/ (intentParams.range.min > 0 && escrowParams.volume < intentParams.range.min)
            || (intentParams.range.max > 0 && escrowParams.volume > intentParams.range.max)
            || transferDetails.requestedAmount != escrowParams.volume
        ) revert InvalidAmount();
        
        // console.logString("--------------------------------");
        bytes32 escrowParamsHash = escrowParams.hash();
        // console.logBytes32(escrowParamsHash);
        bytes32 escrowTypedDataHash = _hashTypedDataV4(escrowParamsHash);
        // console.logBytes32(escrowTypedDataHash);
        // console.logBytes(sig);
        if (!SignatureChecker.isValidSignatureNow(lighterRelayer, escrowTypedDataHash, sig)) revert InvalidSignature();

        bytes32 intentParamsHash = intentParams.hash(); 
        // console.logBytes32(intentParamsHash);
        // console.logString("#########################");
        _transferFromIKnowWhatImDoing(permit, transferDetails, escrowParams.payer, intentParamsHash, ParamsHash._INTENT_WITNESS_TYPE_STRING, permitSig);
        // TODO: 这里需要修改，使用permit2的transferFrom, only for unit test
        // IERC20(address(intentParams.token)).transferFrom(escrowParams.seller, address(escrow), escrowParams.volume);

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
    function takeBuyerIntent(
        ISignatureTransfer.PermitTransferFrom memory permit, 
        ISignatureTransfer.SignatureTransferDetails memory transferDetails,
        ISettlerBase.IntentParams memory intentParams, 
        ISettlerBase.EscrowParams memory escrowParams, 
        bytes memory permitSig, 
        bytes memory intentSig, 
        bytes memory sig
    ) external {
        if(permit.deadline < block.timestamp || intentParams.expiryTime < block.timestamp) revert SignatureExpired(permit.deadline);
        // if(escrowParams.payer != msg.sender) revert InvalidSender();
        if(address(permit.permitted.token) != address(intentParams.token)) revert InvalidToken();
        if(transferDetails.to != address(escrow)) revert InvalidSpender();
        if(
            transferDetails.requestedAmount != escrowParams.volume
            || intentParams.range.min > 0 && escrowParams.volume < intentParams.range.min
            || intentParams.range.max > 0 && escrowParams.volume > intentParams.range.max
        ) revert InvalidAmount();

        bytes32 escrowParamsHash = escrowParams.hash();
        bytes32 escrowTypedDataHash = _hashTypedDataV4(escrowParamsHash);
        SignatureChecker.isValidSignatureNow(lighterRelayer, escrowTypedDataHash, sig);

        bytes32 intentParamsHash = intentParams.hash();
        bytes32 intentTypedDataHash = _hashTypedDataV4(intentParamsHash);
        SignatureChecker.isValidSignatureNow(escrowParams.seller, intentTypedDataHash, intentSig);
        
        _transferFrom(permit, transferDetails, permitSig, _isForwarded());

        _makeEscrow(escrowTypedDataHash, escrowParams, 0, 0);
    }

    function paid(ISettlerBase.EscrowParams calldata escrowParams, bytes memory sig) external {
        if(escrowParams.buyer != msg.sender) revert InvalidSender();

        bytes32 escrowHash = escrowParams.hash();
        bytes32 escrowTypedHash = _hashTypedDataV4(escrowHash);
        SignatureChecker.isValidSignatureNow(lighterRelayer, escrowTypedHash, sig);

        escrow.paid(escrowTypedHash, escrowParams.id, address(escrowParams.token), escrowParams.buyer);
    }

    function release(ISettlerBase.EscrowParams calldata escrowParams, bytes calldata sig) external {
        if(escrowParams.seller != msg.sender) revert InvalidSender();

        bytes32 escrowHash = escrowParams.hash();
        bytes32 escrowTypedHash = _hashTypedDataV4(escrowHash);
        SignatureChecker.isValidSignatureNow(lighterRelayer, escrowTypedHash, sig);

        escrow.releaseByExecutor(escrowTypedHash, escrowParams.id, address(escrowParams.token), escrowParams.buyer, escrowParams.seller, escrowParams.volume);
        
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
            escrowParams.id,
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
        // console.logString("------------_makeEscrow--------------------");
        lighterAccount.addPendingTx(escrowParams.buyer);
        lighterAccount.addPendingTx(escrowParams.seller);
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

        // bytes32 typeHash = keccak256(abi.encodePacked(PermitHash._PERMIT_TRANSFER_FROM_WITNESS_TYPEHASH_STUB, witnessTypeString));
        // console.logBytes32(typeHash);
        // bytes32 tokenPermissionsHash = keccak256(abi.encode(PermitHash._TOKEN_PERMISSIONS_TYPEHASH, permit.permitted));
        // console.logBytes32(tokenPermissionsHash);
        // bytes32 permitHash = keccak256(abi.encode(typeHash, tokenPermissionsHash, address(this), permit.nonce, permit.deadline, witnessHash));
        // console.logBytes32(permitHash);
        // console.logBytes(sig);

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
        ISignatureTransfer __PERMIT2 = _PERMIT2;
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

    function _transferFrom(
        ISignatureTransfer.PermitTransferFrom memory permit,
        ISignatureTransfer.SignatureTransferDetails memory transferDetails,
        bytes memory sig,
        bool isForwarded
    ) internal {
        if (isForwarded) {
            if (sig.length != 0) {
                assembly ("memory-safe") {
                    mstore(0x00, 0xc321526c) // selector for `InvalidSignatureLen()`
                    revert(0x1c, 0x04)
                }
            }
            // if (permit.nonce != 0) Panic.panic(Panic.ARITHMETIC_OVERFLOW);
            if (block.timestamp > permit.deadline) {
                assembly ("memory-safe") {
                    mstore(0x00, 0xcd21db4f) // selector for `SignatureExpired(uint256)`
                    mstore(0x20, mload(add(0x40, permit)))
                    revert(0x1c, 0x24)
                }
            }
            // we don't check `requestedAmount` because it's checked by AllowanceHolder itself
            // TODO: 转发，使用_ALLOWANCE_HOLDER.transferFrom
            _ALLOWANCE_HOLDER.transferFrom(permit.permitted.token, _msgSender(), transferDetails.to, uint160(transferDetails.requestedAmount));
        } else {
            // This is effectively
            /*
            _PERMIT2.permitTransferFrom(permit, transferDetails, _msgSender(), sig);
            */
            // but it's written in assembly for contract size reasons. This produces a non-strict
            // ABI encoding
            // (https://docs.soliditylang.org/en/v0.8.25/abi-spec.html#strict-encoding-mode), but
            // it's fine because Solidity's ABI *decoder* will handle anything that is validly
            // encoded, strict or not.

            // Solidity won't let us reference the constant `_PERMIT2` in assembly, but this
            // compiles down to just a single PUSH opcode just before the CALL, with optimization
            // turned on.
            ISignatureTransfer __PERMIT2 = _PERMIT2;
            address from = _msgSender();
            assembly ("memory-safe") {
                let ptr := mload(0x40)
                mstore(ptr, 0x30f28b7a) // selector for `permitTransferFrom(((address,uint256),uint256,uint256),(address,uint256),address,bytes)`

                // The layout of nested structs in memory is different from that in calldata. We
                // have to chase the pointer to `permit.permitted`.
                mcopy(add(0x20, ptr), mload(permit), 0x40)
                // The rest of the members of `permit` are laid out linearly,
                mcopy(add(0x60, ptr), add(0x20, permit), 0x40)
                // as are the members of `transferDetails.
                mcopy(add(0xa0, ptr), transferDetails, 0x40)
                // Because we're passing `from` on the stack, it must be cleaned.
                mstore(add(0xe0, ptr), and(0xffffffffffffffffffffffffffffffffffffffff, from))
                mstore(add(0x100, ptr), 0x100) // Offset to `sig` (the end of the non-dynamic types)

                // Encode the dynamic object `sig`
                let sigLength := mload(sig)
                mcopy(add(0x120, ptr), sig, add(0x20, sigLength))

                // We don't need to check that Permit2 has code, and it always signals failure by
                // reverting.
                if iszero(call(gas(), __PERMIT2, 0x00, add(0x1c, ptr), add(0x124, sigLength), 0x00, 0x00)) {
                    let ptr_ := mload(0x40)
                    returndatacopy(ptr_, 0x00, returndatasize())
                    revert(ptr_, returndatasize())
                }
            }
        }
    }

    function _isForwarded() internal pure returns (bool) {
        return false;
    }

    function _msgSender() internal view returns (address) {
        return msg.sender;
    }

    function getDomainSeparator() public view virtual returns (bytes32){
        return _domainSeparatorV4();
    }

    function makesureTransferWithWitness(
        address owner, 
        ISignatureTransfer.PermitTransferFrom memory permit, 
        ISignatureTransfer.SignatureTransferDetails memory transferDetails, 
        ISettlerBase.IntentParams memory intentParams, bytes memory sig) public view virtual returns (bytes32 witnessHash) {
        if(transferDetails.to != address(escrow)) revert InvalidSpender();
        bytes32 intentParamsHash = intentParams.hash(); 
        witnessHash = _hashWithWitness(permit, intentParamsHash);
        if(!isValidSignature(owner, witnessHash, sig)) revert InvalidSignature();
    }

    function _hashWithWitness(ISignatureTransfer.PermitTransferFrom memory permit, bytes32 witness) internal view returns (bytes32) {
        string memory witnessTypeString = ParamsHash._INTENT_WITNESS_TYPE_STRING;
        bytes32 typeHash = keccak256(abi.encodePacked(PermitHash._PERMIT_TRANSFER_FROM_WITNESS_TYPEHASH_STUB, witnessTypeString));
        bytes32 tokenPermissionsHash = keccak256(abi.encode(PermitHash._TOKEN_PERMISSIONS_TYPEHASH, permit.permitted));
        return keccak256(abi.encode(typeHash, tokenPermissionsHash, address(this), permit.nonce, permit.deadline, witness));
    }

    function makesureEscrowParams(ISettlerBase.EscrowParams memory params, bytes memory sig) public view virtual returns (bytes32 escrowTypedHash){
        bytes32 escrowHash = params.hash();
        escrowTypedHash = MessageHashUtils.toTypedDataHash(getDomainSeparator(), escrowHash);
        if(!isValidSignature(lighterRelayer, escrowTypedHash, sig)) revert InvalidEscrowSignature();
    }

    function makesureIntentParams(ISettlerBase.IntentParams memory params, bytes memory sig) public view virtual returns (bytes32 intentTypedHash){
        if(block.timestamp > params.expiryTime) revert IntentExpired(params.expiryTime);
        bytes32 intentHash = params.hash();
        intentTypedHash = MessageHashUtils.toTypedDataHash(getDomainSeparator(), intentHash);
        if(!isValidSignature(lighterRelayer, intentTypedHash, sig)) revert InvalidIntentSignature();
    }

    function makesureTradeValidation(ISettlerBase.EscrowParams memory escrowParams, ISettlerBase.IntentParams memory intentParams) public view virtual{
        if(block.timestamp > intentParams.expiryTime) revert IntentExpired(intentParams.expiryTime);
        if(escrowParams.token != intentParams.token) revert InvalidToken();
        if(escrowParams.volume < intentParams.range.min || (intentParams.range.max > 0 && escrowParams.volume > intentParams.range.max)) revert InvalidAmount();
        if(escrowParams.currency != intentParams.currency || escrowParams.paymentMethod != intentParams.paymentMethod || escrowParams.payeeDetails != intentParams.payeeDetails) revert InvalidPayment();
        if(intentParams.price > 0 &&escrowParams.price != intentParams.price) revert InvalidPrice();
    }

    function isValidSignature(address signer, bytes32 hash, bytes memory sig) internal view returns (bool){
        return SignatureChecker.isValidSignatureNow(signer, hash, sig);
    }

}