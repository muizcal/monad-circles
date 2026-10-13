// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {Circle} from "../src/Circle.sol";
import {MockUSDC} from "../src/MockUSDC.sol";

contract CircleTest is Test {
    MockUSDC usdc;
    Circle circle;
    address[3] ms = [address(0xA), address(0xB), address(0xC)];
    uint256 constant AMT = 10e6;

    function setUp() public {
        usdc = new MockUSDC();
        circle = new Circle(address(usdc), AMT, 3, 1 days);
        for (uint256 i; i < 3; i++) {
            usdc.mint(ms[i], 100e6);
            vm.startPrank(ms[i]);
            usdc.approve(address(circle), type(uint256).max);
            circle.join();
            vm.stopPrank();
        }
    }

    function _vote(uint8 a, uint8 b, uint8 c) internal {
        vm.prank(ms[0]); circle.castVote(a);
        vm.prank(ms[1]); circle.castVote(b);
        vm.prank(ms[2]); circle.castVote(c);
    }

    function _payRound() internal {
        for (uint256 i; i < 3; i++) { vm.prank(ms[i]); circle.contribute(); }
    }

    function test_VotingOpensWhenFull() public view {
        assertEq(uint256(circle.phase()), 1);
    }

    function test_LockedMode_PotsLockedUntilAllRoundsThenEveryoneWithdraws() public {
        _vote(1, 1, 2);
        assertEq(uint256(circle.mode()), 0);
        _payRound();
        address first = circle.getRecipients()[0];
        vm.prank(first);
        vm.expectRevert("locked");
        circle.withdraw();
        _payRound();
        _payRound();
        assertEq(uint256(circle.phase()), 3);
        address[] memory r = circle.getRecipients();
        assertTrue(r[0] != r[1] && r[1] != r[2] && r[0] != r[2]);
        for (uint256 i; i < 3; i++) {
            vm.prank(ms[i]);
            circle.withdraw();
            assertEq(usdc.balanceOf(ms[i]), 100e6);
        }
    }

    function test_AsYouGo_RecipientWithdrawsImmediately() public {
        _vote(2, 2, 1);
        assertEq(uint256(circle.mode()), 1);
        _payRound();
        address first = circle.getRecipients()[0];
        vm.prank(first);
        circle.withdraw();
        assertEq(usdc.balanceOf(first), 100e6 - 2 * AMT + 3 * AMT);
    }

    function test_TieDefaultsToLocked() public {
        Circle two = new Circle(address(usdc), AMT, 2, 1 days);
        vm.prank(ms[0]); two.join();
        vm.prank(ms[1]); two.join();
        vm.prank(ms[0]); two.castVote(1);
        vm.prank(ms[1]); two.castVote(2);
        assertEq(uint256(two.mode()), 0);
        assertEq(uint256(two.phase()), 2);
    }

    function test_OnlyMembersCanChat() public {
        vm.prank(ms[0]);
        circle.say("hello");
        assertEq(circle.messageCount(), 1);
        vm.prank(address(0xDEAD));
        vm.expectRevert("not member");
        circle.say("hi");
    }

    function test_StalledLockedCircleRefunds() public {
        _vote(1, 1, 1);
        vm.prank(ms[0]); circle.contribute();
        vm.prank(ms[1]); circle.contribute();
        vm.warp(block.timestamp + 3 days);
        vm.prank(ms[0]);
        circle.abort();
        vm.prank(ms[0]); circle.refund();
        vm.prank(ms[1]); circle.refund();
        assertEq(usdc.balanceOf(ms[0]), 100e6);
        assertEq(usdc.balanceOf(ms[1]), 100e6);
    }
}
