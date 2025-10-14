// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {AbstractContext} from "../Context.sol";

import {ISignatureTransfer} from "@uniswap/permit2/interfaces/ISignatureTransfer.sol";
import {IAllowanceTransfer} from "@uniswap/permit2/interfaces/IAllowanceTransfer.sol";

abstract contract Permit2PaymentAbstract is AbstractContext {
    
    string internal constant TOKEN_PERMISSIONS_TYPE = "TokenPermissions(address token,uint256 amount)";
    
    // EIP-712 Domain Separator constants
    // keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)")
    bytes32 constant EIP712_DOMAIN_TYPEHASH = 0x22a86b360b5485458145028452a23e18ce4839843a9677579ab5c5f87a87e008;
    
        string constant INTENT_WITNESS_TYPE_STRING = "IntentParams intentParams)TokenPermissions(address token,uint256 amount)Witness(address user)";
    // Additional EIP-712 type constants
    string internal constant SLIPPAGE_TYPE = "Slippage(uint256 minAmountOut,uint256 maxAmountIn)";
    string internal constant SLIPPAGE_AND_ACTIONS_TYPE = "SlippageAndActions(Slippage slippage,bytes[] actions)Slippage(uint256 minAmountOut,uint256 maxAmountIn)";
    // keccak256("EscrowParams(uint256 id,address token,uint256 volume,uint256 price,uint256 usdRate,address seller,address sellerFeeRate,bytes32 paymentMethod,bytes32 currency,bytes32 payeeId,bytes32 payeeAccount,address buyer,address buyerFeeRate)")
    bytes32 constant ESCROW_PARAMS_TYPEHASH = 0x22a86b360b5485458145028452a23e18ce4839843a9677579ab5c5f87a87e008;


    function _isRestrictedTarget(address) internal pure virtual returns (bool);

    function _operator() internal view virtual returns (address);

    // function _permitToSellAmountCalldata(ISignatureTransfer.PermitTransferFrom calldata permit)
    //     internal
    //     view
    //     virtual
    //     returns (uint256 sellAmount);

    function _permitToSellAmount(ISignatureTransfer.PermitTransferFrom memory permit)
        internal
        view
        virtual
        returns (uint256 sellAmount);

    function _permitToTransferDetails(ISignatureTransfer.PermitTransferFrom memory permit, address recipient)
        internal
        view
        virtual
        returns (ISignatureTransfer.SignatureTransferDetails memory transferDetails, uint256 sellAmount);

    // /**
    //  * signatureTransferWithWitness SignatureTransfer technique with extra witness data
    //  * @param permit ISignatureTransfer.PermitTransferFrom(
    //  * @param transferDetails ISignatureTransfer.SignatureTransferDetails
    //  * @param from The address from which the transfer is made
    //  * @param witness The witness of the transfer
    //  * @param witnessTypeString The type of witness
    //  * @param sig signature
    //  * @param isForwarded is forwarded
    //  */
    // function _transferWithSellerIntent(
    //     ISignatureTransfer.PermitTransferFrom memory permit,
    //     ISignatureTransfer.SignatureTransferDetails memory transferDetails,
    //     address from,
    //     bytes32 witness,
    //     string memory witnessTypeString,
    //     bytes memory sig,
    //     bool isForwarded
    // ) internal virtual;

    // function _transferWithSellerIntent(
    //     ISignatureTransfer.PermitTransferFrom memory permit,
    //     ISignatureTransfer.SignatureTransferDetails memory transferDetails,
    //     address from,
    //     bytes32 witness,
    //     string memory witnessTypeString,
    //     bytes memory sig
    // ) internal virtual;

    /**
     * signatureTransfer
     * @param permit ISignatureTransfer.PermitTransferFrom(
     * @param transferDetails ISignatureTransfer.SignatureTransferDetails
     * @param sig signature
     * @param isForwarded is forwarded
     */
    function _transferFrom(
        ISignatureTransfer.PermitTransferFrom memory permit,
        ISignatureTransfer.SignatureTransferDetails memory transferDetails,
        bytes memory sig,
        bool isForwarded
    ) internal virtual;

    function _transferFrom(
        ISignatureTransfer.PermitTransferFrom memory permit,
        ISignatureTransfer.SignatureTransferDetails memory transferDetails,
        bytes memory sig
    ) internal virtual;

    function _setOperatorAndCall(
        address target,
        bytes memory data,
        uint32 selector,
        function (bytes calldata) internal returns (bytes memory) callback
    ) internal virtual returns (bytes memory);

        /**
     * allowanceTransferWithPermit
     * @param token The token to transfer
     * @param owner The owner of the token
     * @param recipient The recipient of the transfer
     * @param amount The amount of tokens to transfer
     */
    function _allowanceHolderTransferFrom(address token, address owner, address recipient, uint256 amount)
        internal
        virtual;

    // function _permit(address owner, IAllowanceTransfer.PermitSingle memory permitSingle, bytes memory signature)
    //     internal 
    //     virtual;
    

    modifier metaTx(address msgSender/*, bytes32 witness*/) virtual;

    modifier takerSubmitted() virtual;

}
