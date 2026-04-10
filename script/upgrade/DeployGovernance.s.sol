// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Script, console} from "forge-std/Script.sol";
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";

contract GovernanceDeployer is Script {
    TimelockController public timelock;

    uint256 public minDelay;
    address public proposer;
    address public executor;
    address public admin;

    function setUp() public {
        minDelay = vm.envUint("TIMELOCK_MIN_DELAY");
        proposer = vm.envAddress("GOVERNANCE_PROPOSER");
        executor = vm.envAddress("GOVERNANCE_EXECUTOR");
        admin = vm.envAddress("GOVERNANCE_ADMIN");
    }

    function run() public {
        vm.startBroadcast();

        address[] memory proposers = new address[](1);
        proposers[0] = proposer;

        address[] memory executors = new address[](1);
        executors[0] = executor;

        timelock = new TimelockController(minDelay, proposers, executors, admin);

        console.log("Timelock deployed:", address(timelock));
        console.log("minDelay:", minDelay);
        console.log("proposer:", proposer);
        console.log("executor:", executor);
        console.log("admin:", admin);
        console.log("export TIMELOCK=%s", address(timelock));

        vm.stopBroadcast();
    }
}

