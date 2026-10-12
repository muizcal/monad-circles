// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

/// @title Circle - rotating savings circle with chat, a payout-mode vote and random pot draws
contract Circle {
    enum Phase { Joining, Voting, Active, Finished, Aborted }
    enum Mode { Locked, AsYouGo }
    struct Msg { address from; uint256 time; string text; }

    IERC20 public immutable token;
    uint256 public immutable contribution;
    uint256 public immutable maxMembers;
    uint256 public immutable cycleDuration;
    uint256 public constant VOTE_WINDOW = 1 days;

    Phase public phase;
    Mode public mode;
    address[] public members;
    mapping(address => bool) public isMember;

    mapping(address => uint8) public voted; // 0 none, 1 locked, 2 withdraw as you receive
    uint256 public votesLocked;
    uint256 public votesAsYouGo;
    uint256 public votingStart;

    uint256 public currentRound;
    uint256 public cycleStart;
    uint256 public paidCount;
    mapping(uint256 => mapping(address => bool)) public paid;
    mapping(address => uint256) public totalPaid;
    mapping(address => uint256) public owed;
    address[] internal recipients;
    uint256[] internal remaining;

    Msg[] internal msgs;

    event Joined(address indexed member, uint256 count);
    event Message(address indexed from, string text);
    event ModeDecided(Mode mode, uint256 votesLocked, uint256 votesAsYouGo);
    event Contributed(address indexed member, uint256 indexed round);
    event PotAwarded(address indexed recipient, uint256 indexed round, uint256 amount);
    event Withdrawn(address indexed member, uint256 amount);

    constructor(address _token, uint256 _contribution, uint256 _maxMembers, uint256 _cycleDuration) {
        require(_token != address(0) && _contribution > 0 && _maxMembers >= 2 && _cycleDuration > 0, "bad args");
        token = IERC20(_token);
        contribution = _contribution;
        maxMembers = _maxMembers;
        cycleDuration = _cycleDuration;
    }

    function join() external {
        require(phase == Phase.Joining, "closed");
        require(!isMember[msg.sender], "already member");
        isMember[msg.sender] = true;
        members.push(msg.sender);
        emit Joined(msg.sender, members.length);
        if (members.length == maxMembers) {
            phase = Phase.Voting;
            votingStart = block.timestamp;
            for (uint256 i; i < maxMembers; i++) remaining.push(i);
        }
    }

    function say(string calldata text) external {
        require(isMember[msg.sender], "not member");
        require(bytes(text).length > 0 && bytes(text).length <= 200, "length");
        msgs.push(Msg(msg.sender, block.timestamp, text));
        emit Message(msg.sender, text);
    }

    function castVote(uint8 choice) external {
        require(phase == Phase.Voting, "not voting");
        require(isMember[msg.sender], "not member");
        require(choice == 1 || choice == 2, "choice");
        require(voted[msg.sender] == 0, "voted");
        voted[msg.sender] = choice;
        if (choice == 1) votesLocked++; else votesAsYouGo++;
        if (votesLocked + votesAsYouGo == members.length) _startRounds();
    }

    function finalizeVote() external {
        require(phase == Phase.Voting, "not voting");
        require(block.timestamp > votingStart + VOTE_WINDOW, "voting open");
        _startRounds();
    }

    function _startRounds() internal {
        mode = votesAsYouGo > votesLocked ? Mode.AsYouGo : Mode.Locked; // a tie means locked
        phase = Phase.Active;
        cycleStart = block.timestamp;
        emit ModeDecided(mode, votesLocked, votesAsYouGo);
    }

    function contribute() external {
        require(phase == Phase.Active, "inactive");
        require(isMember[msg.sender], "not member");
        require(!paid[currentRound][msg.sender], "already paid");
        paid[currentRound][msg.sender] = true;
        totalPaid[msg.sender] += contribution;
        paidCount++;
        require(token.transferFrom(msg.sender, address(this), contribution), "transfer failed");
        emit Contributed(msg.sender, currentRound);
        if (paidCount == members.length) _draw();
    }

    /// @dev Pseudo-random draw among members who have not received a pot. Not manipulation-proof
    /// (a production version would use a VRF such as Pyth Entropy).
    function _draw() internal {
        uint256 left = remaining.length;
        uint256 k = uint256(keccak256(abi.encodePacked(blockhash(block.number - 1), block.prevrandao, block.timestamp, currentRound, address(this)))) % left;
        address winner = members[remaining[k]];
        remaining[k] = remaining[left - 1];
        remaining.pop();
        recipients.push(winner);
        uint256 pot = contribution * members.length;
        owed[winner] += pot;
        emit PotAwarded(winner, currentRound, pot);
        paidCount = 0;
        currentRound++;
        if (recipients.length == members.length) phase = Phase.Finished;
        else cycleStart = block.timestamp;
    }

    function withdraw() external {
        require(phase == Phase.Finished || (phase == Phase.Active && mode == Mode.AsYouGo), "locked");
        uint256 a = owed[msg.sender];
        require(a > 0, "nothing");
        owed[msg.sender] = 0;
        require(token.transfer(msg.sender, a), "failed");
        emit Withdrawn(msg.sender, a);
    }

    /// @notice Locked mode only: if a round stalls for two round-lengths, members can stop and reclaim what they paid.
    function abort() external {
        require(isMember[msg.sender], "not member");
        require(phase == Phase.Active && mode == Mode.Locked, "cannot stop");
        require(block.timestamp > cycleStart + 2 * cycleDuration, "too early");
        phase = Phase.Aborted;
    }

    function refund() external {
        require(phase == Phase.Aborted, "not stopped");
        uint256 a = totalPaid[msg.sender];
        require(a > 0, "nothing");
        totalPaid[msg.sender] = 0;
        require(token.transfer(msg.sender, a), "failed");
    }

    function getMembers() external view returns (address[] memory) { return members; }
    function getRecipients() external view returns (address[] memory) { return recipients; }
    function messageCount() external view returns (uint256) { return msgs.length; }

    function getMessages(uint256 start, uint256 count) external view returns (Msg[] memory out) {
        out = new Msg[](count);
        for (uint256 i; i < count; i++) out[i] = msgs[start + i];
    }

    function lateMembers() external view returns (address[] memory) {
        if (phase != Phase.Active || block.timestamp <= cycleStart + cycleDuration) return new address[](0);
        uint256 n;
        for (uint256 i; i < members.length; i++) if (!paid[currentRound][members[i]]) n++;
        address[] memory late = new address[](n);
        uint256 j;
        for (uint256 i; i < members.length; i++) if (!paid[currentRound][members[i]]) late[j++] = members[i];
        return late;
    }
}
