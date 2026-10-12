// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import {MockUSDC} from "../src/MockUSDC.sol";
import {CircleFactory} from "../src/CircleFactory.sol";

contract Deploy is Script {
    function run() external {
        vm.startBroadcast();
        MockUSDC usdc = new MockUSDC();
        CircleFactory factory = new CircleFactory();
        vm.stopBroadcast();

        console.log("MockUSDC:", address(usdc));
        console.log("CircleFactory:", address(factory));
    }
}
