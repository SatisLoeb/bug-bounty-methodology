---
name: immunefi-corpus-wiring
description: "Fourth corpus (Immunefi audit-comps, payer-assigned severity) and exactly where it fires automatically vs needs a manual call"
metadata: 
  node_type: memory
  type: project
  originSessionId: 4c7e8c64-208c-48a0-88d4-ad330b0b9f3d
  modified: 2026-07-31T15:44:10.348Z
---

`~/Desktop/BUGS/immunefi-corpus/` — 2971 findings, 53 competitions, 2023-11 → 2026-05, built
2026-07-31 from reports.immunefi.com. Unlike c4/solodit/web it carries **payer-assigned
severity**: the level on a page is what Immunefi awarded, and `impacts` is the verbatim in-scope
VSC string the report was accepted under. That is the W5 leg of the Weight-Card.

**Never merge its density with solodit's.** solodit = contest judge, 2 levels; Immunefi = payer,
5 levels with Insight weighted 0. Averaging them corrupts the Pendle-Boros H-density calibration
that 9 skills depend on. `corpus-query.sh` renders it as a separate block on its own scale.

Where it surfaces WITHOUT being asked:
- `corpus-query.sh <shape>` / `--route` / `--class` → Immunefi block below the solodit output
  (so any skill calling corpus-query gets it). Adds the node classes and the `L1/L2 node` shape
  solodit has no equivalent for.
- `on-finding.sh --stage 2` → auto-writes `{id}-immunefi-precedent.md` (dup-check + severity
  precedent), keyworded from the stage-1 scope-check "One-line title". Non-blocking.
- `corpus-coverage-check.sh --emit --corpus immunefi <shape> <ws>` → SC/node coverage ledger
  (web stays the default). SC targets had NO coverage gate before this; emitting a ledger is
  what arms it, since preflight already triggers on `[ -f CORPUS-COVERAGE.md ]`.

Still MANUAL: `--impacts` for /immunefi-submit scope strings. Symlinks in `~/arsenal/tools/` are
managed by no install script, and most `audit-lifecycle/bin/` scripts are UNTRACKED in the
arsenal git repo — re-create/back up by hand on a new machine.

Two repos: corpus in BUGS, wiring in `~/arsenal`. See [[protocol-fortress-null-hunt]],
[[feedback-corpus-coverage-gate-lead-dont-improvise]].
