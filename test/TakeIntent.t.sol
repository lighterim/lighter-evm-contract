// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;


import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {Test} from "forge-std/Test.sol";
import {BasePairTest} from "./BasePairTest.t.sol";
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
import {IAllowanceTransfer} from "@uniswap/permit2/interfaces/IAllowanceTransfer.sol";
import {console} from "forge-std/console.sol";
import {Utils} from "./unit/Utils.sol";
import {IPermit2} from "@uniswap/permit2/interfaces/IPermit2.sol";
import {ParamsHash} from "../src/utils/ParamsHash.sol";


contract TakeIntentTest is BasePairTest, Utils {

    function _testName() internal pure override returns (string memory) {
        return "TakeIntent";
    }

    function _testChainId() internal pure virtual override returns (string memory) {
        return "sepolia";
    }

    function _testBlockNumber() internal pure virtual override returns (uint256) {
        return 9839863;
    }
    

    address buyer; //0x220F964013f1b5283A95F5489bD558F71C07Ef1f;
    address seller; //0x0BA7b1d931aDdFBa63d38F4D2c03d3a497E430c8;
    uint256 buyerPrivKey; //
    uint256 sellerPrivKey; //
    address relayer;
    IERC20 usdc; //0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238


    // IAllowanceHolder allowanceHolder = IAllowanceHolder(0xFF49e8B078Ca72C3f0b1d670D2B7e7e858C3926c);
    // IEscrow escrow = IEscrow(0x33340001EA6AbF716040E742A6b21CFAF5F595b7);
    // LighterAccount lighterAccount = LighterAccount(0x00ae2058586C3d4639B454c4542A4365Cf717669);
    // MainnetTakeIntent internal settler = MainnetTakeIntent(
    //     payable(address(0xdc48A4702978D3Ca20DBe53D9D8a516fB9515Ff8))
    //     );
    IAllowanceHolder allowanceHolder = IAllowanceHolder(0x585CA19bFD4fD138C8AB114E78cE01b7Fa292a68);
    IEscrow escrow = IEscrow(0x4DffA1C1C1C49dCF6028A8651124B1Af4918d947);
    LighterAccount lighterAccount = LighterAccount(0xAFCE91f5882a5C3A5c9A5B6C232F30c8B2D6c8a7);
    MainnetTakeIntent internal settler = MainnetTakeIntent(
        payable(address(0x67F07A38f8Cafaa9f8f4a624480c0a863e510D9C))
        );

    

    uint256 relayerPrivKey;
    uint256 rentPrice = 0.00001 ether;
    address eoaSeller;
    address eoaBuyer;
    bytes32 takeIntentDomain;

    function setUp() override public {
        buyerPrivKey = vm.envUint("BUYER_PRIVATE_KEY");
        sellerPrivKey = vm.envUint("SELLER_PRIVATE_KEY");
        relayerPrivKey = vm.envUint("RELAYER_PRIVATE_KEY");
        
        buyer = vm.envAddress("BUYER_TBA");
        seller = vm.envAddress("SELLER_TBA");
        usdc = IERC20(vm.envAddress("USDC"));
        
        
        relayer = vm.addr(relayerPrivKey);
        eoaSeller = vm.addr(sellerPrivKey);
        eoaBuyer = vm.addr(buyerPrivKey);

        // LighterTicket lighterTicket = 0xe6917bbC2307966aC18F2aaf525eC0aF3b890390;
        
        // lighterAccount = 
        // lighterTicket.transferOwnership(address(lighterAccount));
        vm.deal(buyer, 1 ether);
        vm.deal(seller, 1 ether);
        // usdc.mint(seller, 10 ether);
        takeIntentDomain = settler.getDomainSeparator();

    }


    function fromToken() internal view override returns (IERC20) {
        return usdc;
    }

    function buyerFeeRate() internal pure override returns (uint256) {
        return 0;
    }

    function sellerFeeRate() internal pure override returns (uint256) {
        return 0;
    }

    function getBuyer() internal view override returns (address) {
        return buyer;
    }

    function amount() internal pure override returns (uint256) {
        // return 1 ether;
        return 100000;
    }

    function getSeller() internal view override returns (address) {
        return seller;
    }

    function testTakeSellerIntent() public {
        ISettlerBase.IntentParams memory intentParams = getIntentParams();

        ISignatureTransfer.PermitTransferFrom memory permit = ISignatureTransfer.PermitTransferFrom({
            permitted: ISignatureTransfer.TokenPermissions({token: address(fromToken()), amount: amount()}),
            nonce: 2,
            deadline: getDeadline()
        });
        bytes memory transferSignatureWithWitness = getIntentWitnessTransferSignature(
            permit, address(settler), intentParams, sellerPrivKey, permit2Domain
            );
        ISignatureTransfer.SignatureTransferDetails memory transferDetails = ISignatureTransfer.SignatureTransferDetails({
            to: address(escrow),
            requestedAmount: amount()
        });

        ISettlerBase.EscrowParams memory escrowParams = getEscrowParams();
        bytes32 escrowTypedDataHash = settler.getEscrowTypedHash(escrowParams);
        bytes32 intentTypedDataHash = settler.getIntentTypedHash(intentParams);
        bytes memory escrowSignature = getEscrowSignature(
            escrowParams, relayerPrivKey, takeIntentDomain
            );
        // console.logString("escrowSignature");
        // console.logBytes(escrowSignature);
        // console.logString("escrowTypedDataHash");
        // console.logBytes32(escrowTypedDataHash);
        // console.logString("intentTypedDataHash");
        // console.logBytes32(intentTypedDataHash);
        // console.logBytes(escrowSignature);
        
        // console.logString("transferSignatureWithWitness");
        // console.logBytes(transferSignatureWithWitness);
        
        bytes[] memory actions = ActionDataBuilder.build(
            // intent signature is not used in signature sell intent.
            abi.encodeCall(ISettlerActions.ESCROW_AND_INTENT_CHECK, (escrowParams, intentParams, bytes(""))),
            abi.encodeCall(ISettlerActions.ESCROW_PARAMS_CHECK, (escrowParams, escrowSignature)),
            abi.encodeCall(ISettlerActions.SIGNATURE_TRANSFER_FROM_WITH_WITNESS, (permit, transferDetails, intentParams, transferSignatureWithWitness))
        );

        MainnetTakeIntent _settler = settler;

        // uint256 beforeBalance = balanceOf(fromToken(), seller);
        // console.log("beforeBalance", beforeBalance);
        
        /**
         * function permitWitnessTransferFrom(
        PermitTransferFrom memory permit, => (TokenPermissions(address,uint256),uint256,uint256)
        SignatureTransferDetails calldata transferDetails, => (address,uint256)
        address owner,
        bytes32 witness,
        string calldata witnessTypeString,
        bytes calldata signature
         */
        // 明确指定使用单个 permitWitnessTransferFrom 重载（不是批量版本）
        // 使用函数选择器常量来避免重载歧义
        // 单个版本: permitWitnessTransferFrom(PermitTransferFrom,SignatureTransferDetails,address,bytes32,string,bytes) = 0x137c29fe
        // 批量版本: permitWitnessTransferFrom(PermitBatchTransferFrom,SignatureTransferDetails[],address,bytes32,string,bytes) = 0xfe8ec1a7
        bytes4 selector = 0x137c29fe; // 单个版本的选择器
   
        vm.startPrank(eoaBuyer);
        // snapStartName("TakeIntent_takeSellerIntent");
        //  _mockExpectCall(
        //     address(PERMIT2),
        //     abi.encodeWithSelector(
        //         selector,
        //         permit,
        //         transferDetails,
        //         eoaSeller,
        //         intentTypedDataHash,
        //         ParamsHash._INTENT_WITNESS_TYPE_STRING,
        //         transferSignatureWithWitness
        //     ),
        //     ""
        // );
        // _mockExpectCall(
        //     address(fromToken()),
        //     abi.encodeCall(
        //         IERC20.transferFrom,
        //         (eoaSeller, address(escrow), amount())
        //     ),
        //     ""
        // );
        _settler.execute(
            eoaSeller,
            escrowTypedDataHash,
            intentTypedDataHash,
            actions
        );
        // snapEnd();
        vm.stopPrank();
        // uint256 afterBalance = fromToken().balanceOf(seller);
        // console.log("afterBalance", afterBalance);
        // console.log("amount", amount());

        // assertGt(afterBalance, beforeBalance);
    }

    function testTakeBuyerIntent() public {
        console.log("testTakeBuyerIntent, chainId:", block.chainid);
        // buyer: maker
        ISettlerBase.IntentParams memory intentParams = getIntentParams();
        bytes memory intentSignature = getIntentSignature(
            intentParams, buyerPrivKey, takeIntentDomain
        );
        console.log("intentSignature");
        console.logBytes(intentSignature);
        
        // seller: taker
        ISignatureTransfer.PermitTransferFrom memory permit = ISignatureTransfer.PermitTransferFrom({
            permitted: ISignatureTransfer.TokenPermissions({token: address(fromToken()), amount: amount()}),
            nonce: 2,
            deadline: getDeadline()
        });
        ISignatureTransfer.SignatureTransferDetails memory transferDetails = ISignatureTransfer.SignatureTransferDetails({
            to: address(escrow),
            requestedAmount: amount()
        });
        bytes memory transferSignature = getPermitTransferSignature(
            permit, address(escrow), sellerPrivKey, takeIntentDomain
        );
        console.log("transferSignature");
        console.logBytes(transferSignature);

        // relayer: escrow
        ISettlerBase.EscrowParams memory escrowParams = getEscrowParams();
        bytes32 escrowTypedDataHash = settler.getEscrowTypedHash(escrowParams);
        bytes32 intentTypedDataHash = settler.getIntentTypedHash(intentParams);
        bytes memory escrowSignature = getEscrowSignature(
            escrowParams, relayerPrivKey, takeIntentDomain
            );
        console.log("escrowSignature");
        console.logBytes(escrowSignature);

        bytes[] memory actions = ActionDataBuilder.build(
            abi.encodeCall(ISettlerActions.ESCROW_AND_INTENT_CHECK, (escrowParams, intentParams, intentSignature)),
            abi.encodeCall(ISettlerActions.ESCROW_PARAMS_CHECK, (escrowParams, escrowSignature)),
            abi.encodeCall(ISettlerActions.SIGNATURE_TRANSFER_FROM, (permit, transferDetails, transferSignature))
        );

        MainnetTakeIntent _settler = settler;

        vm.startPrank(eoaSeller);
        _settler.execute(
            eoaSeller,
            escrowTypedDataHash,
            intentTypedDataHash,
            actions
        );
        vm.stopPrank();
    }

    function testTakeBulkSellIntent() public {
        
        // allowance holder: seller
        IAllowanceTransfer.PermitSingle memory permitSingle = IAllowanceTransfer.PermitSingle({
            details: IAllowanceTransfer.PermitDetails({
                token: address(fromToken()),
                amount: uint160(amount()),
                expiration: uint48(getDeadline()),
                nonce: uint48(0)
            }),
            spender: address(allowanceHolder),
            sigDeadline: getDeadline()
        });
        console.log("permitSingle");
        console.logBytes(abi.encode(permitSingle));
        
        bytes memory permitSig = getPermitSingleSignature(
            permitSingle, address(allowanceHolder), sellerPrivKey, permit2Domain
        );
        PERMIT2.permit(eoaSeller, permitSingle, permitSig);
        console.log("permitSig");

        IAllowanceTransfer.AllowanceTransferDetails memory details = IAllowanceTransfer.AllowanceTransferDetails({
            token: address(fromToken()),
            from: eoaSeller,
            to: address(allowanceHolder),
            amount: uint160(amount())
        });
        console.log("details");
        console.logBytes(abi.encode(details));

        // maker: seller
        ISettlerBase.IntentParams memory intentParams = getIntentParams();
        bytes memory intentSignature = getIntentSignature(
            intentParams, sellerPrivKey, takeIntentDomain
        );
        console.log("intentSignature");
        console.logBytes(intentSignature);

        // relayer: escrow
        ISettlerBase.EscrowParams memory escrowParams = getEscrowParams();
        bytes32 escrowTypedDataHash = settler.getEscrowTypedHash(escrowParams);
        bytes32 intentTypedDataHash = settler.getIntentTypedHash(intentParams);
        bytes memory escrowSignature = getEscrowSignature(
            escrowParams, relayerPrivKey, takeIntentDomain
            );
        console.log("escrowSignature");
        console.logBytes(escrowSignature);

        bytes[] memory actions = ActionDataBuilder.build(
            abi.encodeCall(ISettlerActions.ESCROW_AND_INTENT_CHECK, (escrowParams, intentParams, intentSignature)),
            abi.encodeCall(ISettlerActions.ESCROW_PARAMS_CHECK, (escrowParams, escrowSignature)),
            abi.encodeCall(ISettlerActions.BULK_SELL_TRANSFER_FROM, (details, intentParams, intentSignature))
        );
        // taker: buyer

        MainnetTakeIntent _settler = settler;
        vm.startPrank(eoaBuyer);
        _settler.execute(
            eoaSeller,
            escrowTypedDataHash,
            intentTypedDataHash,
            actions
        );
        vm.stopPrank();

    }

}