// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Script, console} from "forge-std/Script.sol";
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";

interface IUUPSLike {
    function upgradeToAndCall(address newImplementation, bytes memory data) external payable;
}

contract UpgradeExecutor is Script {
    TimelockController public timelock;
    address public targetProxy;
    address public newImplementation;
    bytes public initCallData;
    bytes32 public predecessor;
    bytes32 public salt;

    function setUp() public {
        timelock = TimelockController(payable(vm.envAddress("TIMELOCK")));
        targetProxy = vm.envAddress("UPGRADE_TARGET_PROXY");
        newImplementation = vm.envAddress("UPGRADE_NEW_IMPLEMENTATION");
        initCallData = vm.envBytes("UPGRADE_INIT_CALLDATA_HEX"); // use 0x for empty bytes
        predecessor = vm.envBytes32("UPGRADE_PREDECESSOR");
        salt = vm.envBytes32("UPGRADE_SALT");
    }

    function run() public {
        bytes memory payload = abi.encodeCall(IUUPSLike.upgradeToAndCall, (newImplementation, initCallData));
        bytes32 opId = timelock.hashOperation(targetProxy, 0, payload, predecessor, salt);
        console.logBytes32(opId);
        vm.startBroadcast();
        timelock.execute(targetProxy, 0, payload, predecessor, salt);
        vm.stopBroadcast();

        console.log("Executed operation id:", vm.toString(opId));
        console.log("Timelock:", address(timelock));
        console.log("Target proxy:", targetProxy);
        console.log("New implementation:", newImplementation);
        console.log("Operation done:", timelock.isOperationDone(opId));
    }
}

