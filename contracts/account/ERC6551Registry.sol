// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

// 重新导出标准的 ERC6551Registry
import {ERC6551Registry as _ERC6551Registry} from "erc6551/src/ERC6551Registry.sol";

// 创建别名让 Hardhat 能识别
contract ERC6551Registry is _ERC6551Registry {}

