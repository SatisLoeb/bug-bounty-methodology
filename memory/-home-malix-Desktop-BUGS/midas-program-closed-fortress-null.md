---
name: midas-program-closed-fortress-null
description: "Midas RWA (EVM + Solana, Cantina) CLOSED 2026-06-26 — fortress-null both chains; 2 bounded items banked, re-open triggers recorded"
metadata: 
  node_type: memory
  type: project
  originSessionId: 8c7164c7-5d3e-4878-99e4-730b45d08d7f
---

**Midas (RWA tokenization, Cantina bug bounty) — whole program CLOSED 2026-06-26.** Both chains audited to earned-null; do NOT re-engage without a re-open trigger below.

**EVM** (`midas-apps/contracts`, $500K Crit / $1M cap): real multi-pass firmaudit (2026-06-20) closed fortress-null; its total-coverage WIDTH pass already executed the corpus class-density route. A 2026-06-26 corpus-replay CONFIRMED it: the firmaudit's "thin wrapper over one base" concession (read only mTBILL, conceded ~75 products unread) is PROVEN correct — all 78 live product dirs are 24-35-line deploy-identity subclasses (override only vaultRole()/feedAdminRole()), even mGLOBAL's "novel" InfiniFi oracle. Cross-product asymmetry diamond = earned null. Hardcoded stable-peg (`ManageableVault._getTokenRate` L641 `if(stable) return STABLECOIN_RATE`) is feed-gated (getDataInBase18 enforces min/max/staleness first) + band-bounded → same shape as the Solana clamp, park defensible. Report: `midas-eth-audit/recon/CORPUS-GAP-REPLAY.md` + `midas-cantina-audit/_negative-results.md`.

**Solana** (`midas-apps/contracts-solana`, $200K Crit / $400K cap, ~$4.3K TVL): pre-intake May-2026 pass HOLD was correct-for-wrong-reason (EV-stop fired before the corpus sweep, conceded 6 lenses; R-011 flagged #1 in ROUTING.md, never executed). Corpus-replay + executed on-chain reads: unlimited-mint / mint-auth-CPI / oracle-decimal / rounding all FORTRESSED or earned-null. ONE dormant **Low banked**: data-feed PYTH arm (`get_price_in_base_9`) ignores `.conf`; the live USDC payment feed (`EY9TeqHx…`) is mode=PYTH on mainnet (mToken feed `7UVwLrMT…` is MANUAL) → reachable untrusted via `mint_instant`, but the USDC FeedState clamp `[0.997,1.003]` bounds it to ≤0.3% = Low. Report: `midas-sol-audit/recon/CORPUS-GAP-REPLAY.md`.

**Re-open triggers (the ONLY reasons to touch Midas again):**
- Solana or EVM: FEED_ADMIN wires a **volatile** payment token (or the mToken itself) to PYTH/Switchboard with a **wide band** → the conf-ignore (Sol) / stable-peg (EVM) becomes a real Medium. `update_feed` is un-timelocked.
- A new product ships a **non-thin** vault/feed override (would break the verified subclass pattern) — watch the fresh-product commits (turtlePST/sGold/mWIN/mGLO were thin).
- EVM deployed-config read (deferred, needs Etherscan key): a non-1:1 token flagged `stable=true` with a wide band.

Methodology contrast worth keeping: **EVM = corpus replay CONFIRMS a fortress (the firmaudit had executed the route); Solana = corpus replay FINDS a dormant miss a thin pass buried.** Same exercise, opposite outcomes — both honest. See [[injective-exchange-firmaudit-parked]] for the parallel L1 close pattern, [[ev-gate-check-program-responsiveness-not-just-severity]].
