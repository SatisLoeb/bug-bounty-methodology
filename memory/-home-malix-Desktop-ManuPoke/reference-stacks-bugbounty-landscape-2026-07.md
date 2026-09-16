---
name: reference-stacks-bugbounty-landscape-2026-07
description: "Stacks-ecosystem bug-bounty programs after StackingDAO was delisted (2026-07). Zest V2 = fresh + NO-KYC + theft-of-yield class = best re-source; Granite = KYC-required (OPSEC wall) + older; Stacks L1 = consensus scope, wrong edge. Clarity fluency + Hiro/c32 tooling now acquired, transfers across all."
metadata:
  node_type: memory
  type: reference
  originSessionId: 3c399e15-ef33-40ad-abe1-f8688fee64f0
  modified: 2026-07-26T15:50:17.802Z
---

StackingDAO was REMOVED from Immunefi (2026-07-26) — but the Clarity/Stacks fluency + the Hiro
`call-read` / c32-encoder / clean-CV-decode tooling built during that engagement TRANSFER to every
Stacks target. The two protocols bigger than StackingDAO on Stacks (operator, Q1 2026 TVL): **Zest
$75.9M**, **Granite $26M**. Both have live Immunefi programs; recon done 2026-07-26 via `/information/`
pages (see tooling note).

**ZEST PROTOCOL V2** — `immunefi.com/bug-bounty/zest-protocol-v2/information/` — **the pick.**
- Bitcoin lending on Stacks (Clarity). V2 = the relaunch AFTER the April-2024 smart-contract attack +
  a heavy security overhaul ("audit of a quality standard they'd never seen"). So heavily audited but
  the CODE IS NEW (fresh surface, few wardens swept it).
- Live **2026-01-15**, updated 2026-04-27 (~6mo, FRESH). **17 assets**, Stacks/Clarity.
- Max **$100k** Crit (min $20k) / High max $20k (min $1k). 10% of funds, cap $100k. **NO Medium/Low**
  (only Crit+High pay). Impacts NAME "theft / permanent freezing of unclaimed yield" + "temporary
  freezing (doubles per 24h)" = EXACTLY the StackingDAO F-01 class → class-fit is high.
- **NO KYC** (payout without identity — big for a pseudonymous operator). PoC required. No mainnet
  testing (local forks only). Primacy of Impact (SC Crit/High). Immunefi VSC V2.3.
- ⚠ Vault balance shown = **$149.97 USDC** (essentially empty on-chain; payout would depend on the
  project funding at claim). Flag, not a disqualifier, but verify capitalization before deep spend.

**GRANITE PROTOCOL** — `immunefi.com/bug-bounty/granite-protocol/information/`
- Autonomous BTC liquidity/lending on Stacks (Nakamoto + sBTC), Clarity. github.com/GraniteProtocol.
- Live **2025-02-26** (~17mo, MORE picked-over), updated 2026-07-25 (yesterday — scope may have just
  moved). **31 assets** (bigger surface). Hard cap **$1M** FCFS.
- Crit max $100k (min $25k) / High $25k-$5k / **Medium $2.5k / Low $1k** (Granite pays M/L, Zest
  doesn't) + web tier. Immunefi VSC V2.3.
- **KYC REQUIRED** ← the OPSEC WALL for this operator (pseudonymous). PoC required. Primacy of Impact
  (SC). Known-issues OOS: soft-liquidation risk, in-dev test framework, governance input-validation,
  deployment-param validation, references-to-nonexistent-methods. Prior-audit unfixed vulns ineligible.
  "Category 2: Notice Required" publication. No oracle-price testing.

**STACKS L1** — `immunefi.com/bug-bounty/stacks/information/` — the blockchain itself + sBTC (NOT the
dApps). Live 2022-03, max **$250k** Crit, 12 assets, **KYC MANDATORY**. Scope = consensus / chain-split
/ invalid-tx / network-shutdown = wrong edge-fit (not Clarity-dApp accounting; high competition). Skip
unless pivoting to L1/consensus work.

**Head-start on Zest — HONEST scope (don't overclaim):** during StackingDAO I read `position-zest-v6`
/ `position-zest-v2` which are **StackingDAO's** adapters, not Zest core. Direct Zest knowledge = ONE
endpoint shape: `SP1A27KFY4XERQCCRCARCYD1CC5N7M6688BSYADJ7.v0-1-data get-user-ststxbtc-balances`
(returns an ststxbtc-DENOMINATED balance, 1:1). `pool-vault` (SP2VCQ…) may be StackingDAO's reserve,
not Zest's. So the edge is **Clarity fluency + tooling + one data-layer endpoint**, NOT a Zest surface
map. V2 is freshly rewritten anyway. Real but modest.

**TOOLING NOTE (reusable):** Immunefi **`/scope/` tabs are NOT WebFetch-able** (SPA/login → WebFetch
returns nothing / gets rejected). Use **`/information/`** for program facts (dates, rewards, rules,
KYC, asset COUNT, impact rubric). To enumerate the actual asset LIST, use the browser tool with the
operator's logged-in session, or the project's public GitHub. [[feedback-check-prior-audits-and-competitions-at-intake]]

**NEXT (operator-gated, before deep code):** enumerate Zest V2's 17 in-scope assets (browser /scope/
or public repo) → `/intake` or `xsurface-prioritize` on the fresh V2 lending/accounting surface →
hunt the theft/freeze-of-unclaimed-yield seam (the class Zest's own rubric names). [[project-stackingdao-stbtc-double-count]]
