// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;


import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ISettlerBase} from "./interfaces/ISettlerBase.sol";
import {IPaymentMethodRegistry} from "./interfaces/IPaymentMethodRegistry.sol";

/**
 * @title PaymentMethodsRegistry
 * @author @Moebius101
 * @notice This contract is used to register payment methods and verifiers for the Settler contract.
 * @dev This contract is owned by the Settler contract and can only be called by the owner.
 */
contract PaymentMethodRegistry is Ownable, IPaymentMethodRegistry {

    mapping(bytes32 => ISettlerBase.PaymentMethodConfig) public configs;
    mapping(bytes32 => mapping(ISettlerBase.Stage => address)) public verifiers;

    event PaymentMethodConfigAdded(bytes32 indexed paymentMethod, ISettlerBase.PaymentMethodConfig config);
    event VerifierAdded(bytes32 indexed paymentMethod, ISettlerBase.Stage stage, address indexed verifier);

    constructor() Ownable(msg.sender) {
    }

    function addPaymentMethodConfig(bytes32 _paymentMethod, ISettlerBase.PaymentMethodConfig memory _config) external onlyOwner {
        configs[_paymentMethod] = _config;

        emit PaymentMethodConfigAdded(_paymentMethod, _config);
    }

    function getPaymentMethodConfig(bytes32 _paymentMethod) external view returns (ISettlerBase.PaymentMethodConfig memory) {
        return configs[_paymentMethod];
    }

    function addVerifier(bytes32 _paymentMethod, ISettlerBase.Stage _stage, address _verifier) external onlyOwner {
        verifiers[_paymentMethod][_stage] = _verifier;

        emit VerifierAdded(_paymentMethod, _stage, _verifier);
    }

    function getVerifier(bytes32 _paymentMethod, ISettlerBase.Stage _stage) external view returns (address) {
        return verifiers[_paymentMethod][_stage];
    }   
}