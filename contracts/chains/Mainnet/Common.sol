// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {SettlerBase} from "../../SettlerBase.sol";
import {ISettlerBase} from "../../interfaces/ISettlerBase.sol";

import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {SafeTransferLib} from "../../vendor/SafeTransferLib.sol";
import {ISettlerActions} from "../../ISettlerActions.sol";
import {ISignatureTransfer} from "@uniswap/permit2/interfaces/ISignatureTransfer.sol";
import {SettlerAbstract} from "../../SettlerAbstract.sol";


abstract contract MainnetMixin is SettlerBase {

    using SafeTransferLib for IERC20;
    using SafeTransferLib for address payable;

    address internal lighterRelayer;
    mapping(bytes32 => ISettlerBase.EscrowData) internal escrowMap;

    constructor(address lighterRelayer_) {
        lighterRelayer = lighterRelayer_;
        assert(block.chainid == 1 || block.chainid == 31337);
    }



    function _dispatch(uint256, uint256 action, bytes calldata data) internal virtual override(SettlerAbstract, SettlerBase) returns (bool) {
        
        return true;
    }

    function _makeEscrow(bytes32 escrowTypedDataHash, ISettlerBase.EscrowParams memory escrowParams, uint256 gasSpentForBuyer, uint256 gasSpentForSeller) internal {
        escrowMap[escrowTypedDataHash] = ISettlerBase.EscrowData({
            status: ISettlerBase.EscrowStatus.Escrowed,
            paidSeconds: 0,
            releaseSeconds: 0,
            lastActionTs: block.timestamp,
            gasSpentForBuyer: gasSpentForBuyer,
            gasSpentForSeller: gasSpentForSeller
        });
    }
}
