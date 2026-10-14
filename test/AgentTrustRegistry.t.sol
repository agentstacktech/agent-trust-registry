// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {AgentTrustRegistry} from "../src/AgentTrustRegistry.sol";

contract AgentTrustRegistryTest is Test {
    event AgentRegistered(uint256 indexed agentId, address indexed owner, string name, string metadataURI);
    event AgentUpdated(uint256 indexed agentId, string metadataURI, bool active);
    event FeedbackGiven(uint256 indexed agentId, address indexed reviewer, uint256 reviewerAgentId, uint8 score, string tag, string evidenceURI);

    AgentTrustRegistry reg;
    address alice = address(0xA11CE);
    address bob = address(0xB0B);
    address carol = address(0xCA401);

    function setUp() public {
        reg = new AgentTrustRegistry();
    }

    function _reg(address who, string memory n) internal returns (uint256) {
        vm.prank(who);
        return reg.register(n, "ipfs://card");
    }

    function testRegister() public {
        uint256 id = _reg(alice, "planner");
        assertEq(id, 1);
        AgentTrustRegistry.Agent memory a = reg.getAgent(1);
        assertEq(a.owner, alice);
        assertEq(a.name, "planner");
        assertTrue(a.active);
        assertEq(reg.agentsOf(alice).length, 1);
    }

    function testEmptyNameReverts() public {
        vm.expectRevert(AgentTrustRegistry.EmptyName.selector);
        reg.register("", "");
    }

    function testFeedbackAndReputation() public {
        uint256 a = _reg(alice, "planner");
        uint256 b = _reg(bob, "executor");
        vm.prank(bob);
        reg.giveFeedback(a, b, 90, "task-completed", "https://tx");
        vm.prank(carol);
        reg.giveFeedback(a, 0, 71, "ok", "");
        (uint256 avg, uint256 cnt) = reg.reputation(a);
        assertEq(cnt, 2);
        assertEq(avg, 8050);
        assertEq(reg.getFeedback(a).length, 2);
        assertEq(reg.getFeedback(a)[0].reviewerAgentId, b);
    }

    function testRejects() public {
        uint256 a = _reg(alice, "planner");
        uint256 b = _reg(bob, "executor");
        vm.startPrank(alice);
        vm.expectRevert(AgentTrustRegistry.SelfReview.selector);
        reg.giveFeedback(a, 0, 50, "", "");
        vm.stopPrank();
        vm.startPrank(bob);
        vm.expectRevert(AgentTrustRegistry.InvalidScore.selector);
        reg.giveFeedback(a, 0, 0, "", "");
        vm.expectRevert(AgentTrustRegistry.InvalidScore.selector);
        reg.giveFeedback(a, 0, 101, "", "");
        vm.expectRevert(AgentTrustRegistry.UnknownAgent.selector);
        reg.giveFeedback(99, 0, 50, "", "");
        reg.giveFeedback(a, b, 50, "", "");
        vm.expectRevert(AgentTrustRegistry.AlreadyReviewed.selector);
        reg.giveFeedback(a, b, 60, "", "");
        vm.stopPrank();
        vm.prank(carol);
        vm.expectRevert(AgentTrustRegistry.NotOwner.selector);
        reg.giveFeedback(a, b, 60, "", ""); // carol does not own agent b
    }

    function testUpdateOnlyOwner() public {
        uint256 a = _reg(alice, "planner");
        vm.prank(bob);
        vm.expectRevert(AgentTrustRegistry.NotOwner.selector);
        reg.update(a, "x", false);
        vm.prank(alice);
        reg.update(a, "https://new", false);
        assertFalse(reg.getAgent(a).active);
    }

    function testReputationZero() public {
        uint256 a = _reg(alice, "planner");
        (uint256 avg, uint256 cnt) = reg.reputation(a);
        assertEq(avg + cnt, 0);
    }

    function testPaginationAndLimits() public {
        uint256 a = _reg(alice, "planner");
        vm.prank(bob);
        reg.giveFeedback(a, 0, 10, "", "");
        vm.prank(carol);
        reg.giveFeedback(a, 0, 20, "", "");
        assertEq(reg.feedbackCount(a), 2);
        assertEq(reg.getFeedbackPage(a, 1, 10).length, 1);
        assertEq(reg.getFeedbackPage(a, 1, 10)[0].score, 20);
        assertEq(reg.getFeedbackPage(a, 5, 10).length, 0);
        bytes memory big = new bytes(257);
        vm.prank(alice);
        vm.expectRevert(AgentTrustRegistry.TooLong.selector);
        reg.update(a, string(big), true);
    }

    function testFuzzScoreBounds(uint8 score) public {
        uint256 a = _reg(alice, "planner");
        vm.prank(bob);
        if (score == 0 || score > 100) {
            vm.expectRevert(AgentTrustRegistry.InvalidScore.selector);
            reg.giveFeedback(a, 0, score, "", "");
        } else {
            reg.giveFeedback(a, 0, score, "", "");
            (uint256 avg, uint256 cnt) = reg.reputation(a);
            assertEq(cnt, 1);
            assertEq(avg, uint256(score) * 100);
        }
    }

    function testFuzzAverage(uint8 s1, uint8 s2) public {
        s1 = uint8(bound(s1, 1, 100));
        s2 = uint8(bound(s2, 1, 100));
        uint256 a = _reg(alice, "planner");
        vm.prank(bob);
        reg.giveFeedback(a, 0, s1, "", "");
        vm.prank(carol);
        reg.giveFeedback(a, 0, s2, "", "");
        (uint256 avg,) = reg.reputation(a);
        assertEq(avg, (uint256(s1) + s2) * 100 / 2);
        assertLe(avg, 10000);
        assertGe(avg, 100);
    }

    function testEmitRegistered() public {
        vm.expectEmit(true, true, false, true);
        emit AgentRegistered(1, alice, "planner", "ipfs://card");
        _reg(alice, "planner");
    }

    function testEmitFeedbackAndUpdate() public {
        uint256 a = _reg(alice, "planner");
        uint256 b = _reg(bob, "executor");
        vm.expectEmit(true, true, false, true);
        emit FeedbackGiven(a, bob, b, 77, "tag", "https://e");
        vm.prank(bob);
        reg.giveFeedback(a, b, 77, "tag", "https://e");
        vm.expectEmit(true, false, false, true);
        emit AgentUpdated(a, "https://new", false);
        vm.prank(alice);
        reg.update(a, "https://new", false);
    }

    function testUpdateUnknownReverts() public {
        vm.expectRevert(AgentTrustRegistry.UnknownAgent.selector);
        reg.update(1, "", true);
        vm.expectRevert(AgentTrustRegistry.UnknownAgent.selector);
        reg.reputation(0);
    }
}
