// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {IEscrow} from "../src/interfaces/IEscrow.sol";
import {LighterAccount} from "../src/account/LighterAccount.sol";
import {MainnetWaypoint} from "../src/chains/Mainnet/Waypoint.sol";
import {MainnetTakeIntent} from "../src/chains/Mainnet/TakeIntent.sol";
import {ISettlerBase} from "../src/interfaces/ISettlerBase.sol";
import {ISettlerActions} from "../src/ISettlerActions.sol";
import {ISignatureTransfer} from "@uniswap/permit2/interfaces/ISignatureTransfer.sol";
import {ActionDataBuilder} from "./utils/ActionDataBuilder.sol";
import {Utils} from "./unit/Utils.sol";
import {BasePairTest} from "./BasePairTest.t.sol";
import {ParamsHash} from "../src/utils/ParamsHash.sol";
import {console} from "forge-std/console.sol";

contract WaypointTest is BasePairTest, Utils{

    using ParamsHash for ISettlerBase.EscrowParams;

    function _testName() internal pure override returns (string memory) {
        return "Waypoint";
    }

    function _testChainId() internal pure virtual override returns (string memory) {
        return "sepolia";
    }

    function _testBlockNumber() internal pure override returns (uint256) {
        return 9904727;
    }

    address buyer = vm.envAddress("BUYER_TBA");
    address seller = vm.envAddress("SELLER_TBA");
    IERC20 usdc = IERC20(vm.envAddress("USDC"));
    uint256 buyerPrivKey = vm.envUint("BUYER_PRIVATE_KEY");
    uint256 sellerPrivKey = vm.envUint("SELLER_PRIVATE_KEY");
    uint256 relayerPrivKey = vm.envUint("RELAYER_PRIVATE_KEY");

    address relayer = vm.addr(relayerPrivKey);
    address eoaBuyer = vm.addr(buyerPrivKey);
    address eoaSeller = vm.addr(sellerPrivKey);

    uint256 rentPrice = 0.00001 ether;
    bytes32 waypointDomain;
    bytes32 takeIntentDomain;

    IEscrow escrow = IEscrow(vm.envAddress("Escrow"));
    LighterAccount lighterAccount = LighterAccount(vm.envAddress("LighterAccount"));
    MainnetWaypoint waypoint = MainnetWaypoint(payable(vm.envAddress("Waypoint")));
    MainnetTakeIntent settler = MainnetTakeIntent(payable(vm.envAddress("TakeIntent")));

    function setUp() public override {
        waypointDomain = waypoint.getDomainSeparator();
        takeIntentDomain = settler.getDomainSeparator();
        vm.deal(eoaBuyer, 1 ether);
        vm.deal(eoaSeller, 1 ether);

    }

    function testPaid() public {
        (ISettlerBase.IntentParams memory intentParams, ISettlerBase.EscrowParams memory escrowParams)= paid();
        bytes32 escrowHash = escrowParams.hash();
        console.logString("escrowHash");
        console.logBytes32(escrowHash);
        assertTrue(escrow.getEscrowData(escrowHash).status == ISettlerBase.EscrowStatus.Paid);
    }

    function testSellerReleased() public {
        (ISettlerBase.IntentParams memory intentParams, ISettlerBase.EscrowParams memory escrowParams) = paid();

        bytes memory escrowSignature = getEscrowSignature(escrowParams, relayerPrivKey, waypointDomain);

        bytes[] memory actions = ActionDataBuilder.build(
            abi.encodeCall(ISettlerActions.RELEASE_BY_SELLER, (escrowParams, escrowSignature))
        );
        vm.startPrank(eoaSeller);
        waypoint.executeWaypoint(
            bytes32(0),
            actions
        );
        vm.stopPrank();
    }

    function paid() public returns (ISettlerBase.IntentParams memory intentParams, ISettlerBase.EscrowParams memory escrowParams) {
        (intentParams, escrowParams) = takeSellerIntent();

        bytes memory escrowSignature = getEscrowSignature(escrowParams, relayerPrivKey, waypointDomain);

        bytes[] memory actions = ActionDataBuilder.build(
            abi.encodeCall(ISettlerActions.MAKE_PAYMENT, (escrowParams, escrowSignature))
        );

        vm.startPrank(eoaBuyer);
        waypoint.executeWaypoint(
            bytes32(0),
            actions
        );
        vm.stopPrank();

        return (intentParams, escrowParams);
    }

    function takeSellerIntent() public returns (
        ISettlerBase.IntentParams memory intentParams, 
        ISettlerBase.EscrowParams memory escrowParams) {

        intentParams = getIntentParams();
        escrowParams = getEscrowParams();

        ISignatureTransfer.PermitTransferFrom memory permit = ISignatureTransfer.PermitTransferFrom({
            permitted: ISignatureTransfer.TokenPermissions({
                token: address(fromToken()), 
                amount: settler.getAmountWithFee(amount(), escrowParams.sellerFeeRate)
            }),
            nonce: 2,
            deadline: getDeadline()
        });
        
        bytes memory transferSignatureWithWitness = getIntentWitnessTransferSignature(
            permit, address(settler), intentParams, sellerPrivKey, permit2Domain
        );
        
        ISignatureTransfer.SignatureTransferDetails memory transferDetails = ISignatureTransfer.SignatureTransferDetails({
            to: address(escrow),
            requestedAmount: settler.getAmountWithFee(amount(), escrowParams.sellerFeeRate)
        });

        bytes32 escrowTypedDataHash = settler.getEscrowTypedHash(escrowParams);
        bytes32 intentTypedDataHash = settler.getIntentTypedHash(intentParams);
        bytes32 tokenPermissionsHash = settler.getTokenPermissionsHash(permit.permitted);
        bytes memory escrowSignature = getEscrowSignature(
            escrowParams, relayerPrivKey, takeIntentDomain
        );
        
        bytes[] memory actions = ActionDataBuilder.build(
            // intent signature is not used in signature sell intent.
            abi.encodeCall(ISettlerActions.ESCROW_AND_INTENT_CHECK, (escrowParams, intentParams, bytes(""))),
            abi.encodeCall(ISettlerActions.ESCROW_PARAMS_CHECK, (escrowParams, escrowSignature)),
            abi.encodeCall(ISettlerActions.SIGNATURE_TRANSFER_FROM_WITH_WITNESS, (permit, transferDetails, intentParams, transferSignatureWithWitness))
        );

        vm.startPrank(eoaBuyer);
         settler.execute(
            eoaSeller,
            tokenPermissionsHash,
            escrowTypedDataHash,
            intentTypedDataHash,
            actions
        );
        // snapEnd();
        vm.stopPrank();
    }

    function fromToken() internal view override returns (IERC20) {
        return usdc;
    }

    function buyerFeeRate() internal pure override returns (uint256) {
        return 20;
    }

    function sellerFeeRate() internal pure override returns (uint256) {
        return 20;
    }

    function getBuyer() internal view override returns (address) {
        return buyer;
    }

    function amount() internal pure override returns (uint256) {
        // return 1 ether;
        return 1000000;
    }

    function getSeller() internal view override returns (address) {
        return seller;
    }
}