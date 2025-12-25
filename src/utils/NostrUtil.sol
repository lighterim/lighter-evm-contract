// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;


library NostrUtil {
/**
     * @notice Convert string to bytes32
     * @dev If string length is less than 32 bytes, right-pad with zeros. If greater than 32 bytes, truncate.
     * Uses inline assembly to load data directly from memory.
     * @param _str String to convert
     * @return result Converted bytes32
     */
    function stringToPubkey(string memory _str) public pure returns (bytes32 result) {
        require(bytes(_str).length <= 32, "stringToPubkey: String too long");
        assembly {
            // Load the first 32 bytes of content from the string's memory address
            // String layout in memory: first slot stores length, subsequent slots store content
            // add(_str, 32) skips the length field and points directly to content
            result := mload(add(_str, 32))
        }
    }
}