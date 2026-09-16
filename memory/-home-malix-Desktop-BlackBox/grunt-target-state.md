---
name: grunt-target-state
description: "3F Grunt (Cantina, $250k) — what round 1 closed with executed evidence, and the two leads still open"
metadata: 
  node_type: memory
  type: project
  originSessionId: 02e5b9fb-6981-4593-96d4-f509bd198ba9
  modified: 2026-08-07T02:01:31.942Z
---

3F Grunt, Cantina public bounty. Critical $250k / High $25k / Medium $2.5k, $50 deposit, KYC. Opened 2 Jun 2026, 75 findings already submitted. Worked 2026-08-06.
Local: `~/Desktop/BlackBox/grunt` (main @ v1.2.1 = 96a18e376e8f95bbb243a774609945749d3a0b3e). **It builds and tests run** — solc 0.8.34, cold build ~25s, `forge test --match-path ...`. Audit PDFs as text in /tmp/grunt-audits/ (re-extract from `audits/` with pdftotext -layout if gone).

**The key structural fact about this program:** the published out-of-scope list is, almost bullet for bullet, the list of findings Cantina (2026-05) and ChainSecurity (2026-04) already reported. The OOS is the audits' balance sheet, not a policy. Anything resembling it is dup or OOS. The only unmined ground is the ordinary permissionless user acting on healthy, correctly-configured components.
The one door the program leaves open, verbatim: in scope if an address "can be introduced without violating that operational assumption", or if a role "exceeds Facilitator-equivalent authority". **Authority escalation is in; authority use is out.**

**Closed with executed evidence (do not re-spend):**
- Lib128Fields / LibAllowance / TokenController 128-bit layer: all 11 raw `uint128()` casts are bounded upstream; `_mint` uses checked `.toUint128()`; `_toStored` rejects the unrepresentable band; `consume` preserves the infinite sentinel per field and its assembly `sub` is guarded by a prior check. Only three writers of the packed slots (`_mint`/`_burn`/`_transfer`), all paired, so sum(balances)==totalSupply holds; VaultController only reads.
- Facility intent/ERC-6909: intent ids monotone and never reused; DEPOSITING and RESOLVED provably disjoint; cross-intent drain blocked by `LibTokenBalances.sub` reverting, proven by executed probes; split-claim arbitrage returns exactly the bag.
- 6 agent-written Request invariants survive fuzzing (supply-matches-balances, no-free-money, asset conservation, PT/YT redemption-rate monotonicity, PT priority).
- **The convergent 3-agent lead is dead:** `FacilityFunds.commit()` snapshots only `_tokenIn` and `unlock()` only `_tokenOut`, so an output token arriving *during* commit would be permanently unclaimable — but no in-scope fund settles synchronously (USCC/Centrifuge/Pareto all return PROCESSING and keep output inside the fund), and ParetoFund explicitly reverts if the CDO routes to the instant-withdrawal path.
- `SyncAllocatorDeposit`'s unvalidated `allocator` param is covered verbatim by the OOS bullet on script payload validation. Dead on arrival.

**ROUND 2 RESULT (the omitted-selector fuzz + post-audit code):**
The devs' uncovered op family is now genuinely fuzzed — ~120k calls across 17 invariants, revert rates 0.1–0.5%, harnesses at `test/poc/inv{1,2,3,4}_*.t.sol`. Global per-token solvency, cross-intent isolation on a shared PositionManager, and snapshot-delta integrity all HOLD. `SyncAllocatorDeposit` (the only never-audited file) is clean over a 486-combo grid / 180 end-to-end cycles.

ONE REAL DEFECT, reproducible, unprivileged trigger — `test/poc/pocFeeOnLoss.t.sol`:
the levered-slice performance fee (post-audit commit 88ac439) is minted on a **strict same-period NAV loss**. A permissionless Morpho `liquidate` by a role-less address removes collateral and debt at LIF:1 while the basis `mulDivUp(lastDebt, currentCollat, lastCollat) - currentDebt` prices the removal at LTV_prev:1, contributing `+R*(1 - LTV_prev*LIF) > 0`. Nothing in `_pendingFees` ever compares `totalAssets_` to `_lastTotalAssets`. Measured: NAV 3000→1153 (LPs −61.6%), yet 161.45 assets = **14% of remaining NAV** moved to the fee recipient; **35%** at MAX_PERFORMANCE_FEE. Isolated by a controlled experiment: the property dies in 192 calls with `liquidate` in the selector set and survives 16,384 calls without it.
**Scope status: arguable, not clean.** Two OOS bullets plausibly fence it ("performance-fee treatment of losses/recoveries is accepted"; "the fee recipient receiving a cut of donated debt relief"). The counter-argument nobody has put to the program: those bullets predate this basis — the OLD NAV-variation basis structurally cannot mint a fee when NAV falls, so the accepted-loss-behaviour carve-out was written about a fee model without this failure mode. Best case Medium ($2.5k). **Ask Cantina triage the scope question before burning a submission slot.**
Killed and NOT worth reviving: the `revertDeposit` solvency-guard finding — its loss quantification rests on `req.outstanding()`, a field that exists only in the agent's own HonestRequest mock, not in the deployed `Request`.

**SHIPPED 2026-08-07** as High (Impact High × Likelihood Medium), Cantina template (Summary / Finding Description / Impact / Likelihood / PoC / Recommendation), chill voice, 298 lines. Package: report + `POC-BUNDLE.md` (single doc for the comment field, since Cantina takes no attachments) + `SCREENSHOTS-GUIDE.md` + three `.sol`.

Two things that generalise beyond this target:
- **A renamed artifact must be renamed everywhere, including its own test name.** `test_poc_triggeredByOrdinaryLpFlow` kept asserting a claim the prose had already retracted (no unprivileged LP triggers the accrual). Fixed by renaming to `test_poc_mintFiresOnRoutinePmOperation` *and disclosing the rename with its reason* rather than silently. Renaming a Solidity test changes its selector, which shifts the dispatch table, which changes every other test's gas and the alphabetical run order, so the pasted output has to be recaptured whole.
- **When you disclose an honest fact that feeds an OOS clause, name the clause yourself and answer it.** Here: role-gating up to FACILITATOR_ROLE feeds "impacts requiring access to privileged addresses". The answer that works is the inversion: that clause targets attacks where the *attacker* must be privileged; here the privileged call is the victim path, not the attack path.

**SUBMISSION PACKAGE (rewritten 2026-08-07):** `~/Desktop/BlackBox/submissions/grunt/` — report + 3 PoCs, hashes matching the repo copies under `grunt/test/poc/`.
Reproduce: `forge test --match-path "test/poc/pocFeeOnLoss.t.sol" -vv` (5 tests — one is the fixture's inherited `test_empty`); bounds the same way; controlled experiment needs `rm -rf cache/invariant && FOUNDRY_PROFILE=full forge test --match-path "test/poc/pocFeeOnLoss.invariant.t.sol" --fuzz-seed 0x3f`. **Foundry persists invariant counterexamples — without purging the cache it replays stored failures as `runs: 1, calls: 1` and the control appears to fail.**

A 5-agent adversarial fact-check found 10 fatal / 22 material defects in the first draft; I re-verified each load-bearing one by hand and they held. Errors that were mine, worth not repeating:
- I asserted no review covered the new basis, having myself established the day before that the Cantina FeeReview covered PR 190. The PDF sits in the target's own `audits/`. Never let a drafted argument contradict a finding already in the transcript.
- "The old basis could not charge on a loss" — falsified by Cantina 3.2.6 Path 4 (clipped NAV, 50→40 real loss, fee minted), a finding I was quoting from. The true, narrower claim: it could not charge when *reported* `totalAssets_` fell.
- "No privileged actor has to choose it" — false; every accrual path is FACILITATOR/owner/rebalancer-gated and `FacilityLP` has zero references to the PositionManager. The surviving framing is that no role-holder *chooses* the mint or benefits from it.
- I pasted forge output that was stale by one edit (gas +22 on three tests, `5 passed` not 4, a dropped log line). Never paste test output that predates the last edit to the file.

Measured bounds (mine, in `pocFeeOnLoss.bounds.t.sol`): a 20% tranche mints **zero** (the price move drives the basis to −980 first; the repayment must clear it, >half the debt here); a full liquidation sets `lastDebt = 0` and the sentinel disarms the next accrual; recurrence needs a second decline below ~65% of the original price, not another 14%.

**Still open, in priority order:**
1. **The devs' own `Facility.invariant.t.sol` handler registers ZERO fund/PM/request selectors** — no commit/unlock/recover/pull/repay/depositManager/withdrawManager/burnManager. The entire facilitator-op family is outside their invariant coverage. Build a handler wiring MockFund + MockRequest + PM helpers into the fuzzed selector set and run it against global per-token solvency with **two intents sharing one PositionManager**. This is the single highest-value untested thing on the target.
2. **Post-audit code.** Only three commits touched `src/` after the audits: `96a18e3` (2026-06-30, SyncAllocatorDeposit + IMorphoAllocator — no audit covers it), `88ac439` (2026-05-28, levered-slice performance fee across **9 PositionManager files** — the Cantina FeeReview is dated 2026-05-27, the day *before*, so it may not cover the merged version), `9f9ae93` (Pareto mock pricing reads). The fee commit is the biggest unaudited semantic change in scope.

Round-2 harnesses moved out of `test/poc/` to `~/Desktop/BlackBox/grunt-harnesses/` (268K, 7 files: inv1-4, poc196_sync_allocator, pocX_packed128_boundaries, pocX_request_invariant). They need `PositionManagerBase.t.sol` / the facility fixtures, so copy them back into `grunt/test/poc/` to run them. `test/poc/` now holds only the four `pocFeeOnLoss*` submission artifacts. The invariant file needs `--match-path` to run — foundry.toml's `no_match_test = "^invariant"` silently excludes it by default; a "no counterexample" from a default run means nothing.

See [[recevability-gate-before-poc]].
