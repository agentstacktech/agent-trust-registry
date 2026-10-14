// agent-trust-gate: minimal SDK for AgentTrustRegistry (Monad testnet)
import { Contract, JsonRpcProvider } from "ethers";

export const DEFAULTS = {
  rpcUrl: "https://testnet-rpc.monad.xyz",
  address: "0x04d98b621fcD72388e7c1259e3b3577cde2Bf079",
  chainId: 10143,
  explorer: "https://testnet.monadexplorer.com",
};

export const ABI = [
  "function agentCount() view returns (uint256)",
  "function getAgent(uint256) view returns (tuple(address owner,string name,string metadataURI,uint64 registeredAt,bool active,uint64 feedbackCount,uint128 scoreSum))",
  "function reputation(uint256) view returns (uint256 avgX100, uint256 count)",
  "function getFeedbackPage(uint256,uint256,uint256) view returns (tuple(address reviewer,uint256 reviewerAgentId,uint8 score,string tag,string evidenceURI,uint64 timestamp)[])",
];

export function createClient(opts = {}) {
  const cfg = { ...DEFAULTS, ...opts };
  const provider = opts.provider ?? new JsonRpcProvider(cfg.rpcUrl, cfg.chainId, { staticNetwork: true });
  const c = new Contract(cfg.address, ABI, provider);

  async function getAgent(id) {
    const a = await c.getAgent(BigInt(id));
    const [avgX100, count] = await c.reputation(BigInt(id));
    return {
      id: Number(id), owner: a.owner, name: a.name, metadataURI: a.metadataURI,
      registeredAt: Number(a.registeredAt), active: a.active,
      score: Number(avgX100) / 100, feedbackCount: Number(count),
    };
  }

  async function getFeedback(id, offset = 0, limit = 50) {
    const page = await c.getFeedbackPage(BigInt(id), BigInt(offset), BigInt(limit));
    return page.map((f) => ({
      reviewer: f.reviewer, reviewerAgentId: Number(f.reviewerAgentId), score: Number(f.score),
      tag: f.tag, evidenceURI: f.evidenceURI, timestamp: Number(f.timestamp),
    }));
  }

  /**
   * Trust gate. Never throws for policy failures; returns {allowed, reason, agent}.
   * @param {number|bigint} id agent id
   * @param {number} minScore 0..100
   * @param {{minFeedback?:number, requireActive?:boolean}} [policy]
   */
  async function checkAgent(id, minScore = 70, policy = {}) {
    const { minFeedback = 1, requireActive = true } = policy;
    let agent;
    try { agent = await getAgent(id); }
    catch (e) {
      if (String(e?.message ?? e).includes("UnknownAgent") || e?.revert || e?.code === "CALL_EXCEPTION")
        return { allowed: false, reason: "unknown-agent", agent: null };
      throw e; // network errors bubble up: fail closed at caller
    }
    if (requireActive && !agent.active) return { allowed: false, reason: "inactive", agent };
    if (agent.feedbackCount < minFeedback) return { allowed: false, reason: "insufficient-feedback", agent };
    if (agent.score < minScore) return { allowed: false, reason: "score-below-threshold", agent };
    return { allowed: true, reason: "ok", agent };
  }

  return { contract: c, provider, config: cfg, getAgent, getFeedback, checkAgent,
    explorerUrl: (addr = cfg.address) => `${cfg.explorer}/address/${addr}` };
}

export async function checkAgent(id, minScore, policy, opts) {
  return createClient(opts).checkAgent(id, minScore, policy);
}
