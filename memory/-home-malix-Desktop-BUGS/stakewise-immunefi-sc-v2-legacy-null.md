---
name: stakewise-immunefi-sc-v2-legacy-null
description: "StakeWise Immunefi SC scope is V2-LEGACY (not V3); executed NULL-COÛTEUX, real ore (V3 $900M) hard-OOS"
metadata: 
  node_type: memory
  type: project
  originSessionId: 0d683fbc-0da4-4fc4-96ca-4ba883ca4500
  modified: 2026-08-22T21:07:58.647Z
---

**StakeWise Mainnet (Immunefi, $200K max)** — SC scope pivot 2026-08-22. Verdict: **NULL-COÛTEUX (measured), RE-SOURCE.**

**The scope trap (the valuable takeaway):** The Immunefi "StakeWise Mainnet" program is a **stale V2 listing** (live since 2022, all 14 SC assets dated 24–31 May 2022). Authoritative Instascope export: every asset `isPrimacyOfImpact:false` → **StakeWise V3 ($900M TVL: EthVault/Keeper/OsToken/**MetaVault+SubVaults**) is HARD-OOS on this program.** My hot lead (V3 post-audit delta: HEAD `fc70cbe1` 2026-06-25 "Fix enter sub vaults exit queue #139", last audit 2026-04 Statemind — the churned withdrawal seam + the program's own "Freezing ≥1wk=High" flag) is real ore but **not bountied here**. Same pattern as [[gmtrade-gmx-solana-deployed-build-baseline]] / [[feedback-scope-asset-dates-are-not-build-dates]].

**In-scope = V2 wind-down husk + canonical governance.** Executed ledger (source read + on-chain state @ block 0x189e0e3):
- **sETH2 ~1693 ETH + rETH2 ~412 ETH (~$6-8M claims)** — NO untrusted mint/theft path in-scope. `RewardEthToken.migrate()` burns caller's own tokens 1:1 (SafeMath `.sub`); `StakedEthToken` has **no mint fn**; `updateTotalRewards` gated `msg.sender==vault` where `vault=0xAC0F..52885` = V3 **EthGenesisVault** (OOS); `Pool` is a 75-line husk (no `stake`/mint, holds 0 ETH). All in-scope contracts hold **0 ETH** on-chain (backing migrated to V3).
- **MerkleDistributor 15M SWISE (~$375K)** — `claim()` leaf `keccak256(abi.encode(index,tokens,account,amounts))` binds all fields (not encodePacked), per-root bitmap. Over-claim needs a malicious root (oracle-gated) or off-chain cumulative-vs-incremental tree bug (OOS: "incorrect data supplied by oracles").
- **Oracles `0x8a88` → setMerkleRoot** — standard ECDSA **4-of-5** (`sigCount*3 > total*2`), nonce replay-protected, distinct-signer loop, `addOracle`→OZ `grantRole` admin=Safe. Defeat needs oracle keys → OOS.
- **DAO Safe `0x144a` 18.38M SWISE (~$460K, the flagged $459.8K)** via **RealityModuleERC20 `0xb5cf`** — **canonical Zodiac verbatim** (`buildQuestion` `bytes3(0xe2909f)` sep, `executeProposalWithIndex`). Execution requires won Reality.eth outcome w/ **1M SWISE bond** (bond token = SWISE `0x48C3`) = economic/governance = OOS. No code bypass.
- VestingEscrow `0xaE67` holds 0 SWISE (measured) → $0 impact.

**EV:** p_bounty on in-scope ≈ 0 (4yr-audited V2 Halborn+SigmaPrime + canonical Zodiac; treasury is illiquid SWISE microcap; max $200K). Real ore = V3, OOS here.

**RE-SOURCE:** if hunting StakeWise V3, needs a DIFFERENT channel — check for a separate V3 bounty (Cantina/Sherlock/direct); the V3 repo is public (`stakewise/v3-core`, cloned at `~/Desktop/BUGS/stakewise-audit/src/v3-core`, foundry, audits/ dir) → fork-based PoCs feasible IF a payer exists. Web scope (`app.stakewise.io` only; `api.stakewise.io` GraphQL/`admin.stakewise.io` are OOS by literalism) — operator continuing solo; `updateProfile` sig-replay + cross-field tamper both server-blocked, vault-metadata XSS closed (js-xss FilterXSS `br/p/b/span/a` + React auto-escape). Workspace: `~/Desktop/BUGS/stakewise-audit/`. Harness: `~/Downloads/foundry-v2-stakewise-da3cface58837cb4` (all 14 in-scope sources verified-fetched).
