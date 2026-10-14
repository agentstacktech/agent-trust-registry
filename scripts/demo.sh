#!/usr/bin/env bash
# Demo: two agents register, agent #2 reviews agent #1 on Monad testnet.
# Requires: REGISTRY, PK1, PK2 (testnet keys funded from https://faucet.monad.xyz)
set -euo pipefail
RPC=${RPC:-https://testnet-rpc.monad.xyz}
cast send "$REGISTRY" "register(string,string)" "agentstack-planner" "https://agentstack.tech" --rpc-url "$RPC" --private-key "$PK1"
cast send "$REGISTRY" "register(string,string)" "agentstack-executor" "https://agentstack.tech/mcp" --rpc-url "$RPC" --private-key "$PK2"
ID1=$(cast call "$REGISTRY" "agentCount()(uint256)" --rpc-url "$RPC"); ID1=$((ID1-1))
cast send "$REGISTRY" "giveFeedback(uint256,uint256,uint8,string,string)" "$ID1" "$((ID1+1))" 92 "task-completed" "" --rpc-url "$RPC" --private-key "$PK2"
cast call "$REGISTRY" "reputation(uint256)(uint256,uint256)" "$ID1" --rpc-url "$RPC"
