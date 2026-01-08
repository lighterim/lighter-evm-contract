pragma solidity ^0.8.25;

import {Script, console} from "forge-std/Script.sol";
import {Permit2Helper} from "../src/utils/Permit2Helper.sol";

contract HelperDeployer is Script {

    Permit2Helper public permit2Helper;
    address public takeIntent;

    function setUp() public {
        takeIntent = vm.envAddress("TakeIntent");
    }

    function run() public{
        vm.startBroadcast();
 
        console.log("Deploying Permit2Helper...");

        permit2Helper = new Permit2Helper(takeIntent);
        
        console.log("Permit2Helper deployed at:", address(permit2Helper));
        
        vm.stopBroadcast();
    }
}
