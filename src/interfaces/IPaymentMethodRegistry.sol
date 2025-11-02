//SPDX-License-Identifier: MIT

pragma solidity ^0.8.25;

import {ISettlerBase} from "./ISettlerBase.sol";

interface IPaymentMethodRegistry {
    
    function getPaymentMethodConfig(bytes32 _paymentMethod) external view returns (ISettlerBase.PaymentMethodConfig memory config);
    function addPaymenMethodConfig(bytes32 _paymentMethod, ISettlerBase.PaymentMethodConfig memory config) external;
    function getVerifier(bytes32 _paymentMethod, ISettlerBase.Stage _stage) external view returns (address verifier);
    function addVerifier(bytes32 _paymentMethod, ISettlerBase.Stage _stage, address verifier) external;

}
