/**
 * AgentStack trust-gate example.
 * An orchestrator agent (e.g. an AgentStack MCP agent working a Work Graph node) checks the
 * counterparty agent's onchain reputation on Monad before delegating a task, and after the task
 * it can write feedback back onchain (optional, needs a funded testnet key).
 *
 * Run:  npm i ethers tsx && npx tsx examples/agentstack-trust-gate.ts 2 80
 *       REVIEWER_PK=0x... REVIEWER_AGENT_ID=1 npx tsx examples/agentstack-trust-gate.ts 2 80 --review 90
 */
import { ethers } from "ethers";

const RPC = process.env.RPC ?? "https://testnet-rpc.monad.xyz";
const REGISTRY = process.env.REGISTRY ?? "0x04d98b621fcD72388e7c1259e3b3577cde2Bf079";
const ABI = [
  "function getAgent(uint256) view returns (tuple(address owner,string name,string metadataURI,uint64 registeredAt,bool active,uint64 feedbackCount,uint128 scoreSum))",
  "function reputation(uint256) view returns (uint256 avgX100, uint256 count)",
  "function giveFeedback(uint256 id, uint256 reviewerAgentId, uint8 score, string tag, string evidenceURI)",
];

export interface TrustDecision { allow: boolean; agentId: number; name: string; endpoint: string; score: number; reviews: number; reason: string }

export async function checkTrust(agentId: number, minScore = 80, minReviews = 1): Promise<TrustDecision> {
  const provider = new ethers.JsonRpcProvider(RPC, 10143, { staticNetwork: true });
  const reg = new ethers.Contract(REGISTRY, ABI, provider);
  const [agent, rep] = await Promise.all([reg.getAgent(agentId), reg.reputation(agentId)]);
  const score = Number(rep.avgX100) / 100, reviews = Number(rep.count);
  let reason = "ok";
  if (!agent.active) reason = "agent inactive";
  else if (reviews < minReviews) reason = `only ${reviews} review(s), need ${minReviews}`;
  else if (score < minScore) reason = `score ${score} < ${minScore}`;
  return { allow: reason === "ok", agentId, name: agent.name, endpoint: agent.metadataURI, score, reviews, reason };
}

async function delegate(task: string, d: TrustDecision) {
  // In AgentStack this would be an MCP call to the counterparty's endpoint (d.endpoint),
  // e.g. agentstack.execute with the Work Graph node; here we just simulate it.
  console.log(`→ delegating "${task}" to ${d.name} at ${d.endpoint}`);
  return { ok: true, receipt: "https://agentstack.tech" };
}

async function main() {
  const [idArg = "2", minArg = "80", flag, reviewArg] = process.argv.slice(2);
  const d = await checkTrust(Number(idArg), Number(minArg));
  console.log(`${d.allow ? "ALLOW" : "BLOCK"} #${d.agentId} ${d.name}: score=${d.score} reviews=${d.reviews} (${d.reason})`);
  if (!d.allow) process.exit(1);
  const result = await delegate("summarize Work Graph node", d);

  if (flag === "--review" && process.env.REVIEWER_PK) {
    const wallet = new ethers.Wallet(process.env.REVIEWER_PK, new ethers.JsonRpcProvider(RPC));
    const reg = new ethers.Contract(REGISTRY, ABI, wallet);
    const tx = await reg.giveFeedback(d.agentId, BigInt(process.env.REVIEWER_AGENT_ID ?? "0"), Number(reviewArg ?? 90), "task-completed", result.receipt);
    console.log(`feedback tx: https://testnet.monadexplorer.com/tx/${tx.hash}`);
    await tx.wait();
  }
}

main().catch((e) => { console.error(e.shortMessage ?? e.message); process.exit(2); });
