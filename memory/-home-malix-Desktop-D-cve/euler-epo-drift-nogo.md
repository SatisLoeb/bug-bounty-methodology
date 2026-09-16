---
name: euler-epo-drift-nogo
description: "Euler Cantina bounty drift triage — nanosecond oracle adapter is fail-safe, evk-periphery OOS"
metadata: 
  node_type: memory
  type: project
  originSessionId: c639357a-aca4-4017-84b4-5a00b153de69
  modified: 2026-09-15T08:59:43.954Z
---

Euler = **live Cantina bounty** (https://cantina.xyz/bounties/4d285eee-602e-440a-845e-25e155cec26a), core tier (EVC/EVK/EPO) **High up to $5M (min $200k), $7.5M w/ Usual boost; Medium up to $200k**. KYC, $20 deposit. Scope = **DEPLOYED addresses** (verify via `app.euler.finance/api/public/is-known`) at pinned commits, NOT repo HEAD. It's a bounty (first-valid), not a saturating competition.

**Drift triage 2026-09-15 (from [[drift-watch-daily-routine]]) → NO-GO:**
- **euler-price-oracle** gained exactly one new file: `ChainlinkInfrequentNanosecondOracle.sol`. IN SCOPE (top tier). Differential vs its audited parent `ChainlinkInfrequentOracle`: byte-identical except one line `updatedAt = updatedAtNanos / 1e9`. **Fail-safe in every degenerate case** — truncation rounds updatedAt DOWN → staleness LARGER → reverts sooner; the unsafe direction (staleness understated → stale price accepted) is mathematically unreachable for a nanosecond-or-coarser feed. Residual risks are governor-misconfig (explicitly OOS) or a nonexistent unsafe feed. Clean kill in primary source before the fee.
- **evk-periphery** +100 commits (IRMFixedCyclicalBinaryMonthly, MigrationHelper, Lens/*, EdgeFactory) = **OUT OF SCOPE**: the bounty covers evk-periphery ONLY for the *Securitize Collateral Vault*. Dropped from the daily routine (can't cheaply filter to Securitize via ls-remote).

**Key OOS notes**: "misconfigured vaults/oracles (governor responsibility)", "issues in prior security audits" (EPO has 11 audit PDFs in repo/audits/). So a payable EPO finding needs NEW adapter logic that fails UNSAFELY, wired to a known deployed vault.

Dossier: `~/Desktop/BUGS/euler-v2-recon/EULER-DRIFT-TRIAGE-2026-09-15.md`. Reflects the drift-watch thesis working: surfaced fresh code fast, triaged manually in minutes, declined negative-EV per [[feedback-no-dubious-low-submissions]].
