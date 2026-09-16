---
name: gmtrade-gmx-solana-deployed-build-baseline
description: "GMTrade (GMX-Solana) Immunefi — deployed builds pinned to OLD audited commits; July-2026 \"fresh surface\" is NOT deployed; RE-SOURCE verdict"
metadata: 
  node_type: memory
  type: project
  originSessionId: 7937d3a0-c213-40ba-ab49-f53e00180aee
  modified: 2026-07-30T10:37:06.010Z
---

Immunefi **GMTrade** (gmsol-labs/gmx-solana), worked 2026-07-30. Scope = store + treasury + **liquidity-provider** (Timelock/Competition dropped vs the old C4 scope; LP added and has only **1** audit). Workspace `~/Desktop/BUGS/gmtrade-gmx-solana-audit/PROGRESS.md`; prior C4-era recon in `~/Desktop/BUGS/gmx-solana-recon/`.

**The decisive fact — deployed ≠ main.** On-chain hashes computed from ProgramData (skip 45-byte header → strip trailing zeros → sha256) all match an independent osec rebuild:
- store `6d1cfe84`, deployed **2026-03-19** (= the Zenith 2026-03-19 audited commit ⇒ **zero post-audit drift on mainnet**)
- treasury `7618169d`, deployed **2025-10-20**
- liquidity-provider `6a5e6b24`, deployed **2026-02-11**

⇒ The 460-line July-2026 market-status feature I first targeted as "fresh unaudited surface" is **NOT DEPLOYED** (zero funds at risk). LP + treasury have **zero** source diff vs deployed, so that analysis *was* against live code guarding **$17.46M** (3,441 LP positions, `claim_enabled=true`, GT $1.92, 500 GtBanks).

**Feature flags on the deployed store:** `multi-store` **OFF, proven by execution** — `simulateTransaction initialize(key="x")` → `NonDefaultStore` code 6000 at `store.rs:73`; so exactly one Store (`CTDLvGG…`) can ever exist. `mock` verifier **OFF** (mock PID absent from the 4.23MB binary; would be mandatory in the static `IDS` array). `devnet` immaterial (fails closed).

**Verdict: RE-SOURCE.** Every in-scope untrusted surface walked and null: market-status gate is strictly additive; `set_closed` has one order-keeper-only writer; LP `position_vault` seed-bound in both stake and unstake and `position` is `init` not `init_if_needed`; LP reward-window asymmetry is real but the live gradient is monotonically increasing so it penalises the claimer; GT-saturation freeze is structurally real but unreachable by 1.4e7×; treasury is 100% role-gated except `complete_gt_exchange`, whose pro-rata accounting decrements in lockstep. Keepers/admins are **trusted per scope**, which is what collapses the untrusted surface.

Re-open on: any new deploy (especially the one shipping market-status), `multi-store` enabled, LP gradient reconfigured decreasing, or `EnableMarketClosedParams` turned on. See [[feedback-scope-asset-dates-are-not-build-dates]].
