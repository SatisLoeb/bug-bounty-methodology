# Drift-watch — pre-loaded engagements on code you've already mapped

Thesis (why this beats cold sourcing): the bounty market is saturated and competitive; the ONE
edge a solo keeps is being FIRST when new code arms a seam you already understand. You have ~138
worked repos with verdicts/seams. When one drifts onto a re-arm trigger, you engage with the thesis
pre-loaded while the field starts cold. This watches your own stock instead of re-sourcing.

## Files
- `watchlist.tsv` — every git repo under ~/Desktop with its BASELINE head (the state each verdict was
  frozen on), remote, branch, and whether it has a dossier. Regenerate baselines only after you
  RE-ENGAGE a target (a verdict is frozen at its baseline; moving it silently loses the drift signal).
- `triggers.tsv` — per-target `id \t watched-globs \t re-arm-keyword-regex`. These encode the exact
  conditions that reopen a fortress/NO-GO (e.g. Lombard: a new Mailbox handler / _mint msgRecipient /
  ratio() consumer). Add a row when you verdict a new target.
- `drift-check.sh [id-filter]` — fetches each watched branch, compares baseline vs remote tip, prints:
  no-drift · drift (new commits, none on watched paths) · DRIFT*path · DRIFT+TRIG (a new commit hits a
  re-arm keyword) · FROZEN (detached contest snapshot) · FETCHERR.

## Run
    ~/Desktop/drift-watch/drift-check.sh              # all dossier repos (network-heavy, ~138 fetches)
    ~/Desktop/drift-watch/drift-check.sh D-cve        # subset by id substring
    ~/Desktop/drift-watch/drift-check.sh lombard

## Read the output
- DRIFT+TRIG = look NOW: a new commit touched a re-arm keyword on a target you verdicted. Highest EV.
- DRIFT*path = new commits on the in-scope contract dir (no keyword) — skim the diff.
- drift = churn off the watched paths — usually noise (CI/tests/docs).
- Beware trigger false positives: a keyword in a TEST/refactor line is not a re-arm. Confirm the
  commit changes PRODUCTION logic in the seam before engaging (see first-run: Stacks miner.rs test hit
  = noise; Granite liquidator.clar change = real).

## Re-baseline discipline
After you re-engage a drifted target and re-verdict it, update its baseline_head in watchlist.tsv to
the new tip. Until then, leave it — the diff baseline..tip IS the fresh slice to hunt.

## First run (2026-09-15) — signals captured in FIRST-RUN-2026-09-15.md

## Daily cloud routine (created 2026-09-15)
- **Routine**: `drift-watch-daily` · ID `trig_01J8z1dJDsjqJHtjYnbyi2ca`
- **Link**: https://claude.ai/code/routines/trig_01J8z1dJDsjqJHtjYnbyi2ca
- **Schedule**: `0 7 * * *` (07:00 UTC = 08:00 Africa/Algiers), daily. Env: Default. Model: sonnet-5.
- **What**: self-contained `git ls-remote` on the 15-repo daily set (baselines embedded in the routine prompt = `daily-watch.today.tsv`; evk-periphery dropped 2026-09-15 — only Securitize in scope, not cheaply filterable via ls-remote), compares tips, and on any actionable drift writes ONE Gmail DRAFT to loopt1793@gmail.com (compare-URL + re-arm triggers). Silent on no-drift. Draft-only (connector has no autonomous send). stacks-core tip-changes suppressed unless a literal epoch-4.1 height appears.
- **Prompt source of truth**: `cloud-routine-prompt.txt`. To change the watched set / baselines: edit the prompt + re-baseline `daily-watch.today.tsv`, then `RemoteTrigger update trig_01J8z1dJDsjqJHtjYnbyi2ca`.
- **Re-baseline after acting on a drift**: bump that repo's tip in the routine prompt so it stops re-alerting.

## A5 fresh-surface watch (added 2026-09-17) — `fresh-surface-watch.sh`
The HEAD-drift watch above monitors ALREADY-MAPPED stock (re-engagement). Once that stock is
exhausted (every target a fortress/NO-GO — the state on 2026-09-17), HEAD-churn is mostly noise.
The access-layer's A5 channel needs FRESH surface, so this second watcher adds two signals the
HEAD watch is blind to:
- **A5a NEW-REPO**: `gh repo list` per seam-dense org (`fresh-surface/orgs.txt`) vs baseline →
  a new repo = a new product = fresh (often Tier-0) surface. Baselines in `fresh-surface/repos.<org>.baseline`.
- **A5b IMPL-DRIFT**: reads each watched proxy's EIP-1967 impl slot (`fresh-surface/proxies.tsv`)
  vs baseline (`fresh-surface/impl.<id>`) → an impl change = fresh DEPLOYED code. Born from the
  2026-09-17 Lombard A1 pass: deployed != repo, so HEAD watching misses deployments/upgrades. The
  Lombard impls are baselined at their CURRENT (older, drifted) state → the next upgrade (incl. prod
  finally shipping the repo fee-fix/rate-limits) fires an alert to re-diff.

Run: `./fresh-surface-watch.sh` (check) · `./fresh-surface-watch.sh --baseline` (re-freeze after acting).
Extend A5b by adding rows to `fresh-surface/proxies.tsv` (id⇥proxy⇥chainid) for any proxied target.

## A6 on-chain value watch (added 2026-09-26) — `onchain-value-watch.sh`
HEAD-drift (ls-remote) and impl-drift (EIP-1967) are blind to on-chain ECONOMIC state
(funding/supply/TVL). Several HELD/PARKED findings re-arm only on a value crossing:
- StackingDAO #88777 (SUBMITTED Critical insolvency): ststxbtc-token-v2 pool growth,
  the dormant redesign token going >0 (cutover imminent), and a tracking/token-v3 deploy (404->200).
- StackingDAO second-pass: stbtc-token supply >0 => the pre-launch stBTC surface is LIVE.
- Stacks pox-5 (NULL-COÛTEUX): get-total-sbtc-staked >0 => dormant-theft class re-arms.
Runs LOCALLY (Hiro reads; cloud egress blocked, same as A5). `./onchain-value-watch.sh` (check) ·
`--baseline` (re-freeze after acting). State in `onchain/stacks-values.baseline` (gitignored).

## Daily-set onboarding 2026-09-26 — 9 re-arm targets (rows 19-27)
Added to watchlist.tsv + triggers.tsv + daily-watch.today.tsv (+ cloud-routine-prompt.txt rows 19-27):
reserve-governor (HELD veto-dilution HIGH, baselined at the verdict-freeze dc27a68 so it fires the
~47-commit drift), reserve-index-dtf, symbiotic-v2 core, alchemy modular-account, avalanche libevm,
rootstock LPS, midas evm+solana, stackingdao contracts. Each trigger regex is the recorded seam.

`daily-local.sh` (cron 07:05 UTC, log-only) is the LOCAL backstop that ls-remote-checks rows 19-27
(`daily-watch.new.tsv`) + runs onchain-value-watch.sh, until the CLOUD routine is consolidated to 27.
To consolidate: the deployed prompt is ready in cloud-routine-prompt.txt (single-TASK, 27 rows) —
apply with RemoteTrigger update on trig_01J8z1dJDsjqJHtjYnbyi2ca, then daily-local becomes pure backup.
