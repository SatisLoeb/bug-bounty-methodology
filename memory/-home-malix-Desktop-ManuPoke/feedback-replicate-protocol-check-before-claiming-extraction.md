---
name: feedback-replicate-protocol-check-before-claiming-extraction
description: "Before claiming an over-seizure/over-extraction from a raw internal-function output, value it the protocol's OWN way and replicate the actual acceptance check; treat an absurd magnitude as YOUR valuation bug."
metadata: 
  node_type: memory
  type: feedback
  originSessionId: cb645e11-8651-4234-a23c-d044f4563d96
---

When a raw internal function (e.g. calculatePartialLiquidation) returns amounts that look like a theft, DO NOT
claim it. The raw output is a proposal that a downstream guard validates. Reproduce the guard EXACTLY with the
protocol's own functions before concluding.

**Why:** on Ammalgam PartialLiquidations I hit THREE successive apparent over-seizures (10x, then 100x, then
1.23x) and each was MY test's artifact: (1) valued the seize at the CURRENT price 1:1 instead of the LIQUIDATION
price (a netX borrower liquidates when X is expensive) -> price inversion; (2) ignored the BORROW_L leg being
repaid -> incomplete valuation; (3) ran the slice on a position HEALTHY at the valuation price, so the protocol's
own check (calcHardPremiumInBips <= calcHardMaxPremiumInBips = convertLtvToPremium(sliceLTV)) returns maxAllowed=0
and REVERTS. The premium is LTV-scaled: deeper positions are allowed more premium by design; a healthy position
allows zero. Only replicating verifyHardLiquidation's exact math settled it.

**How to apply:** (a) a >2x "premium/extraction" magnitude is almost always a valuation-direction or missing-leg
bug in your harness -- sanity-check it as YOUR error first. (b) value every leg the protocol's way (getCheckLtvParams
+ calcDebtAndCollateral), at the price the protocol uses (inputParams sqrt range, not the liq price), including L
legs. (c) replicate the actual accept/revert condition, not an ad-hoc bound. (d) the input STATE must be
attack-reachable (liquidatable at the valuation price), else the guard trivially rejects and the result is
meaningless. Relates to [[feedback-model-manipulation-cost-before-crediting-twap-finding]] and
[[feedback-invariant-that-passes-is-not-a-finding]] -- all three: execute the real economic check, don't infer.
