// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;


import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {ERC6551Registry} from "../src/account/ERC6551Registry.sol";
import {AccountV3Simplified} from "../src/account/AccountV3.sol";
import {LighterTicket} from "../src/token/LighterTicket.sol";
import {Test} from "forge-std/Test.sol";
import {IERC721Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";

import {LighterAccount} from "../src/account/LighterAccount.sol";
import {ParamsHash} from "../src/utils/ParamsHash.sol";
import {ISettlerBase} from "../src/interfaces/ISettlerBase.sol";
import {console} from "forge-std/console.sol";
contract SettlerTest is Test {

  using ParamsHash for ISettlerBase.EscrowParams;
  

  function setUp() public {
    
  }

  


  function test_lighterAccount() public {
    console.log("escrowHash");
    console.logBytes32(getEscrowParams().hash());

  }


  function getEscrowParams() public view returns (ISettlerBase.EscrowParams memory escrowParams) {
    

        escrowParams = ISettlerBase.EscrowParams({
            id: 1,
            token: address(0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238),
            volume: 1500000,
            price: 1000000000000000000,
            usdRate: 1000000000000000000,
            payer: address(0xD58382f295f5c98BAeB525FAbb7FEBcCc62bc63B),
            seller: address(0xD58382f295f5c98BAeB525FAbb7FEBcCc62bc63B),
            sellerFeeRate: 0,
            paymentMethod: bytes32(0x0000000000000000000000000000000000000000000000000000000000000000),
            currency: bytes32(0x0000000000000000000000000000000000000000000000000000000000000000),
            payeeDetails: bytes32(0x0000000000000000000000000000000000000000000000000000000000000000),
            buyer: address(0xD58382f295f5c98BAeB525FAbb7FEBcCc62bc63B),
            buyerFeeRate: 0
        });
    }

}