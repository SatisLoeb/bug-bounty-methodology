# SURFACE INVENTORY — {TARGET}
> Generated: {DATE} (init stub — Phase-0 auto-sweep PENDING)
> Perimeter: in-scope + adjacent (flagged). Playbook: ~/.claude/skills/SURFACE-INVENTORY-PLAYBOOK.md

## ⚠️ PHASE-0 AUTO-SWEEP NOT YET RUN
This is the init stub. Before the first hunt, run the **auto-exhaustive surface sweep** (agent fan-out)
per `~/.claude/skills/SURFACE-INVENTORY-PLAYBOOK.md` to fill the table below EXHAUSTIVELY:
- enumerate EVERY route/endpoint (typed client in bundles + OpenAPI + lazy/off-disk chunks fetched + live probe), EVERY host, EVERY off-chain seam, EVERY contract/module/deployed-address, AND companion/native apps (RN/Expo/mobile).
- one row per surface; flag IN-SCOPE / ADJACENT / OOS; record method · mutates? · auth · status.
- this is HUNT-INDEPENDENT: enumerate everything first, the status column records what gets chased later.
Token cost is a non-constraint; a silently-unmapped surface is the only cost that counts (the Injective-web lesson: 49 routes catalogued, ~6 audited, the virgin list had to be reconstructed by hand later).

Delete this banner once the sweep has filled the table.

## Scope anchor
<one line: what the program lists as in-scope + the adjacency rule used>

## Surfaces
| # | Surface (method+path / contract / host / seam) | Class | Scope | Mutates? | Auth | STATUS | Artifact / why |
|---|---|---|---|---|---|---|---|
| | | | | | | UNAUDITED | |

## Status legend
- **UNAUDITED** — enumerated, never probed (the virgin list — a re-engagement reads these FIRST)
- **IN-PROGRESS** — currently being audited
- **COVERED+artifact** — audited, executed artifact exists (cite it)
- **KILLED+reason** — audited, no finding, executed disconfirmer (cite it)
- **LIVE-FINDING** — a finding came out of it (cite the report id)
- **OOS** — out of scope (quote the scope line that excludes it)

## Coverage summary
Enumerated: 0 · UNAUDITED: 0 · COVERED/KILLED: 0 · LIVE: 0 · OOS: 0

---
*Status column is living memory — update each row as the engagement proceeds (on-finding / kill-gate / null bump it). No "engagement complete / fortress" verdict while any IN-SCOPE row is UNAUDITED. End-of-engagement file-level completeness = COVERAGE-LEDGER-PLAYBOOK.md (the SC twin of this file).*
