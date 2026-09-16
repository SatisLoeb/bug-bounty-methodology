---
name: pyth-network-audit
description: Pyth Network Immunefi audit — SC/oracle core is a fortress, NULL-COÛTEUX; the payable surface is the web seam
metadata:
  type: project
---

Pyth Network ($250k Immunefi, Primacy of Rules, downstream-excluded, KYC+PoC, no fee). Folder `pyth/`.
19-finder fan-out (wf_cfc61113-db4) + operator solo diff + 6 leaf-verifications + 1 live on-chain kill.

**Verdict: NULL-COÛTEUX on the SC/oracle surface.** No payable theft/freeze/governance bug.
- Fresh veins are competently built (hand-read to leaf, all hold): Cardano guardian-quorum
  (`has_quorum`+`not_ordered_subset`), Lazer EVM `verifyUpdate` (staleness is consumer's job by
  design), Lazer Sui v2 parse, Entropy commit-reveal (blockhash bias mitigated by `BlockhashUnavailable`).
- Two synthesis leads REFUTED at leaf: Entropy `revealWithCallback` `req` stale-pointer = attacker-
  confined (every corrupted request has requester=attacker, Gate 1); staking positions `#[account(zero)]`
  non-canonical length = memory-safe (capacity floors + Rust bounds-check).
- The one Critical-class thread (#2 governance cool-off disenfranchisement) = **reachability-null,
  killed on mainnet**: staking config PDA `6RYqefZNXXATuXrgXfSxi9rDj9JS1bi5CQkRwyyQ72Bd` epoch=7d,
  realm `4ct8XU5…Paug4`, both GovernanceV2 accounts have `voting_cool_off_time = 0` → no cool-off
  phase → disenfranchisement window doesn't exist.
- Permissionless `merge_target_positions` (Voting target, no Signer) IS real but self-healing griefing
  (no stake/weight loss) → sub-payable. `create_stake_account` freeze needs victim to deposit into
  attacker's account → SE/Gate1.
- Scope edges: Cardano `pyth`/`pyth/message` (price sig check) = external dep `pyth-lazer-cardano` = OOS;
  governance `integrity-pool`/`publisher-caps` = siblings NOT literally listed (only `staking/programs/staking`).

**RE-SOURCE:** the web seam **staking.pyth.network** (asset #9) is the highest-EV surface — the fan-out
couldn't reach it (needs live browser, not source review), and per playbook 100% of comparable payouts
came from a web/API seam not SC core. Staking program ID `pytS9TjG1qyAZypk7n8rw8gfW9sUaqqYyMhJQ4E7JCQ`.
Method note: Immunefi RSC decode + audit-corpus-txt/ dedup + on-chain reachability via solders+mainnet RPC.
See [[immunefi-webfetch-scope-page-mangles-rewards]].
