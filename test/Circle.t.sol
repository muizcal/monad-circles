// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {Circle} from "../src/Circle.sol";
import {MockUSDC} from "../src/MockUSDC.sol";

contract CircleTest is Test {
    MockUSDC usdc;
    Circle circle;
    address a = address(0xA);
    address b = address(0xB);
    address c = address(0xC);
    uint256 constant AMT = 10e6;
    uint256 constant START = 100e6;

    function setUp() public {
        usdc = new MockUSDC();
        circle = new Circle(address(usdc), AMT, 3, 7 days);
        address[3] memory ms = [a, b, c];
        for (uint256 i; i < 3; i++) {
            usdc.mint(ms[i], START);
            vm.startPrank(ms[i]);
            usdc.approve(address(circle), type(uint256).max);
            circle.join();
            vm.stopPrank();
        }
    }

    function _everyonePays() internal {
        address[3] memory ms = [a, b, c];
        for (uint256 i; i < 3; i++) {
            vm.prank(ms[i]);
            circle.contribute();
        }
    }

    function test_StartsWhenFull() public view {
        assertTrue(circle.started());
        assertEq(circle.memberCount(), 3);
        assertEq(circle.currentRecipient(), a);
    }

    function test_PayoutGoesToFirstMemberThenSecond() public {
        _everyonePays();
        circle.payout();
        assertEq(usdc.balanceOf(a), START - AMT + 3 * AMT);
        assertEq(circle.currentRecipient(), b);

        _everyonePays();
        circle.payout();
        assertEq(usdc.balanceOf(b), START - 2 * AMT + 3 * AMT);
    }

    function test_PayoutRevertsIfNotAllPaid() public {
        vm.prank(a);
        circle.contribute();
        vm.expectRevert("not all paid");
        circle.payout();
    }

    function test_CannotPayTwiceInSameCycle() public {
        vm.startPrank(a);
        circle.contribute();
        vm.expectRevert("already paid");
        circle.contribute();
        vm.stopPrank();
    }

    function test_NonMemberCannotContribute() public {
        vm.prank(address(0xDEAD));
        vm.expectRevert("not member");
        circle.contribute();
    }

    function test_FullCircleEveryoneBreaksEven() public {
        for (uint256 i; i < 3; i++) {
            _everyonePays();
            circle.payout();
        }
        assertTrue(circle.finished());
        assertEq(usdc.balanceOf(a), START);
        assertEq(usdc.balanceOf(b), START);
        assertEq(usdc.balanceOf(c), START);
        assertEq(usdc.balanceOf(address(circle)), 0);
    }

    function test_LateMembersAfterDeadline() public {
        vm.prank(a);
        circle.contribute();
        assertEq(circle.lateMembers().length, 0);
        vm.warp(block.timestamp + 8 days);
        address[] memory late = circle.lateMembers();
        assertEq(late.length, 2);
        assertEq(late[0], b);
        assertEq(late[1], c);
    }

    function test_CannotJoinTwiceOrWhenFull() public {
        Circle fresh = new Circle(address(usdc), AMT, 3, 7 days);
        vm.startPrank(a);
        fresh.join();
        vm.expectRevert("already member");
        fresh.join();
        vm.stopPrank();

        vm.expectRevert("started");
        vm.prank(address(0xD));
        circle.join();
    }
}
