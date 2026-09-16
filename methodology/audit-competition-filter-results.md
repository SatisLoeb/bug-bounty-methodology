# Audit-competition filter (reports.immunefi.com via MCP) — 2026-09-14

Gate-4 public-dup pre-check: does the target have a prior Immunefi audit COMPETITION
(a public corpus of disclosed findings = saturation on every probed seam)?

| Target | Competition? | Corpus | Read |
|---|---|---|---|
| **Lombard** | YES — `reports.immunefi.com/lombard` ("Audit Comp \| Lombard", Dec 2024) | disclosed findings skew Insight/Low on Bascule/mintWithFee/bridge/CLAdapter | DEDUP burden on exactly my periphery seams (bridge-vs-Bascule, mintWithFee grief). $250k program, so a Critical the comp didn't disclose can still pay — but dedup the periphery vs this corpus FIRST. |
| **Strata** | NO (page 404) | — | Clean on the dedup axis. Blocker is unchanged & economic: only Critical pays (High capped $10k), and AccountingLib+RoundingGuard are NOT deployed ($0 funds-at-risk). Conditional GO only for a Critical anchored to DEPLOYED bytecode. |
| **Robinhood-chain** | NO (page 404) | — | Cleanest freshness of the three on this axis. Active seams (JIT + Factory) per prior work; multiplier-diff was a near-kill. No public competition corpus to dup against. |

## Ranking (dedup/freshness axis only)
1. **Robinhood-chain** — no competition + fresh active seams → best GO candidate here.
2. **Strata** — no competition, but the deployment/economics blocker stands (Critical-only, libs not deployed).
3. **Lombard** — competition exists → dedup periphery seams vs the corpus before depth; $250k keeps it alive for a non-disclosed Critical.

Note: absence confirmed by direct getPage 404, not just search silence. Plain `reports.immunefi.com/robinhood`
not separately checked (target of interest is robinhood-chain).
