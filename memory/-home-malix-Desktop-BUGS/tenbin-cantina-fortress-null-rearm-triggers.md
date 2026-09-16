---
name: tenbin-cantina-fortress-null-rearm-triggers
description: Tenbin (Cantina) SC in-scope core = 8-audit fortress-null; the re-arm triggers that would revive it
metadata: 
  node_type: memory
  type: project
  originSessionId: d7422246-b641-4c30-a6ec-67f01aa82d07
  modified: 2026-09-15T07:20:23.666Z
---

Tenbin bug bounty (Cantina, `github.com/tenbinlabs/tenbin-contracts` @ `031df2d`/v1.4.3, LIVE mainnet, funded ~$2.34M across 3 Morpho vaults). Re-run 2026-09-15 as a fresh target: **NULL-COÛTEUX / NO-GO**. 30-agent fanout → 34 candidates → 0 survivors, each killed with an executed disconfirmer.

**Why fortress:** 16 audit docs / 11 review passes (Spearbit, Zellic ×2, Fuzzland ×2, Verilog ×2, 0xleastwood, AI ×3) over 2,273 logic LoC. ZERO un-audited in-scope delta — every Aug-2026 remediation commit touches only OOS `src/external/**` (Morpho/Bebop adapters); freshest in-scope commit (Q3 audit, Jul 27) is cosmetic. Do NOT re-audit the in-scope core cold.

**Verified on-chain facts (don't re-derive):** Controller HOLDS CURATOR_ROLE on its CollateralManager (`hasRole==true`) — the one place an untrusted actor touches protocol accounting, but mis-booked value flows to Tenbin's OWN multisig (profit=0). All 3 staked vaults seeded (first-depositor dead). tGLD Controller `0x5e631388` runs **v1.4.0** not judged v1.4.3, BUT the v1.4.0→v1.4.3 in-scope diff is only constructor zero-checks + Merkl feature + legal-notice refactor = NO exploitable security delta. `maxWithdraw(CM)==0` but `withdraw() --from Controller` SUCCEEDS (V2 liquidityAdapter on-demand; ERC-4626 conservatism — never report the state-read as a freeze). tBRL ~0 on-chain transfer activity (static/operational, not user-traded) → oracle-optionality (Spearbit 5.2.1 ACK) has no realized extraction to measure.

**Re-arm triggers (a future session revives ONLY on these):**
1. A **4th product line** deployed where the StakedAsset seed and deploy are NOT atomic (no `_decimalsOffset` override → classic first-depositor Critical for that window). Check `totalSupply()` in the block of its first external deposit.
2. `RestrictedStatusChanged` shows an address on **exactly one** of the two separate restricted registries (Controller.isRestricted vs StakedAsset.isRestricted) persistently → Gate-5-testable High.
3. A StakedAsset line where `instantUnstakeCap < ~2× totalAssets()` → temporary-freeze Medium.
4. A new oracle adapter over a **shorter-heartbeat feed** while keeping the 86400 staleness constant (halts mint+redeem).
5. tGLD upgrades to 1.4.3+ (closes the provenance drift; until then treat tGLD as a separate-provenance target).

**Real ore is OOS:** backend MINTER/HSM key, KYC-signer keys, REBALANCER, custodian off-ramp — a contracts-only Cantina scope cannot land them. Deliverable: `~/Desktop/D-cve/tenbin/rerun-2026-09-15/findings/PLAYBOOK-AUDIT-tenbin-rerun.md`. See [[protocol-fortress-null-hunt]], [[feedback-depth-is-an-edge-only-where-ore-remains]], [[feedback-audit-acknowledgment-is-a-liability-not-an-asset]].
