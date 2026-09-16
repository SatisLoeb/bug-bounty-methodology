---
name: stacks-pox5-immunefi-null-couteux
description: "Stacks pox-5 (Immunefi $250K) firmaudit — NULL-COÛTEUX; fresh Epoch-4.0 contract but theft fenced+dormant, consensus sound; re-arm when sBTC funded"
metadata: 
  node_type: memory
  type: project
  originSessionId: 1419477f-3924-4971-9678-fdb3dc286eb2
  modified: 2026-08-11T20:57:46.914Z
---

Stacks pox-5 / costs / lockup (Immunefi $250K, Clarity + Rust node). Engaged 2026-08-11 via /firmaudit. Workspace: `~/Desktop/BUGS/stacks-pox5-audit/` (13/13 spine artifacts). Clone: `~/Desktop/BlackBox/stacks`.

**Verdict: NULL-COÛTEUX, RE-SOURCE.** The intake correctly ID'd pox-5.clar as FRESH ore (3845-line Epoch-4.0 sBTC-signer-bond rewrite, live on mainnet 2026-07-30, sha256 deployed==local==GitHub), not the picked-clean pox-4 core. But depth found no payable finding:
- **Theft is doubly dead:** FENCED by ToB issue **#7301** (OPEN, unfixed — bond rollover doesn't remove old shares; kills the whole total-sbtc-staked-invariant/reward-share class) AND **dormant** (`get-total-sbtc-staked` = live uint **0** — sBTC bond system deployed but $0). The Immunefi OOS dedup covers open+closed GitHub issues/PRs.
- **Consensus surface genuinely well-built** (all executed-refuted): zero-lock→block-invalidation defended by miner `is_problematic`→drop (miner.rs:662-672); prepare-phase contract-vs-node differential benign (contract freezes 1 block before node snapshot); signer weight = uSTX and stays locked, sBTC not slashable (`grep slash|forfeit|penal=0`); signer-grant crypto sound (SIP-018, recover-pinned); costs_5 is a deliberate Callgrind recalibration not underpricing; .cost-vote retired (SIP-044).
- **One hardening note (NOT payable, unreachable):** node-side signer-set linked-list iterator `StakeEntryIteratorPox5::fallible_next` (signer_set.rs:363-455) walks `next` with no visited-set/bound; `add-signer-to-set-for-cycle` (pox-5.clar:3446) has no double-add guard → a cyclic list would hang every node (Critical) — but the Clarity biconditional `in-LL ⟺ delegated≥MIN` holds on all untrusted paths (2 delegation writers 1591/1747), so unreachable today. Good direct-disclosure goodwill note to Stacks team.

**Node P2P/RPC surface ALSO swept (2026-08-11) → NULL-COÛTEUX.** Workspace `~/Desktop/BUGS/stacks-node-audit/`. Well-hardened L1: codec exhaustively capped (MAX_MESSAGE_LEN/GETPOXINV_MAX_BITLEN/STACKERDB_INV_MAX/inbox_maxlen=1024); callreadonly per-call bounded (cost+30s-wall+mem+10-clients); all panic sites guarded + release build wraps overflow (no arithmetic-panic subclass). Best 2 candidates both Medium-ceiling/dedup-high/reachability-caveated: (A) GetNakamotoInv unthrottled ~2100-iter cold-cache scan on the p2p thread (read-handles, no halt); (C) callreadonly runs 30s Clarity INLINE on the single P2P+RPC thread while block_proposal was offloaded to a spawned thread (Rule-8 inconsistency) — but bounded + KNOWN class (stacks-core issue **#7403** open on "RPC route-table rebuild degrades the HTTP/p2p thread"). Low p_bounty; did NOT sink a PoC week into it.

**Verdict on the whole Stacks program: mature 4+yr $1.8M-paid heavily-hardened L1 — low p_bounty for new findings on BOTH the SC and node surfaces. RE-SOURCE to a fresher/off-chain/less-saturated target.**

**Re-arm triggers:** (1) sBTC TVL becomes non-zero → re-open L1-lockup-proof-forgery + reward-distribution (dormant-theft). (2) callreadonly-inline (C) could be pursued as a Medium IF a testnet PoC quantifies real signer/consensus degradation AND it differentiates from #7403 — low EV, operator's call.

Lessons: [[feedback-a-known-issue-note-is-a-dup-fossil]] (an OPEN ToB issue in the repo fences the whole class), [[ev-gate-check-program-responsiveness-not-just-severity]] (live TVL read flipped the theft target to $0 — always read it), [[feedback-reachability-is-kill-gate-not-severity-modifier]] (the unbounded iterator dies on reachability, not severity). Zest V2 is the sibling Stacks/Clarity engagement ([[zest-v2-stacks-next-target]]).
