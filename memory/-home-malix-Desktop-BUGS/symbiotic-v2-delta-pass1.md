---
name: symbiotic-v2-delta-pass1
description: Symbiotic V2+adapter delta — Pass-1 AND Pass-3 mirror COMPLETE; earned-null on Crit/High, 2 Medium candidates held; resume = operator submit-decision only
metadata: 
  node_type: memory
  type: project
  originSessionId: 123dd578-164e-4675-8beb-aa21faeef483
---

Symbiotic V2 + adapter DELTA — disciplined re-open of the target closed 2026-06-29 (v1 core @ 3b6add2 = earned fortress-null, see [[symbiotic-cantina-fortress-null]]). Platform Cantina $500K (Crit $100K-$500K / High $50K-$100K / Med $10K), KYC. **v1 core = earned-null, EXCLUDED.** Workspace `~/Desktop/BUGS/symbiotic-v2-delta-audit/`, clone `~/Desktop/BUGS/symbiotic-v2-delta/src/core` @ 327c005.

**THE SEAM:** VaultV2 breaks the v1 "internal-checkpoints-never-balanceOf" invariant — `getAccrueInterest: newTotalAssets = freeAssets() + Σ adapter.totalAssets()`, adapters read EXTERNAL value (Aave aToken, Morpho/Euler share, RWA-oracle NAV).

**PASS-1 (18-agent fan-out + solo, 2026-07-05):** 0 payable survivors on the AUDITED core (VaultV2/UniversalDelegator/WithdrawalQueue/base-adapters). Virtual-shares defend donation; adapters monotone; queue band-locked; DoS-Low only.

**PASS-3 MIRROR-INVARIANT (2026-07-05, wf_ae1f9609-1ba + FULL solo hand-coverage) — COMPLETE:**
- **DUP-GATE REFRAME:** `pdftotext` across all 3 V2 audits → the ll-adapter RWA layer (LiquidLaneAdapter + Settlement/Cutoff/Async bases + 75 accounts + 6 oracles) = **0 audit mentions = UNAUDITED.** Fresh surface = the RWA redemption layer, not the audited core.
- **VERDICT: no Critical/High fund-theft.** 3 defenses kill the untrusted-atomic share-price-inflation Critical: (1) oracle `[MIN,MAX]` immutable clamp (exceed=revert not exploit; within-band donation-costly/net-negative); (2) `VaultV2._withdraw` reverts on phantom value (extraction needs a LIQUID sibling to fund exit); (3) most issuers value conservatively (OpenEden previewRedeem, Makina min(live,quote), Async held≈pending). The optimistic `max()` is confined to the cutoff-settlement family.
- **2 Medium candidates investigated — both fail to reach payable:**
  - **F-1 REFUTED by neutral executed PoC (operator required unbiased PoC).** Hypothesis: CutoffMidasAccount round-walk `MidasAccount.sol:286-296` (`getRoundData(--roundId)`) bricks totalAssets() (round-0 revert / gas / phase-cross). REAL mGLOBAL aggregator (`0x4c82…cf6F`) probed on-chain: FLAT roundIds (latest=3, NO phases → phase-leg moot), sparse monthly rounds, oldest round r1 @ Apr-6-2026 PREDATES the minimum cohort cutoff INITIAL_CUTOFF=Jul-26-2026 → walk ALWAYS terminates at round ≥1, NEVER round 0 → no brick; sparse feed → no gas DoS. mGLOBAL is the ONLY CutoffMidas token. Round-walk stays a code-quality fragility (ignores in-repo phase-safe `ChainlinkPriceFeed.getRoundDataAt`; would brick only under a phase-encoded or late-deployed feed that doesn't currently exist) = Low/informational, not payable. Detail: `findings/F1-REFUTED-neutral-poc.md`. Workflow agent's "Medium firm" was WRONG — [[feedback-workflow-agents-coverage-not-verdict]].
  - **F-2 contestable Medium (NOT submitted):** RWA settlement over-credit — Settlement/Asseto/Securitize credit `max(received, frozen cutoffValue)` to the write-off cliff; on an external RWA haircut an informed depositor exits at inflated price (liquid sibling funds it). External-event-contingent + design-intent-defensible = high dismissal risk. Held.
- Full detail: `symbiotic-v2-delta-audit/PASS-3-SYNTHESIS.md` (+ PASS-3-IMPACT-LEG, PASS-3-ORACLE-SOLO, findings/F1-REFUTED-neutral-poc.md, findings/CANDIDATE-settlement-overcredit.md).

**STATUS: CLOSED earned-null on payable Crit/High/Medium (2026-07-05).** Pass-1 core-null + Pass-3 ll-layer: value-conservation well-defended, F-1 refuted by neutral PoC, F-2 too contestable. The neutral-PoC discipline (Standing Order #1) prevented a false-positive F-1 submission. Re-open ONLY on: a new commit, a NEW CutoffMidas token wired to a phase-encoded/late-deployed feed (makes F-1 live), or an authed/off-chain seam. Live EV is elsewhere (target diet).
