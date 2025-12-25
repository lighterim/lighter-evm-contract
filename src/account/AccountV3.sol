// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

/**
 * @title AccountV3 Wrapper
 * @dev This is a wrapper contract for:
 * 1. Test environment: Use simplified ERC6551Account
 * 2. Production environment: Use TokenBound official deployed AccountV3
 * 
 * TokenBound official AccountV3 has been deployed on major networks:
 * - Deployed using CREATE2, deterministic addresses
 * - Includes full features: ERC-4337, permissions, locking, batch execution
 * 
 * Official deployment parameters:
 * - EntryPoint: 0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789
 * - MulticallForwarder: 0xcA1167915584462449EE5b4Ea51c37fE81eCDCCD
 * - Registry: 0x000000006551c19487814612e58FE06813775758
 * - Guardian: Use tokenboundSafe
 * 
 * Deployment script will select based on network:
 * - Test networks: Deploy this contract
 * - Mainnet: Use official address
 */

import {ERC6551Account as _ERC6551Account} from "erc6551/src/examples/simple/ERC6551Account.sol";

/**
 * @dev Simplified version for testing
 * Production environment should use TokenBound official deployed AccountV3
 */
contract AccountV3Simplified is _ERC6551Account {
    // This contract is for testing only
    // Production environment should use TokenBound official AccountV3 implementation
}

