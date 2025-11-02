// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "forge-std/console.sol";

contract MockUSDC is ERC20 {
    constructor() ERC20("USDC", "USC") {}

    function mint(address to, uint256 amount) public {
        console.log("Minting %s tokens to the address %s", amount, to);
        _mint(to, amount);
        console.log("Post Mint");
    }
}
