#!/usr/bin/env bash
# AgentStack trust-gate: allow delegation to an agent only if its onchain reputation is high enough.
# Usage: REGISTRY=0x... ./scripts/trust-gate.sh <agentId> [minScore=80] [minReviews=1]
# Exit codes: 0 = ALLOW, 1 = BLOCK, 2 = usage/RPC error.
set -uo pipefail
RPC=${RPC:-https://testnet-rpc.monad.xyz}
REGISTRY=${REGISTRY:-0x04d98b621fcD72388e7c1259e3b3577cde2Bf079}
ID=${1:-}; MIN=${2:-80}; MINREV=${3:-1}
[[ "$ID" =~ ^[0-9]+$ ]] || { echo "usage: $0 <agentId> [minScore] [minReviews]" >&2; exit 2; }
OUT=$(cast call "$REGISTRY" "reputation(uint256)(uint256,uint256)" "$ID" --rpc-url "$RPC" 2>&1) || { echo "ERROR: $OUT" >&2; exit 2; }
AVG=$(echo "$OUT" | sed -n 1p | awk '{print $1}'); CNT=$(echo "$OUT" | sed -n 2p | awk '{print $1}')
SCORE=$((AVG / 100))
if (( CNT >= MINREV && AVG >= MIN * 100 )); then
  echo "ALLOW agent #$ID score=$SCORE.$(printf %02d $((AVG % 100))) reviews=$CNT (min $MIN, $MINREV reviews)"; exit 0
fi
echo "BLOCK agent #$ID score=$SCORE.$(printf %02d $((AVG % 100))) reviews=$CNT (min $MIN, $MINREV reviews)"; exit 1
