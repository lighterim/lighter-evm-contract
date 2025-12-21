pragma solidity ^0.8.25;

import {Script, console} from "forge-std/Script.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {LighterTicket} from "../src/token/LighterTicket.sol";
import {ERC6551Registry} from "erc6551/src/ERC6551Registry.sol";
import {AccountV3Simplified} from "../src/account/AccountV3.sol";
import {LighterAccount} from "../src/account/LighterAccount.sol";
import {Escrow} from "../src/Escrow.sol";
import {AllowanceHolder} from "../src/allowanceholder/AllowanceHolder.sol";
import {MainnetTakeIntent} from "../src/chains/Mainnet/TakeIntent.sol";
import {MockUSDC} from "../src/utils/TokenMock.sol";
import {ZkVerifyProofVerifier} from "../src/chains/Mainnet/ZkVerifyProofVerifier.sol";

contract DeployerContract is Script {

    LighterTicket public ticket;
    ERC6551Registry public registry;
    AccountV3Simplified public accountImpl;
    LighterAccount public lighterAccount;
    Escrow public escrow;
    AllowanceHolder public allowanceHolder;
    // MainnetUserTxn public userTxn;
    MainnetTakeIntent public takeIntent;
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
        escrow = new Escrow(deployer, lighterAccount, deployer);
        escrow.whitelistToken(usdc, true);
        console.log("Escrow deployed at:", address(escrow));
        
        console.log("Deploying AllowanceHolder...");
        allowanceHolder = new AllowanceHolder();
        console.log("AllowanceHolder deployed at:", address(allowanceHolder));
        
        // console.log("Deploying MainnetUserTxn...");
        // userTxn = new MainnetUserTxn(deployer, escrow, lighterAccount, allowanceHolder);
        // console.log("MainnetUserTxn deployed at:", address(userTxn));

        console.log("Deploying MainnetTakeIntent...");
        takeIntent = new MainnetTakeIntent(deployer, escrow, lighterAccount, bytes20(0), allowanceHolder);
        escrow.authorizeCreator(address(takeIntent), true);
        lighterAccount.authorizeOperator(address(takeIntent), true);
        console.log("MainnetTakeIntent deployed at:", address(takeIntent));
        
        console.log("Deploying ZkVerifyProofVerifier...");
        zkVerifyProofVerifier = new ZkVerifyProofVerifier(escrow, zkVerify);
        escrow.authorizeVerifier(address(zkVerifyProofVerifier), true);
        console.log("ZkVerifyProofVerifier deployed at:", address(zkVerifyProofVerifier));
        
        console.log("Deploying completed!");
        console.log("Deployer:", deployer);
        console.log("ZkVerify:", zkVerify);
        console.log("LighterAccount:", address(lighterAccount));
        console.log("LighterTicket:", address(ticket)); 
        console.log("ERC6551Registry:", address(registry));
        console.log("AccountV3Simplified:", address(accountImpl));
        console.log("Escrow:", address(escrow));
        console.log("AllowanceHolder:", address(allowanceHolder));
        console.log("MainnetTakeIntent:", address(takeIntent));
        console.log("ZkVerifyProofVerifier:", address(zkVerifyProofVerifier));
        
        vm.stopBroadcast();
    }
}
