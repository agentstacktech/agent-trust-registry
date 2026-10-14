// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {AgentTrustRegistry} from "../src/AgentTrustRegistry.sol";

/// forge script script/Deploy.s.sol --rpc-url monad_testnet --private-key $PRIVATE_KEY --broadcast
contract Deploy is Script {
    function run() external returns (AgentTrustRegistry reg) {
        vm.startBroadcast();
        reg = new AgentTrustRegistry();
        // Demo seed: two agents + one review (second agent needs another key; see scripts/demo.sh)
        reg.register("agentstack-planner", "https://agentstack.tech");
        vm.stopBroadcast();
        console.log("AgentTrustRegistry:", address(reg));
    }
}
