// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;


import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {ISettlerBase} from "./ISettlerBase.sol";

interface IEscrow {

    function creditOf(IERC20 token, address account) external view returns (uint256);

    function create(IERC20 token, address buyer, address seller, uint256 amount, bytes32 escrowHash, ISettlerBase.EscrowData memory escrowData) external;

    function release(IERC20 token, address buyer, address seller, uint256 amount, bytes32 escrowHash, ISettlerBase.EscrowStatus status) external;

    function cancel(IERC20 token, address buyer, address seller, uint256 amount, bytes32 escrowHash, ISettlerBase.EscrowStatus status) external;

    function claim(IERC20 token, address to, uint256 amount) external;


    //event
    event Created(IERC20 indexed token, address indexed buyer, address indexed seller, bytes32 escrowHash, uint256 amount);
    event Released(IERC20 indexed token, address indexed buyer, address indexed seller, bytes32 escrowHash, uint256 amount, ISettlerBase.EscrowStatus status);
    event Cancelled(IERC20 indexed token, address indexed buyer, address indexed seller, bytes32 escrowHash, uint256 amount, ISettlerBase.EscrowStatus status);
    event Claimed(IERC20 indexed token, address indexed to, uint256 amount);
}