// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {IERC20} from "forge-std/interfaces/IERC20.sol";

import {Context} from "./Context.sol";

abstract contract SettlerAbstract is Context {
    
    function _tokenId() internal pure virtual returns (uint256);

    function _domainSeparator() internal view virtual returns (bytes32);

    function _dispatch(uint256 i, uint256 action, bytes calldata data) internal virtual returns (bool);
    
}