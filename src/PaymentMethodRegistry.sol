// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;


import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ISettlerBase} from "./interfaces/ISettlerBase.sol";
import {IPaymentMethodRegistry} from "./interfaces/IPaymentMethodRegistry.sol";
import {InvalidWindowSeconds, ZeroAddress} from "./core/SettlerErrors.sol";

/**
 * @title PaymentMethodsRegistry
 * @author @Dust
 * @notice This contract is used to register payment methods and verifiers for the Settler contract.
 * @dev
 */
contract PaymentMethodRegistry is Ownable, IPaymentMethodRegistry {

    mapping(bytes32 => ISettlerBase.PaymentMethodConfig) public configs;
    mapping(bytes32 => mapping(ISettlerBase.Stage => address)) public verifiers;

    event PaymentMethodConfigAdded(bytes32 indexed paymentMethod, ISettlerBase.PaymentMethodConfig config);
    event VerifierAdded(bytes32 indexed paymentMethod, ISettlerBase.Stage stage, address indexed verifier);
    event VerifierRemoved(bytes32 indexed paymentMethod, ISettlerBase.Stage stage, address indexed verifier);

    constructor() Ownable(msg.sender) {
    }

    function addPaymentMethodConfig(bytes32 _paymentMethod, ISettlerBase.PaymentMethodConfig memory _config) external onlyOwner {
        if(_config.windowSeconds == 0 || _config.disputeWindowSeconds == 0) revert InvalidWindowSeconds();
        configs[_paymentMethod] = _config;
        emit PaymentMethodConfigAdded(_paymentMethod, _config);
    }

    function getPaymentMethodConfig(bytes32 _paymentMethod) external view returns (ISettlerBase.PaymentMethodConfig memory) {
        return configs[_paymentMethod];
    }

    function addVerifier(bytes32 _paymentMethod, ISettlerBase.Stage _stage, address _verifier) external onlyOwner {
        if(_verifier == address(0)) revert ZeroAddress();
        verifiers[_paymentMethod][_stage] = _verifier;
        emit VerifierAdded(_paymentMethod, _stage, _verifier);
    }

    function removeVerifier(bytes32 _paymentMethod, ISettlerBase.Stage _stage) external onlyOwner {
        address verifier = verifiers[_paymentMethod][_stage];
        delete verifiers[_paymentMethod][_stage];
        emit VerifierRemoved(_paymentMethod, _stage, verifier);
    }

    function getVerifier(bytes32 _paymentMethod, ISettlerBase.Stage _stage) external view returns (address) {
        return verifiers[_paymentMethod][_stage];
    }   
}