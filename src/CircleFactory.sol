// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Circle} from "./Circle.sol";

contract CircleFactory {
    address[] public circles;

    event CircleCreated(address indexed circle, address indexed creator);

    function createCircle(address token, uint256 contribution, uint256 maxMembers, uint256 cycleDuration)
        external
        returns (address)
    {
        Circle c = new Circle(token, contribution, maxMembers, cycleDuration);
        circles.push(address(c));
        emit CircleCreated(address(c), msg.sender);
        return address(c);
    }

    function allCircles() external view returns (address[] memory) {
        return circles;
    }
}
