// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {IAllowanceTransfer} from "@uniswap/permit2/interfaces/IAllowanceTransfer.sol";
import {ISignatureTransfer} from "@uniswap/permit2/interfaces/ISignatureTransfer.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

import {InvalidSpender, InvalidAmount, SignatureExpired, InvalidSignature} from "../../core/SettlerErrors.sol";
import {ISettlerBase} from "../../interfaces/ISettlerBase.sol";



contract MainnetUserTxn {

    string internal constant TOKEN_PERMISSIONS_TYPE = "TokenPermissions(address token,uint256 amount)";

    string constant INTENT_WITNESS_TYPE_STRING = "IntentParams intentParams)TokenPermissions(address token,uint256 amount)Witness(address user)";
    
    // EIP-712 Domain Separator constants
    // keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)")
    bytes32 constant EIP712_DOMAIN_TYPEHASH = 0x22a86b360b5485458145028452a23e18ce4839843a9677579ab5c5f87a87e008;
    
    string constant INTENT_PARAMS_TYPE = "IntentParams(address token,Range range,uint64 expiryTime,bytes32 currency,bytes32 paymentMethod,bytes32 payeeDetails,uint256 price)Range(uint256 min,uint256 max)";
    // keccak256("Range(uint256 min,uint256 max)")
    bytes32 constant RANGE_TYPEHASH = 0x4f957099e465954533e4f7c229f55b0a330752b757366579c2a64f434b9b59c7;
    // keccak256("IntentParams(address token,Range range,uint64 expiryTime,bytes32 currency,bytes32 paymentMethod,bytes32 payeeDetails,uint256 price)Range(uint256 min,uint256 max)")
    bytes32 constant INTENT_PARAMS_TYPEHASH = 0x22a86b360b5485458145028452a23e18ce4839843a9677579ab5c5f87a87e008;

    string constant ESCROW_PARAMS_TYPE = "EscrowParams(uint256 id,address token,uint256 volume,uint256 price,uint256 usdRate,address seller,address sellerFeeRate,bytes32 paymentMethod,bytes32 currency,bytes32 payeeId,bytes32 payeeAccount,address buyer,address buyerFeeRate)";
    
    // Additional EIP-712 type constants
    string internal constant SLIPPAGE_TYPE = "Slippage(uint256 minAmountOut,uint256 maxAmountIn)";
    string internal constant SLIPPAGE_AND_ACTIONS_TYPE = "SlippageAndActions(Slippage slippage,bytes[] actions)Slippage(uint256 minAmountOut,uint256 maxAmountIn)";
    // keccak256("EscrowParams(uint256 id,address token,uint256 volume,uint256 price,uint256 usdRate,address seller,address sellerFeeRate,bytes32 paymentMethod,bytes32 currency,bytes32 payeeId,bytes32 payeeAccount,address buyer,address buyerFeeRate)")
    bytes32 constant ESCROW_PARAMS_TYPEHASH = 0x22a86b360b5485458145028452a23e18ce4839843a9677579ab5c5f87a87e008;

    IAllowanceTransfer internal constant _PERMIT2_ALLOWANCE = IAllowanceTransfer(0x000000000022D473030F116dDEE9F6B43aC78BA3);

    address internal lighterRelayer;

    constructor(address lighterRelayer_) {
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
        if(permitSingle.sigDeadline > block.timestamp) revert SignatureExpired(permitSingle.sigDeadline);
        if (permitSingle.spender != address(this)) revert InvalidSpender(); 
        
        // EIP-712 signature verification for intentParams
        bytes32 intentParamsHash = _hashIntentParams(intentParams);
        bytes32 typedDataHash = _hashTypedDataV4(intentParamsHash);
        address recoveredSigner = _recover(typedDataHash, sig);
        
        // Verify that the recovered signer is the expected signer (e.g., msg.sender or a specific authorized address)
        if (recoveredSigner != msg.sender) revert InvalidSignature();

        _permit(msg.sender, permitSingle, permitSig); 

    }

    function _permit(address owner, IAllowanceTransfer.PermitSingle memory permitSingle, bytes memory signature) internal {
        _PERMIT2_ALLOWANCE.permit(owner, permitSingle, signature);
    }



    // ----
    /**
     * @dev Returns the EIP-712 hash of the IntentParams struct
     */
    function _hashIntentParams(ISettlerBase.IntentParams memory intentParams) internal pure returns (bytes32) {
        return keccak256(
            abi.encode(
                INTENT_PARAMS_TYPEHASH,
                intentParams.token,
                keccak256(
                    abi.encode(
                        RANGE_TYPEHASH,
                        intentParams.range.min,
                        intentParams.range.max
                    )
                ),
                intentParams.expiryTime,
                intentParams.currency,
                intentParams.paymentMethod,
                intentParams.payeeDetails,
                intentParams.price
            )
        );
    }

    function _hashEscrowParams(ISettlerBase.EscrowParams memory escrowParams) internal pure returns (bytes32) {
        return keccak256(
            abi.encode(
                ESCROW_PARAMS_TYPEHASH,
                escrowParams.id,
                escrowParams.token,
                escrowParams.volume,
                escrowParams.price,
                escrowParams.usdRate,
                escrowParams.seller,
                escrowParams.sellerFeeRate,
                escrowParams.paymentMethod,
                escrowParams.currency,
                escrowParams.payeeId,
                escrowParams.payeeAccount,
                escrowParams.buyer,
                escrowParams.buyerFeeRate
            )
        );
    }

    function _domainSeparator() internal view returns (bytes32) {
        return keccak256(
            abi.encode(
                EIP712_DOMAIN_TYPEHASH,
                keccak256(bytes("MainnetUserTxn")),
                keccak256(bytes("1")),
                block.chainid,
                address(this)
            )
        );
    }

     /**
     * @dev Returns the EIP-712 hash to be signed
     */
    function _hashTypedDataV4(bytes32 structHash) internal view returns (bytes32) {
        return keccak256(
            abi.encodePacked(
                "\x19\x01",
                _domainSeparator(),
                structHash
            )
        );
    }

        /**
     * @dev Recovers the signer address from the signature using OpenZeppelin's ECDSA library
     */
    function _recover(bytes32 hash, bytes memory signature) internal pure returns (address) {
        (address recovered, ECDSA.RecoverError error, ) = ECDSA.tryRecover(hash, signature);
        
        if (error != ECDSA.RecoverError.NoError || recovered == address(0)) {
            revert InvalidSignature();
        }
        
        return recovered;
    }
}