---
name: rheo-size-fork-fortress
description: "Rheo bug bounty = Size Credit fork; hunted 2026-07-05, thin-residual fortress, no payable Critical/High"
metadata: 
  node_type: memory
  type: project
  originSessionId: 381b8c8e-a82f-4012-9009-e612ba5fbaff
---

**Rheo** (Cantina bounty, Ethereum mainnet) = **Size Credit rebranded** (DeepWiki badge → `SizeCredit/size-solidity`; README "Rheo (prev. Size Credit)"). Two repos: `rheo-xyz/rheo-solidity` @ b7714a2 (v1.9-rc.0+20, the lending order-book) and `rheo-xyz/very-liquid-vaults` @ e356a70 (v0.1.3, yearn-v3-style ERC4626 meta-vault). **11 audits** on the lending core through v1.8 (Solidified/Spearbit/Code4rena/Custodia×3/ChainDefenders/Cantina×3/Hashlock/Omniscia) + **2** on VLV (Obsidian, OZ). All 13 reports are in each repo's `audits/`.

**Hunted 2026-07-05 via /darkside** (manual + 12-agent adversarial workflow + deployed-layer read pass). **Verdict: thin-residual fortress — no untrusted-reachable Critical/High.** Full writeup: `/home/malix/Desktop/Thiefs-corporation/rheo-hunt/VERDICT.md`.

**Why it's clean:** audited core + the vault/adapter share-accounting seam are the most-mined surface across all 3 firms. Only the post-v1.8 delta could hold the diamond (MarketShutdown, Liquidate overdue-reward split, debtTokenCap, SizeFactory remove/createRheo, CollectionsManager per-collection copy-config, oracle zoo, VLV post-OZ rescueTokens/reorder). Every candidate REFUTED. `removeMarket` permanent-freeze and `createMarketRheo` are Critical-impact but `DEFAULT_ADMIN`-gated behind a **3-of-5 Gnosis Safe** (become-the-actor = executed-null: `_disableInitializers`, one-time init, no role-admin gap).

**Only deployed finding (centralization, likely OOS/Low):** the VLV `Auth` (`0xB5294A791c37DFdc2228FACEd7dCE8EFCEb14B84`) grants `VAULT_MANAGER_ROLE` to a plain hot EOA `0x7cBb7bE250C366Ab5458260c9ee8bc7912CD7Fe3` that **bypasses the documented+audited 1-day timelock** and also holds `GUARDIAN + STRATEGIST` — one key drains the live VLVs (addStrategy-evil + setRebalanceMaxSlippagePercent(100%) + rebalance). Trusted-key → not a payable Critical.

**If re-engaging:** only a NEW version delta (past v1.9-rc.0+20) or a NEW whitelisted non-standard ERC4626 vault in a Size market is worth a fresh look. Don't re-audit the core. See [[capability-vs-view-the-paying-vein]].
