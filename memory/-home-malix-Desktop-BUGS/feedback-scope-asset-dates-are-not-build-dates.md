---
name: feedback-scope-asset-dates-are-not-build-dates
description: "A bounty scope's asset dates and \"verified-build\" links are scope-entry dates, not build dates — derive the deployed commit yourself BEFORE picking a surface"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 7937d3a0-c213-40ba-ab49-f53e00180aee
  modified: 2026-07-30T10:37:21.464Z
---

A bounty program's asset table dates (and its "verified-build" explorer links) tell you **when the scope entry was written**, NOT when the program was built or what commit is live. Resolve the deployed commit *before* choosing where to spend depth.

**Why:** on GMTrade 2026-07-30 the scope listed verified builds dated *7 July 2026* and GitHub `tree/main` dated *1 July 2026*. I found a 460-line unaudited market-status feature merged 2026-07-04/05 and spent the first half of the session auditing it as "the fresh surface." The deployed store was actually commit `6d1cfe84` from **2026-03-19** — the feature was never deployed, zero funds at risk. Same session, treasury was 9 months stale and LP 5 months stale. Selecting the surface on the scope's dates = auditing code that cannot pay. This is Rule 5 (`code present ≠ code deployed`) at the *commit* level, and it decides surface selection, not just severity.

**How to apply** (Solana; ~2 min, no signer needed):
1. `curl https://verify.osec.io/status/<PID>` → `repo_url`, `commit`, `executable_hash`. Treat `last_verified_at` as **stale** — it is not the current hash.
2. Read the Program account (36 B) → `programdata` pubkey at bytes 4..36. Read ProgramData: bytes 4..12 = **last-deploy slot**, 12 = Option tag, 13..45 = upgrade authority; ELF starts at 45. `getBlockTime(slot)` → the real deploy date.
3. Hash it the `solana-verify` way: strip trailing `\x00` from the ELF, `sha256`. Compare to `executable_hash`. Match ⇒ deployed == that commit **and** an independent rebuild reproduced it, which also implies standard build args.
4. `git merge-base --is-ancestor <feature-commit> <deployed-commit>` to test whether the surface you want is even live; `git diff --stat <deployed> HEAD -- <path>` to size the undeployed delta.
5. For cfg-gated security features, prove the flag by **execution**, not by reading `Cargo.toml`: `simulateTransaction` (`sigVerify:false`, `replaceRecentBlockhash:true`, `encoding:base64`) the guarded path and read the AnchorError — it prints file:line. Use any funded mainnet account as payer; nothing is submitted. For a feature that *adds* an accepted pubkey, absence of that pubkey in the dumped `.so` is a one-sided **proof** it is off.

Corollary, both directions: code fixed in `main` but not deployed is still **live on mainnet** (an N-day) — though a merged/closed PR usually makes it a known-issue OOS. And EVM equivalent: compare deployed bytecode to the tagged release, don't trust the scope's date. Relates to [[feedback-reachability-is-kill-gate-not-severity-modifier]] and [[gmtrade-gmx-solana-deployed-build-baseline]].
