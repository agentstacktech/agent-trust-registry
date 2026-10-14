import { test } from "node:test";
import assert from "node:assert/strict";
import { createClient } from "../index.js";

const client = createClient();

test("reads agent #1 from live Monad testnet", async () => {
  const a = await client.getAgent(1);
  assert.equal(a.id, 1);
  assert.match(a.owner, /^0x[0-9a-fA-F]{40}$/);
  assert.ok(a.score >= 0 && a.score <= 100);
});

test("gate: unknown agent denied", async () => {
  const r = await client.checkAgent(999999, 50);
  assert.equal(r.allowed, false);
  assert.equal(r.reason, "unknown-agent");
});

test("gate: impossible threshold denied, zero threshold consistent", async () => {
  const hi = await client.checkAgent(1, 101);
  assert.equal(hi.allowed, false);
  const lo = await client.checkAgent(1, 0, { minFeedback: 0 });
  assert.equal(lo.allowed, lo.agent.active);
});

test("feedback page shape", async () => {
  const f = await client.getFeedback(1, 0, 5);
  assert.ok(Array.isArray(f));
  for (const x of f) assert.ok(x.score >= 1 && x.score <= 100);
});
