// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

// Re-export standard ERC6551Registry
import {ERC6551Registry as _ERC6551Registry} from "erc6551/src/ERC6551Registry.sol";

// Create alias for Hardhat recognition
contract ERC6551Registry is _ERC6551Registry {}

