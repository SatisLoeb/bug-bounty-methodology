---
name: project-perena-bankineco-intake
description: "Perena/Bankineco (Cantina $25k, Solana, CLOSED-SOURCE) — sourced as a solfork target 2026-07-21. The edge = post-audit DRIFT: the deployed program has un-audited junior-tranche + Kamino/Marginfi atomic-lending subsystems the 2 public audits never covered."
metadata:
  node_type: memory
  type: project
  originSessionId: 3c399e15-ef33-40ad-abe1-f8688fee64f0
---

**Perena / Bankineco** — Cantina bounty (public, live, Cantina-triaged), cap **$25k Crit / $10k High / $2.5k Med / $500 Low**,
$20 deposit, KYC+PoC, AI-no-PoC rejected, **82 findings submitted** (since Apr 6 2026). Sourced 2026-07-21 as the best
CLOSED-SOURCE Solana solfork fit on the operator's platforms (OOOSec=Jupiter/Meteora exhausted, HackenProof=mostly
Solidity/web + Zynk $5k public-source, Immunefi excluded). Dossier `~/Desktop/BUGS/perena-2026/INTAKE.md`.

- **Program (deployed, in-scope)**: `save8RQVPMWNTzU18t3GBvBkN9hT7jsGjiCQ28FpD9H` (Anchor, BPFLoaderUpgradeable, upgrade auth
  `7Tn58Jp…`, last slot 431427990). USD* mint `star9ag…`. Marginfi `MFv2hWf…`. IDL from anchor:idl PDA `Cikg8Qzg…`
  (32 ix / 6 accts / 27 types). CLOSED-SOURCE: only IDL + `@perena/bankineco-sdk` given; quineco org publishes only the
  Jupiter AMM `bankineco-amm-interface` + `fix`/`fixed-exp` (fixed-point libs) + SDKs, NOT the core program.
- Artifacts: bankineco.so (dumped), idl.json, audits/{frankcastle-perena.pdf, hashlock-full.pdf}, ref repos cloned.

**THE EDGE — post-audit DRIFT (the whole reason this is worth it despite 1 audit + 82 subs):** neither public audit covers
the deployed program's new subsystems.
- Frank Castle/Cantina "Perena PRIME" (Mar 2025, commit 43b08c2c) = a DIFFERENT older program (native-Solana stableswap
  usd_prime/usd_star/swap_in-out). N/A to Bankineco.
- Hashlock "Perena" (Oct 2025, commit 97b69ae) audits `programs/bankineco` but the SIMPLE version — grep of the audit text =
  ZERO tranche/junior/senior/kamino/marginfi/leverage/loss-absorption. Findings all on mint_w_yielding/burn_for_yielding/
  oracle/yield: H-01/H-02 decimals convert, H-03 metadata PDA, M-01 oracle staleness, M-02..06, L-01..08 (all Resolved = OOS).
- The DEPLOYED program adds, un-audited-in-public + in-scope + closed: (1) **junior/senior TRANCHES** (stake_junior,
  request/fulfill/instant_unstake_junior, TrancheState/Accounting/Config, leverage factor, loss absorption); (2) **atomic-lending
  Kamino+Marginfi** (init_marginfi_account, refresh_atomic_lending_accounting, apply_capital_loss, external/kamino+marginfi).

**Payable surface (unprivileged only; admin/manager-gated = OOS per "Privileged Access" exclusion):** mint_w_yielding_gen,
burn_for_yielding_gen, stake_junior, request/fulfill/instant_unstake_junior.

**OUTCOME (2026-07-21) — state-fork built + driven on the real bytecode. ONE finding, drafted, scope-fragile.**
Solfork state-fork stood up (fork/ dir: statefork clone of TrancheState hXfEYpB5 + BankState sM6P + VaultGenState 3bZ1 +
oracle/team PDAs + mints + junior_escrow=ATA(tranche,USD*) 3c1gpe; crafted attacker user + funded USD* ATA). Drove stake_junior +
instant_unstake_junior against real state. **Clean-in-scope self-contained veins = executed NULL (byte-compared):** (1) round-trip
stake→unstake CONSERVES (floor(value/sp)×sp + 1% early-fee, both protocol-favorable — provable, can't net a gain); (2) accrual
symmetric (stake & unstake both apply the optimistic stored-rate accrual — no stale-at-stake/fresh-at-exit asymmetry);
(3) CROSS-FUNCTION leverage coupling NULL — unstake payout BYTE-IDENTICAL under bank supply ×10 (junior% /10), so the exit is
self-contained in stored tranche state, no leverage manipulation via senior mint.
**The ONE real defect = loss-timing / stale share_price on instant_unstake_junior** (RE agent + my fork PoC): payout =
shares × STORED tranche.share_price@0x118, no live-backing recompute, no lending accounts on the ix, NO freshness gate (M-01's
oracle-staleness fix on mint/burn was never ported to the tranche unstake — the audited build had no tranche code). PoC EXECUTED:
same 102,281,258,368 shares pay 99,000 USD* pre-loss-booking vs 79,200 post-booking (share_price −20%) = **junior dodges ~19,800
USD* of a realized loss for a 1% fee (~20:1)**, socialized onto remaining stakers. cumulative_loss_absorbed ~$15k = losses real+recurring.
**SCOPE-FRAGILE (the honest caveat):** trigger = race the keeper booking (apply_capital_loss disc f9d91db637cc4a8a) on a realized
Kamino/Marginfi loss = Cantina MEV/front-running exclusion + third-party-loss source + design-cadence.

**FINAL (2026-07-21, after a rigorous operator-driven RE+drive campaign — the model of the discipline):** finding = REAL, **High**
(mapped to the PROGRAM'S OWN rubric — [[feedback-map-severity-to-program-rubric]] — their High = "manipulation of protocol state / core-
operation disruption", NO $ floor; an earlier Medium anchored on bounded-magnitude was a generic funds-at-risk model the operator corrected).
Program-driven on the state-fork of the deployed bytecode: (1) instant_unstake_junior pays shares×STORED share_price, byte-identical under
vault external/tvl −40% AND bank supply ×10 = decoupled from live vault value (Loopscale byte-compare on the CORRECT variable — an earlier
share_price−20% "decisive test" was CIRCULAR and the operator caught it). (2) Loss enters the tranche ONLY via apply_capital_loss
(auth-PATCHED drive per solfork step7/Correction2 — 0x55→0x05 @0x45a28, study-only: junior absorbs 100%, senior 0, vv drops by the loss;
senior price held 1.080987→1.080997). (3) refresh_atomic_lending_accounting does NOT book losses → window = admin apply-latency; reframed
in-report as OBSERVABLE STANDING STALENESS (readable on-chain), NOT a mempool race → dodges Cantina's standard "work-as-intended
sandwich/arb" MEV exclusion (no Perena-specific MEV/timing exclusion exists — scope lookup done). (4) **Branch (b) — can the senior realize
the markdown in the window? RESOLVED NO (verified, v6):** drove a SENIOR burn_for_yielding against external −40% → REVERTS `RoundingImpact`
(14015) @ burn_for_yielding.rs:229 at every size (15k & 5k); in the SAME state instant_unstake_junior SUCCEEDS (pays 99,011 USD*). So the
senior EXIT paths run the vault accounting sanity check and refuse a loss-pending vault; instant_unstake_junior is the ONE decoupled exit
that SKIPS that check = the tightened finding. Senior protected per-event; Critical only via AGGREGATE junior-exhaustion→senior-spill (stated,
bounded). Booking gated: losses_accepted (vault@483) + loss≤reserve (~55k) → per-event dodge ~3% of the 1.7M junior tranche.
**Report `REPORT-instant-unstake-stale-loss.md` FINALIZED + internally consistent** (operator ran SIX+ adversarial review passes, each caught
a real defect: circular byte-compare, window/fix contradiction, unsourced audit-scope claim, fee double-count, MEV-framing, mis-mapped tier,
and finally the senior-reprices-vs-stays-stale contradiction → all fixed; the misleading computed-but-reverted "1.077704" price REMOVED).
**v7 — ABOVE-RESERVE regime tested (operator: "reserve caps the BOOKING; did you test it caps the DODGE? if a loss >reserve → stuck bad-debt/freeze = Critical").** EXECUTED verdict = **High confirmed; Critical NOT proven but the bad-debt edge NOT cleanly refuted either (honest open edge); my own magnitude was inflated + a first "reserve=deployment" claim was WRONG and corrected.** Findings, robust across clones: (1) **max BOOKABLE loss = the vault `reserve@592`** (apply_capital_loss reverts CapitalLossExceedsReserve rs:47 above it; VaultLossNotAccepted rs:51 if losses_accepted@483=0). (2) **CAUTION — reserve ≠ deployment (I briefly claimed this, it's FALSE):** across clones reserve was BOTH > external_yielding_amount@584 (old clone 55,237 vs 47,608) AND < it (fresh clone 54,705 vs 78,814). So a loss in (reserve, external] would be REAL but UN-bookable; apply_capital_loss just reverts and I found no other booking path ⇒ the loss>reserve case = OPEN EDGE (would keep junior price stale LONGER = wider window, possible un-booked bad-debt) — flagged in report, NOT turned into a Critical claim (didn't execute a bad-debt/senior-spill artifact). (3) **senior protected (robust):** senior bank price FLAT every bookable booking (fresh clone 1.081048→1.081048; clean 1:1 absorption Senior 0 Junior=loss); PLUS the two senior exits I drove (burn_for_yielding+mint_w_yielding) REVERT RoundingImpact against a marked-down vault ⇒ senior can't realize the markdown. NO single-event freeze (escrow rebalance ~−37k vs 1.68M escrow). (4) **magnitude corrected DOWN:** v1 "19,800 dodge" used −20% share_price = ~360k loss, impossible; real max BOOKABLE loss (~53.7k on fresh clone) → junior share_price −2.96% → dodge ~$2.9k gross / ~$1.9k net on a 100k position. Report Step4/Impact/limits reframed to reproducible fresh-clone numbers; the 19,800 flagged as my own overstatement. Strongest-High framing folded (operator): exogenous Kamino/Marginfi loss IS the normal event the cascade exists to absorb ⇒ core-mechanism failure in its designed scenario ⇒ neutralizes "timing→Medium". Redemption-controls Critical-label CUT (operator Catch#2: even hedged it's the one reach a skeptic uses to doubt the rest; RoundingImpact=accounting-consistency guard, "redemption control" equivalence arguable) — KEPT the structural observation (junior = the one exit skipping the check the senior paths revert on), let the triager escalate. Precisions: "senior exit paths" scoped to the 2 driven; RoundingImpact = EFFECT not intent. **LESSON: don't infer a structural relation (reserve=deployment) from ONE clone — clone-drift falsified it; state clone-specific numbers as fork-measured + hold the structural claim only if it survives re-clone.** POC-RESULT.md v7, probe_reserve*.py/probe_final.py.
**SUBMITTED 2026-07-22 as Cantina finding #83** (title: "Stale share_price on junior instant-unstake lets an unprivileged staker escape unbooked capital losses"), Target asset=IDL, Impact=High + Likelihood=Medium → severity **High**. Post-submission: chain-of-custody comment = REPRO-COMMENT.md; 6-shot screenshot pack inline (01 provenance-sha256, 02 solscan, 03 cum_loss, fork-boot, 06 decoupling one-frame baseline+markdown→99000000000 invariant, 07 optional senior-flat). Was ready-to-submit; submission operator-gated (KYC + $20 deposit + PoC). **Cantina takes NO file attachments → self-contained repro packaged as a separate COMMENT: `~/Desktop/BUGS/perena-2026/REPRO-COMMENT.md`** (one `fork/repro.py`: fetch clones live state on the triager's own RPC + crafts throwaway-attacker token accts, persisted real stake_junior(100k)→~102.27e9 shares, simulate instant_unstake→`to user: 99000000000`, mutate-vault-40→relaunch→byte-identical payout=decoupling; optional prep-loss+auth-patch(0x45a28:0x55→0x05)+apply-loss shows Senior:0/junior-absorbs/senior-price-flat). VALIDATED end-to-end on the fork; OPSEC-clean (no RPC key, no local paths). **Cantina DOES allow inline photos** (confirmed by operator) → `~/Desktop/BUGS/perena-2026/submissions/SCREENSHOTS-GUIDE.md` (screenshot skill, 7 shots tiered, min-vital=4: 01 provenance-sha256 / 05 stored-price-exit / 06 decoupling-byte-identical=the finding / 02|03 independent explorer+RPC read; 07 senior-flat optional). LESSON: dropped a discriminator-grep shot — Anchor disc NOT stored contiguously in compiled sBPF (`disc in .so`=False, misleading); the program's own `Instruction: InstantUnstakeJunior` log is the real-handler proof. Artifacts: REPRO-COMMENT.md, fork/repro.py, fork/POC-RESULT.md (v1→v7), fork/ (statefork),
bankineco_authpatched.so. Helius RPC in fork/.env (.gitignored, masked, NOT here). LESSON: state-fork math-verdict discipline (mutate ONE
real input, byte-compare) catches circular PoCs; driving the REAL booking instructions (not hex-editing output states) separates a
measurement from an assertion; and the PAIRED artifact (senior-reverts / junior-succeeds in the SAME state) is what resolves a "does the
protected class leak?" branch cleanly. [[feedback-map-severity-to-program-rubric]] [[feedback-trigger-reachability-is-payability-gate]] [[feedback-read-both-or-clauses-in-exclusions]] [[feedback-invariant-that-passes-is-not-a-finding]].
