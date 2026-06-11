# PROGRESS — {TARGET}

> Last updated: [timestamp]
> Workspace: [path]
> Skill invoked: [gravedigger / mrrobbot / manual]

## Context Recovery Protocol

On EVERY new session or context compression:
1. Read this file FIRST — it contains the complete audit state.
2. Do NOT re-fetch contracts / files already marked as audited below.
3. Continue from the NEXT ACTIONS section.

Before EVERY context compression or end of session:
1. Update this file with: new findings, contracts read, gaps discovered, updated next actions.
2. Move completed items out of NEXT ACTIONS.
3. Update the timestamp on the top line.

---

## Lifecycle status

- [ ] `init-target.sh` run → [ISO timestamp]
- [ ] Routing identified → see `ROUTING.md`
- [ ] Findings catalogued below
- [ ] OUTCOMES.jsonl initialized

## Gate stack (enforced by preflight-mechanical.sh)

Per finding, MANDATORY order:
- [ ] Kill Gate (Q1-Q10, 30 min max)
- [ ] SEVERITY-COMMIT populated with artifact-required inputs
- [ ] Draft written
- [ ] CHAIN-PROOF-GATE (D7) — if auth-class finding
- [ ] WEIGHT-CARD (D8a numerical + D8b live conditions) — if severity ≥ Low with dollar impact
- [ ] preflight-mechanical.sh → PASS
- [ ] on-submit.sh → OUTCOMES entry

---

## Target metadata

- Protocol: 
- Platform: [C4 / Sherlock / HackenProof / H1 / Direct / other (Immunefi BOYCOTTED — skip)]
- Bounty max: 
- TVL: 
- Deadline: 
- Scope URL: 

## API keys / RPC endpoints (survives context compression)

- 
- 

## Proxy map (EIP-1967 readbacks)

| Proxy | Implementation | Verified? | Block |
|---|---|---|---|
| | | | |

---

## Findings

| ID | Severity claimed | Class | Kill gate | Severity commit | Draft | D7 | D8a | D8b | Preflight | Status |
|---|---|---|---|---|---|---|---|---|---|---|
| | | | | | | | | | | |

## Contracts / files audited

| File | Lines | Finding? | Verdict |
|---|---|---|---|
| | | | |

## Audit gaps

- 

---

## Session log

### Session 1 — [date]
- Completed:
- Next actions:

### Session 2 — [date]
- Completed:
- Next actions:

---

## Next actions (priority-ordered)

1. 
2. 
3. 
