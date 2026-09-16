---
name: xterio-immunefi-sc-core-executed-null
description: Xterio Immunefi SC core — executed NULL-COÛTEUX across 12 money-path veins; program tombstones kill the obvious impacts; real ore is off-chain Web&App
metadata: 
  node_type: memory
  type: project
  originSessionId: 402be6ec-f201-4666-a2c0-025f51ec6c40
  modified: 2026-08-15T07:34:05.243Z
---

Xterio (Immunefi SC, Primacy of Impact, $122.1k paid, $80K max Crit, ~3d resolution → payer LIVE). Repo `github.com/XterioTech/xt-contracts`, EVM 8 chains (ETH/BSC/opBNB/Arb/Polygon/Base/Xterio-BNB 112358/Xterio-ETH 2702128). 16.3K LOC, 7 PeckShield audits Mar-2024→May-2025, NO crowd/contest coverage (0 C4/Sherlock/Solodit), NO AI-bot.

**PROGRAM TOMBSTONES (Immunefi page — kill the obvious impacts, contractually OOS):** (a) raffle predictable-RNG "attack value < cost" → DepositRaffleMinter/RaffleAuctionMinter `keccak256(blockhash(n-1),timestamp)` is OOS despite RNG being a listed Critical; (b) WhitelistMinter.mintWithSig sig-reuse = intended; (c) MarketplaceV2 "no chainId" = intended (STALE — deployed code DOES include `block.chainid`); (d) all 7 PeckShield findings NOT eligible. **Lesson: the mapper's high-confidence RNG headline was already dead — always cross the surface map against the program tombstones (recon) BEFORE building.** [[feedback-oos-bullet-describing-your-finding-is-its-tombstone]] [[feedback-audit-acknowledgment-is-a-liability-not-an-asset]]

**12 veins executed/read-NULL (measured, not agent-inferred — nullguard-audited):**
1. Oracle (OnchainIAP + UniswapV3Aggregator/PancakeV3 variant `0x9DaA`→pool `0xE7Bd29`): manip-defeated — `slot0` cast read = observationCardinality **4500** (not 1) → `observe([3600,0])` = active 1h TWAP; team deliberately hardened. Impact ceiling soft anyway (purchaseSKU delivers OFF-CHAIN IAP goods, protocol under-collects ≠ on-chain fund theft). Live Product-1 XTER path only DEX oracle; USDT/BNB + BNB/USD are Chainlink (OOS).
2. TokenGateway mint-authz: `onlyWithMintAccess` single require (no fail-open), all 3 sets admin-gated; proxy already `initialize`d (cast-verified, no uninit takeover); MarketplaceV2 NOT operatorWhitelisted.
3. LootboxUnwrapper: burns 1 box per mint → 1:1 bounded (map's "1 sig→N NFTs" refuted).
4. WhitelistMinter: hash binds msg.sender+chainid+this; only footgun = native msg.value stuck on ERC20-pay call.
5. DepositRaffleMinter accounting: conserves (Σdeposits = winner+loser refunds + sendPayment); CEI + nonReentrant. Only exploit = tombstoned RNG.
6. WhitelistClaim airdrop: claim=msg.sender==account; delegateClaim needs beneficiary sig; encodePacked-collision not exploitable (post-proof fields non-attacker-controlled). Residual = cross-deployment merkle-replay iff same root funded ≥2 deployments (reachability-gated, high design-dismissal).
7. MarketplaceV2 (937 LOC full read): signed digest includes chainid+marketplaceAddress; buyer+seller sign same Order (price agreed); encodePacked(order,metadata) fixed-len no collision; fees→revert on overflow; mint-at-sale gated to nftManager==seller.
8. FansCreate curve (deployed UUPS upgradeable = guarded, NOT unguarded plain): linear bonding curve, buy@S / sell@S+a both ref calcPrice(S,a) → symmetric, solvent, nonReentrant, transfers soulbound-restricted. **Reentrancy lead #2 dead: deployed 0x7e913A is UUPS proxy (.openzeppelin/unknown-112358.json), has the dev-added nonReentrant; the vulnerable plain FansCreateCore is NOT deployed (Rule 5).**
9-10. XterStaking / XterNFTStaking: staker-gated unstake, CEI; only freeze = self-inflicted direct safeTransfer.
11. AuctionMinter + BidHeap: tie-break consistent (price desc, id asc) → floor = highest-id in-heap floor bid, out-of-heap floor bids have higher id → correctly losers; no over-mint, conserves. NOT tombstoned (no RNG) but clean.
12. Launchpool: Synthetix-standard; FoT-stakeToken/admin-underfund = OOS.

Also read null: DepositMinter (CEI-order flag on sendPayment defended by nonReentrant; conserves), XterStakeDelegator (claim→stake→withdraw, guarded), BasicERC1155C.mintAirdrop (onlyGatewayOrOwner).

**MECHANICAL BACKSTOP (NUKE aderyn+semgrep, needs `npm i --legacy-peer-deps` first — hardhat/OZ conflict):** 63 signals, 16 HIGH all adjudicated null — 14 are vendored Biconomy AA / test MockMarket / tombstoned RNG (DepositRaffleMinter:316) / cleared WhitelistMinter:107 payee (sig-bound) / BidHeap:44 comparison-only FP. Only 2 new real-contract HIGH (DepositMinter:75 reentrancy = nonReentrant-defended, BasicERC1155C:62 msg-value-loop = FP not-payable). Slither couldn't compile (hardhat v3 HHE22) but aderyn's own parser gave the dataflow pass. Corpus NFT/gaming named patterns (P-MISC-001..005) don't hit on-chain; P-MISC-004 (off-chain nonexistent-field→silent-zero) is a pivot signal.

**All non-OOS impacts require admin/manager privilege (migrate/setFeeRatio/pause) = OOS.**

**VERDICT: NULL-COÛTEUX (measured) → RE-SOURCE.** Depth on this 7-audit core is exhausted; the freshest surface (oracle) was team-hardened. **Real EV = the off-chain Web & App asset `app.xter.io`** (in-scope separate asset) — the null SC core pushes the ore off-chain, my repeated pattern. A 3rd asset was added 2026-04-17 (address not extracted; read rendered Immunefi scope in browser). 

**Re-open triggers:** a NEW launchpad minter or UniswapV3Aggregator wired over a **cardinality-1** pool (revives atomic oracle manip); FansCreate redeployed as plain (non-UUPS); a reused funded airdrop merkle root across ≥2 chains.

Engagement composed: [[protocole-forteresse-v2]] spine · extract gate-chain · [[feedback-workflow-agents-coverage-not-verdict]] (agents mapped, I hand-verified every verdict) · nullguard corrected my first synthesis (agent LIKELY_REFUTED presented as executed-null — reclassed + re-read myself).
