// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {IAllowanceTransfer} from "@uniswap/permit2/interfaces/IAllowanceTransfer.sol";

interface IAllowanceHolder {

    
    function permit(address owner, IAllowanceTransfer.PermitSingle memory permitSingle, bytes calldata signature) external;

    /**
     * consumes allowance to recipient
     * @param token token address
     * @param owner owner
     * @param recipient recipient address
     * @param amount amount
     */
    function transferFrom(address token, address owner, address recipient, uint160 amount) external;
}
