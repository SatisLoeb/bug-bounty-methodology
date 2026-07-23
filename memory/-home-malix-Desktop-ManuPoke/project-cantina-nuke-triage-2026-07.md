---
name: project-cantina-nuke-triage-2026-07
description: "Cantina live-bounty landscape triaged for /nuke on 2026-07-13 — which are non-EVM, private-repo, fresh vs mega-saturated"
metadata: 
  node_type: memory
  type: project
  originSessionId: 76238c5f-a7fa-4a5f-8c3b-19dd78e66c8f
---

Triage of Cantina live bounties as [[project-nuke-static-barrage-skill]] candidates, done 2026-07-13 via Claude-in-Chrome + a 32-agent verification workflow (each agent pulled the Cantina "findings submitted" saturation counter + confirmed the public clonable repo + language).

**Best solo /nuke picks (EVM-Solidity, public repo, still-low saturation):**
- **Makina** — `MakinaHQ/makina-core` (99% Sol), $500k, 127 findings; cross-chain vault + MakinaVM arbitrary-call.
- **Rheo** — `rheo-xyz/rheo-solidity` + `rheo-xyz/very-liquid-vaults` (pinned commits), $50k, 97 findings; fixed-rate order-book lending + yield-curve math. Least-famous = biggest blind spot.
- **Pendle Boros** — `pendle-finance/boros-core-public`, $500k, 99 findings; IRS order-book↔AMM seam.

**Durable exclusions (hard gate fails — don't re-scrape these for /nuke):**
- NON-EVM (no Solidity to scan): dYdX (Go/Cosmos), Injective (Go+CosmWasm; only Peggy.sol is Sol and [[project-injective-peggy-exhausted]]), Aave-on-Aptos (Move), pump.fun+Perena (Solana), Aztec (Noir), Monad Consensus (C++/Rust node).
- NO public clonable Solidity: Ondo Perps (private/KYC, Ondo Chain Cosmos), Kuru (`kuru-contracts` PRIVATE 404, only TS SDK public), deri-protocol (contracts OUT of scope, only deri.io web in-scope), Rogo (web/iOS AI SaaS).
- Private bounties: Paxos, Invite-only.

**Mega-saturated but accessible → /nuke DIFF mode only (base-audit..head), cold barrage EV≈0:** Morpho (1448 findings), Coinbase (1336), Polymarket (843), Uniswap (833), doppler (758), USDai (628), Euler (579), Agglayer (519, Rust core OOS), Alchemy Modular Account V2 (478), Centrifuge (480), Liquity (450), Kinetiq (398), infiniFi (348), Symbiotic (336), Concrete (332), Mezo (330), Midas (301), LI.FI (291), PancakeSwap Infinity (222), Reserve (159).

**Already my territory:** Ammalgam ($25k, redeployed 2026-06-24, only 35 findings but ChainSecurity+0xMacro+Cantina-comp) — Saturation/TWAP/PartialLiquidations hot-spots already killed in my notes; only diff-drift left.

Note: findings-counts drift over time; treat the language/repo-visibility facts as stable, the saturation numbers as a 2026-07 snapshot.
