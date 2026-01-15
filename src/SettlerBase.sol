// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {IERC20} from "forge-std/interfaces/IERC20.sol";

import {SafeTransferLib} from "./vendor/SafeTransferLib.sol";
import {FullMath} from "./vendor/FullMath.sol";

import {InvalidPaymentMethod} from "./core/SettlerErrors.sol";
import {ISettlerActions} from "./ISettlerActions.sol";
import {TransientStorage} from "./utils/TransientStorage.sol";
import {ISettlerBase} from "./interfaces/ISettlerBase.sol";
import {SettlerAbstract} from "./SettlerAbstract.sol";
import {IPaymentMethodRegistry} from "./interfaces/IPaymentMethodRegistry.sol";

import {ISignatureTransfer} from "@uniswap/permit2/interfaces/ISignatureTransfer.sol";
import {IAllowanceTransfer} from "@uniswap/permit2/interfaces/IAllowanceTransfer.sol";



abstract contract SettlerBase is ISettlerBase, SettlerAbstract {
    using SafeTransferLib for IERC20;
    using SafeTransferLib for address payable;
    using FullMath for uint256;

    uint256 constant public BASIS_POINTS_BASE = 10000;
    uint8 constant public USD_DECIMALS = 6;
    uint8 constant public PRICE_DECIMALS = 18;
    uint8 constant public USD_RATE_DECIMALS = 18;

    IPaymentMethodRegistry internal paymentMethodRegistry;

    receive() external payable {}

    event GitCommit(bytes20 indexed);

    // When/if you change this, you must make corresponding changes to
    // `sh/deploy_new_chain.sh` and 'sh/common_deploy_settler.sh' to set
    // `constructor_args`.
    constructor(bytes20 gitCommit, IPaymentMethodRegistry paymentMethodRegistry_) {
        if (block.chainid != 31337) {
            emit GitCommit(gitCommit);
            // assert(IERC721Owner(DEPLOYER).ownerOf(_tokenId()) == address(this));
        } else {
            assert(gitCommit == bytes20(0));
        }
        paymentMethodRegistry = paymentMethodRegistry_;
    }


    function _setTakeIntent(address payer, bytes32 tokenPermissions, bytes32 witness, bytes32 intentTypeHash) internal {
        TransientStorage.setPayerAndWitness(payer, tokenPermissions, witness, intentTypeHash);
    }

    function _checkTakeIntent() internal view {
        TransientStorage.checkSpentPayerAndWitness();
    }

    function getWitness() internal view returns (bytes32) {
        return TransientStorage.getWitness();
    }

    function getIntentTypeHash() internal view returns (bytes32) {
        return TransientStorage.getIntentTypeHash();
    }

    function getPayer() internal view returns (address) {
        return TransientStorage.getPayer();
    }

    function getTokenPermissionsHash() internal view returns (bytes32) {
        return TransientStorage.getTokenPermissionsHash();
    }

    function clearPayer(address expectedOldPayer) internal {
        TransientStorage.clearPayer(expectedOldPayer);
    }

    function clearTokenPermissionsHash() internal {
        TransientStorage.clearTokenPermissionsHash();
    }

    function getAndClearWitness() internal returns (bytes32) {
        return TransientStorage.getAndClearWitness();
    }

    function clearWitness() internal {
        TransientStorage.clearWitness();
    }

    function clearIntentTypeHash() internal {
        TransientStorage.clearIntentTypeHash();
    }

    /**
     * @notice Get the amount with fee for a given amount and fee rate
     * @param amount The amount to get the amount with fee for
     * @param feeRate The fee rate to get the amount with fee for (e.g. 1000 for 10%)
     * @return The amount with fee
     */
    function getAmountWithFee(uint256 amount, uint256 feeRate) public pure returns (uint256) {
        return amount.mulDivUp(BASIS_POINTS_BASE + feeRate, BASIS_POINTS_BASE);
    }

    /**
     * @notice Get the fee amount for a given amount and fee rate
     * @param amount The amount to get the fee for
     * @param feeRate The fee rate to get the fee for (e.g. 1000 for 10%)
     * @return The fee amount
     */
    function getFeeAmount(uint256 amount, uint256 feeRate) public pure returns (uint256) {
        return amount.mulDivUp(feeRate, BASIS_POINTS_BASE);
    }

    function _dispatchVIP(uint256 action, bytes calldata data) internal virtual returns (bool);

    function _makesurePaymentMethod(bytes32 paymentMethod) internal view{
        ISettlerBase.PaymentMethodConfig memory cfg = paymentMethodRegistry.getPaymentMethodConfig(paymentMethod);
        if(!cfg.isEnabled) revert InvalidPaymentMethod();
    }

    function _getPaymentMethodConfig(bytes32 paymentMethod) internal view returns (ISettlerBase.PaymentMethodConfig memory){
        return paymentMethodRegistry.getPaymentMethodConfig(paymentMethod);
    }
}
