// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;


import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {ISignatureTransfer} from "@uniswap/permit2/interfaces/ISignatureTransfer.sol";
import {IAllowanceHolder} from "../../allowanceholder/IAllowanceHolder.sol";
import {MainnetMixin} from "./Common.sol";
import {SettlerWaypoint} from "../../SettlerWaypoint.sol";
import {ISettlerActions} from "../../ISettlerActions.sol";


import {SettlerAbstract} from "../../SettlerAbstract.sol";
import {SettlerBase} from "../../SettlerBase.sol";
import {Context} from "../../Context.sol";
import {IEscrow} from "../../interfaces/IEscrow.sol";
import {LighterAccount} from "../../account/LighterAccount.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";


contract MainnetWaypoint is MainnetMixin, SettlerWaypoint, EIP712 {

    constructor(address lighterRelayer, IEscrow escrow, LighterAccount lighterAccount, bytes20 gitCommit, IAllowanceHolder allowanceHolder) 
    MainnetMixin(lighterRelayer, escrow, lighterAccount, gitCommit)
    EIP712("MainnetWaypoint", "1")
    {

    }


    
    function _dispatch(uint256 i, uint256 action, bytes calldata data) internal virtual override(SettlerAbstract) DANGEROUS_freeMemory returns (bool) {
        return false;
    }

    function _dispatchVIP(uint256 action, bytes calldata data) internal virtual override DANGEROUS_freeMemory returns (bool) {
        return false;
    }

    function getDomainSeparator() public view returns (bytes32) {
        return super._domainSeparatorV4();
    }

    /**
     * @dev Returns the EIP-712 domain separator for this contract
     */
    function _domainSeparator() internal view override returns (bytes32) {
        return super._domainSeparatorV4();
    }

}