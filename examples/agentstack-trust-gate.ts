/**
 * AgentStack × Agent Trust Registry — trust-gated delegation of a Work Graph step.
 *
 * Flow (one Work Graph node):
 *   1. agents.work_next        → next pending node + candidate executor agent (onchain agentId)
 *   2. trust check (Monad)     → reputation(agentId) ≥ threshold ? continue : skip/escalate
 *   3. agents.plan_claim       → claim the node for the executor
 *   4. execute                 → executor runs the step (MCP call to its endpoint)
 *   5. gates_passed            → AgentStack completion gates → node completed (plan_patch)
 *   6. giveFeedback (Monad)    → score + tag + evidenceURI = link to the Work Graph node/result
 *
 * Modes
 *   default / --dry-run : NO keys needed. Reads real reputation from Monad testnet, prints the AgentStack
 *                         MCP payloads instead of sending them, and SIMULATES giveFeedback with eth_call
 *                         (staticCall) so you see whether the onchain write would succeed.
 *   --live              : sends to AgentStack MCP (needs AGENTSTACK_API_KEY, AGENTSTACK_PROJECT_ID)
 *                         and writes feedback onchain (needs REVIEWER_PK = testnet key, REVIEWER_AGENT_ID).
 *
 * Run:
 *   npm i ethers tsx
 *   npx tsx examples/agentstack-trust-gate.ts                              # dry-run, executor agent #2, min 80
 *   npx tsx examples/agentstack-trust-gate.ts --agent 2 --min 90           # dry-run, blocked
 *   AGENTSTACK_API_KEY=... AGENTSTACK_PROJECT_ID=... REVIEWER_PK=0x... REVIEWER_AGENT_ID=1 \
 *     npx tsx examples/agentstack-trust-gate.ts --live --node <nodeId> --agent 2
 */
import { ethers } from "ethers";

// ---------- config ----------
const args = process.argv.slice(2);
const opt = (k: string, d?: string) => { const i = args.indexOf(`--${k}`); return i >= 0 ? args[i + 1] : d; };
const LIVE = args.includes("--live");
const RPC = process.env.RPC ?? "https://testnet-rpc.monad.xyz";
const EXPLORER = "https://testnet.monadexplorer.com";
const REGISTRY = process.env.REGISTRY ?? "0x04d98b621fcD72388e7c1259e3b3577cde2Bf079";
const AGENTSTACK_MCP = process.env.AGENTSTACK_MCP ?? "https://agentstack.tech/mcp";
const PROJECT_ID = Number(process.env.AGENTSTACK_PROJECT_ID ?? 0);
const EXECUTOR_AGENT_ID = Number(opt("agent", "2"));
const MIN_SCORE = Number(opt("min", "80"));
const MIN_REVIEWS = Number(opt("min-reviews", "1"));
const REVIEWER_AGENT_ID = BigInt(process.env.REVIEWER_AGENT_ID ?? "1");

const ABI = [
  "function getAgent(uint256) view returns (tuple(address owner,string name,string metadataURI,uint64 registeredAt,bool active,uint64 feedbackCount,uint128 scoreSum))",
  "function reputation(uint256) view returns (uint256 avgX100, uint256 count)",
  "function hasReviewed(uint256, address) view returns (bool)",
  "function giveFeedback(uint256 id, uint256 reviewerAgentId, uint8 score, string tag, string evidenceURI)",
];
const provider = new ethers.JsonRpcProvider(RPC, 10143, { staticNetwork: true });
const registry = new ethers.Contract(REGISTRY, ABI, provider);

// ---------- AgentStack MCP (agentstack.execute) ----------
type Step = { id: string; action: string; params: Record<string, unknown> };
async function agentstack(steps: Step[], goal: string): Promise<any> {
  const body = { jsonrpc: "2.0", id: Date.now(), method: "tools/call",
    params: { name: "agentstack.execute", arguments: { steps, context: { project_id: PROJECT_ID }, options: { goal } } } };
  if (!LIVE) {
    console.log(`   [dry-run] POST ${AGENTSTACK_MCP} agentstack.execute → ${steps.map((s) => s.action).join(", ")}`);
    console.log(`             ${JSON.stringify(steps)}`);
    return null;
  }
  const r = await fetch(AGENTSTACK_MCP, { method: "POST",
    headers: { "Content-Type": "application/json", Accept: "application/json, text/event-stream", "X-API-Key": process.env.AGENTSTACK_API_KEY ?? "" },
    body: JSON.stringify(body) });
  const j: any = await r.json();
  return j?.result?.structuredContent ?? j;
}

// ---------- trust check ----------
export interface TrustDecision { allow: boolean; agentId: number; name: string; endpoint: string; score: number; reviews: number; reason: string }
export async function checkTrust(agentId: number, minScore = MIN_SCORE, minReviews = MIN_REVIEWS): Promise<TrustDecision> {
  const [agent, rep] = await Promise.all([registry.getAgent(agentId), registry.reputation(agentId)]);
  const score = Number(rep.avgX100) / 100, reviews = Number(rep.count);
  let reason = "ok";
  if (!agent.active) reason = "agent inactive";
  else if (reviews < minReviews) reason = `only ${reviews} review(s), need ${minReviews}`;
  else if (score < minScore) reason = `score ${score} < ${minScore}`;
  return { allow: reason === "ok", agentId, name: agent.name, endpoint: agent.metadataURI, score, reviews, reason };
}

// ---------- executor (stub: in production an MCP call to the executor's endpoint) ----------
async function executeStep(nodeId: string, d: TrustDecision) {
  console.log(`   executor ${d.name} (${d.endpoint}) runs node ${nodeId} …`);
  return { ok: true, gatesPassed: true, quality: 0.9, resultURI: `https://agentstack.tech/work-graph/${PROJECT_ID || "demo"}/${nodeId}` };
}

// ---------- main flow ----------
async function main() {
  if (LIVE && (!process.env.AGENTSTACK_API_KEY || !PROJECT_ID)) { console.error("--live needs AGENTSTACK_API_KEY and AGENTSTACK_PROJECT_ID"); process.exit(2); }
  console.log(`Agent Trust Registry ${REGISTRY} on Monad testnet · mode=${LIVE ? "LIVE" : "dry-run"}\n`);

  console.log("1) agents.work_next — pick the next Work Graph step");
  const wn = await agentstack([{ id: "wn", action: "agents.work_next", params: { claim: false } }], "trust-gated delegation: pick next step");
  const nodeId: string = opt("node") ?? wn?.data?.steps?.[0]?.result?.node_id ?? "demo-node-1";
  console.log(`   node = ${nodeId}, candidate executor = agent #${EXECUTOR_AGENT_ID}\n`);

  console.log("2) trust check on Monad — reputation(agentId)");
  const d = await checkTrust(EXECUTOR_AGENT_ID);
  console.log(`   ${d.allow ? "ALLOW" : "BLOCK"} #${d.agentId} ${d.name}: score=${d.score} reviews=${d.reviews} (${d.reason}; min ${MIN_SCORE})\n`);
  if (!d.allow) {
    console.log("   → not delegating. In AgentStack: leave node pending, pick another agent or escalate to a human.");
    process.exit(1);
  }

  console.log("3) agents.plan_claim — claim the node for the trusted executor");
  await agentstack([{ id: "claim", action: "agents.plan_claim", params: { node_id: nodeId } }], "claim step for trusted executor");

  console.log("\n4) execute the step");
  const res = await executeStep(nodeId, d);

  console.log("\n5) completion gates → mark node completed");
  await agentstack([{ id: "done", action: "agents.plan_patch", params: { ops: [
    { op: "set_meta", id: nodeId, key: "gates_passed", value: res.gatesPassed },
    { op: "set_meta", id: nodeId, key: "executor_agent_id", value: d.agentId },
    { op: "set", id: nodeId, status: "completed" } ] } }], "complete trusted step");

  const score = Math.max(1, Math.min(100, Math.round((res.gatesPassed ? res.quality : 0.2) * 100)));
  const tag = res.gatesPassed ? "task-completed" : "gates-failed";
  console.log(`\n6) onchain feedback: giveFeedback(${d.agentId}, ${REVIEWER_AGENT_ID}, ${score}, "${tag}", "${res.resultURI}")`);
  if (LIVE && process.env.REVIEWER_PK) {
    const wallet = new ethers.Wallet(process.env.REVIEWER_PK, provider);
    if (await registry.hasReviewed(d.agentId, wallet.address)) { console.log("   already reviewed by this wallet — skipping"); return; }
    const tx = await (registry.connect(wallet) as any).giveFeedback(d.agentId, REVIEWER_AGENT_ID, score, tag, res.resultURI);
    console.log(`   tx: ${EXPLORER}/tx/${tx.hash}`);
    await tx.wait();
  } else {
    // simulate from a fresh address (reviewerAgentId=0, since a fresh address owns no agent)
    const from = ethers.Wallet.createRandom().address;
    try {
      await registry.giveFeedback.staticCall(d.agentId, 0n, score, tag, res.resultURI, { from });
      console.log(`   [dry-run] eth_call simulation from ${from}: OK — the write would succeed onchain`);
    } catch (e: any) { console.log(`   [dry-run] simulation reverted: ${e.shortMessage ?? e.message}`); }
  }
  const after = await registry.reputation(d.agentId);
  console.log(`\nDone. Current onchain score of #${d.agentId}: ${Number(after.avgX100) / 100} (${after.count} reviews) · ${EXPLORER}/address/${REGISTRY}`);
}

main().catch((e) => { console.error(e.shortMessage ?? e.message); process.exit(2); });
