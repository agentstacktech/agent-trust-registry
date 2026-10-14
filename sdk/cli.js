#!/usr/bin/env node
// Usage: trust-gate <agentId> [minScore=70]   exit 0 = allowed, 1 = denied, 2 = error
import { checkAgent } from "./index.js";
const [id, min = "70"] = process.argv.slice(2);
if (!id) { console.error("usage: trust-gate <agentId> [minScore]"); process.exit(2); }
checkAgent(Number(id), Number(min), {}, process.env.MONAD_RPC_URL ? { rpcUrl: process.env.MONAD_RPC_URL } : {})
  .then((r) => { console.log(JSON.stringify(r)); process.exit(r.allowed ? 0 : 1); })
  .catch((e) => { console.error("error:", e.shortMessage ?? e.message); process.exit(2); });
