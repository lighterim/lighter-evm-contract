// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Script, console} from "forge-std/Script.sol";
import {LighterAccount} from "../../src/account/LighterAccount.sol";

contract AccountVxDeployer is Script {
    LighterAccount public lighterAccountImpl;
    

    function run() public {
        vm.startBroadcast();

        lighterAccountImpl = new LighterAccount();
        console.log("LighterAccount deployed at:", address(lighterAccountImpl));
        console.log("export UPGRADE_NEW_IMPLEMENTATION=%s", address(lighterAccountImpl));
        vm.stopBroadcast();
    }
}

