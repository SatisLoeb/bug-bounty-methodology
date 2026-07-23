---
name: reference-cantina-solfork-targets-2026-07-21
description: "Cantina targets in the /solfork vein (closed-source deployed Solana) — pump.fun ($500k, saturated→Pump Fees sliver) + Perena ($25k, fresh, intake done)"
metadata: 
  node_type: memory
  type: reference
  originSessionId: 7a1cec50-aec0-40f4-9311-a86e2cb19f35
---

Cantina sweep for /solfork-vein targets (closed-source deployed Solana/Anchor, fork-execution PoC). Browser extension dropped mid-session → used WebFetch/WebSearch.

**pump.fun** (cantina.xyz/bounties/253a4e11-…, LIVE, Cantina-triaged). $500k Crit / $100k High / $10k Med. 3 closed-source-deployed Anchor programs, IDL PUBLIC on GitHub (recovery shortcut), PoCs = Anchor test / Solana CLI (= fork-execution expected). Program IDs: Pump `6EF8rrecthR5Dkzon8Nwu78hRvfCKubJ14M5uBEwF6P` (core bonding curve), Pump Fees `pfeeUxB6jkeY1Hxd7CsFCAjcbHA9rWtchMGdZ6VojVZ`, Pump AMM `pAMMBay6oceH9fJKBRHGP5D4bD4sWpmSwMn52FMfXEA`. DUP-GATE ([[feedback-check-prior-audits-and-competitions-at-intake]]): AMM = **9 independent audits + slated to OPEN-SOURCE** (fortress + loses closed angle); core Pump = battle-tested since 2024, billions volume (fortress). → the ONLY /solfork edge = **Pump Fees** (pfee…), newest/separate/least-scrutinized, still closed. NUANCE: scope tagged "Devnet Only" for contracts though mainnet IDs listed — verify it's "demo on devnet" not a severity cap [[feedback-commit-anchored-scope-pays-deployment-impact]]. High ceiling, narrow fresh sliver, crowd-swept.

**Perena** (cantina.xyz/bounties/4bbe54f6-…, LIVE). $25k Crit / $10k High / $2.5k Med / $500 Low. Solana stablecoin USD* (mint/redeem/yield/pool mgmt). "Testing must occur on a LOCAL FORK ONLY" = /solfork mandated. Closed deployed `save8…` (Anchor). Already in corpus [[project-perena-bankineco-intake]] with fresh edge: the 2 public audits (FrankCastle Prime-stableswap N/A; Hashlock simple-vault) MISS the deployed junior-TRANCHE + Kamino/Marginfi atomic-lending subsystems → hunt tranche loss-absorption + share-price on a fork. Lower ceiling BUT genuinely fresh + un-crowded + intake DONE.

Also seen: Olas/lockbox-solana competition (Solana but competitions usually source-provided → not closed /solfork).

RECOMMENDATION: Perena = better pure-/solfork EV (fresh un-audited subsystem = higher p_bounty, local-fork mandated, intake done) despite $25k ceiling. pump.fun = bigger name/$500k but /solfork-relevant surface is the narrow Pump Fees sliver inside a 9-audit/battle-tested/soon-open-source fortress. Operator to weigh ceiling vs freshness.
