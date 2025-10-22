// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;


import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {ERC6551Registry} from "./account/ERC6551Registry.sol";
import {AccountV3Simplified} from "./account/AccountV3.sol";
import {LighterTicket} from "./token/LighterTicket.sol";
import {Test} from "forge-std/Test.sol";
import {IERC721Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";

import {LighterAccount} from "./account/LighterAccount.sol";
import {console} from "forge-std/console.sol";
contract SettlerTest is Test {
  address buyer;
  address seller;
  address relayer;
  address tbaBuyer;
  address tbaSeller;
  uint256 tbaBuyerTokenId;
  uint256 tbaSellerTokenId;
  uint256 rentPrice;

  IERC20 usdc;

  LighterAccount lighterAccount;
  LighterTicket lighterTicket;

  function setUp() public {
    init();
  }

  function init() internal {
    buyer = makeAddr("buyer");
    seller = makeAddr("seller");
    relayer = makeAddr("relayer");
    vm.deal(buyer, 1 ether);
    vm.deal(seller, 1 ether);

    usdc = IERC20(0x07865c6E87B9F70255377e024ace6630C1Eaa37F);
    lighterTicket = new LighterTicket("LighterTicket", "LTKT", "https://lighter.im/ticket/");

    ERC6551Registry registry = new ERC6551Registry();
    AccountV3Simplified accountImpl = new AccountV3Simplified();
    rentPrice = 0.00001 ether;

    lighterAccount = new LighterAccount(address(lighterTicket), address(registry), address(accountImpl), rentPrice);
    lighterTicket.transferOwnership(address(lighterAccount));

    // vm.startPrank(buyer);
    vm.prank(buyer);
    (tbaBuyerTokenId,tbaBuyer) = lighterAccount.createAccount{value: rentPrice}(buyer, 0x0000000000000000000000000000000000000000000000000000000000000000);
    // vm.stopPrank();

    vm.prank(seller);
    (tbaSellerTokenId, tbaSeller) = lighterAccount.createAccount{value: rentPrice}(seller, 0x0000000000000000000000000000000000000000000000000000000000000001);
    // vm.stopPrank();
    
    console.logBytes32(keccak256(abi.encodePacked("oren","wxp://f2f0cFGOsdaOtU3SQfpyBcl_0u0UCU9AIIVaTEmmVDgvN-Q","wechat")));
  }


  function test_lighterAccount() public {
    assertEq(lighterAccount.getBalance(), rentPrice*2);
    assertEq(lighterAccount.getAccountAddress(tbaBuyerTokenId), tbaBuyer);
    assertEq(lighterAccount.getAccountAddress(tbaSellerTokenId), tbaSeller);
    assertEq(lighterAccount.getQuota(tbaBuyer), 1);
    assertEq(lighterAccount.getQuota(tbaSeller), 1);

    vm.prank(buyer);
    lighterAccount.upgradeQuota{value: rentPrice}(tbaBuyerTokenId);
    assertEq(lighterAccount.getQuota(tbaBuyer), 2);

    vm.prank(buyer);
    lighterAccount.destroyAccount(tbaBuyerTokenId, payable(buyer));
    assertEq(lighterAccount.getBalance(), rentPrice);

    // (uint256 chainId, address tokenContract, uint256 tokenId) = lighterAccount.token(tbaBuyer);
    // assertEq(chainId, block.chainid);
    // assertEq(tokenContract, address(lighterTicket));
    // assertEq(tokenId, tbaBuyerTokenId);
    
    // vm.expectRevert();
    // lighterTicket.ownerOf(tokenId);

  }
}