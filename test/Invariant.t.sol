// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {AgentTrustRegistry} from "../src/AgentTrustRegistry.sol";

/// @notice Stateful fuzz handler: random actors register agents and leave feedback.
contract Handler is Test {
    AgentTrustRegistry public reg;
    address[] public actors;
    mapping(uint256 => uint256) public ghostSum;
    mapping(uint256 => uint256) public ghostCount;
    uint256 public ghostTotalFeedback;

    constructor(AgentTrustRegistry r) {
        reg = r;
        for (uint256 i = 1; i <= 8; i++) actors.push(address(uint160(0x1000 + i)));
    }

    function register(uint256 actorSeed) external {
        vm.prank(actors[actorSeed % actors.length]);
        reg.register("agent", "ipfs://card");
    }

    function feedback(uint256 actorSeed, uint256 idSeed, uint8 score) external {
        uint256 n = reg.agentCount();
        if (n == 0) return;
        uint256 id = bound(idSeed, 1, n);
        address who = actors[actorSeed % actors.length];
        score = uint8(bound(score, 1, 100));
        if (reg.getAgent(id).owner == who || reg.hasReviewed(id, who)) {
            vm.prank(who);
            vm.expectRevert();
            reg.giveFeedback(id, 0, score, "t", "");
            return;
        }
        vm.prank(who);
        reg.giveFeedback(id, 0, score, "t", "");
        ghostSum[id] += score;
        ghostCount[id] += 1;
        ghostTotalFeedback += 1;
    }
}

contract AgentTrustRegistryInvariantTest is Test {
    AgentTrustRegistry reg;
    Handler h;

    function setUp() public {
        reg = new AgentTrustRegistry();
        h = new Handler(reg);
        targetContract(address(h));
    }

    /// reputation is always within [100, 10000] when count > 0, else 0; matches ghost accounting.
    function invariant_reputationBoundedAndConsistent() public view {
        uint256 total;
        for (uint256 id = 1; id <= reg.agentCount(); id++) {
            (uint256 avg, uint256 c) = reg.reputation(id);
            assertEq(c, h.ghostCount(id));
            assertEq(c, reg.feedbackCount(id));
            if (c == 0) assertEq(avg, 0);
            else {
                assertGe(avg, 100);
                assertLe(avg, 10000);
                assertEq(avg, h.ghostSum(id) * 100 / c);
            }
            total += c;
        }
        assertEq(total, h.ghostTotalFeedback());
    }

    /// no agent ever contains feedback from its own owner (self-review blocked).
    function invariant_noSelfFeedback() public view {
        for (uint256 id = 1; id <= reg.agentCount(); id++) {
            AgentTrustRegistry.Feedback[] memory f = reg.getFeedback(id);
            address o = reg.getAgent(id).owner;
            for (uint256 i; i < f.length; i++) assertTrue(f[i].reviewer != o);
        }
    }
}

contract AgentTrustRegistryFuzzTest is Test {
    AgentTrustRegistry reg;

    function setUp() public {
        reg = new AgentTrustRegistry();
    }

    function testFuzz_unknownAgentReverts(uint256 id) public {
        vm.assume(id != 0);
        vm.expectRevert(AgentTrustRegistry.UnknownAgent.selector);
        reg.reputation(id);
    }

    function testFuzz_stringLengthLimit(uint16 len) public {
        len = uint16(bound(len, 1, 600));
        string memory s = string(new bytes(len));
        if (len > 256) vm.expectRevert(AgentTrustRegistry.TooLong.selector);
        reg.register(s, "");
    }

    function testFuzz_paginationNeverOverflows(uint256 offset, uint256 limit) public {
        reg.register("a", "");
        for (uint160 i = 1; i <= 3; i++) {
            vm.prank(address(i + 100));
            reg.giveFeedback(1, 0, 50, "", "");
        }
        limit = bound(limit, 0, 1e6);
        offset = bound(offset, 0, 1e6);
        AgentTrustRegistry.Feedback[] memory p = reg.getFeedbackPage(1, offset, limit);
        assertLe(p.length, 3);
    }

    function testFuzz_reviewerAgentMustBeOwned(address other) public {
        vm.assume(other != address(this) && other != address(0));
        reg.register("target", "");
        vm.prank(other);
        uint256 rid = reg.register("reviewer", "");
        address stranger = address(0xBEEF);
        vm.assume(other != stranger);
        vm.prank(stranger);
        vm.expectRevert(AgentTrustRegistry.NotOwner.selector);
        reg.giveFeedback(1, rid, 50, "", "");
    }
}
