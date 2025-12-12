// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {SettlerBase} from "../../SettlerBase.sol";
import {ISettlerBase} from "../../interfaces/ISettlerBase.sol";

import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {SafeTransferLib} from "../../vendor/SafeTransferLib.sol";
import {ISettlerActions} from "../../ISettlerActions.sol";
import {ISignatureTransfer} from "@uniswap/permit2/interfaces/ISignatureTransfer.sol";
import {SettlerAbstract} from "../../SettlerAbstract.sol";
import {Permit2PaymentBase} from "../../core/Permit2Payment.sol";
import {FreeMemory} from "../../utils/FreeMemory.sol";
import {IEscrow} from "../../interfaces/IEscrow.sol";
import {LighterAccount} from "../../account/LighterAccount.sol";
// import {console} from "forge-std/console.sol";


abstract contract MainnetMixin is SettlerBase, FreeMemory{

    using SafeTransferLib for IERC20;
    using SafeTransferLib for address payable;


    address internal lighterRelayer;
    IEscrow internal escrow;
    LighterAccount internal lighterAccount;

    constructor(address lighterRelayer_, IEscrow escrow_, LighterAccount lighterAccount_, bytes20 gitCommit) SettlerBase(gitCommit) {
        // assert(block.chainid == 1 || block.chainid == 31337);
        lighterRelayer = lighterRelayer_;
        escrow = escrow_;
        lighterAccount = lighterAccount_;
    }

    function _getRelayer() internal view override returns (address) {
        return lighterRelayer;
    }

    function _dispatch(uint256 i, uint256 action, bytes calldata data) internal virtual override(SettlerBase) DANGEROUS_freeMemory returns (bool) {
        return super._dispatch(i, action, data);
    }


    function _makeEscrow(bytes32 escrowTypedDataHash, ISettlerBase.EscrowParams memory escrowParams, uint256 gasSpentForBuyer, uint256 gasSpentForSeller) internal {
        lighterAccount.addPendingTx(escrowParams.buyer);
        lighterAccount.addPendingTx(escrowParams.seller);
        escrow.create(
            address(escrowParams.token), 
            escrowParams.buyer, 
            escrowParams.seller, 
            escrowParams.volume, 
            escrowTypedDataHash, 
            escrowParams.id,
            ISettlerBase.EscrowData(
                {
                    status: ISettlerBase.EscrowStatus.Escrowed,
                    paidSeconds: 0,
                    releaseSeconds: 0,
                    cancelTs: 0,
                    lastActionTs: uint64(block.timestamp),
                    gasSpentForBuyer: gasSpentForBuyer,
                    gasSpentForSeller: gasSpentForSeller
                }
            )
        );
        // console.logString("------------#### _makeEscrow### --------------------");
    }

}
