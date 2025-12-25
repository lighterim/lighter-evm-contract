// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

/**
 * @title TokenBound Configuration
 * @dev Stores standard contract addresses for TokenBound ecosystem
 * 
 * These addresses are consistent across multiple networks, deployed via CREATE2
 */
library TokenBoundConfig {
    /**
     * @dev ERC-4337 EntryPoint v0.6.0 standard address
     * Deployed on all major networks
     */
    address internal constant ENTRY_POINT = 0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789;
    
    /**
     * @dev TokenBound MulticallForwarder address
     * Used for batch calls
     */
    address internal constant MULTICALL_FORWARDER = 0xcA1167915584462449EE5b4Ea51c37fE81eCDCCD;
    
    /**
     * @dev ERC-6551 Registry standard address
     * Used for creating Token Bound Accounts
     */
    address internal constant ERC6551_REGISTRY = 0x000000006551c19487814612e58FE06813775758;
    
    /**
     * @dev TokenBound Safe (for Guardian)
     * This is TokenBound official multisig address
     */
    address internal constant TOKENBOUND_SAFE = 0x781b6A527482828bB04F33563797d4b696ddF328;
    
    /**
     * @dev Get all configurations
     */
    function getConfig() internal pure returns (
        address entryPoint,
        address multicallForwarder,
        address erc6551Registry,
        address tokenboundSafe
    ) {
        return (ENTRY_POINT, MULTICALL_FORWARDER, ERC6551_REGISTRY, TOKENBOUND_SAFE);
    }
}

