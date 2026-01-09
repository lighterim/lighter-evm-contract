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
import {IPaymentMethodRegistry} from "../src/interfaces/IPaymentMethodRegistry.sol";
import {PaymentMethodRegistry} from "../src/PaymentMethodRegistry.sol";
import {IAllowanceHolder} from "../src/allowanceholder/IAllowanceHolder.sol";
import {IAllowanceTransfer} from "@uniswap/permit2/interfaces/IAllowanceTransfer.sol";
import {IEscrow} from "../src/interfaces/IEscrow.sol";
import {Escrow} from "../src/Escrow.sol";
import {ISettlerActions} from "../src/ISettlerActions.sol";
import {ActionDataBuilder} from "./utils/ActionDataBuilder.sol";
import {ISettlerBase} from "../src/interfaces/ISettlerBase.sol";
import {Permit2Signature} from "./utils/Permit2Signature.sol";
import {ISignatureTransfer} from "@uniswap/permit2/interfaces/ISignatureTransfer.sol";
import {console} from "forge-std/console.sol";

contract LocalTakeIntentTest is Permit2Signature {

    address buyer;
    address seller;
    address eoaSeller;
    address eoaBuyer;
    address relayer;
    MockUSDC usdc;
    IAllowanceHolder allowanceHolder;
    Escrow escrow;
    LighterAccount lighterAccount;
    IPaymentMethodRegistry internal paymentMethodRegistry;
    MainnetTakeIntent internal settler;
    

    uint256 relayerPrivKey = 0x123;
    uint256 buyerPrivKey = 0x456;
    uint256 sellerPrivKey = 0x789;
    uint256 rentPrice = 0.00001 ether;
    bytes32 permit2Domain = 0x94c1dec87927751697bfc9ebf6fc4ca506bed30308b518f0e9d6c5f74bbafdb8;
    bytes32 takeIntentDomain;
    bytes32 buyerNostrPubKey = 0x36bd5b22605899659cb1053737316096195b3ceb37c851645efd23e4497d7097;
    bytes32 sellerNostrPubKey = 0x2a9716cdd08bd7b14c94119c8259c89f3baab64d7b161eb03ad43dc1c1ccec68;
    

    function setUp() public {
        relayer = vm.addr(relayerPrivKey);
        eoaBuyer = vm.addr(buyerPrivKey);
        eoaSeller = vm.addr(sellerPrivKey);
        
        usdc = new MockUSDC();

        LighterTicket lighterTicket = new LighterTicket("LighterTicket", "LTKT", "https://lighter.im/ticket/");
        ERC6551Registry registry = new ERC6551Registry();
        AccountV3Simplified accountImpl = new AccountV3Simplified();
        
        lighterAccount = new LighterAccount(address(lighterTicket), address(registry), address(accountImpl), rentPrice);
        lighterTicket.transferOwnership(address(lighterAccount));
        escrow = new Escrow(lighterAccount, relayer);
        vm.prank(relayer);
        escrow.whitelistToken(address(usdc), true);
        allowanceHolder = new AllowanceHolder();
        
        usdc.mint(eoaSeller, 10 ether);
        vm.deal(eoaBuyer, 1 ether);
        vm.deal(eoaSeller, 1 ether);

        vm.prank(eoaBuyer);
        (, buyer) = lighterAccount.createAccount{value: rentPrice*2}(eoaBuyer, buyerNostrPubKey);
        vm.prank(eoaSeller);
        (, seller) = lighterAccount.createAccount{value: rentPrice}(eoaSeller, sellerNostrPubKey);
        console.log("buyer", buyer);
        console.log("seller", seller);
        console.log("eoaBuyer", eoaBuyer);
        console.log("eoaSeller", eoaSeller);
        console.log("relayer", relayer);
        console.log("seller getQuota", lighterAccount.getQuota(seller));
        console.log("buyer getQuota", lighterAccount.getQuota(buyer));

        paymentMethodRegistry = new PaymentMethodRegistry();
        paymentMethodRegistry.addPaymentMethodConfig(keccak256("wechat"), ISettlerBase.PaymentMethodConfig({
            windowSeconds: 300,
            isEnabled: true
        }));
        paymentMethodRegistry.addPaymentMethodConfig(keccak256("wise"), ISettlerBase.PaymentMethodConfig({
            windowSeconds: 300,
            isEnabled: true
        }));
        paymentMethodRegistry.addPaymentMethodConfig(keccak256("alipay"), ISettlerBase.PaymentMethodConfig({
            windowSeconds: 300,
            isEnabled: true
        }));


        settler = new MainnetTakeIntent(
            relayer,
            escrow,
            lighterAccount,
            paymentMethodRegistry,
            bytes20(0),
            allowanceHolder
        );
        takeIntentDomain = settler.getDomainSeparator();
        escrow.authorizeCreator(address(settler), true);
        lighterAccount.authorizeOperator(address(settler), true);

        //for bulk sell
        vm.startPrank(eoaSeller);
        usdc.approve(address(allowanceHolder), type(uint256).max);
        vm.stopPrank();
        // IAllowanceTransfer.PermitSingle memory permitSingle = IAllowanceTransfer.PermitSingle({
        //     details: IAllowanceTransfer.TokenPermissions({token: address(usdc), amount: amount()}),
        //     nonce: 1,
        //     expiry: getDeadline(),
        //     spender: address(allowanceHolder)
        // });
        // bytes memory permitSig = getPermitSignature(permitSingle, sellerPrivKey, permit2Domain);
    

    }


    function fromToken() internal view returns (IERC20) {
        return IERC20(address(usdc));
    }

    function buyerFeeRate() internal pure returns (uint256) {
        return 0;
    }

    function sellerFeeRate() internal pure returns (uint256) {
        return 0;
    }

    function getBuyer() internal view returns (address) {
        return buyer;
    }

    function amount() internal pure returns (uint256) {
        return 1 ether;
    }

    function getSeller() internal view returns (address) {
        return seller;
    }

    function getDeadline() internal view returns (uint64){
        return uint64(block.timestamp + 7 days);
    }

    function getCurrency() internal pure returns (bytes32){
        return keccak256(abi.encodePacked("USD"));
    }
    function getPaymentMethod() internal pure returns (bytes32){
        return keccak256(abi.encodePacked("wechat"));
    }
    function getPayeeDetails() internal pure returns (bytes32){
        return keccak256(abi.encodePacked("dust", "wxp://f2f0in9xnsA4G_eXWBRORK63ixD6bMQcP11eKGFz1VS4Kf0", "memo" ));
    }
    function getPrice() internal pure returns (uint256){
        return 1 ether;
    }

    function testTakeSellerIntent() public {
        ISettlerBase.IntentParams memory intentParams = getIntentParams();
        ISettlerBase.EscrowParams memory escrowParams = getEscrowParams(1);

        ISignatureTransfer.PermitTransferFrom memory permit = ISignatureTransfer.PermitTransferFrom({
            permitted: ISignatureTransfer.TokenPermissions({
                token: address(fromToken()), 
                amount: settler.getAmountWithFee(amount(), escrowParams.sellerFeeRate)
            }),
            nonce: 1,
            deadline: getDeadline()
        });
        bytes memory transferSignatureWithWitness = getIntentWitnessTransferSignature(
            permit, address(settler), intentParams, sellerPrivKey, permit2Domain
            );
        ISignatureTransfer.SignatureTransferDetails memory transferDetails = ISignatureTransfer.SignatureTransferDetails({
            to: address(escrow),
            requestedAmount: settler.getAmountWithFee(amount(), escrowParams.sellerFeeRate)
        });

        
        bytes32 tokenPermissionsHash = settler.getTokenPermissionsHash(permit.permitted);
        bytes32 escrowTypedDataHash = settler.getEscrowTypedHash(escrowParams);
        bytes32 intentTypedDataHash = settler.getIntentTypedHash(intentParams);
        bytes memory escrowSignature = getEscrowSignature(
            escrowParams, relayerPrivKey, takeIntentDomain
            );
        console.logString("escrowSignature");
        console.logBytes(escrowSignature);
        console.logString("escrowTypedDataHash");
        console.logBytes32(escrowTypedDataHash);
        console.logString("intentTypedDataHash");
        console.logBytes32(intentTypedDataHash);
        
        // console.logBytes(escrowSignature);
        
        bytes[] memory actions = ActionDataBuilder.build(
            // intent signature is not used in signature sell intent.
            abi.encodeCall(ISettlerActions.ESCROW_AND_INTENT_CHECK, (escrowParams, intentParams, bytes(""))),
            abi.encodeCall(ISettlerActions.ESCROW_PARAMS_CHECK, (escrowParams, escrowSignature)),
            abi.encodeCall(ISettlerActions.SIGNATURE_TRANSFER_FROM_WITH_WITNESS, (permit, transferDetails, intentParams, transferSignatureWithWitness))
        );

        MainnetTakeIntent _settler = settler;

        uint256 beforeBalance = balanceOf(fromToken(), eoaSeller);
        console.log("beforeBalance", beforeBalance);
        vm.startPrank(eoaBuyer);
        // snapStartName("TakeIntent_takeSellerIntent");
        _settler.execute(
            eoaSeller,
            tokenPermissionsHash,
            escrowTypedDataHash,
            intentTypedDataHash,
            actions
        );
        // snapEnd();
        vm.stopPrank();
        uint256 afterBalance = fromToken().balanceOf(eoaSeller);
        console.log("afterBalance", afterBalance);
        
        // assertFalse(lighterAccount.hasAvailableQuota(seller));
        // assertFalse(lighterAccount.hasAvailableQuota(buyer));

        ISettlerBase.EscrowData memory escrowData = escrow.getEscrowData(escrowTypedDataHash);
        assertTrue(escrowData.status == ISettlerBase.EscrowStatus.Escrowed);
        

        // assertTrue(escrow.escrowOf(address(fromToken()), seller) == amount());
        // assertTrue(escrow.creditOf(address(fromToken()), buyer) == 0);
        // assertGt(afterBalance, beforeBalance);
    }

    function testTakeBulkSell() public {
        //seller: maker
        ISettlerBase.IntentParams memory intentParams = getIntentParams();
        bytes32 intentTypedDataHash = settler.getIntentTypedHash(intentParams);
        bytes memory makerIntentSignature = getIntentSignature(
            intentParams, sellerPrivKey, takeIntentDomain
            );

        //relayer: relayer
        ISettlerBase.EscrowParams memory escrowParams = getEscrowParams(2);
        bytes32 escrowTypedDataHash = settler.getEscrowTypedHash(escrowParams);
        bytes memory escrowSignature = getEscrowSignature(
            escrowParams, relayerPrivKey, takeIntentDomain
            );
        
       IAllowanceTransfer.AllowanceTransferDetails memory details = IAllowanceTransfer.AllowanceTransferDetails({
            token: address(fromToken()),
            amount: uint160(settler.getAmountWithFee(amount(), escrowParams.sellerFeeRate)),
            to: address(escrow),
            from: eoaSeller
        });

        bytes32 tokenPermissionsHash = settler.getTokenPermissionsHash(
            ISignatureTransfer.TokenPermissions({
                token: address(fromToken()), amount: settler.getAmountWithFee(amount(), escrowParams.sellerFeeRate)}
            )
        );

        bytes[] memory actions = ActionDataBuilder.build(
            abi.encodeCall(ISettlerActions.ESCROW_AND_INTENT_CHECK, (escrowParams, intentParams, makerIntentSignature)),
            abi.encodeCall(ISettlerActions.ESCROW_PARAMS_CHECK, (escrowParams, escrowSignature)),
            abi.encodeCall(ISettlerActions.BULK_SELL_TRANSFER_FROM, (details, intentParams, makerIntentSignature))
        );

        MainnetTakeIntent _settler = settler;
        vm.startPrank(eoaBuyer);
        _settler.execute(
            eoaSeller,
            tokenPermissionsHash,
            escrowTypedDataHash,
            intentTypedDataHash,
            actions
        );
        vm.stopPrank();

        console.log("escrow balance", usdc.balanceOf(address(escrow)));
        console.log("amount", amount());
        // assertTrue(usdc.balanceOf(address(escrow)) == amount());

        ISettlerBase.EscrowData memory escrowData = escrow.getEscrowData(escrowTypedDataHash);
        // assertTrue(escrowData.status == ISettlerBase.EscrowStatus.Escrowed);
        
        // assertTrue(escrow.escrowOf(address(fromToken()), seller) >= amount());
        // assertTrue(escrow.creditOf(address(fromToken()), buyer) == 0);
    }

    function testTakeBuyerIntent() public {
        // buyer: maker
        ISettlerBase.IntentParams memory intentParams = getIntentParams();
        bytes32 intentTypedDataHash = settler.getIntentTypedHash(intentParams);
        bytes memory makerIntentSignature = getIntentSignature(
            intentParams, buyerPrivKey, takeIntentDomain
            );
        
        // relayer: relayer
        ISettlerBase.EscrowParams memory escrowParams = getEscrowParams(3);
        bytes32 escrowTypedDataHash = settler.getEscrowTypedHash(escrowParams);
        bytes memory escrowSignature = getEscrowSignature(
            escrowParams, relayerPrivKey, takeIntentDomain
            );
        
        // seller: taker
        ISignatureTransfer.PermitTransferFrom memory permit = ISignatureTransfer.PermitTransferFrom({
            permitted: ISignatureTransfer.TokenPermissions({
                token: address(fromToken()),
                amount: settler.getAmountWithFee(amount(), escrowParams.sellerFeeRate)
            }),
            nonce: 1,
            deadline: getDeadline()
        });
        ISignatureTransfer.SignatureTransferDetails memory transferDetails = ISignatureTransfer.SignatureTransferDetails({
            to: address(escrow),
            requestedAmount: settler.getAmountWithFee(amount(), escrowParams.sellerFeeRate)
        });
        bytes32 tokenPermissionsHash = settler.getTokenPermissionsHash(permit.permitted);
        bytes memory transferSignature = getPermitTransferSignature(
            permit, address(escrow), sellerPrivKey, permit2Domain
            );

        bytes[] memory actions  = ActionDataBuilder.build(
            abi.encodeCall(ISettlerActions.ESCROW_AND_INTENT_CHECK, (escrowParams, intentParams, makerIntentSignature)),
            abi.encodeCall(ISettlerActions.ESCROW_PARAMS_CHECK, (escrowParams, escrowSignature)),
            abi.encodeCall(ISettlerActions.SIGNATURE_TRANSFER_FROM, (permit, transferDetails, transferSignature))
        );

        MainnetTakeIntent _settler = settler;
        vm.startPrank(eoaSeller);
        _settler.execute(
            eoaSeller,
            tokenPermissionsHash,
            escrowTypedDataHash,
            intentTypedDataHash,
            actions
        );
        vm.stopPrank();
        
        ISettlerBase.EscrowData memory escrowData = escrow.getEscrowData(escrowTypedDataHash);
        assertTrue(escrowData.status == ISettlerBase.EscrowStatus.Escrowed);
        
        assertTrue(escrow.escrowOf(address(fromToken()), seller) >= amount());
        assertTrue(escrow.creditOf(address(fromToken()), buyer) == 0);
        
    }


    function getIntentParams() public view returns (ISettlerBase.IntentParams memory intentParams) {
        intentParams = ISettlerBase.IntentParams({
            token: address(fromToken()),
            range: ISettlerBase.Range({ min: amount(), max: amount() }),
            expiryTime: getDeadline(),
            currency: getCurrency(), 
            paymentMethod: getPaymentMethod(),
            payeeDetails: getPayeeDetails(),
            price: getPrice()
        });
    }

    function getEscrowParams(uint256 id) public view returns (ISettlerBase.EscrowParams memory escrowParams) {
        escrowParams = ISettlerBase.EscrowParams({
            id: id,
            token: address(fromToken()),
            volume: amount(),
            price: getPrice(),
            usdRate: 1_000,
            payer: eoaSeller,
            seller: getSeller(),
            sellerFeeRate: sellerFeeRate(),
            paymentMethod: getPaymentMethod(),
            currency: getCurrency(),
            payeeDetails: getPayeeDetails(),
            buyer: getBuyer(),
            buyerFeeRate: buyerFeeRate()
        });
    }

    function balanceOf(IERC20 token, address account) internal view returns (uint256) {
        (bool success, bytes memory returnData) =
            address(this).staticcall(abi.encodeCall(this._balanceOf, (token, account)));
        assert(!success);
        assert(returnData.length == 32);
        return abi.decode(returnData, (uint256));
    }

    function _balanceOf(IERC20 token, address account) external view {
        uint256 result = token.balanceOf(account);
        assembly ("memory-safe") {
            mstore(0x00, result)
            revert(0x00, 0x20)
        }
    }
}