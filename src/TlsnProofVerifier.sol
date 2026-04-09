// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";

import {ISettlerBase} from "./interfaces/ISettlerBase.sol";
import {revertActionInvalid} from "./core/SettlerErrors.sol";
import {VerifierAbstract} from "./core/VerifierAbstract.sol";
import {ITlsnProofVerifier} from "./interfaces/ITlsnProofVerifier.sol";
import {IEscrow} from "./interfaces/IEscrow.sol";
import {LighterAccount} from "./account/LighterAccount.sol";
import {
    UnauthorizedCaller, InvalidTlsnProofSignature, InvalidNullifier, InvalidPaymentMethod, InvalidEscrowId,
    InvalidCurrency, InvalidPayeeDetails, PaymentInsufficient
} from "./core/SettlerErrors.sol";
import {ParamsHash} from "./utils/ParamsHash.sol";
import {FullMath} from "./vendor/FullMath.sol";
import {Context} from "./Context.sol";

abstract contract TlsnProofVerifier is VerifierAbstract, ITlsnProofVerifier, EIP712{

    using FullMath for uint256;
    using ParamsHash for ISettlerBase.PaymentDetails;
    using ParamsHash for ISettlerBase.EscrowParams;

    LighterAccount internal lighterAccount;
    address internal tlsnWitness;

    mapping(bytes32 => bool) internal nullifiers;

    event GitCommit(bytes20 indexed);

    constructor(address tlsnWitness_, LighterAccount lighterAccount_, IEscrow escrow_, address lighterRelayer_, bytes20 gitCommit_) Context(escrow_, lighterRelayer_){
        if (block.chainid != 31337) {
            emit GitCommit(gitCommit_);
            // assert(IERC721Owner(DEPLOYER).ownerOf(_tokenId()) == address(this));
        } else {
            assert(gitCommit_ == bytes20(0));
        }
        tlsnWitness = tlsnWitness_;
        lighterAccount = lighterAccount_;
    }

    function _getPaymentMethod() internal view virtual returns (bytes32);

    function getDomainSeparator() public view returns (bytes32){
        return _domainSeparatorV4();
    }

    function _domainSeparator() internal view returns (bytes32){
        return _domainSeparatorV4();
    }

    function getEscrowTypedHash(ISettlerBase.EscrowParams memory params) public view returns (bytes32){
        bytes32 escrowHash = params.hash();
        return _hashTypedDataV4(escrowHash);
    }

    function getPaymentTypedHash(ISettlerBase.PaymentDetails memory params) public view returns (bytes32){
        bytes32 paymentHash = params.hash();
        return _hashTypedDataV4(paymentHash);
    }

    function releaseAfterProofVerify(
        ISettlerBase.EscrowParams calldata escrowParams, 
        ISettlerBase.PaymentDetails calldata paymentParams,
        bytes calldata tlsnProofSig,
        bytes calldata sig
    ) external returns (bool) {
        (bytes32 escrowHash,) = makesureEscrowParams(_domainSeparator(), escrowParams, sig);
        if(!lighterAccount.isOwnerCall(escrowParams.buyer, msg.sender)) revert UnauthorizedCaller(msg.sender);
        
        bytes32 paymentMethod = _getPaymentMethod();
        if(escrowParams.paymentMethod != paymentMethod || paymentParams.paymentMethod != paymentMethod) revert InvalidPaymentMethod();
        if(!isValidSignature(tlsnWitness, getPaymentTypedHash(paymentParams), tlsnProofSig)) revert InvalidTlsnProofSignature();

        if(escrowParams.id != paymentParams.id) revert InvalidEscrowId();
        if(escrowParams.currency != paymentParams.currency) revert InvalidCurrency();
        if(escrowParams.payeeDetails != paymentParams.payeeDetails) revert InvalidPayeeDetails();

        uint256 amount = escrowParams.volume * escrowParams.price;
        if (paymentParams.amount < amount) revert PaymentInsufficient(amount, paymentParams.amount);

        bytes32 nullifier = _hashNullifier(paymentMethod, paymentParams.paymentId);
        if(nullifiers[nullifier]) revert InvalidNullifier();
        
        nullifiers[nullifier] = true;
        _releaseByVerifier(escrowHash, escrowParams, paymentParams.confirmTs);
        

        return true;
    }


    function _releaseByVerifier(bytes32 escrowHash, ISettlerBase.EscrowParams calldata escrowParams, uint64 confirmTs) internal override {
        uint256 volume = escrowParams.volume;
        address token = escrowParams.token;
        address buyer = escrowParams.buyer;
        address seller = escrowParams.seller;
        uint256 buyerFee = getFeeAmount(volume, escrowParams.buyerFeeRate);
        uint256 sellerFee = getFeeAmount(volume, escrowParams.sellerFeeRate);
        (uint32 paidSeconds, uint32 releaseSeconds) = escrow.releaseByVerifier(escrowHash, escrowParams.id, token, buyer, buyerFee, seller, sellerFee, volume, confirmTs);
        uint8 tokenDecimals = IERC20(token).decimals();
        uint256 amountUsd = _calcAmountUsd(volume, tokenDecimals, escrowParams.price, escrowParams.usdRate);
        lighterAccount.releasePendingTx(buyer, seller, amountUsd, paidSeconds, releaseSeconds);
    }

    function _hashNullifier(bytes32 paymentMethod, bytes32 paymentId) internal pure  returns (bytes32 result) {
        assembly {
            mstore(0x00, paymentMethod)
            mstore(0x20, paymentId)
            result := keccak256(0x00, 0x40)
        }
    }

    /**
     * @notice Calculates the USD value of a given token amount.
     * @dev Formula: (tokenAmount * price * usdRate) / 10^(tokenDecimals + PRICE_DECIMALS + USD_RATE_DECIMALS - USD_DECIMALS)
     * @param tokenAmount The raw amount of the token (in its smallest unit)
     * @param tokenDecimals The decimals of the token
     * @param price The price of the token (scaled by PRICE_DECIMALS)
     * @param usdRate The conversion rate to USD (scaled by USD_RATE_DECIMALS)
     * @return amountUsd The total value in USD (scaled by USD_DECIMALS)
     */
    function _calcAmountUsd(
        uint256 tokenAmount,
        uint8 tokenDecimals,
        uint256 price,
        uint256 usdRate
    ) internal pure returns (uint256 amountUsd) {
        // Optimization: Calculate the shared exponent once.
        // Small uint8 operations are safe from overflow in this context.
        uint256 exponent;
        unchecked {
            exponent = uint256(tokenDecimals) + PRICE_DECIMALS + USD_RATE_DECIMALS - USD_DECIMALS;
        }

        amountUsd = (tokenAmount * price).mulDiv(usdRate, 10 ** exponent);
    }

    modifier finalize(address sender, ISettlerBase.EscrowParams memory escrowParams) override {
        _;
    }

}