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
import {MainnetWaypoint} from "../src/chains/Mainnet/Waypoint.sol";
import {PaymentMethodRegistry} from "../src/PaymentMethodRegistry.sol";
import {IPaymentMethodRegistry} from "../src/interfaces/IPaymentMethodRegistry.sol";
import {MockUSDC} from "../src/utils/TokenMock.sol";
import {AllowanceHolder} from "../src/allowanceholder/AllowanceHolder.sol";
import {IAllowanceHolder} from "../src/allowanceholder/IAllowanceHolder.sol";
import {IAllowanceTransfer} from "@uniswap/permit2/interfaces/IAllowanceTransfer.sol";
import {IEscrow} from "../src/interfaces/IEscrow.sol";
import {Escrow} from "../src/Escrow.sol";
import {ISettlerActions} from "../src/ISettlerActions.sol";
import {ActionDataBuilder} from "./utils/ActionDataBuilder.sol";
import {ISettlerBase} from "../src/interfaces/ISettlerBase.sol";
import {Permit2Signature} from "./utils/Permit2Signature.sol";
import {ISignatureTransfer} from "@uniswap/permit2/interfaces/ISignatureTransfer.sol";
import {ParamsHash} from "../src/utils/ParamsHash.sol";
import {console} from "forge-std/console.sol";

contract LocalTakeIntentTest is Permit2Signature {

    using ParamsHash for ISettlerBase.EscrowParams;

    address buyer;
    address seller;
    address eoaSeller;
    address eoaBuyer;
    address relayer;
    MockUSDC usdc;
    IAllowanceHolder allowanceHolder;
    Escrow escrow;
    PaymentMethodRegistry paymentMethodRegistry;
    LighterAccount lighterAccount;
    MainnetTakeIntent internal settler;
    MainnetWaypoint internal waypoint;
    

    uint256 relayerPrivKey = 0x123;
    uint256 buyerPrivKey = 0x456;
    uint256 sellerPrivKey = 0x789;
    uint256 rentPrice = 0.00001 ether;
    bytes32 permit2Domain = 0x94c1dec87927751697bfc9ebf6fc4ca506bed30308b518f0e9d6c5f74bbafdb8;
    bytes32 takeIntentDomain;
    bytes32 waypointDomain;
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
        escrow = new Escrow(relayer, lighterAccount, relayer);
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


        
        waypoint = new MainnetWaypoint(
            relayer,
            escrow,
            lighterAccount,
            paymentMethodRegistry,
            bytes20(0)
        );
        waypointDomain = waypoint.getDomainSeparator();
        vm.startPrank(relayer);
        escrow.authorizeExecutor(address(waypoint), true);
        //only for test
        escrow.authorizeCreator(address(this), true);
        vm.stopPrank();

    }

    function testPaid() public {
        ISettlerBase.EscrowParams memory escrowParams = getEscrowParams(1);
        
        createEscrow(escrowParams);
        makePayment(escrowParams);
        assertTrue(escrow.getEscrowData(escrowParams.hash()).status == ISettlerBase.EscrowStatus.Paid);
    }

    function testSellerReleased() public {
        ISettlerBase.EscrowParams memory escrowParams = getEscrowParams(2);
        bytes memory escrowSignature = getEscrowSignature(escrowParams, relayerPrivKey, waypointDomain);

        createEscrow(escrowParams);
        makePayment(escrowParams);

        bytes[] memory actions = ActionDataBuilder.build(
            abi.encodeCall(ISettlerActions.RELEASE_BY_SELLER, (escrowParams, escrowSignature))
        );

        vm.startPrank(eoaSeller);
        waypoint.execute(bytes32(0), actions);
        vm.stopPrank();
        assertTrue(escrow.getEscrowData(escrowParams.hash()).status == ISettlerBase.EscrowStatus.SellerReleased);
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

    function makePayment(ISettlerBase.EscrowParams memory escrowParams) public {
        bytes memory escrowSignature = getEscrowSignature(escrowParams, relayerPrivKey, waypointDomain);
        bytes[] memory actions = ActionDataBuilder.build(
            abi.encodeCall(ISettlerActions.MAKE_PAYMENT, (escrowParams, escrowSignature))
        );

        vm.startPrank(eoaBuyer);
        waypoint.execute(bytes32(0), actions);
        vm.stopPrank();
    }

    function createEscrow(ISettlerBase.EscrowParams memory escrowParams) public {
        uint256 sellerFee = waypoint.getFeeAmount(escrowParams.volume, escrowParams.sellerFeeRate);
        bytes32 escrowHash = escrowParams.hash();
        escrow.create(
            address(escrowParams.token), 
            escrowParams.buyer, 
            escrowParams.seller, 
            escrowParams.volume,
            sellerFee, 
            escrowHash, 
            escrowParams.id,
            ISettlerBase.EscrowData(
                {
                    status: ISettlerBase.EscrowStatus.Escrowed,
                    paidSeconds: 0,
                    releaseSeconds: 0,
                    cancelTs: 0,
                    lastActionTs: uint64(block.timestamp),
                    gasSpentForBuyer: 0,
                    gasSpentForSeller: 0
                }
            )
        );
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