// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Script, console} from "forge-std/Script.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {LighterTicket} from "../src/token/LighterTicket.sol";
import {ERC6551Registry} from "erc6551/src/ERC6551Registry.sol";
import {AccountV3Simplified} from "../src/account/AccountV3.sol";
import {LighterAccount} from "../src/account/LighterAccount.sol";
import {Escrow} from "../src/Escrow.sol";
import {AllowanceHolder} from "../src/allowanceholder/AllowanceHolder.sol";
import {MainnetTakeIntent} from "../src/chains/Bsc/TakeIntent.sol";
import {MainnetWaypoint} from "../src/chains/Bsc/Waypoint.sol";
import {PaymentMethodRegistry} from "../src/PaymentMethodRegistry.sol";
import {ISettlerBase} from "../src/interfaces/ISettlerBase.sol";
import {ZkVerifyProofVerifier} from "../src/chains/Bsc/ZkVerifyProofVerifier.sol";

contract BscDeployer is Script {

    LighterTicket public ticket;
    ERC6551Registry public registry;
    AccountV3Simplified public accountImpl;
    LighterAccount public lighterAccount;
    Escrow public escrow;
    AllowanceHolder public allowanceHolder;
    MainnetWaypoint public mainnetWaypoint;
    MainnetTakeIntent public takeIntent;
    PaymentMethodRegistry public paymentMethodRegistry;
    ZkVerifyProofVerifier public zkVerifyProofVerifier;

    uint256 public rentPrice = 0.00001 ether;
    
    address public deployer;
    address public zkVerify;
    address public usdc;

    function setUp() public {
        deployer = vm.envAddress("DEPLOYER");
        zkVerify = vm.envAddress("ZK_VERIFY");
        usdc = vm.envAddress("USDC");
        // MockUSDC u = new MockUSDC();
        // usdc = address(u);
        // console.log("usdc deployed at:", usdc);
    }

    function run() public{
        vm.startBroadcast();
 
        console.log("Deploying LighterTicket...");
        ticket = new LighterTicket("LighterTicket", "LTK", "https://nft.lighter.im/horizen/");
        ticket.genesisMint(deployer, 10);
        console.log("LighterTicket deployed at:", address(ticket));
        
        console.log("Deploying ERC6551Registry...");
        registry = new ERC6551Registry();
        console.log("ERC6551Registry deployed at:", address(registry));
        
        console.log("Deploying AccountV3Simplified...");
        accountImpl = new AccountV3Simplified();
        console.log("AccountV3Simplified deployed at:", address(accountImpl));
        
        console.log("Deploying LighterAccount...");

        lighterAccount = new LighterAccount(address(ticket), address(registry), address(accountImpl), rentPrice);
        console.log("LighterAccount deployed at:", address(lighterAccount));
        
        console.log("Transferring LighterTicket ownership to LighterAccount...");
        ticket.transferOwnership(address(lighterAccount));
        console.log("LighterTicket ownership transferred to LighterAccount");
        
        console.log("Deploying Escrow...");
        escrow = new Escrow(lighterAccount, deployer);
        escrow.whitelistToken(usdc, true);
        console.log("Escrow deployed at:", address(escrow));
        
        console.log("Deploying AllowanceHolder...");
        allowanceHolder = new AllowanceHolder();
        console.log("AllowanceHolder deployed at:", address(allowanceHolder));
        
        console.log("Deploying PaymentMethodRegistry...");
        paymentMethodRegistry = new PaymentMethodRegistry();
        console.log("PaymentMethodRegistry deployed at:", address(paymentMethodRegistry));
        paymentMethodRegistry.addPaymentMethodConfig(keccak256("wechat"), ISettlerBase.PaymentMethodConfig({
            windowSeconds: 300,
            disputeWindowSeconds: 604800, // 7 days
            isEnabled: true
        }));
        paymentMethodRegistry.addPaymentMethodConfig(keccak256("wise"), ISettlerBase.PaymentMethodConfig({
            windowSeconds: 300,
            disputeWindowSeconds: 604800, // 7 days
            isEnabled: true
        }));
        paymentMethodRegistry.addPaymentMethodConfig(keccak256("alipay"), ISettlerBase.PaymentMethodConfig({
            windowSeconds: 300, 
            disputeWindowSeconds: 604800, // 7 days
            isEnabled: true
        }));
        // paymentMethodRegistry.addVerifier(bytes32(0), ISettlerBase.Stage.MANUAL, address(zkVerifyProofVerifier));

        console.log("Deploying MainnetTakeIntent...");
        takeIntent = new MainnetTakeIntent(deployer, escrow, lighterAccount, paymentMethodRegistry, bytes20(0), allowanceHolder);
        escrow.authorizeCreator(address(takeIntent), true);
        lighterAccount.authorizeOperator(address(takeIntent), true);
        console.log("MainnetTakeIntent deployed at:", address(takeIntent));

        console.log("Deploying MainnetWaypoint...");
        mainnetWaypoint = new MainnetWaypoint(deployer, escrow, lighterAccount, paymentMethodRegistry, bytes20(0));
        escrow.authorizeExecutor(address(mainnetWaypoint), true);
        lighterAccount.authorizeOperator(address(mainnetWaypoint), true);
        console.log("MainnetWaypoint deployed at:", address(mainnetWaypoint));
        
        console.log("Deploying ZkVerifyProofVerifier...");
        zkVerifyProofVerifier = new ZkVerifyProofVerifier(escrow, zkVerify);
        escrow.authorizeVerifier(address(zkVerifyProofVerifier), true);
        console.log("ZkVerifyProofVerifier deployed at:", address(zkVerifyProofVerifier));
        
        console.log("Deploying completed!");
        console.log("Deployer:", deployer);
        console.log("ERC6551Registry:", address(registry));
        console.log("AccountV3Simplified:", address(accountImpl));
        console.log("ZkVerify:", zkVerify);

        console.log("export LighterAccount=%s", address(lighterAccount));
        console.log("export LighterTicket=%s", address(ticket)); 
        console.log("export Escrow=%s", address(escrow));
        console.log("export AllowanceHolder=%s", address(allowanceHolder));
        console.log("export TakeIntent=%s", address(takeIntent));
        console.log("export SetWaypoint=%s", address(mainnetWaypoint));
        console.log("export ZkVerifyProofVerifier=%s", address(zkVerifyProofVerifier));
        console.log("export PaymentMethodRegistry=%s", address(paymentMethodRegistry));
        
        vm.stopBroadcast();
    }
}
