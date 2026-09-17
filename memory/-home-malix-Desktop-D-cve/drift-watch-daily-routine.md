---
name: drift-watch-daily-routine
description: "Daily cloud routine that alerts when new code lands on 16 mapped bounty repos' money-paths"
metadata: 
  node_type: memory
  type: project
  originSessionId: c639357a-aca4-4017-84b4-5a00b153de69
  modified: 2026-09-17T08:46:37.142Z
---

Drift-watch is the operator's answer to "programmes limités + concurrence rude": instead of fresh sourcing, monitor the already-mapped stock (~/Desktop/drift-watch/, 121 repos baselined) for post-verdict code changes that RE-ARM a known seam, so the operator is FIRST when new code lands.

**System location**: `~/Desktop/drift-watch/` — `watchlist.tsv` (192 baselined), `remote-watchlist.tsv` (121, git ls-remote, no clones), `daily-watch.today.tsv` (16 curated high-value repos re-baselined 2026-09-15), `triggers.tsv` (per-target re-arm keyword regex), `drift-check-remote.sh`, `FULL-SWEEP-WORKLIST-2026-09-15.md`.

**Daily cloud routine** (created 2026-09-15): `drift-watch-daily`, ID `trig_01J8z1dJDsjqJHtjYnbyi2ca`, https://claude.ai/code/routines/trig_01J8z1dJDsjqJHtjYnbyi2ca. Cron `0 7 * * *` (07:00 UTC = 08:00 Africa/Algiers). Env Default, model sonnet-5, Gmail connector. Self-contained: baselines embedded in the routine prompt (`~/Desktop/drift-watch/cloud-routine-prompt.txt`), `git ls-remote` each of 16 repos, and on drift writes ONE Gmail DRAFT to loopt1793@gmail.com (connector = draft-only, no autonomous send). Silent on no-drift.

**Fresh money-path drift as of 2026-09-15 full sweep** (candidate pre-loaded engagements — still need live-bounty + audit-comp gate before engaging): Euler oracle-adapter (new ChainlinkInfrequentNanosecondOracle) + evk-periphery; Reserve CowSwapFiller; Coinbase AuthCaptureEscrow; OKX RFQ-PMM; Nado Clearinghouse; Yield Basis AMM. Granite core-v1 is DRIFT+TRIG but known (the submitted finding is being remediated there — see [[granite-clarity-findings]]).

**How to maintain**: after acting on a drift, bump that repo's tip in `cloud-routine-prompt.txt` + `daily-watch.today.tsv` and `RemoteTrigger update`. stacks-core drift is suppressed unless a literal epoch-4.1 height appears ([[stacks-fresh-drift-epoch41-dormant]]). NO-GO repos (alchemix 527-comp, termmax saturated, pendle fortress) stay watched because a NEW mechanism can re-arm them.

**A5 ADDITION 2026-09-17** (`drift-watch/fresh-surface-watch.sh` + `fresh-surface/`, local, baselined+tested): the HEAD-watch above monitors already-mapped stock; once that's ALL exhausted (every target a fortress/NO-GO — [[coinbase-venue-exhausted]], [[project-lombard-finance-audit]]), HEAD-churn is mostly noise. This adds the access-layer's A5 FRESH-surface signals — **A5a NEW-REPO** (`gh repo list` per seam-dense org in `fresh-surface/orgs.txt` vs baseline = a new product = fresh, often Tier-0, surface) and **A5b IMPL-DRIFT** (EIP-1967 impl slot of proxies in `fresh-surface/proxies.tsv` vs `fresh-surface/impl.<id>` = fresh DEPLOYED code, born from the Lombard A1 deployed-not-head lesson). Lombard core impls baselined at their current OLDER state → the next upgrade (incl. prod shipping the repo fee-fix/rate-limits) fires an alert, operationalizing the Lombard A1 parked lead. **A5 IS LOCAL-ONLY (resolved 2026-09-17): tested hooking it into the cloud routine — the cloud egress policy HARD-BLOCKS the GitHub org API ("sessions bound to configured repositories, use repo-scoped endpoints") and arbitrary RPCs return nothing. Cloud routine = HEAD-drift (git ls-remote) ONLY (that works); A5a/A5b run LOCALLY where gh+cast work. Run `./fresh-surface-watch.sh` by hand (or a LOCAL cron), not in the cloud.**
