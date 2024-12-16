// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { Script } from "forge-std/Script.sol";

import { SafeSubscriptions } from "../src/SafeSubscriptions.sol";

contract DeploySafeSubscriptions is Script {
    address public safe;

    function run() public {
        // placeholder, replace with your safe's proxy address
        safe = address(1);

        vm.startBroadcast();
        new SafeSubscriptions(safe);
        vm.stopBroadcast();
    }
}
