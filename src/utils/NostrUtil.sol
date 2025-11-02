// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;


library NostrUtil {
/**
     * @notice 将 string 转换为 bytes32。
     * @dev 如果字符串长度小于 32 字节，右侧会用零填充。如果大于 32 字节，则会截断。
     * 使用内联汇编直接从内存中加载数据。
     * @param _str 要转换的字符串。
     * @return result 转换后的 bytes32。
     */
    function stringToPubkey(string memory _str) public pure returns (bytes32 result) {
        require(bytes(_str).length <= 32, "stringToPubkey: String too long");
        assembly {
            // 从字符串的内存地址加载前 32 字节的内容。
            // 字符串在内存中的布局是：第一个 slot 存长度，后续 slot 存内容。
            // add(_str, 32) 跳过了长度字段，直接指向内容。
            result := mload(add(_str, 32))
        }
    }
}