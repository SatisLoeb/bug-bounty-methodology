---
name: grunt-fee-on-loss-verified-ready
description: "3F grunt (Cantina) perf-fee-on-loss finding: verified over 4 rounds, artifacts synced, NOT yet submitted as of 2026-08-07"
metadata: 
  node_type: memory
  type: project
  originSessionId: 8e9825ed-c199-4a09-82f6-dd5dbe4fdeea
  modified: 2026-08-07T01:57:29.899Z
---

**3FLabs/grunt, Cantina bug bounty. Finding: `_pendingFees()` mints a positive PERFORMANCE fee over a
period of monotonic NAV decline.** Root cause = the levered-slice basis from `88ac439` (PR #190,
2026-05-28) deleted the `totalAssets_ > _lastTotalAssets` precondition; the basis prices the collateral
leg of a liquidation at `LTV_prev` and the debt leg at 1:1, so `Δbasis = R(1 - LTV_prev·LIF) > 0`.

**Status 2026-08-08: CLOSED as DUPLICATE, $0, submission fee refunded.** Triage had passed technical
review; client review closed it on two independent grounds, a pre-existing report on the same accounting
behaviour AND the scope bullet accepting performance-fee treatment of losses. The report had pre-committed
in writing to withdrawing on exactly this condition, so it was accepted without dispute. Nothing technical
was refuted. Post-mortem in [[feedback-oos-bullet-describing-your-finding-is-its-tombstone]].

**Prior status (kept for the record): SUBMITTED, Cantina triage PASSED, client review.**
Triage confirmed the mechanism, the PR#190 gate removal, and that the invariant control isolates the
liquidation. Severity left open ("subject to the project's assessment"); report commits Medium x Medium.
Triage surfaced the best not-intended artifact in the repo, which I verified: `test/manager/
PositionManagerLiquidation.t.sol:63-64` comments "liquidation has a cost due to incentive" then
`assertLt(totalAssetsAfter, totalAssetsBefore)`, and :72 `assertLt(shareValueAfter, shareValueBefore)`.
3F's own suite asserts a liquidation is a LOSS on the same event the fee reads as performance. HOLD it:
the triager already put it in the thread, so do NOT re-post. Deploy only if the client claims "intended".
Report `~/Desktop/BlackBox/submissions/grunt/3f-grunt-perf-fee-on-loss.md`; 4 test files in repo
`~/Desktop/BlackBox/grunt/test/poc/pocFeeOnLoss{,.bounds,.invariant,.preliquidate}.t.sol`, mirrored to
`submissions/grunt/` and to gist `9072cb370dcb21127e9a25aeb014c8ea` (byte-identical, `.sol` carry an
extra `// path:` line 1). 16/16 tests green.

**Everything verified by execution:** all logged numbers reproduce to the wei; every scope-text and
audit quote is verbatim; source line refs 130-143/158/160/162, `FacilityPositionManager.sol:35/74/110`,
fixture `:167/:181-186/:281` all exact. The 7 `_accrueFees()` call sites are fully enumerated and all
role-gated (no ungated path). Fixture uses the REAL `lib/morpho-blue/src/Morpho.sol`; only oracle/IRM/
ERC20 are that repo's own mocks. Executed disconfirmer: restoring the deleted guard drives all 4 defect
tests to 0, makes the liquidate-inclusive invariant PASS 256/16384/0, and leaves the legitimate-gain fee
bit-identical (`108808290155440414507`).

**Two things I derived that the report now carries:** (a) absent an unbracketed flow and with a fixed
module set, `basis > 0` already implies NAV rose, so the proposed gate is analytically free; (b) the
"preLiquidate cannot do this" claim was FALSE as originally written -- `LTV_prev` is
`lastDebt/(lastTotalAssets+lastDebt)`, the live ratio frozen at the last accrual, NOT the PM target or
`safeLtv`, so an accrual landing while the sleeve is above the market LLTV records `LTV_prev = 87.5%`
and preLiquidate mints `243243243243243243243` shares on NAV `1000e18 -> 820e18`. Same fix kills it.

**THE ONE REMAINING GAP, unclosed across 4 rounds:** no on-chain readback. No deployed PositionManager
with `performanceFee != 0` / `feeRecipient != 0` was ever sourced, so the $ framing rests on test config
(2000 bps chosen, 5000 = `MAX_PERFORMANCE_FEE`). The program indexes reward on "report quality,
completeness, and severity/exploitability" -- this is the only remaining lever. A `cast call` on
`feeData()` + `lastDebt()` of a live PM would transform the Impact section. Do this before submitting.

Prior ruling on this target still holds: findings present in the 4 in-repo audit PDFs are known/OOS
including re-derivations, so hunt only post-audit code and novel compositions. See
[[grunt-3flabs-intake]] and [[feedback-a-known-issue-note-is-a-dup-fossil]].
