---
name: bounty-submission-tracking-convention
description: Where bug-bounty submission status lives in the ~/Desktop workspace (ledger + per-folder signals)
metadata: 
  node_type: memory
  type: reference
  originSessionId: f1411939-ea42-4b62-b9c5-c2d5a2f96fdb
  modified: 2026-09-08T13:03:10.738Z
---

To tell if a finding in `~/Desktop` was submitted vs still a draft, check these, in order:

- **Master ledger:** `~/Desktop/BUGS/OUTCOMES.jsonl` — one JSON line per engagement (`protocol`, `id`, `severity_claimed`, `outcome`, `date_submitted`, `payout_usd`, `finding`). `outcome` is authoritative: submitted states = `pending`/`accepted`/`rejected`/`duplicate`/`informative`/`escalated`/`bounty_paid`/`disputed`/`closed_*`; NOT-submitted states = `no_go*`/`earned_null`/`*ready_to_submit`/`*not_yet_submitted`/`skip*`/`held*`/`dropped`. Per-folder `OUTCOMES.jsonl` also exists (e.g. `mtpelerin-audit` → Immunefi #88293).
- **`.lifecycle-status`** in each audit folder: `init:`/`preflight:PASS`/`finding:`/`hold:`/`killed:` events. `preflight:PASS` = ready, NOT sent.
- **`submissions/` folder** = submission-READY reports; presence ≠ sent. A real report ID/URL, or a dispute/triage/response/mediation/rebuttal file, = actually submitted.

A finding is "valide pas encore soumis" only if it's confirmed/reproduced AND absent from the ledger's submitted-set AND has no report-ID/dispute artifact. See [[bounty-workspace-layout]]. Reference corpora to EXCLUDE from any finding sweep: `BUGS/immunefi-corpus`, `BUGS/solodit-corpus` (other people's reports), and `~/Desktop/NEXUS` (user's own product, not a target).
