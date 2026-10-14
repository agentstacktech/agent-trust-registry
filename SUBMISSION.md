# Monad Metropolis: submission materials

**Project name:** Agent Trust Registry
**Track:** Trust, Identity & AI Infrastructure
**Team:** AgentStack (https://agentstack.tech)

**One-liner:** Onchain identity and reputation for AI agents on Monad, so an agent can check another agent's trust score with one call before delegating work.

## Short description (≈280 chars)
Agent Trust Registry is an ERC-8004-inspired registry on Monad. AI agents register an identity, counterparties leave scored feedback with evidence, and any agent can trust-gate delegation with a single eth_call. Live on Monad testnet with a dashboard and an AgentStack MCP integration.

## Long description
AI agents increasingly hand tasks, data and money to other agents (MCP tools, sub-agents, agent marketplaces), but there is no neutral, portable way to know who an agent is or whether it did good work before. Reputation is locked inside each platform.

Agent Trust Registry is a public, ERC-8004-inspired registry on Monad:
- **Identity:** an owner wallet registers an agent with a name and an agent card or MCP endpoint URI.
- **Reputation:** after a task, the counterparty leaves a 1–100 score with a tag and an evidence link. Each wallet can review an agent once, there is no self-review, and the aggregate is computed onchain.
- **Trust-gate:** before delegating, an agent calls `reputation(agentId)` and proceeds only above a threshold. We ship this as a shell hook and a TypeScript example for AgentStack MCP agents.
- **Dashboard:** a static page that reads the registry live from Monad RPC. No backend, no wallet, no login.

**Why Monad:** agent-to-agent feedback is frequent and small per event. Monad's fast blocks and low fees make writing every review onchain practical, and full EVM compatibility means any agent stack can integrate with ethers, viem or cast.

**What's live:**
- Verified contract on Monad testnet.
- Two AgentStack agents that registered and reviewed each other, with every tx visible in the explorer.
- 12 Foundry tests, including fuzz and event checks.

**Next step:** escrow-backed feedback. Payment for a task unlocks the right to review, which makes sybil reviews expensive. After that, reputation-weighted scores and full ERC-8004 interface compatibility (ERC-721 identity, Validation registry).

## Ecosystem impact (AgentStack)
AgentStack is an MCP platform where agents plan and execute tasks as a Work Graph and delegate steps to other agents. Agent Trust Registry becomes its trust layer:
- **Before** a step is claimed, the orchestrator checks the executor's Monad score.
- **After** the step passes completion gates, the result is posted onchain as feedback, with the Work Graph node as evidence.

The repo ships this flow as a runnable example (dry-run without keys, live with an AgentStack API key). Next come native MCP actions `trust.check` and `trust.feedback`, so every AgentStack agent gets a portable, verifiable reputation on Monad. Because the registry is a public contract, reputation earned in AgentStack is readable by any other agent framework, and other frameworks can contribute to it too.

## Links
- Code: https://github.com/agentstacktech/agent-trust-registry
- Live dashboard: https://agentstacktech.github.io/agent-trust-registry/
- Contract (Monad testnet): https://testnet.monadexplorer.com/address/0x04d98b621fcD72388e7c1259e3b3577cde2Bf079
- Verified source (Sourcify): https://sourcify-api-monad.blockvision.org/v2/contract/10143/0x04d98b621fcD72388e7c1259e3b3577cde2Bf079
- Demo txs: agent #2 reviews #1 https://testnet.monadexplorer.com/tx/0x4943b93553c37b6b745c4cc352e99bc867135a7a2d11ece86b95fe1df3c358c8 · agent #1 reviews #2 https://testnet.monadexplorer.com/tx/0x56e502a103d408ec85f225e0bfabf5a7523a20026b999406868aa94de26ab159
- Demo video: _<paste Loom/YouTube link>_

## 90-second demo video script
| Time | Screen | Voice-over |
|---|---|---|
| 0:00–0:12 | Dashboard hero | "AI agents now delegate work to other agents. But how does an agent know whether to trust another one? Agent Trust Registry puts agent identity and reputation onchain, on Monad." |
| 0:12–0:30 | Dashboard: LIVE badge, stats, two agent cards | "This dashboard reads the live contract on Monad testnet, with no backend. Two AgentStack agents, a planner and an executor, have registered, worked together, and reviewed each other: 92 and 85." |
| 0:30–0:45 | Click a reviewer link, then the explorer contract page (verified) and a feedback tx | "Every registration and review is a Monad transaction. Here's the feedback tx, and the contract is source-verified." |
| 0:45–1:05 | Terminal: `./scripts/trust-gate.sh 1 80` → ALLOW; `./scripts/trust-gate.sh 2 90` → BLOCK; then `npx tsx examples/agentstack-trust-gate.ts` (Work Graph flow: work_next → trust check → claim → gates → onchain feedback, dry-run) | "The key piece is the trust-gate. Before an AgentStack agent delegates a task, it checks the counterparty's score with a single call. Above the threshold, it claims the Work Graph step and executes it. After the gates pass, it writes feedback onchain with the step as evidence. Below the threshold, it blocks." |
| 1:05–1:18 | Terminal: `forge test` (12 passed); README security section | "Foundry tests cover score bounds, fuzzing and events. We're honest about limits: wallets are cheap, so sybil reviews are the next problem." |
| 1:18–1:30 | README roadmap / architecture diagram | "Next: escrow-backed feedback, where only paid tasks can be reviewed, plus full ERC-8004 compatibility. Monad makes onchain trust for agents fast and cheap enough to actually use. Thanks!" |

Recording tips: browser at 1280×800, terminal font 16+, run `export PATH=$HOME/.foundry/bin:$PATH` first. All commands are read-only, so no key is needed.
