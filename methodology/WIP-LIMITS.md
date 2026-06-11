# WIP Limits — Kanban discipline for solo hunter

**Rationale:** Cognitive bandwidth, not time, is the scarce resource at $17K/2.5mo trajectory with ~50 open projects across memory. Fragmentation between projects costs more than the audit work itself. Kanban-style WIP caps force closure before expansion.

## The three buckets

| Bucket | Max | What counts |
|---|---|---|
| **Active** | **3** | Target requires write / audit / PoC iteration THIS week. Mrrobbot Phase 1-3, gravedigger scanning, ongoing contest. |
| **Ready to Submit** | **2** | Finding drafted, preflight gate pending, or awaiting disclosure channel setup. |
| **Waiting Triage** | ∞ | Submitted + no action needed today. Governed by `archive-stale.sh`, not by this cap. |

## Enforcement

- Before opening a new Active project: check count via `dashboard.sh`. If 3 already, EITHER close one (submit Ready → Waiting, or archive) OR defer new target.
- Before moving a target to Ready: check Ready count. If 2 already, push a Ready to submission first or block the transition.
- Waiting Triage is NOT capped — a submitted report with relance-pending does not consume cognitive bandwidth continuously. It consumes 15 min on relance day.

## What triggers transitions

```
[Identified target]
      ↓ decision to hunt
  [Active] ──── submission ready ───→ [Ready to Submit]
      ↓                                      ↓ submit
   kill/skip                             [Waiting Triage]
      ↓                                      ↓ accepted/rejected/stale
  [Archived]                             [Closed]
```

## Violation response

`dashboard.sh` flags:
- **Active > 3** → "WIP violation: close one before continuing"
- **Ready > 2** → "Submit backlog: push oldest Ready first"
- **Active + Ready combined > 5** → "Overall context overload — halt new intake"

## Why 3+2 and not 8

Earlier proposal of 8 mixed Active/Waiting. Fragmentation metric is about **targets demanding decisions/writing this week**, not targets awaiting a 15-min relance. Active=3 matches real focus capacity (one primary, one secondary for mood/context switch, one background). Ready=2 prevents submission backlog from becoming its own queue.

## Exceptions

- Waiting Triage with `disclosure_deadline` within 14 days briefly re-enters Active count during escalation prep. Does not require Active closure if the escalation itself is <4h work.
- Multi-chain contest (e.g., Transak, LayerZero stellar) counts as 1 Active even if spans multiple platforms, as long as the audit methodology is unified.

## Integration

- `dashboard.sh` — prints current counts + violations
- `archive-stale.sh` — handles Waiting Triage decisions (out of scope of this doc)
- CLAUDE.md — reference at top of project intake section
