---
name: xoxno-lending-soroban-nogo-2026-09
description: "XOXNO Lending (Immunefi ~$50k, Stellar Soroban, TVL ~$720k) — v1.0.1 named SC surface = executed NO-GO with kill-list (~70 hypotheses, 5 agents, exact-integer models); live items are documented availability dependencies bounded by a 1-minute governance timelock; watch P-16 (LP-leg tx-budget) and Reflector DEX factor"
metadata:
  node_type: memory
  type: project
  originSessionId: session_01GAy4kKaY6C67n6TzYXH2Xz
---

**XOXNO Lending** (github.com/XOXNO/rs-lending-xlm, Immunefi since 2026-09-18, Primacy of Impact, max ≈ $50k
UNVERIFIED — immunefi.com egress-blocked in the cloud container; TVL ≈ $719k via DefiLlama snippet). Named scope:
controller, pool, governance, position NFT, price aggregator, shared math. Dossier:
`methodology/targets/xoxno-lending-xlm-2026-09-29.md` (verdict register, 19 hypothesis classes + 4 availability
dependencies + 5 design observations). Models: `arsenal/alternate-implementations/xoxno-soroban-integer-models/`.

**Status 2026-09-29: NO-GO on the named SC surface at v1.0.1 (HEAD c50f25a == tag on contract code; on-chain
hash match not re-verified, RPC blocked).** Theft/insolvency classes died on executed guards or executed numeric
nulls at every sink (rounding ~1.6M dirty cases + 20 written hypotheses, liquidation 3,564 runs 0 violations,
credit-mode split 0/20k). Host-level guards do most of the work: soroban-env-host 28.0.2 forbids any re-entry
(frame.rs:1150-1180), invoker auth entries are exact + single-use + subtree-scoped, archived persistent entries
auto-restore or abort (never read as absent). Protocol-level: prices cached before every callback, fair-value LP
pricing on stored reserves, liquidator-favouring risk restamps gated at HF ≥ 1.05 on every caller path, owner
never stored (live `owner_of`), every cash credit = measured delta around its own transfer.

**What is alive (not payable as found):** (1) fail-closed valuation means any unpriceable supply leg blocks
liquidation/cleanup of that account — documented DoS.1, recoverable by owner `set_oracle` behind a 12-ledger
(~1 min) timelock; (2) Reflector Stellar-DEX factor keys (USTRY, CETES, AQUA + 4 LPs) fail on ≥5–10 % leg
disagreement and the DEX feed's manipulation resistance is undocumented (external premise OPEN → NOT READY);
(3) fixed sanity bands on accruing/FX RWA will be crossed by drift (advisory); (4) **P-16**: tx budget of a
max-position account with LP legs is unmeasured by the team (benches accept budget panics; stress.sh disclaims
LP costs) — measurement addendum in the dossier.

**Lessons:** (a) the Soroban host is a first-class guard source — read env-host source before generating
reentrancy/auth/TTL hypotheses, it kills whole classes in minutes; (b) on an LLM-audited + Certora'd fresh
protocol the ore is in what the benches structurally skip (LP nesting, deployed config bands), not in math;
(c) safety classifiers stop operational attack write-ups against live protocols — keep dossiers at
condition→mechanism→guard level and keep agents on that form from the first brief.

Related: [[feedback-audited-target-hunt-invariant-not-class]], [[feedback-default-posture-thief-not-fortress-prover]],
[[feedback-reachability-is-kill-gate-not-severity-modifier]].
