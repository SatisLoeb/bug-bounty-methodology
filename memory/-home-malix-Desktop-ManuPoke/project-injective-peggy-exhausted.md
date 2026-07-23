---
name: project-injective-peggy-exhausted
description: "Injective Peggy bridge (Cantina bounty) is exhausted for a solo finding — C4-saturated + deployed==audited; don't re-audit from scratch."
metadata: 
  node_type: memory
  type: project
  originSessionId: 18f37fbd-b9f1-4054-a4dd-7c210c6f1e52
---

Injective **Peggy** Ethereum bridge (Cantina bounty asset; proxy `0xF955C57f9EA9Dc8781965FEaE0b6A2acE2BAD6f3`,
active impl `0x100DCB8B78c608D148cb207ac3875935dFe6abdc`, verified Solidity 0.8.0) was fully worked in July 2026
and judged **exhausted for a solo payable finding**:

- **Deployed == audited, byte-identical.** The deployed verified source matches the Code4rena snapshot
  `code-423n4/2026-02-injective` (`peggo/solidity/contracts/Peggy.sol`) with zero drift. That C4 contest
  (25 Feb–17 Mar 2026, $105.5k) covered Peggy.sol + the Cosmos peggy module + peggo orchestrator; the report
  is **sealed/unpublished** (live-code contest) → 12 High/48 Medium findings are **un-dedupable**.
- **power vein** (money-out `submitBatch`/`updateValset`): gate holds, measured — 4 executed reverts on a
  mainnet fork from an unprivileged EOA + reconstructed the real 45-validator set (checkpoint verified,
  no address(0), no dup). Threshold = 2/3·2³².
- **C3 fee-on-transfer** (`sendToInjective` emits requested `_amount`, not balance delta): real in-code but
  DEAD — sponsor known-issue #6 + Zellic V12-LOW; no attacker profit (round-trip = −A·f); loss lands in the
  Cosmos module (Vendor/OOS).
- **C1/C2/C4** (updateValset no new-set power check; ecrecover(0)/address(0); signer dedup): un-fenced by
  visible coverage but payable only if the **Cosmos peggy module (Vendor/OOS)** emits a degenerate valset;
  saturated by the sealed C4.

Key scope rule that kills most of it: Cantina asset = the **Ethereum contract**; the Cosmos-SDK peggy module
is **vendor-excluded**, and *production is source of truth* (Production Reachability Requirement).

Artefacts: `/home/malix/Desktop/BUGS/injective-peggy/` (POWER-RESULT, EXTRACT-RESULT, C4-RECON, DRIFT-RESULT).
Fresh surface on the same program: `InjectiveLabs/swap-contract` (CosmWasm/Rust — needs Rust tooling, not
[[project-nuke-static-barrage-skill]]); RFQ contract not yet in scope. **Verified first-party (don't trust
agents): the DEPLOYED Helix swap is code_id 67 `inj1psk3468yr9teahgz73amwvpfjehnhczvkrhhqx`, sha256-confirmed
= an OLD build (`injective-math 0.1.17`, `cosmwasm-std 1.2.5`, cw2 hardcoded-leftover "atomic-order-example
0.1.0", NEVER migrated) = the repo's ~2023 helix-converter era, NOT the v1.1.2 HEAD. Cantina "production is
source of truth" ⇒ hunt the 0.1.17-era code, not v1.1.2. Proven to lack the v1.0.1 (Feb-2024) multi-hop rounding
fix; the value-relevant Aug-2023 fix `1c6368d` presence needs wasm decompile. Impact ceiling ~$35k (182 INJ +
$32k USDT). Artefacts in `/home/malix/Desktop/BUGS/injective-swap/` (SWAP-VERIFICATION.md, TARGET-DOSSIER.md,
EXTRACT-SWAP-RESULT.md). **/extract CLOSED = NULL:** the real vein (shape the orderbook → bias
`estimate_swap_result` → drain support funds) is killed by SPREAD/manipulation-cost — attacker pays the spread
on both legs (shape book + fill against own orders) > the ~$35k extractable. Operator already proved this pattern
on twin targets (`injective-fresh2026-audit/analysis/S4-recon.md` "attacker pays the spread to move VWAP";
`ipor-protocol-audit/KILLS.md` both-sides-cancel net -fees). Apply [[feedback-model-manipulation-cost-before-crediting-twap-finding]]
FIRST on any orderbook/AMM extract. Note: `FPDecimal` is SIGNED (subtractions go negative, not underflow-revert)
— a real footgun class but the negative paths here revert at min_output. Injective terrain is heavily worked by
the operator (landed Cantina #345 Medium via seam-composition per `MANIFEST-injective-funding-hunt.md`;
`injective-untouched-2026-07-01` has ranked untouched candidates e.g. insurance-fund surplus). See [[feedback-model-manipulation-cost-before-crediting-twap-finding]] discipline (execute the cost, don't credit the gate-opening).

## Re-pointed oracle/replay lens verdict (2026-07-23) — EXHAUSTED, one parked WATCH item
Re-checked Injective under the re-pointed oracle-freeread lens ([[feedback-oracle-replay-refute-first-reflex-fix]]).
Result: **no fresh ground — and it VALIDATES the remedy.** The lens's crown jewel (cost-free staleness-consumption
at the liquidation read) was ALREADY found in `injective-core-v120-audit/WEEK4-oracle-liquidation-HANDTRACE.md`
(`GetProviderPrice provider_oracle.go:227` returns stored Price with NO age-check at the liquidation read) AND
correctly killed in `WEEK4-v119-liquidations-VERDICT.md` on **reachability, not a manipulation-cost category error**
(3 legs: no attacker-controlled stale primitive [relayers IsStorkPublisher/IsPriceFeedRelayer-gated = OOS outage];
staleness symmetric, direction not attacker-selectable; eligibility+execution read the SAME markPrice → only
genuinely-underwater positions liquidate). All 8 liquidation candidates KILLED, loss=$0, FORTRESS. The prior work
was ALREADY lens-correct → the lens fix helps un-worked targets, not ones already done right.
**WATCH TRIGGER (the ONE parked revival vein):** WEEK4-VERDICT line 44 flagged that a "consumer-A-fresh-vs-
consumer-B-stale on same market" asymmetry is the only thing that turns the staleness gap real — absent in v1.19.0.
The candidate second consumer = the **EVM oracle precompile 0x67**, which is **OOS/not-live on mainnet** (returns
bare `0x`, v1.20.0-only per `SCOPE-REALITY-v119-vs-v120.md`). ⇒ **RE-ENGAGE Injective oracle ONLY when v1.20.0
deploys to mainnet with 0x67 live**, then check whether 0x67's oracle read path diverges in freshness/scale from
the liquidation's `GetDerivativeMarketPrice` (the consumer-asymmetry → unfair-liquidation margin theft, lens-perfect
DRIFT vein, ~1-day bounded). Until then: NO-GO. Nado (fresh, oracle harness applies) > Injective now.
