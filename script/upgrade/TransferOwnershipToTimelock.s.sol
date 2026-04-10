// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Script, console} from "forge-std/Script.sol";
import {LighterAccount} from "../../src/account/LighterAccount.sol";
import {Escrow} from "../../src/Escrow.sol";

contract OwnershipMigrator is Script {
    LighterAccount public lighterAccount;
    Escrow public escrow;
    address public timelock;

    function setUp() public {
        lighterAccount = LighterAccount(vm.envAddress("LIGHTER_ACCOUNT"));
        escrow = Escrow(vm.envAddress("ESCROW"));
        timelock = vm.envAddress("TIMELOCK");
    }

    function run() public {
        vm.startBroadcast();

        console.log("Current LighterAccount owner:", lighterAccount.owner());
        console.log("Current Escrow owner:", escrow.owner());
        console.log("New owner (Timelock):", timelock);

        lighterAccount.transferOwnership(timelock);
        escrow.transferOwnership(timelock);

        console.log("Updated LighterAccount owner:", lighterAccount.owner());
        console.log("Updated Escrow owner:", escrow.owner());

        vm.stopBroadcast();
    }
}

