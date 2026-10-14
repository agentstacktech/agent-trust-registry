# Security

Contract: `AgentTrustRegistry` at `0x04d98b621fcD72388e7c1259e3b3577cde2Bf079` (Monad testnet, chainId 10143). **Testnet hackathon software, not audited.** Report issues via GitHub issues (or privately to the AgentStack team for anything exploitable).

## Design properties
- No owner/admin, no upgradeability, no `selfdestruct`, no ETH handling, no external calls → no reentrancy or privileged-key risk.
- Custom errors for every revert path (`NotOwner`, `UnknownAgent`, `InvalidScore`, `SelfReview`, `AlreadyReviewed`, `EmptyName`, `TooLong`) and events for every state change (`AgentRegistered`, `AgentUpdated`, `FeedbackGiven`) for indexers.
- Solidity ^0.8.24 checked arithmetic. `scoreSum` is `uint128`: max 100 per review → would need >3.4e36 reviews to overflow.
- All user strings capped at 256 bytes (gas-griefing / storage-bloat bound). Dashboard HTML-escapes all onchain strings and only links `http(s)` URIs (XSS from metadata).
- `getFeedbackPage` gives bounded reads; `getFeedback` is unbounded and intended only for small sets.

## Verification performed
| Check | Result |
|---|---|
| Foundry unit tests (12) | pass |
| Fuzz tests (score bounds, averages, string limits, pagination, unknown ids, reviewer-agent ownership) | pass, 256 runs each |
| Stateful invariant tests (`test/Invariant.t.sol`): reputation ∈ [1,100] or 0, matches ghost sum/count, total feedback conserved, no feedback ever from agent owner | pass, 64 runs × 50 calls |
| Slither 0.11 (102 detectors) on `src/AgentTrustRegistry.sol` | **0 findings** |
| CI | `.github/workflows/ci.yml` runs `forge build` + `forge test` + SDK live-RPC tests |

## Threat model
| Threat | Description | Implemented mitigation | Roadmap |
|---|---|---|---|
| Self-feedback | Owner rates own agent | `SelfReview` revert when `msg.sender == owner`; invariant-tested | — |
| Repeat / wash rating | Same wallet spams reviews to move the average | One review per (agent, wallet): `AlreadyReviewed` | Time-decayed scores; revocable feedback (ERC-8004 `revokeFeedback`) |
| Impersonating a reviewer agent | Claim reviews come from a reputable agent | `reviewerAgentId` must be owned by `msg.sender` (`NotOwner`) | — |
| Sybil wallets | Owner spins up fresh wallets to praise self / grief competitors | Partially: reviews are public and attributable; integrators can set `minFeedback` and inspect reviewers via SDK | **Escrow-gated feedback** (review only after a paid task), **stake-weighted** / reviewer-reputation-weighted scores, allow-listed reviewer sets per tenant |
| Collusion rings | Group of agents rate each other | Not mitigated onchain | Graph-based (PageRank-style) trust off-chain, Validation registry with staked re-execution / TEE attestations |
| Identity squatting | Register a well-known name | Names are not unique by design; identity = id + owner wallet; metadataURI points to a verifiable agent card | ERC-721 identity + domain verification of agent card |
| Gas griefing / huge arrays | Bloat feedback to break readers | 256-byte caps; paginated reads | Indexer/subgraph for reads |
| Malicious metadata (XSS/phishing) | Script or `javascript:` URIs in strings | Dashboard escapes and filters to http(s) | — |
| Trust-gate fail-open | RPC down → agent delegates anyway | SDK `checkAgent` throws on network errors (callers fail closed), denies unknown/inactive/under-reviewed agents | Multiple RPC fallback |

## Out of scope / known limitations
- Feedback cannot be revoked or disputed.
- Simple arithmetic mean; a single review fully determines a new agent's score (use `minFeedback`).
- Deployed bytecode is kept unchanged to preserve the verified address; NatSpec improvements land with the next (v2) deployment.
