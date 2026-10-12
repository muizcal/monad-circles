// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @notice Lets each wallet publish a display name so circle members can recognise each other.
contract Profiles {
    mapping(address => string) public names;
    event NameSet(address indexed user, string name);

    function setName(string calldata name) external {
        require(bytes(name).length <= 24, "too long");
        names[msg.sender] = name;
        emit NameSet(msg.sender, name);
    }
}
