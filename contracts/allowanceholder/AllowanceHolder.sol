// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {IAllowanceTransfer} from "@uniswap/permit2/interfaces/IAllowanceTransfer.sol";
import {IAllowanceHolder} from "./IAllowanceHolder.sol";
import {InvalidSpender} from "../core/SettlerErrors.sol";

/// @custom:security-contact security@0x.org
contract AllowanceHolder is IAllowanceHolder {
    
    IAllowanceTransfer internal constant PERMIT2_ALLOWANCE = IAllowanceTransfer(0x000000000022D473030F116dDEE9F6B43aC78BA3);

    constructor() {
    }

    function permit(address owner, IAllowanceTransfer.PermitSingle memory permitSingle, bytes calldata signature) external {
        if(permitSingle.spender != address(this)) revert InvalidSpender();
        // if(permitSingle.details.nonce != PERMIT2_ALLOWANCE.nonce(owner, permitSingle.details.token, permitSingle.spender)) revert InvalidNonce();
        PERMIT2_ALLOWANCE.permit(owner, permitSingle, signature);
    }

    function transferFrom(address token, address owner, address recipient, uint160 amount) public  {
        PERMIT2_ALLOWANCE.transferFrom(owner, recipient, amount, token);
    }
}
