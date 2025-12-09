// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;


import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {Test} from "forge-std/Test.sol";
// import {BasePairTest} from "./BasePairTest.t.sol";
import {BasePairTest} from "./LocalBasePairTest.t.sol";
import {Settler} from "../src/Settler.sol";
import {ISettlerTakeIntent} from "../src/interfaces/ISettlerTakeIntent.sol";
import {MainnetTakeIntent} from "../src/chains/Mainnet/TakeIntent.sol";
import {LighterTicket} from "../src/token/LighterTicket.sol";
import {LighterAccount} from "../src/account/LighterAccount.sol";
import {ERC6551Registry} from "../src/account/ERC6551Registry.sol";
import {AccountV3Simplified} from "../src/account/AccountV3.sol";
import {MockUSDC} from "../src/utils/TokenMock.sol";
import {AllowanceHolder} from "../src/allowanceholder/AllowanceHolder.sol";
import {IAllowanceHolder} from "../src/allowanceholder/IAllowanceHolder.sol";
import {IEscrow} from "../src/interfaces/IEscrow.sol";
import {Escrow} from "../src/Escrow.sol";
import {ISettlerActions} from "../src/ISettlerActions.sol";
import {ActionDataBuilder} from "./utils/ActionDataBuilder.sol";
import {ISettlerBase} from "../src/interfaces/ISettlerBase.sol";
import {ISignatureTransfer} from "@uniswap/permit2/interfaces/ISignatureTransfer.sol";
import {console} from "forge-std/console.sol";

contract TakeIntentTest is BasePairTest {

    function _testName() internal pure override returns (string memory) {
        return "TakeIntent";
    }

    // function _testChainId() internal pure virtual override returns (string memory) {
    //     return "sepolia";
    // }

    // function _testBlockNumber() internal pure virtual override returns (uint256) {
    //     return 9788151;
    // }
    

    address buyer;
    address seller;
    address relayer;
    MockUSDC usdc;
    IAllowanceHolder allowanceHolder;
    IEscrow escrow;
    LighterAccount lighterAccount;
    MainnetTakeIntent internal settler;
    

    uint256 relayerPrivKey = 0x123;
    uint256 rentPrice = 0.00001 ether;
    

    function setUp() override public {
        relayer = vm.addr(relayerPrivKey);
        usdc = new MockUSDC();

        LighterTicket lighterTicket = new LighterTicket("LighterTicket", "LTKT", "https://lighter.im/ticket/");
        ERC6551Registry registry = new ERC6551Registry();
        AccountV3Simplified accountImpl = new AccountV3Simplified();
        
        lighterAccount = new LighterAccount(address(lighterTicket), address(registry), address(accountImpl), rentPrice);
        lighterTicket.transferOwnership(address(lighterAccount));
        escrow = new Escrow(relayer);
        allowanceHolder = new AllowanceHolder();


        buyer = vm.addr(FROM_PRIVATE_KEY);
        seller = vm.addr(MAKER_PRIVATE_KEY);
        vm.deal(buyer, 1 ether);
        vm.deal(seller, 1 ether);
        usdc.mint(seller, 10 ether);
        
        settler = new MainnetTakeIntent(
            relayer,
            escrow,
            lighterAccount,
            bytes20(0),
            allowanceHolder
        );
    }


    function fromToken() internal view override returns (IERC20) {
        return IERC20(address(usdc));
    }

    function buyerFeeRate() internal pure override returns (uint256) {
        return 0;
    }

    function sellerFeeRate() internal pure override returns (uint256) {
        return 0;
    }

    function getBuyer() internal view override returns (address) {
        return FROM;
    }

    function amount() internal pure override returns (uint256) {
        return 1 ether;
    }

    function getSeller() internal view override returns (address) {
        return MAKER;
    }

    function testTakeSellerIntent() public {
        ISettlerBase.IntentParams memory intentParams = getIntentParams();

        ISignatureTransfer.PermitTransferFrom memory permit = ISignatureTransfer.PermitTransferFrom({
            permitted: ISignatureTransfer.TokenPermissions({token: address(fromToken()), amount: amount()}),
            nonce: 1,
            deadline: getDeadline()
        });
        bytes memory transferSignatureWithWitness = getIntentWitnessTransferSignature(
            permit, address(settler), intentParams, MAKER_PRIVATE_KEY, permit2Domain
            );
        ISignatureTransfer.SignatureTransferDetails memory transferDetails = ISignatureTransfer.SignatureTransferDetails({
            to: address(escrow),
            requestedAmount: amount()
        });

        ISettlerBase.EscrowParams memory escrowParams = getEscrowParams();
        bytes32 escrowTypedDataHash = settler.getEscrowTypedHash(escrowParams);
        bytes32 intentTypedDataHash = settler.getIntentTypedHash(intentParams);
        bytes memory escrowSignature = getEscrowSignature(
            escrowParams, relayerPrivKey, permit2Domain
            );
        console.logString("escrowSignature");
        console.logBytes(escrowSignature);
        console.logString("escrowTypedDataHash");
        console.logBytes32(escrowTypedDataHash);
        console.logString("intentTypedDataHash");
        console.logBytes32(intentTypedDataHash);
        
        console.logBytes(escrowSignature);
        
        bytes[] memory actions = ActionDataBuilder.build(
            // intent signature is not used in signature sell intent.
            abi.encodeCall(ISettlerActions.ESCROW_AND_INTENT_CHECK, (escrowParams, intentParams, bytes(""))),
            abi.encodeCall(ISettlerActions.ESCROW_PARAMS_CHECK, (escrowParams, escrowSignature)),
            abi.encodeCall(ISettlerActions.SIGNATURE_TRANSFER_FROM_WITH_WITNESS, (permit, transferDetails, intentParams, transferSignatureWithWitness))
        );

        // MainnetTakeIntent _settler = settler;

        uint256 beforeBalance = balanceOf(fromToken(), seller);
        console.log("beforeBalance", beforeBalance);
        vm.startPrank(buyer);
        snapStartName("TakeIntent_takeSellerIntent");
        // _settler.execute(
        //     seller,
        //     escrowTypedDataHash,
        //     intentTypedDataHash,
        //     actions
        // );
        snapEnd();
        vm.stopPrank();
        uint256 afterBalance = fromToken().balanceOf(seller);
        console.log("afterBalance", afterBalance);
        console.log("amount", amount());

        // assertGt(afterBalance, beforeBalance);
    }
}