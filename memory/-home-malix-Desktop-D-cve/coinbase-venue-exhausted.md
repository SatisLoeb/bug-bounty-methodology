---
name: coinbase-venue-exhausted
description: "Coinbase $5M Cantina venue is EXHAUSTED mapped-stock — 6/6 targets audited to 0 submittable findings; do not re-pick, only re-arm on a NEW Coinbase deployment via drift-watch"
metadata: 
  node_type: memory
  type: project
  originSessionId: c639357a-aca4-4017-84b4-5a00b153de69
  modified: 2026-09-17T07:56:10.914Z
---

**Coinbase $5M Cantina bounty (all Coinbase-deployed mainnet SC; HackerOne=offchain) = fully mapped and DRY for me.** No submission fee, KYC required, tiered: Tier-0 (mainnet Coinbase contracts) Crit $5M/High $500k/Med $50k; Tier-1 (other) Crit $500k/High $50k/Med $5k. NOT explicitly Primacy of Impact. Cantina bounty id `55316f42-3c5e-4746-9bd0-0f18dcbc344b`.

**Six targets audited, ALL 0 submittable findings (verdicts on disk in ~/Desktop/BUGS/coinbase-*-audit):** spend-permissions (SPM/SpendRouter/PublicERC6492Validator, 5 Cantina audits, P2 angles all dead — cross-chain replay killed by Solady EIP712 live-rebuild, batch-uniqueness documented, 128-bit nonce 2^64-infeasible), recovery-signer, commerce-payments (5 reports, Medium+ all fixed), flywheel (one Low-Med kill-gate-passed but dropped per no-dubious policy), eip7702, echo (permissioned OTC, no direct user withdrawal). The `## Next:` chains are all followed and closed. spend-permissions repo HEAD is 2026-03-24 (before my 04-20 audit) → zero drift.

**Why / how to apply:** Do NOT re-pick any Coinbase target as a "pivot" — it re-audits a fortress ([[feedback-manual-poke-bracket-mandatory]] applies at the sourcing level too). Re-arm ONLY when [[drift-watch-daily-routine]] flags a NEW Coinbase-deployed contract (a new product = fresh Tier-0 surface). This venue was the 2nd consecutive "pivot" (after [[project-lombard-finance-audit]]) that landed on my own audited fortress → concrete proof the mapped-stock well is dry and the binding constraint is ACCESS to fresh surface, not rigor ([[venue-landscape-2026-09]], [[feedback-seam-density-is-the-surface-selection-axis]]). Next move is the access-layer (A2 reciprocity / A5 pre-mainnet), not re-selection among mapped stock.
