// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

/// @title Circle - a rotating savings circle (ROSCA / ajo / tanda)
/// @notice Members contribute a fixed amount each cycle. When everyone has
/// paid, the whole pot goes to the next member in join order.
contract Circle {
    IERC20 public immutable token;
    uint256 public immutable contribution;
    uint256 public immutable maxMembers;
    uint256 public immutable cycleDuration;

    address[] public members;
    mapping(address => bool) public isMember;

    bool public started;
    bool public finished;
    uint256 public currentCycle;
    uint256 public cycleStart;
    uint256 public paidCount;
    mapping(uint256 => mapping(address => bool)) public paid;

    event Joined(address indexed member, uint256 memberCount);
    event Started(uint256 startTime);
    event Contributed(address indexed member, uint256 indexed cycle);
    event PaidOut(address indexed recipient, uint256 indexed cycle, uint256 amount);
    event Finished();

    constructor(address _token, uint256 _contribution, uint256 _maxMembers, uint256 _cycleDuration) {
        require(_token != address(0), "token");
        require(_contribution > 0, "contribution");
        require(_maxMembers >= 2, "members");
        require(_cycleDuration > 0, "duration");
        token = IERC20(_token);
        contribution = _contribution;
        maxMembers = _maxMembers;
        cycleDuration = _cycleDuration;
    }

    function join() external {
        require(!started, "started");
        require(!isMember[msg.sender], "already member");
        require(members.length < maxMembers, "full");

        isMember[msg.sender] = true;
        members.push(msg.sender);
        emit Joined(msg.sender, members.length);

        if (members.length == maxMembers) {
            started = true;
            cycleStart = block.timestamp;
            emit Started(block.timestamp);
        }
    }

    function contribute() external {
        require(started && !finished, "inactive");
        require(isMember[msg.sender], "not member");
        require(!paid[currentCycle][msg.sender], "already paid");

        paid[currentCycle][msg.sender] = true;
        paidCount++;
        require(token.transferFrom(msg.sender, address(this), contribution), "transfer failed");
        emit Contributed(msg.sender, currentCycle);
    }

    /// @notice Anyone can trigger the payout once every member has paid.
    function payout() external {
        require(started && !finished, "inactive");
        require(paidCount == members.length, "not all paid");

        uint256 cycle = currentCycle;
        address recipient = members[cycle];
        uint256 pot = contribution * members.length;

        paidCount = 0;
        currentCycle = cycle + 1;
        if (currentCycle == members.length) {
            finished = true;
            emit Finished();
        } else {
            cycleStart = block.timestamp;
        }

        require(token.transfer(recipient, pot), "payout failed");
        emit PaidOut(recipient, cycle, pot);
    }

    function memberCount() external view returns (uint256) {
        return members.length;
    }

    function getMembers() external view returns (address[] memory) {
        return members;
    }

    function currentRecipient() external view returns (address) {
        require(started && !finished, "inactive");
        return members[currentCycle];
    }

    /// @notice Members who have not paid this cycle after the cycle deadline.
    function lateMembers() external view returns (address[] memory) {
        if (!started || finished || block.timestamp <= cycleStart + cycleDuration) {
            return new address[](0);
        }
        uint256 n;
        for (uint256 i; i < members.length; i++) {
            if (!paid[currentCycle][members[i]]) n++;
        }
        address[] memory late = new address[](n);
        uint256 j;
        for (uint256 i; i < members.length; i++) {
            if (!paid[currentCycle][members[i]]) late[j++] = members[i];
        }
        return late;
    }
}
