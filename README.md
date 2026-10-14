# Agent Trust Registry — onchain identity & reputation for AI agents on Monad

**Monad Metropolis hackathon submission** (AgentStack team).

AI agents increasingly call each other (MCP tools, agent-to-agent tasks), but there is no neutral way to know
*which agent is who* and *whether it did good work before*. Agent Trust Registry is a minimal,
[ERC-8004](https://eips.ethereum.org/EIPS/eip-8004)-style registry on Monad:

- **Identity** — an agent registers `name` + `metadataURI` (agent card / MCP endpoint), owned by a wallet.
- **Reputation** — any wallet (optionally acting as a registered agent) leaves scored feedback (1–100) with a tag and an evidence URI (task log / tx receipt). One review per reviewer per agent; no self-review.
- **Aggregation onchain** — `reputation(id)` returns the average score (×100) and count, so other agents can make trust decisions in a single cheap `eth_call`.
- **Dashboard** — static page (`docs/index.html`) reading the registry directly from Monad testnet RPC with ethers.js; demo-data mode when no address is set.

Why Monad: agent-to-agent feedback is high-frequency and small; Monad's throughput and low fees make writing every review onchain practical, and EVM compatibility means any agent framework can integrate with standard tooling.

## Architecture
```
AgentStack MCP agents ──(cast / ethers / viem)──► AgentTrustRegistry.sol (Monad testnet)
                                                     ▲
Dashboard (GitHub Pages, static HTML+ethers) ──eth_call──┘
```
Contract: `src/AgentTrustRegistry.sol` — `register`, `update`, `giveFeedback`, `getAgent`, `reputation`, `getFeedback`, `agentsOf`; events `AgentRegistered`, `AgentUpdated`, `FeedbackGiven` for indexers.

## Run locally (for judges)
```bash
curl -L https://foundry.paradigm.xyz | bash && foundryup
git clone https://github.com/agentstacktech/agent-trust-registry && cd agent-trust-registry
forge install foundry-rs/forge-std   # if lib/ is empty
forge test -vv                       # 6 tests
# local end-to-end demo
anvil &
M="test test test test test test test test test test test junk"
K1=$(cast wallet private-key "$M" 0); K2=$(cast wallet private-key "$M" 1)
forge script script/Deploy.s.sol --rpc-url http://127.0.0.1:8545 --private-key $K1 --broadcast
RPC=http://127.0.0.1:8545 REGISTRY=0x5FbDB2315678afecb367f032d93F642f64180aa3 PK1=$K1 PK2=$K2 ./scripts/demo.sh
```
Dashboard: open `docs/index.html` (or the GitHub Pages URL) and append `?address=<registry>`.

## Monad testnet
| | |
|---|---|
| Chain ID | 10143 |
| RPC | https://testnet-rpc.monad.xyz |
| Explorer | https://testnet.monadexplorer.com |
| Faucet | https://faucet.monad.xyz |

Deploy (testnet key only, never a mainnet key):
```bash
forge script script/Deploy.s.sol --rpc-url monad_testnet --private-key $PRIVATE_KEY --broadcast
# verify (Sourcify)
forge verify-contract <ADDRESS> src/AgentTrustRegistry.sol:AgentTrustRegistry --chain 10143 \
  --verifier sourcify --verifier-url https://sourcify-api-monad.blockvision.org
REGISTRY=<ADDRESS> PK1=... PK2=... ./scripts/demo.sh   # 2 agents + review, tx links in explorer
```
## Live deployment (Monad testnet)
**AgentTrustRegistry:** [](https://testnet.monadexplorer.com/address/0x04d98b621fcD72388e7c1259e3b3577cde2Bf079) — source verified on Sourcify (exact runtime match).

Demo transactions (two agents register and review each other):
| Step | Tx |
|---|---|
| Deploy contract | [0x53f64d61…8811](https://testnet.monadexplorer.com/tx/0x53f64d61a358cb6a027b6bb7ea09f8539439590a6d23beb858288dd0bf2a8811) |
| Agent #1  registers | [0xe42c0b0e…43e7](https://testnet.monadexplorer.com/tx/0xe42c0b0e53cbb221d632dc5d3913775a3342952f5f5a6e0f044bc70e697843e7) |
| Fund demo wallet #2 | [0x14a1e04a…b1d4](https://testnet.monadexplorer.com/tx/0x14a1e04a6f0514fceee5f6f202c3bb2fa2360751d2436dafa785cdc00926b1d4) |
| Agent #2  registers | [0x26cbfa89…2f97](https://testnet.monadexplorer.com/tx/0x26cbfa89fa146f08d52361c2ef4c1feeb69689faad54cd45f57cb59b83322f97) |
| Agent #2 reviews #1 (92, task-completed) | [0x4943b935…58c8](https://testnet.monadexplorer.com/tx/0x4943b93553c37b6b745c4cc352e99bc867135a7a2d11ece86b95fe1df3c358c8) |
| Agent #1 reviews #2 (85, fast-execution) | [0x56e502a1…b159](https://testnet.monadexplorer.com/tx/0x56e502a103d408ec85f225e0bfabf5a7523a20026b999406868aa94de26ab159) |

Result: , .


## Roadmap
Validation registry (stake-backed re-execution checks), signed off-chain feedback authorisations, AgentStack MCP tool `trust.check` that gates agent-to-agent calls by reputation.

MIT License.
