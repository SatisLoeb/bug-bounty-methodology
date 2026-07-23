---
name: project-rheo-veryliquid-intake
description: "Rheo (Size ecosystem) Cantina bounty — GO surface = very-liquid-vaults meta-vault (fresh, 2-audit, live+funded ETH); Size core = ~10-audit fortress. Vein = extract (value-conservation)."
metadata: 
  node_type: memory
  type: project
  originSessionId: 3c399e15-ef33-40ad-abe1-f8688fee64f0
---

Rheo = the Size protocol ecosystem. Cantina bounty `c5811be1-cc87-4418-80b0-f0b50f7e5849` **ACTIVE**,
fixed-tier discretionary **Critical $50k / High $5k** (not TVL-scaled), Ethereum-mainnet deployment.
Two in-scope repos (pinned commits) in ~/Desktop/BUGS/rheo-2026:
- `rheo-solidity @ b7714a2` (src 5526 LOC) = **Size order-book lending core**, ~10 audits → FORTRESS, diff-mode only.
- `very-liquid-vaults @ e356a70` (src 973 LOC) = **Yearn-v3-style ERC4626 meta-vault**, only 2 audits (Obsidian+OZ) →
  **THE GO SURFACE** (fresh, small, live+funded on ETH mainnet: VeryLiquidVault Core 0x3AdF08AFe804691cA6d76742367cc50A24a1F4A1
  + strategy vaults wrapping real Morpho/Euler/Aave). Checkout is on e356a70 (NOT HEAD bb57f52); at e356a70 strategies =
  Aave-V3/Cash/generic-ERC4626 (MorphoVaultV2StrategyVault + Aave-V4 are LATER = OOS).

Exclusions LENIENT (only known-issues + already-tested-cases). Valuation seam: VeryLiquidVault.totalAssets = Σ
strategy.convertToAssets(strategy.balanceOf), each ERC4626StrategyVault.totalAssets = extVault.convertToAssets(...).
Deposit mints shares for full `assets` BEFORE per-strategy try/catch-skip routing (VeryLiquidVault:160,177); totalAssets
un-guarded (nonReentrantView only on getters). **Vein = /extract** (deposit/withdraw value-conservation + 3-boundary
rounding, reachable by any depositor) + /darkside Door-C on the meta composition. /power low (roles trusted).
Dossier: ~/Desktop/BUGS/rheo-2026/TARGET-DOSSIER.md. Apply [[feedback-trigger-reachability-is-payability-gate]] +
full-impact-taxonomy [[feedback-payable-impact-not-just-theft]].

**HUNT DONE 2026-07-20 — EXECUTED NULL across all in-scope fresh surfaces (defensible registre-de-tentatives, NO payable found):**
- **very-liquid-vaults NULL**: 4-agent extract workflow + manual read + aderyn. Clean OZ ERC4626 fortress. Donation-inflation
  proven non-extractable (executed Probe B: donor NET −1,359 USDC, socialized to mandatory dead-shares; already Obsidian C-01
  FIXED). Superform/Aave differential floors in the SAFE direction. Multi-strategy composition neutral (deposit atomic,
  sum-of-floors conservative, withdraw same-asset). Residuals = documented known-limitations (deposit-dust griefing KL#13,
  reverting-strategy DoS KL#10), griefing/liveness class, not payable at $50k-crit tier.
- **rheo-solidity Size DELTA NULL** (MarketShutdown/debtTokenCap/vault/factory-remove, the post-audit fresh part):
  candidate ERC4626Adapter first-depositor inflation HAND-VERIFIED REFUTED — sharesOf = pure 1:1 pass-through of extVault
  shares (ERC4626Adapter.sol:65-68), Size adds no share layer to inflate; inflation lives only in a non-standard whitelisted
  underlying (trust-boundary/OOS) and the bug would be in the underlying, not Size. debtTokenCap only on 2 mint paths (no
  exit reached), MarketShutdown/remove-market admin-only.
- **rheo-solidity collections copy-limit-order NULL**: effective APR clamped to subscriber [minAPR,maxAPR] on LIVE curve at
  match time (CollectionsManagerView:140-148); offset applied before clamp so can't escape. And it was Cantina-2025-06
  dedicated-audited (3.4.3 fixed / 3.5.2 ack / 3.3.4 fixed) — NOT fresh un-reviewed as I first thought.
- NOT exhausted (both LOW EV): the OLD Size order-book core (BuyCredit/SellCredit/liquidation/accounting) = 10-audit fortress;
  tooled barrage on Size failed on a nested @solady dep (2 attempts, dropped). 
**VERDICT: RE-SOURCE off Rheo for solo — well-audited (10+ Size, 2 VLV, + Cantina on collections), fresh deltas executed-NULL.**
Don't re-hunt from scratch. See [[feedback-hunt-dont-narrate-ev]].
