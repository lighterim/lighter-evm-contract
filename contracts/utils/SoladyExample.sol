// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

// Solady 常用工具库导入示例
import {LibString} from "solady/src/utils/LibString.sol";
import {SafeTransferLib} from "solady/src/utils/SafeTransferLib.sol";
import {FixedPointMathLib} from "solady/src/utils/FixedPointMathLib.sol";
import {LibBytes} from "solady/src/utils/LibBytes.sol";
import {LibBitmap} from "solady/src/utils/LibBitmap.sol";
import {ECDSA} from "solady/src/utils/ECDSA.sol";
import {MerkleProofLib} from "solady/src/utils/MerkleProofLib.sol";
import {SignatureCheckerLib} from "solady/src/utils/SignatureCheckerLib.sol";
import {LibClone} from "solady/src/utils/LibClone.sol";

/**
 * @title SoladyExample
 * @dev Solady 工具函数使用示例
 * 
 * Solady 是一个高度优化的 Solidity 库，提供：
 * - Gas 优化的工具函数
 * - 安全的转账函数
 * - 字符串处理
 * - 数学运算
 * - 签名验证
 * - 等等...
 */
contract SoladyExample {
    using LibString for *;
    using LibBytes for bytes;
    using LibBitmap for LibBitmap.Bitmap;

    // ============ 字符串工具示例 ============

    /**
     * @notice 将 uint256 转换为字符串
     * @param value 数值
     * @return 字符串表示
     */
    function uintToString(uint256 value) external pure returns (string memory) {
        return LibString.toString(value);
    }

    /**
     * @notice 将地址转换为字符串（带 0x 前缀）
     * @param addr 地址
     * @return 字符串表示
     */
    function addressToString(address addr) external pure returns (string memory) {
        return LibString.toHexString(addr);
    }

    /**
     * @notice 将 bytes32 转换为十六进制字符串
     * @param data 数据
     * @return 字符串表示
     */
    function bytes32ToString(bytes32 data) external pure returns (string memory) {
        return LibString.toHexString(uint256(data), 32);
    }

    // ============ 数学工具示例 ============

    /**
     * @notice 计算百分比（避免溢出）
     * @param amount 金额
     * @param percentage 百分比（以 basis points 表示，10000 = 100%）
     * @return 计算结果
     */
    function calculatePercentage(uint256 amount, uint256 percentage) 
        external 
        pure 
        returns (uint256) 
    {
        // mulDiv(a, b, c) = a * b / c，避免中间溢出
        return FixedPointMathLib.mulDiv(amount, percentage, 10000);
    }

    /**
     * @notice 计算平方根
     * @param x 输入值
     * @return 平方根
     */
    function sqrt(uint256 x) external pure returns (uint256) {
        return FixedPointMathLib.sqrt(x);
    }

    // ============ 安全转账示例 ============

    /**
     * @notice 安全转账 ETH
     * @param to 接收地址
     * @param amount 金额
     */
    function safeTransferETH(address to, uint256 amount) external {
        SafeTransferLib.safeTransferETH(to, amount);
    }

    /**
     * @notice 安全转账 ERC20
     * @param token ERC20 代币地址
     * @param to 接收地址
     * @param amount 金额
     */
    function safeTransferERC20(address token, address to, uint256 amount) external {
        SafeTransferLib.safeTransfer(token, to, amount);
    }

    /**
     * @notice 安全批准 ERC20
     * @param token ERC20 代币地址
     * @param spender 授权地址
     * @param amount 金额
     */
    function safeApproveERC20(address token, address spender, uint256 amount) external {
        SafeTransferLib.safeApprove(token, spender, amount);
    }

    // ============ Bytes 工具示例 ============

    /**
     * @notice 切片 bytes
     * @param data 原始数据
     * @param start 起始位置
     * @param end 结束位置
     * @return 切片结果
     */
    function sliceBytes(bytes calldata data, uint256 start, uint256 end) 
        external 
        pure 
        returns (bytes memory) 
    {
        return LibBytes.slice(data, start, end);
    }

    // ============ 签名验证示例 ============

    /**
     * @notice 恢复签名者地址
     * @param hash 消息哈希
     * @param signature 签名
     * @return 签名者地址
     */
    function recoverSigner(bytes32 hash, bytes calldata signature) 
        external 
        view 
        returns (address) 
    {
        return ECDSA.recover(hash, signature);
    }

    /**
     * @notice 验证签名
     * @param signer 预期签名者
     * @param hash 消息哈希
     * @param signature 签名
     * @return 是否有效
     */
    function isValidSignature(
        address signer, 
        bytes32 hash, 
        bytes calldata signature
    ) external view returns (bool) {
        return SignatureCheckerLib.isValidSignatureNow(signer, hash, signature);
    }

    // ============ Merkle Proof 示例 ============

    /**
     * @notice 验证 Merkle Proof
     * @param proof Merkle proof
     * @param root Merkle root
     * @param leaf 叶节点
     * @return 是否有效
     */
    function verifyMerkleProof(
        bytes32[] calldata proof,
        bytes32 root,
        bytes32 leaf
    ) external pure returns (bool) {
        return MerkleProofLib.verify(proof, root, leaf);
    }

    // ============ Bitmap 工具示例 ============

    LibBitmap.Bitmap private bitmap;

    /**
     * @notice 设置 bitmap 位
     * @param index 位索引
     */
    function setBit(uint256 index) external {
        bitmap.set(index);
    }

    /**
     * @notice 获取 bitmap 位
     * @param index 位索引
     * @return 是否设置
     */
    function getBit(uint256 index) external view returns (bool) {
        return bitmap.get(index);
    }

    // ============ Clone 工具示例 ============

    /**
     * @notice 使用最小代理模式克隆合约
     * @param impl 实现合约地址
     * @return 克隆合约地址
     */
    function cloneContract(address impl) external returns (address) {
        return LibClone.clone(impl);
    }

    /**
     * @notice 使用确定性克隆（CREATE2）
     * @param impl 实现合约地址
     * @param salt 盐值
     * @return 克隆合约地址
     */
    function cloneDeterministic(address impl, bytes32 salt) 
        external 
        returns (address) 
    {
        return LibClone.cloneDeterministic(impl, salt);
    }
}

