---
name: project-flare-fassets-executed-null
description: "Flare FAssets FXRP proof/mint crown-jewel = near-fortress, EXECUTED-NULL. xsurface-prioritize GO → xseam swept. RE-SOURCE."
metadata: 
  node_type: memory
  type: project
  originSessionId: 3c399e15-ef33-40ad-abe1-f8688fee64f0
---

Flare Network **FAssets FXRP** (Immunefi-style, Primacy-of-Impact) — collateralized XRP↔Flare
minting bridge, ~55 diamond facets, FDC-attestation-proof gated. Scope 23-Jul-2026. EVM verified
(github.com/flare-foundation). Clone: ~/Desktop/BUGS/flare-2026/fassets.

**Chain validated end-to-end on a real target:** `xsurface-prioritize` (GO + alloc to P-01 mint
proof-consumption / P-02 false redemption-default) → `xseam` (invariant seam mapped, pierced,
near-fortress). Both skills created THIS session; this was their first live run.

**Crown-jewel invariant** (xseam): "each minted FXRP backed by real locked XRP; each XRPL payment
proof consumed EXACTLY ONCE for its RIGHT purpose." V = `PaymentConfirmations` dedup registry +
agent underlying backing + `totalReservedCollateralAMG` capacity accumulator.

## Every theft-path KILLED with an executed artifact (greps + line-exact reads):
- **Proof dedup** (`library/data/PaymentConfirmations.sol`): `_recordPaymentVerification` reverts
  `PaymentAlreadyConfirmed`; called on EVERY consumer. Two namespaces (transactionId vs
  keccak256(sourceAddressHash,transactionId)) both covered.
- **Cross-purpose** (redemption-ref → direct-mint): EXPLICIT guard `ForbiddenPaymentReference` in
  `DirectMintingFacet._validateTagAndMemoData` (comment: "could be used to steal agents' core vault
  deposits") + **dev-tested** (14-DirectMinting.ts t.368/377/359).
- **False redemption-default** (`RedemptionDefaultsFacet`): binding reference+destinationAddressHash
  +amount+block-window (L64-73); soundness of the FDC non-payment proof = OOS (attestation layer).
- **DirectMinting delay-replay**: dev-tested (t.828/852/875) + gated (delayedMintings +
  requireIncomingPaymentUnconfirmed + rate-limiter). On DELAY the fn RETURNS before confirm (line ~138).
- **Shared capacity accumulator `totalReservedCollateralAMG`** (the last dig, operator-requested
  "fuzz" → answered with exhaustive writer-enumeration, STRONGER than a fuzz for an accumulator):
  exactly **4 writers, 2 balanced reserve/release pairs**. Normal-minting pair
  (`CollateralReservationsFacet:151 +=` / `Minting.sol:62 -=`): the release RECOMPUTES
  `reservationAMG = valueAMG + poolFee(reservationPoolFeeShare)` but the pool-fee-share is
  round-tripped via an offset — reserve stores `cr.poolFeeShareBIPS = agent.poolFeeShareBIPS + 1`
  (`CollateralReservationsFacet:99`), release reads `stored>0 ? stored-1 : LIVE` (`Minting.sol:117`).
  The `+1` makes `==0` impossible for any current CRT → release ALWAYS reads the frozen reserve-time
  share → **zero drift**. The `==0` live-read branch is legacy-transient-dead (pre-upgrade CRTs only,
  all purged within the short reservation window, none creatable now). DirectMinting pair
  (`176 +=` / `185 -=`): same `receivedAmount` from same proof both ends → zero drift. No out-of-band
  release (grep: no cancel/reclaim/refund path). → shared-var provably balanced.

## KNOWN_ISSUES (5, all OOS, DUP-dead): liquidation no-slippage, factory-spoofing, Conversion-rounding
collateralRatioBIPS reset, work-address frontrun, CoreVaultManager triggerInstructions gas.

**VERDICT: near-fortress on the crown-jewel proof/mint seam, EXECUTED-NULL. RE-SOURCE.** Dev-conscious
(explicit guards naming the exact attacks + exhaustive 1969-line adversarial test harness). Residual =
thin. Don't re-audit FXRP core. If returning to Flare: the UNTESTED periphery (Smart Accounts ~20
facets, CoreVaultManager newest subsystem) or a fresh version delta — NOT this seam.

Pairs the other executed-fortress nulls: [[project-arcadia-fortress-executed-null]]
[[project-tare-sherlock-fortress]] [[project-stbl-fortress-executed-null]]
[[project-reserve-dtf-r5-drift-null]]. Discipline anchors: [[feedback-trigger-reachability-is-payability-gate]]
[[feedback-tool-complete-stop-polishing]].
