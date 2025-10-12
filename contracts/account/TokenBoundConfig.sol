// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

/**
 * @title TokenBound Configuration
 * @dev 存储 TokenBound 生态系统的标准合约地址
 * 
 * 这些地址在多个网络上是一致的，通过 CREATE2 部署
 */
library TokenBoundConfig {
    /**
     * @dev ERC-4337 EntryPoint v0.6.0 标准地址
     * 部署在所有主要网络上
     */
    address internal constant ENTRY_POINT = 0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789;
    
    /**
     * @dev TokenBound MulticallForwarder 地址
     * 用于批量调用
     */
    address internal constant MULTICALL_FORWARDER = 0xcA1167915584462449EE5b4Ea51c37fE81eCDCCD;
    
    /**
     * @dev ERC-6551 Registry 标准地址
     * 用于创建 Token Bound Accounts
     */
    address internal constant ERC6551_REGISTRY = 0x000000006551c19487814612e58FE06813775758;
    
    /**
     * @dev TokenBound Safe (用于 Guardian)
     * 这是 TokenBound 官方的多签地址
     */
    address internal constant TOKENBOUND_SAFE = 0x781b6A527482828bB04F33563797d4b696ddF328;
    
    /**
     * @dev 获取所有配置
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

