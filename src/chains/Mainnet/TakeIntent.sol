// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;


import {MainnetMixin} from "./Common.sol";
import {Settler} from "../../Settler.sol";

import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {ISignatureTransfer} from "@uniswap/permit2/interfaces/ISignatureTransfer.sol";
import {IAllowanceTransfer} from "@uniswap/permit2/interfaces/IAllowanceTransfer.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import {SignatureChecker} from "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";
import {ISettlerActions} from "../../ISettlerActions.sol";
import {ISettlerBase} from "../../interfaces/ISettlerBase.sol";
import {InvalidSpender, InvalidSignature, InvalidWitness} from "../../core/SettlerErrors.sol";

import {SettlerAbstract} from "../../SettlerAbstract.sol";
import {SettlerBase} from "../../SettlerBase.sol";
import {ParamsHash} from "../../utils/ParamsHash.sol";
import {Permit2PaymentAbstract} from "../../core/Permit2PaymentAbstract.sol";
import {Permit2PaymentTakeIntent} from "../../core/Permit2Payment.sol";
import {IAllowanceHolder} from "../../allowanceholder/IAllowanceHolder.sol";
import {IEscrow} from "../../interfaces/IEscrow.sol";
import {LighterAccount} from "../../account/LighterAccount.sol";

contract MainnetTakeIntent is Settler, MainnetMixin,  EIP712 {

    
    constructor(
        address lighterRelayer, IEscrow escrow, LighterAccount lighterAccount,
        bytes20 gitCommit, IAllowanceHolder allowanceHolder
        ) 
        MainnetMixin(lighterRelayer, escrow, lighterAccount, gitCommit)
        Permit2PaymentTakeIntent(allowanceHolder)
        EIP712("MainnetTakeIntent", "1") 
    {

    }

    /**
     * @dev Returns the EIP-712 domain separator for this contract
     */
    function _domainSeparator() internal view override returns (bytes32) {
        return super._domainSeparatorV4();
    }

    function _dispatch(uint256 i, uint256 action, bytes calldata data)
        internal
        override(Settler, MainnetMixin)
        returns (bool)
    {
        if (super._dispatch(i, action, data)) {
            return true;
        } else if (action == uint32(ISettlerActions.NATIVE_CHECK.selector)) {
            (uint256 deadline, uint256 msgValue) = abi.decode(data, (uint256, uint256));
            if (block.timestamp > deadline) {
                assembly ("memory-safe") {
                    mstore(0x00, 0xcd21db4f) // selector for `SignatureExpired(uint256)`
                    mstore(0x20, deadline)
                    revert(0x1c, 0x24)
                }
            }
            if (msg.value > msgValue) {
                assembly ("memory-safe") {
                    mstore(0x00, 0x4a094431) // selector for `MsgValueMismatch(uint256,uint256)`
                    mstore(0x20, msgValue)
                    mstore(0x40, callvalue())
                    revert(0x1c, 0x44)
                }
            }
        } else {
            return false;
        }
        return true;
    }


    function _dispatchVIP(uint256 action, bytes calldata data) internal virtual override DANGEROUS_freeMemory returns (bool) {
        if(action == uint32(ISettlerActions.ESCROW_AND_INTENT_CHECK.selector)) {
            (ISettlerBase.EscrowParams memory escrowParams, ISettlerBase.IntentParams memory intentParams) = abi.decode(data, (ISettlerBase.EscrowParams, ISettlerBase.IntentParams));
            bytes32 escrowTypedHash = getEscrowTypedHash(escrowParams, _domainSeparator());
            if (escrowTypedHash != getWitness()) {
                revert InvalidWitness();
            }
            makesureTradeValidation(escrowParams, intentParams);
            _makeEscrow(escrowTypedHash, escrowParams, 0, 0);
            return true;
        }

        return false;
    }

}