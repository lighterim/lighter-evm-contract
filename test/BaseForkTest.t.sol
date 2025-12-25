// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

abstract contract BaseForkTest {
    function _testChainId() internal view virtual returns (string memory);
    function _testBlockNumber() internal view virtual returns (uint256);
}

contract MainnetDefaultFork is BaseForkTest {
    function _testChainId() internal pure virtual override returns (string memory) {
        return "mainnet";
    }

    function _testBlockNumber() internal pure virtual override returns (uint256) {
        return 18685612;
    }
}

// Local test mode: do not fork, return empty string
contract LocalFork is BaseForkTest {
    function _testChainId() internal pure virtual override returns (string memory) {
        return ""; // Empty string means do not fork
    }

    function _testBlockNumber() internal pure virtual override returns (uint256) {
        return 0; // Block number not used in local mode
    }
}
