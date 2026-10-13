// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {Circle} from "../src/Circle.sol";
import {MockUSDC} from "../src/MockUSDC.sol";

contract AsYouGoTest is Test {
    MockUSDC usdc;
    Circle circle;
    address[3] ms = [address(0xA), address(0xB), address(0xC)];

    function setUp() public {
        usdc = new MockUSDC();
        circle = new Circle(address(usdc), 10e6, 3, 1 days);
        for (uint256 i; i < 3; i++) {
            usdc.mint(ms[i], 100e6);
            vm.startPrank(ms[i]);
            usdc.approve(address(circle), type(uint256).max);
            circle.join();
            vm.stopPrank();
        }
        for (uint256 i; i < 3; i++) { vm.prank(ms[i]); circle.castVote(2); }
        for (uint256 i; i < 3; i++) { vm.prank(ms[i]); circle.contribute(); } // round 1 done
    }

    function test_CollectingBeforePayingDeductsYourShare() public {
        address w = circle.getRecipients()[0];
        for (uint256 i; i < 3; i++) {
            if (ms[i] != w) { vm.prank(ms[i]); circle.contribute(); }
        }
        uint256 before = usdc.balanceOf(w);
        vm.prank(w);
        circle.withdraw();
        assertEq(usdc.balanceOf(w) - before, 20e6); // 30 pot minus the 10 owed for this round
        assertTrue(circle.paid(1, w));
        assertEq(circle.currentRound(), 2); // the round completed and the next pot was drawn
    }

    function test_PaidMemberWithdrawsFullPot() public {
        address w = circle.getRecipients()[0];
        vm.prank(w);
        circle.contribute();
        uint256 before = usdc.balanceOf(w);
        vm.prank(w);
        circle.withdraw();
        assertEq(usdc.balanceOf(w) - before, 30e6);
    }
}
