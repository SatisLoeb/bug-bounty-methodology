---
name: project-decentraland-immunefi-full-engagement
description: "Decentraland Immunefi ($500k) — web + SC BOTH exhausted by own surface-by-surface audit; #87537 the one win; F2 the only SC finding (Low). Don't re-audit without NEW surface."
metadata: 
  node_type: memory
  type: project
  originSessionId: 17b07e38-4f8a-4c0c-ba12-871bd24a48dd
  modified: 2026-08-27T12:20:20.432Z
---

**Decentraland (Immunefi, max $500k, KYC, PoC-required) — MEASURED-NULL on both scopes, 2026-08-27.** Workspace: `~/Desktop/BUGS/decentraland-immunefi-audit` (OUTCOMES.jsonl has every verdict). Engaged twice: deep pass 2026-08-12/13, then a full operator-directed re-audit 2026-08-26/27 (operator distrusted the first pass → re-did every surface myself).

**The one WIN — report #87537 (Confirmed Critical, awaiting payment, KYC given 2026-08-13).** `decodeAuthChain` case-desync: signed payload lowercased, authz reads raw → act-as-another across every signed-fetch backend. **HOLD: do NOT poke the program.** This is the calibration anchor for the [[decentra]] skill.

**WEB scope = HARDENED PROGRAM-WIDE, dead.** The folded-metadata-key sibling of #87537 was REAL against Aug-12 clones (PoC `harness/poc-scene-signer-keycase.mjs`: control rejected, uppercased-key authenticates as owner) but ALL SIX backends (builder/worlds/marketplace/signatures/social/auth) upgraded to `@dcl/crypto-middleware 6.3.0` with commits NAMING the bug ("folded signer-key bypass" etc.) — clustered at the program's Last-Updated 2026-08-24. The 6.3.0 guard itself is a fortress (verbatim-metadata-bind + `rejectIfSigner`/`canonicalField` reject value/key/fold/non-string/proto on both primary+legacy paths; residual = legacy-value malleability, dev-CONCEDED MITM-bound). Diff-forward killed it. [[feedback-diff-forward-to-head-not-just-scope-changelog]]

**SC scope = FORTRESS, all 18 surfaces audited at depth myself.** Only finding = **F2** (EstateRegistry per-LAND `updateOperator` persists across estate-token transfer; LANDRegistry:548 clears, EstateRegistry:432 doesn't). **Low + dup-risk** (victim-remediable 1 tx, = accepted-known-low AL-01, off-chain content-impersonation) → marginal, not clearly submittable. Everything else conserved/gated: MarketplaceV2 (CEI, fingerprint), Bid (allowance-escrow, dangling-bid closed), Collections V2 (meta-tx sound, mint creator-gated, factory→forwarder=Decentraland-owned so no creator self-approve), TPR (Committee-gated at consumeSlots), Names (register-then-pay atomic 100-MANA-burn, lowercased-hash uniqueness), Rentals (conserved, index-revocation), Vesting (OZ + atomic-init factory). **CreditsManager two-wallet cashout** = real bypass of the `senderBalanceChanged` anti-cashout guard BUT bounded by the attacker's OWN trusted-signer-granted credit → maps to no listed impact = [[feedback-model-accounting-invariant-not-economic-ideal]] actor-trap, uninteresting impact.

**Source not in the workspace clone** (had to fetch): Bid=`github.com/decentraland/bid-contract`, Rentals=`decentraland/rentals-contract` (raw curl), Names+Vesting via Blockscout `https://eth.blockscout.com/api/v2/smart-contracts/<addr>` (Etherscan V1 deprecated → V2 needs key; Blockscout is keyless). Names controller `0x6843…0772` / registrar `0x2a18…acb8`; Vesting factory `0xe357…f6d0` / impl `0x42f3…9fbf`.

**Why:** $500k + active + my own Confirmed Crit make this a tempting re-visit; it's exhausted. **How to apply:** only re-engage on a genuinely NEW asset (diff `date_added`, not "Last Updated") or a new backend not yet on crypto-middleware 6.3.0. Don't re-hunt the crypto-middleware seam, don't re-audit the SC ecosystem, don't submit F2 or the CreditsManager cashout. [[feedback-findings-die-on-the-actor-not-the-mechanism]]
