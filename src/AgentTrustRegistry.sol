// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title AgentTrustRegistry
/// @notice ERC-8004-style onchain identity + reputation registry for AI agents on Monad.
/// Agents register an identity (owner wallet, name, metadata URI such as an MCP/agent card),
/// other agents/users leave scored feedback (1..100) that is aggregated onchain.
contract AgentTrustRegistry {
    struct Agent {
        address owner;
        string name;
        string metadataURI; // e.g. https://.../agent-card.json or MCP endpoint
        uint64 registeredAt;
        bool active;
        uint64 feedbackCount;
        uint128 scoreSum;
    }

    struct Feedback {
        address reviewer;
        uint256 reviewerAgentId; // 0 if reviewer is not a registered agent
        uint8 score; // 1..100
        string tag; // e.g. "task-completed", "spam"
        string evidenceURI; // link to receipt / task log
        uint64 timestamp;
    }

    uint256 public agentCount;
    mapping(uint256 => Agent) private _agents;
    mapping(uint256 => Feedback[]) private _feedback;
    mapping(address => uint256[]) private _byOwner;
    mapping(uint256 => mapping(address => bool)) public hasReviewed;

    event AgentRegistered(uint256 indexed agentId, address indexed owner, string name, string metadataURI);
    event AgentUpdated(uint256 indexed agentId, string metadataURI, bool active);
    event FeedbackGiven(uint256 indexed agentId, address indexed reviewer, uint256 reviewerAgentId, uint8 score, string tag, string evidenceURI);

    error NotOwner();
    error UnknownAgent();
    error InvalidScore();
    error SelfReview();
    error AlreadyReviewed();
    error EmptyName();
    error TooLong();

    uint256 public constant MAX_STR = 256;

    function _len(string calldata a) private pure {
        if (bytes(a).length > MAX_STR) revert TooLong();
    }

    modifier exists(uint256 id) {
        if (id == 0 || id > agentCount) revert UnknownAgent();
        _;
    }

    function register(string calldata name, string calldata metadataURI) external returns (uint256 id) {
        if (bytes(name).length == 0) revert EmptyName();
        _len(name);
        _len(metadataURI);
        id = ++agentCount;
        _agents[id] = Agent(msg.sender, name, metadataURI, uint64(block.timestamp), true, 0, 0);
        _byOwner[msg.sender].push(id);
        emit AgentRegistered(id, msg.sender, name, metadataURI);
    }

    function update(uint256 id, string calldata metadataURI, bool active) external exists(id) {
        Agent storage a = _agents[id];
        if (a.owner != msg.sender) revert NotOwner();
        _len(metadataURI);
        a.metadataURI = metadataURI;
        a.active = active;
        emit AgentUpdated(id, metadataURI, active);
    }

    /// @param reviewerAgentId optional id of an agent owned by msg.sender (0 = none)
    function giveFeedback(uint256 id, uint256 reviewerAgentId, uint8 score, string calldata tag, string calldata evidenceURI)
        external
        exists(id)
    {
        if (score == 0 || score > 100) revert InvalidScore();
        _len(tag);
        _len(evidenceURI);
        Agent storage a = _agents[id];
        if (a.owner == msg.sender) revert SelfReview();
        if (hasReviewed[id][msg.sender]) revert AlreadyReviewed();
        if (reviewerAgentId != 0) {
            if (reviewerAgentId > agentCount) revert UnknownAgent();
            if (_agents[reviewerAgentId].owner != msg.sender) revert NotOwner();
        }
        hasReviewed[id][msg.sender] = true;
        a.feedbackCount += 1;
        a.scoreSum += score;
        _feedback[id].push(Feedback(msg.sender, reviewerAgentId, score, tag, evidenceURI, uint64(block.timestamp)));
        emit FeedbackGiven(id, msg.sender, reviewerAgentId, score, tag, evidenceURI);
    }

    function getAgent(uint256 id) external view exists(id) returns (Agent memory) {
        return _agents[id];
    }

    /// @return avgX100 average score scaled by 100 (e.g. 8750 = 87.50); 0 if no feedback
    function reputation(uint256 id) external view exists(id) returns (uint256 avgX100, uint256 count) {
        Agent storage a = _agents[id];
        count = a.feedbackCount;
        avgX100 = count == 0 ? 0 : (uint256(a.scoreSum) * 100) / count;
    }

    function getFeedback(uint256 id) external view exists(id) returns (Feedback[] memory) {
        return _feedback[id];
    }

    function feedbackCount(uint256 id) external view exists(id) returns (uint256) {
        return _feedback[id].length;
    }

    /// @notice Paginated read to avoid unbounded-array eth_call limits.
    function getFeedbackPage(uint256 id, uint256 offset, uint256 limit)
        external
        view
        exists(id)
        returns (Feedback[] memory page)
    {
        Feedback[] storage all = _feedback[id];
        if (offset >= all.length) return new Feedback[](0);
        uint256 end = offset + limit > all.length ? all.length : offset + limit;
        page = new Feedback[](end - offset);
        for (uint256 i = offset; i < end; i++) page[i - offset] = all[i];
    }

    function agentsOf(address owner) external view returns (uint256[] memory) {
        return _byOwner[owner];
    }
}
