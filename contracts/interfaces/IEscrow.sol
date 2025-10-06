// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;


import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {ISettlerBase} from "./ISettlerBase.sol";

interface IEscrow {

    function creditOf(address token, address account) external view returns (uint256);

    function create(address token, address buyer, address seller, uint256 amount, bytes32 escrowHash, ISettlerBase.EscrowData memory escrowData) external;

    function paid(bytes32 escrowHash, address token, address buyer) external;

    function release(address token, address buyer, address seller, uint256 amount, bytes32 escrowHash, ISettlerBase.EscrowStatus status) external;

    function cancel(address token, address buyer, address seller, uint256 amount, bytes32 escrowHash, ISettlerBase.EscrowStatus status) external;

    function claim(address token, address to, uint256 amount) external;


    //event
    event Created(address indexed token, address indexed buyer, address indexed seller, bytes32 escrowHash, uint256 amount);
    event Paid(address indexed token, address indexed buyer, bytes32 indexed escrowHash, uint64 paidSeconds);
    event Released(address indexed token, address indexed buyer, address indexed seller, bytes32 escrowHash, uint256 amount, ISettlerBase.EscrowStatus status);
    event Cancelled(address indexed token, address indexed buyer, address indexed seller, bytes32 escrowHash, uint256 amount, ISettlerBase.EscrowStatus status);
    event Claimed(address indexed token, address indexed to, uint256 amount);
}