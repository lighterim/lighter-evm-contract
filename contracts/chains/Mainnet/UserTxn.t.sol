// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;


import {ERC6551Registry} from "../../account/ERC6551Registry.sol";
import {AccountV3Simplified} from "../../account/AccountV3.sol";
import {LighterTicket} from "../../token/LighterTicket.sol";
import {Test} from "forge-std/Test.sol";
import {MockUSDC} from "../../utils/TokenMock.sol";
import {IEscrow} from "../../interfaces/IEscrow.sol";
import {MainnetUserTxn} from "./UserTxn.sol";
import {Escrow} from "../../Escrow.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {ParamsHash} from "../../utils/ParamsHash.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {LighterAccount} from "../../account/LighterAccount.sol";
import {ISignatureTransfer} from "@uniswap/permit2/interfaces/ISignatureTransfer.sol";
import {PermitHash} from "@uniswap/permit2/libraries/PermitHash.sol";
import {ISettlerBase} from "../../interfaces/ISettlerBase.sol";
import {console} from "forge-std/console.sol";

contract UserTxnTest is Test {

    using ParamsHash for ISettlerBase.IntentParams;
    using ParamsHash for ISettlerBase.EscrowParams;
    using PermitHash for ISignatureTransfer.PermitTransferFrom;

  address buyer;
  address seller;
  uint256 relayerPrivKey = 0x123;
  address relayer;
  address tbaBuyer;
  uint256 sellerPrivKey = 0x456;
  uint256 rentPrice;

  MockUSDC usdc;

  IEscrow escrow;
  LighterAccount lighterAccount;
  LighterTicket lighterTicket;
  MainnetUserTxn userTxn;
  uint256 deadline = block.timestamp + 7 days;

  bytes32 private constant TYPE_HASH =
        keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");
  bytes32 private constant _HASHED_NAME_SIGNATURE_TRANSFER = keccak256("Permit2");
    bytes32 private constant _TYPE_HASH_SIGNATURE_TRANSFER =
        keccak256("EIP712Domain(string name,uint256 chainId,address verifyingContract)");
string public constant _PERMIT_TRANSFER_FROM_WITNESS_TYPEHASH_STUB =
        "PermitWitnessTransferFrom(TokenPermissions permitted,address spender,uint256 nonce,uint256 deadline,";
bytes32 public constant _TOKEN_PERMISSIONS_TYPEHASH = keccak256("TokenPermissions(address token,uint256 amount)");

  function setUp() public {
    init();
  }

  function init() internal {
    buyer = makeAddr("buyer");
    seller = vm.addr(sellerPrivKey);
    relayer = vm.addr(relayerPrivKey);
    vm.deal(buyer, 1 ether);
    vm.deal(seller, 1 ether);

    usdc = new MockUSDC();
    usdc.mint(seller, 10 ether);
    

    lighterTicket = new LighterTicket("LighterTicket", "LTKT", "https://lighter.im/ticket/");

    ERC6551Registry registry = new ERC6551Registry();
    AccountV3Simplified accountImpl = new AccountV3Simplified();
    rentPrice = 0.00001 ether;

    lighterAccount = new LighterAccount(address(lighterTicket), address(registry), address(accountImpl), rentPrice);
    lighterTicket.transferOwnership(address(lighterAccount));

    vm.prank(buyer);
    (,tbaBuyer) = lighterAccount.createAccount{value: rentPrice}(buyer, 0x0000000000000000000000000000000000000000000000000000000000000000);
    

    escrow = new Escrow(relayer);
    userTxn = new MainnetUserTxn(relayer, escrow, lighterAccount);
  }


  function test_takeSellerIntent() public {
    
    vm.startPrank(seller);
    usdc.approve(address(userTxn), 1 ether);
    vm.stopPrank();

    (ISignatureTransfer.PermitTransferFrom memory permit, ISignatureTransfer.SignatureTransferDetails memory transferDetails, ISettlerBase.IntentParams memory intentParams, ISettlerBase.EscrowParams memory escrowParams, bytes memory permitSig, bytes memory escrowSig) = getParams();
    vm.prank(buyer);
    userTxn.takeSellerIntent(permit, transferDetails, intentParams, escrowParams, permitSig, escrowSig);
    
    assertEq(usdc.balanceOf(seller), 9 ether);
    assertEq(usdc.balanceOf(address(escrow)), 1 ether);
    
  }

  function test_takeBuyerIntent() public {
    vm.prank(seller);
    usdc.approve(address(userTxn), 1 ether);
    
    
    (ISignatureTransfer.PermitTransferFrom memory permit, ISignatureTransfer.SignatureTransferDetails memory transferDetails, ISettlerBase.IntentParams memory intentParams, ISettlerBase.EscrowParams memory escrowParams, bytes memory permitSig, bytes memory intentSig, bytes memory escrowSig) = getTakeBuyerParams();
    vm.prank(seller);
    userTxn.takeBuyerIntent(permit, transferDetails, intentParams, escrowParams, permitSig, intentSig, escrowSig);
    
    // assertEq(usdc.balanceOf(seller), 9 ether);
    // assertEq(usdc.balanceOf(address(escrow)), 1 ether);
    
  }

  function getTakeBuyerParams() public view returns (
    ISignatureTransfer.PermitTransferFrom memory permit,
    ISignatureTransfer.SignatureTransferDetails memory transferDetails,
    ISettlerBase.IntentParams memory intentParams,
    ISettlerBase.EscrowParams memory escrowParams,
    bytes memory permitSig,
    bytes memory intentSig,
    bytes memory escrowSig
  ) {
    
    (permit, transferDetails) = getSignatureTransferPermit();
    bytes32 permitHash = permit.hash();
    bytes32 permitTypeDataHash = _hashTypedData(permitHash);
    (uint8 v_permit, bytes32 r_permit, bytes32 s_permit) = vm.sign(sellerPrivKey, permitTypeDataHash);
    permitSig = abi.encodePacked(r_permit, s_permit, v_permit);

    intentParams = getIntentParams();
    bytes32 intentHash = intentParams.hash();
    bytes32 intentTypeDataHash = MessageHashUtils.toTypedDataHash(_buildDomainSeparator(), intentHash);
    (uint8 v_intent, bytes32 r_intent, bytes32 s_intent) = vm.sign(sellerPrivKey, intentTypeDataHash);
    intentSig = abi.encodePacked(r_intent, s_intent, v_intent);
    
    escrowParams = getEscrowParams();
    bytes32 escrowHash = escrowParams.hash();
    bytes32 escrowTypeDataHash = MessageHashUtils.toTypedDataHash(_buildDomainSeparator(), escrowHash);
    (uint8 v_escrow, bytes32 r_escrow, bytes32 s_escrow) = vm.sign(relayerPrivKey, escrowTypeDataHash);
    escrowSig = abi.encodePacked(r_escrow, s_escrow, v_escrow);

    
  }

  function _buildDomainSeparator0(bytes32 typeHash, bytes32 nameHash) private view returns (bytes32) {
        return keccak256(abi.encode(typeHash, nameHash, block.chainid, address(0x000000000022D473030F116dDEE9F6B43aC78BA3)));
    }

    /// @notice Creates an EIP-712 typed data hash
    function _hashTypedData(bytes32 dataHash) internal view returns (bytes32) {
        return keccak256(abi.encodePacked("\x19\x01", _buildDomainSeparator0(_TYPE_HASH_SIGNATURE_TRANSFER, _HASHED_NAME_SIGNATURE_TRANSFER), dataHash));
    }

  function getParams() public view returns (
    ISignatureTransfer.PermitTransferFrom memory permit, 
    ISignatureTransfer.SignatureTransferDetails memory transferDetails,
    ISettlerBase.IntentParams memory intentParams, 
    ISettlerBase.EscrowParams memory escrowParams, 
    bytes memory permitSig, 
    bytes memory escrowSig) {
    intentParams = getIntentParams();
    escrowParams = getEscrowParams();
    bytes32 intentHash = intentParams.hash();
    bytes32 escrowHash = escrowParams.hash();


    console.logBytes32(escrowHash);
    
    bytes32 escrowTypeDataHash = MessageHashUtils.toTypedDataHash(_buildDomainSeparator(), escrowHash);
    console.logBytes32(escrowTypeDataHash);
    (uint8 v_escrow, bytes32 r_escrow, bytes32 s_escrow) = vm.sign(relayerPrivKey, escrowTypeDataHash);
    escrowSig = abi.encodePacked(r_escrow, s_escrow, v_escrow);
    console.logBytes(escrowSig);

    (permit, transferDetails) = getTransferWithWitness();
    console.logBytes32(intentHash);
    bytes32 permitHash = _hashPermitTransferWithWitness(permit, intentHash, address(userTxn));
    console.logBytes32(permitHash);
    (uint8 v_permit, bytes32 r_permit, bytes32 s_permit) = vm.sign(sellerPrivKey, permitHash);
    permitSig = abi.encodePacked(r_permit, s_permit, v_permit);
    console.logBytes(permitSig);
  }

  function getTransferWithWitness() public view returns (
    ISignatureTransfer.PermitTransferFrom memory permit,
    ISignatureTransfer.SignatureTransferDetails memory transferDetails
    ) {
    permit = ISignatureTransfer.PermitTransferFrom({
            permitted: ISignatureTransfer.TokenPermissions({ token: address(usdc), amount: 1 ether }),
            nonce: uint256(1347343934330334),
            deadline: deadline
        });
    transferDetails = ISignatureTransfer.SignatureTransferDetails({
        to: address(userTxn),
        requestedAmount: 1 ether
    });
  }

  function getSignatureTransferPermit() public view returns (
    ISignatureTransfer.PermitTransferFrom memory permit,
    ISignatureTransfer.SignatureTransferDetails memory transferDetails
  ) {
    permit = ISignatureTransfer.PermitTransferFrom({
            permitted: ISignatureTransfer.TokenPermissions({ token: address(usdc), amount: 1 ether }),
            nonce: uint256(1347343934330335),
            deadline: deadline
        });
    transferDetails = ISignatureTransfer.SignatureTransferDetails({
        to: address(userTxn),
        requestedAmount: 1 ether
    });
    
  }
  

  function getIntentParams() public view returns (ISettlerBase.IntentParams memory intentParams) {
    intentParams = ISettlerBase.IntentParams({
            token: IERC20(address(usdc)),
            range: ISettlerBase.Range({ min: 1 * 1e18, max: 2 * 1e18 }),
            expiryTime: uint64(deadline),
            currency: bytes32(0), 
            paymentMethod: bytes32(0), 
            payeeDetails: bytes32(0), 
            price: 1_000
        });
  }

  function getEscrowParams() public view returns (ISettlerBase.EscrowParams memory escrowParams) {
    escrowParams = ISettlerBase.EscrowParams({
            id: 1,
            token: IERC20(address(usdc)),
            volume: 1 ether,
            price: 1_000,
            usdRate: 1_000,
            seller: seller,
            sellerFeeRate: 1_000,
            paymentMethod: bytes32(0),
            currency: bytes32(0),
            payeeId: bytes32(0),
            payeeAccount: bytes32(0),
            buyer: buyer,
            buyerFeeRate: 1_000
        });
  }

  function _buildDomainSeparator() internal view returns (bytes32) {
    return keccak256(abi.encode(TYPE_HASH, keccak256(bytes("MainnetUserTxn")), keccak256(bytes("1")), block.chainid, address(userTxn)));
  }


  function _hashPermitTransferWithWitness(
    ISignatureTransfer.PermitTransferFrom memory permit,
        bytes32 witness,
        address spender
        ) internal pure returns (bytes32) {
    
        bytes32 typeHash = keccak256(abi.encodePacked(_PERMIT_TRANSFER_FROM_WITNESS_TYPEHASH_STUB, ParamsHash._INTENT_WITNESS_TYPE_STRING));
        console.logBytes32(typeHash);
        bytes32 tokenPermissionsHash = keccak256(abi.encode(_TOKEN_PERMISSIONS_TYPEHASH, permit.permitted));
        console.logBytes32(tokenPermissionsHash);
        return keccak256(abi.encode(typeHash, tokenPermissionsHash, spender, permit.nonce, permit.deadline, witness));
    
  }


}