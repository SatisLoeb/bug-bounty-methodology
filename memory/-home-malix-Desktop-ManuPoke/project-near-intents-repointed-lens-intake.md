---
name: project-near-intents-repointed-lens-intake
description: NEAR Intents (defuse Verifier) HackenProof $500k — top pick of the re-pointed oracle/replay lens sourcing. First-move recon done; flagged cross-standard/WebAuthn replay vein REFUTING at core layers. Residual drift worklist inside. NOT exhausted.
metadata: 
  node_type: memory
  type: project
  originSessionId: 91ada56b-1372-4a8e-9cae-4aa535de28a0
---

Top pick from the re-pointed replay-lens sourcing ([[feedback-oracle-replay-refute-first-reflex-fix]], 2026-07-23). HackenProof live bounty, up to $500k. Repo github.com/near/intents, `contracts/defuse`. Rank #2 was **Nado** (HackenProof $500k, oracle-freeread, sequencer-bundled Chaos oracle staleness/gap on 24/7 WTI/Brent commodity perps — the built `oracle-consumer-freeread.t.sol` harness applies directly; ~67 subs/8mo = genuinely low-competition; **intake gate: pull the pre-mainnet audit PDF first**).

**Flagged vein:** cross-standard / EIP-712-field-omission replay across the uniform `MultiPayload` hashing — 7 signing-standard adapters (nep413, erc191, tip191, raw_ed25519, webauthn, ton_connect, sep53) in `contracts/defuse/core/src/payload/`, dispatched by `multi.rs`. Thesis was post-audit DRIFT: the multi-standard adapters sit outside the Dec-2024 Hacken review that owns the single-standard core.

**First-move recon (cheap source read, no fork) — flagged vein REFUTING at checked layers:**
- `verifying_contract` is a field INSIDE `DefusePayload` (payload/mod.rs:27) and checked `!= self.state.verifying_contract()` at `engine/mod.rs:59` → no cross-deployment/cross-contract replay.
- Nonce committed per-account (`commit_nonce` state.rs:125, `is_nonce_used`) → no intra-contract replay.
- Per-standard hash separation (multi.rs:62-79): each arm uses its own hash fn (NEP-413 SHA-256 vs ERC-191 Keccak256 w/ prefix) → a signed blob can't be re-tagged to another `standard`.
- **WebAuthn challenge binding HOLDS**: adapter passes `self.hash()` = SHA256(payload) as the challenge; the crate enforces `c.challenge != challenge → false` at `crates/signatures/webauthn/src/lib.rs:71`. The passkey assertion is bound to the exact DefusePayload.

**Residual UN-checked drift (where a lead could still live — do NOT write "fortress" yet, First-Maxim):**
1. **pubkey → signer_id authz binding for NAMED accounts** — `verify()` returns the recovered PublicKey; tests assert `to_implicit_account_id() == signer_id` (implicit path). Confirm how a recovered key is bound to a *named* signer_id's registered keys in the engine (a gap = forge intent for a victim account). HIGHEST-VALUE next read.
2. The 4 unread adapters (tip191/sep53/ton_connect/raw) each fold `verifying_contract` into their signed bytes uniformly (nep413 maps it via `recipient` @nep413.rs:47 — verify the others).
3. Nonce/GC interaction (`garbage_collector.rs:40` drops nonces past deadline; deadline check should already reject expired payloads — confirm no GC'd-nonce replay).
4. The `intents` execution layer (token_diff solvency / balance conservation) — a different (extract) lens, not the signature layer.

**Decision point:** the flagged replay crown-jewel is cheaply refuting → either continue into residual #1 (pubkey→signer_id, one read to a clean go/no-go) OR pivot to **Nado** where the just-built oracle harness applies to a fresher, less-audited surface. Excluded by gate: K2 (C4 closed/saturated), 0xMarkets (426-sub contest), 0x Protocol/Coinbase-SW/USDT0/LayerZero (fortresses), NEAR-Intents-SDK (157 subs). Warm alternate from corpus INCLUDE-LIST: Jupiter JupUSD RedStone-$1-vs-oracle (fits oracle-freeread).
