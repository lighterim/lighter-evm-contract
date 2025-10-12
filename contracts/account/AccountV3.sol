// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

/**
 * @title AccountV3 Wrapper
 * @dev 这是一个包装合约，用于：
 * 1. 测试环境：使用简化的 ERC6551Account
 * 2. 生产环境：使用 TokenBound 官方部署的 AccountV3
 * 
 * TokenBound 官方 AccountV3 已在主要网络部署：
 * - 使用 CREATE2 部署，地址确定性
 * - 包含完整功能：ERC-4337、权限、锁定、批量执行
 * 
 * 官方部署参数：
 * - EntryPoint: 0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789
 * - MulticallForwarder: 0xcA1167915584462449EE5b4Ea51c37fE81eCDCCD
 * - Registry: 0x000000006551c19487814612e58FE06813775758
 * - Guardian: 使用 tokenboundSafe
 * 
 * 部署脚本将根据网络选择：
 * - 测试网络：部署此合约
 * - 主网：使用官方地址
 */

import {ERC6551Account as _ERC6551Account} from "erc6551/src/examples/simple/ERC6551Account.sol";

/**
 * @dev 用于测试的简化版本
 * 生产环境请使用 TokenBound 官方部署的 AccountV3
 */
contract AccountV3Simplified is _ERC6551Account {
    // 此合约仅用于测试
    // 生产环境应使用 TokenBound 官方的 AccountV3 实现
}

