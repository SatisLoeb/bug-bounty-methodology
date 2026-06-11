# Machine2 Sync Instructions

**Date:** 2026-04-04
**Update:** H1 Hacktivity Pattern Database + Skills Integration

---

## 1. Pull Arsenal Repo

```bash
cd ~/arsenal
git pull --rebase origin main
```

New files:
- `methodology/H1-HUNTING-PATTERNS.md` — 60+ patterns from 2,500+ disclosed H1 reports
- `methodology/H1-STATISTICS.md` — bounty ROI analysis + target selection heuristics

---

## 2. Update Skills (COPY FROM MACHINE1)

The skills on machine1 have been patched with H1 pattern integration. Machine2 must apply the same patches.

### Option A: Copy skills directly (if machines share network/ssh)

```bash
# From machine2:
scp machine1:~/.claude/skills/mrrobbot/SKILL.md ~/.claude/skills/mrrobbot/SKILL.md
scp machine1:~/.claude/skills/gravedigger/SKILL.md ~/.claude/skills/gravedigger/SKILL.md
```

### Option B: Apply patches manually

#### mrrobbot SKILL.md — 2 patches

**Patch 1: Pattern Databases table** (after MULTI-LANG-PATTERNS row)

Add these 2 rows to the Pattern Databases table:

```markdown
| `~/arsenal/methodology/H1-HUNTING-PATTERNS.md` | HackerOne hacktivity patterns: IDOR, SSRF, RCE, race conditions, auth bypass, business logic, API, cache, AI/LLM | 60+ patterns |
| `~/arsenal/methodology/H1-STATISTICS.md` | Bounty ROI analysis, payout distribution, target selection heuristics, industry patterns | Data-driven |
```

**Patch 2: Second Pass Methodology** (after the existing second pass table ending "...they span multiple contracts.")

Add a new subsection `### Web/API Second Pass (H1 Patterns)` with the 10-step detection priority matrix. See machine1 `~/.claude/skills/mrrobbot/SKILL.md` for exact content.

#### gravedigger SKILL.md — 5 patches

**Patch 1: Resource table** (after DEFI-FULLSTACK-CHECKLIST row)

```markdown
| `~/arsenal/methodology/H1-HUNTING-PATTERNS.md` | **HackerOne hacktivity patterns** — 60+ patterns: IDOR, SSRF, RCE, race conditions, auth bypass, business logic, API, cache, AI/LLM. 13 categories with grep detection + chain potential. | For ANY web/API target (auto-activate in Phase 2) |
| `~/arsenal/methodology/H1-STATISTICS.md` | Bounty ROI analysis, payout distribution by vuln type, target selection heuristics, industry patterns | Phase 0.5 deep mode decision + target prioritization |
```

**Patch 2: Phase 2 Surface Mapping** (after §2.19 Container Layer Analysis, before the closing ```)

Add `§2.20 H1 Pattern Scan` — 11-step auto-activated detection priority matrix.

**Patch 3: Phase 4 Deep Analysis** (after §4.12 Shared lock analysis, before the closing ```)

Add `§4.13 H1 Deep Dive Patterns` — SSRF chain escalation, race PoC, auth bypass chain, IDOR chain, business logic, cache attacks, smuggling, AI/LLM, + 4 mandatory meta-patterns.

**Patch 4: Non-Negotiable Rules** (after rule 28)

Add:
- Rule 29: H1 meta-patterns mandatory on ALL web/API targets (M-H1-001 to M-H1-010)
- Rule 30: AI/LLM as fastest-growing attack surface (+540% YoY)

**Patch 5: Integration Points** (before `JWT-ARSENAL-PLAYBOOK.md` section)

Add `### From H1-HUNTING-PATTERNS.md (Auto-Activated on ANY Web/API Target)` section.

---

## 3. Update CLAUDE.md (~/Desktop/BUGS/CLAUDE.md)

Add these rules after rule 33 (Lock contention cross-subsystem audit):

```markdown
34. **MANDATORY for web/API targets: H1 hacktivity pattern scan** — Apply the detection priority matrix from `~/arsenal/methodology/H1-HUNTING-PATTERNS.md` on every web/API engagement. 13 categories, 60+ patterns extracted from 2,500+ disclosed HackerOne reports. Key meta-patterns: M-H1-001 (inconsistent auth across interfaces — REST vs GraphQL vs WebSocket), M-H1-002 (destructive ops have weaker auth than read ops), M-H1-003 (race windows in state transitions), M-H1-004 (user-controlled URLs = SSRF candidates), M-H1-007 (session tokens before auth complete = MFA bypass), M-H1-008 (same resource different route different auth), M-H1-010 (always chain — IDOR read=$1K vs IDOR->ATO=$12K). ROI data in `~/arsenal/methodology/H1-STATISTICS.md`: IDOR+auth bypass outpay XSS 3:1. AI/LLM vulns +540% YoY (P-H1-100, P-H1-101).
```

---

## 4. Verify

```bash
# Check files exist
ls ~/arsenal/methodology/H1-*.md

# Check skills reference H1 patterns
grep -c "H1-HUNTING" ~/.claude/skills/mrrobbot/SKILL.md    # expect >= 3
grep -c "H1-HUNTING" ~/.claude/skills/gravedigger/SKILL.md  # expect >= 5

# Check CLAUDE.md has the new rule
grep -c "H1-HUNTING\|M-H1-" ~/Desktop/BUGS/CLAUDE.md       # expect >= 1
```

---

## What Changed (TL;DR)

Scanned HackerOne's entire disclosed hacktivity. Key findings:

1. **IDOR + auth bypass now outpay XSS 3:1** — hackbots saturate surface XSS (78% of bot findings)
2. **$81M annual H1 payouts** — top 10 programs = $21.6M (27%)
3. **AI/LLM is the fastest-growing category** — +540% prompt injection, 1,121 programs with AI in scope
4. **Race conditions on financial ops** — quick to test, direct $ impact, fast triage
5. **SSRF via PDF gen/webhooks/imports** — still the path to cloud metadata/RCE chains
6. **Authorization consistency gaps** — the Request Finance pattern (MFA delete without re-auth) generalizes across all web targets

Pattern database uses same format as C4-HUNTING-PATTERNS.md. Each pattern has: source report, severity, entry point, invariant violated, grep detection, false positive guard, chain potential.

Both skills now auto-activate H1 patterns on any web/API target (gravedigger Phase 2 §2.20, Phase 4 §4.13; mrrobbot Second Pass Web/API).

---

## 2026-04-18 Update: Audit Lifecycle Infrastructure

**Date:** 2026-04-18
**Scope:** Phase A–D complete — automatic gate/pre-gate/instrumentation firing regardless of skill entry path.

### 1. Pull arsenal + sync skills + CLAUDE.md

```bash
cd ~/arsenal
git pull --rebase origin main

# Sync canonical copies to runtime locations (Machine 2)
cp ~/arsenal/skills/gravedigger/SKILL.md  ~/.claude/skills/gravedigger/SKILL.md
cp ~/arsenal/skills/mrrobbot/SKILL.md     ~/.claude/skills/mrrobbot/SKILL.md
cp ~/arsenal/CLAUDE.md                    ~/Desktop/BUGS/CLAUDE.md
```

### 2. audit-lifecycle — new directory at `~/arsenal/audit-lifecycle/`

Shared lifecycle enforcement for all skills (gravedigger, mrrobbot, security-disclosure, manual). 13 files, 1327 lines total.

**Structure:**
```
~/arsenal/audit-lifecycle/
├── bin/                          # lifecycle scripts
│   ├── init-target.sh            # MANDATORY first action of any target
│   ├── on-finding.sh             # per-finding gate instantiation
│   ├── preflight-mechanical.sh   # deterministic gates (D0, D8b, D10, hygiene)
│   ├── on-submit.sh              # OUTCOMES append with timestamps + tier commits
│   └── on-hold.sh                # held_reason enum + uncertainty_source
├── templates/
│   ├── SEVERITY-COMMIT.md        # pre-gate framing, artifact-required per tier
│   ├── PROGRESS.md               # gate stack checklist + context recovery
│   └── OUTCOMES-schema.json      # extended schema with held_reason, preflight_run, tier fields
├── lib/
│   ├── target-router.sh          # 6 target classes + blind spot warnings
│   ├── artifact-validator.sh     # artifact structure + severity equation consistency
│   └── marker.sh                 # .lifecycle-status I/O
├── README.md                     # architecture + phase roadmap
└── tests/diagnostic-retroactive.md   # Phase diagnostic blind-prediction report
```

### 3. CLAUDE.md — 2 new rules

**Rule #38** — Lifecycle init mandatory first action (after rule #37)
**Rule #39** — SEVERITY-COMMIT artifact-required before draft (after rule #38)

Both enforced mechanically by `~/arsenal/audit-lifecycle/` scripts. See rules text in `~/arsenal/CLAUDE.md` lines 298–300.

### 4. Skill integrations (gravedigger + mrrobbot)

**gravedigger SKILL.md — 3 new blocks:**
- Phase -1: Lifecycle Init (before Phase 0, ~line 69)
- Phase 3 Kill Gate: on-finding.sh invocation + artifact-validator requirement (~line 306)
- Phase 6.7/6.8/6.9: preflight-mechanical + on-submit + on-hold (~line 522)

**mrrobbot SKILL.md — 3 new blocks:**
- Phase -1: Lifecycle Init (before Phase 0 Triage, ~line 326)
- Phase 1 Check Matrix: on-finding.sh + artifact-validator (~line 409)
- Phase 4.7/4.8/4.9: preflight-mechanical + on-submit + on-hold (~line 604)

### 5. OUTCOMES.jsonl — extended schema

New fields added for diagnostic phase measurement (tracked via `retroactive: true` for backfills):
- `evidence_tier` (L1/L2/L3/L4)
- `chain_tier` (unverified/partial/full_ethical)
- `impact_tier` (narrative/computed_W1/W5_anchored/both_W1_W5)
- `severity_committed` (the tier committed in SEVERITY-COMMIT.md)
- `drafted_at`, `gates_run_at`, `submitted_at`, `result_at`, `held_at`
- `preflight_run` (bool — visible in 30-day metric: if false rate > 20%, infra being ignored)
- `rejected_by_gate` (array of gate names that blocked)
- `held_reason` enum: rep_gate / deposit_pending / geo_block / awaiting_validation / gate_failed_unresolved / self_uncertainty / framing_unclear
- `uncertainty_source` enum (required if held_reason = self_uncertainty): technical_doubt / severity_doubt / scope_doubt

5 April 2026 entries backfilled retroactively with pre-gate would-block verdict for diagnostic calibration. See `~/arsenal/audit-lifecycle/tests/diagnostic-retroactive.md`.

### 6. Diagnostic validation results

Blind pre-gate predictions ran on 12 historical failures + WEEX-002 positive control:

- **Pre-gate standalone preventability: 33% clean wins** (not the 60% estimate from earlier round — cherry-picked)
- **Pre-gate combined with D8b + Q1/Q2/Q10 + artifact-resolves: 75% coverage**
- Phase B2 surfaced: added `severity_committed ≤ min(evidence, chain, impact)` equation check to artifact-validator after Phase D simulation exposed that Phemex R2 pattern (L3/full/narrative + High commit) was structurally valid but equation-violating

### 7. Verify after sync

```bash
# audit-lifecycle exists and scripts executable
ls ~/arsenal/audit-lifecycle/bin/ ~/arsenal/audit-lifecycle/lib/
test -x ~/arsenal/audit-lifecycle/bin/init-target.sh && echo "OK"

# CLAUDE.md rules 38/39 present
grep -cE '^38\. \*\*MANDATORY — Lifecycle|^39\. \*\*MANDATORY — SEVERITY' ~/Desktop/BUGS/CLAUDE.md  # expect 2

# Skills reference arsenal paths (not old Desktop/BUGS paths)
grep -c '~/arsenal/audit-lifecycle\|/home/malix/arsenal/audit-lifecycle' ~/.claude/skills/gravedigger/SKILL.md  # expect >= 6
grep -c '~/arsenal/audit-lifecycle\|/home/malix/arsenal/audit-lifecycle' ~/.claude/skills/mrrobbot/SKILL.md     # expect >= 6

# Smoke test — init a throwaway workspace
TARGET_HINTS="smart.contract solidity" ~/arsenal/audit-lifecycle/bin/init-target.sh verify-sync /tmp/verify-sync-audit
ls /tmp/verify-sync-audit/ && rm -rf /tmp/verify-sync-audit
```

### 8. What changed (TL;DR)

- Gates/pre-gate/instrumentation now fire AUTOMATICALLY regardless of skill entry path
- SEVERITY-COMMIT artifact-required constraint prevents 3000-word HIGH inflation (HRB-001 pattern) at the FRAMING stage, not post-draft
- Pre-gate preventability honestly measured at 33% standalone / 75% combined — NOT the 60% cherry-picked estimate from early planning
- held_reason + uncertainty_source tracking surfaces whether gates have moved from protection to inhibition (target: `self_uncertainty + framing_unclear < 25%` over 30d)
- `preflight_run: false` rate is the drift signal — if > 20% over 30d, infrastructure is being ignored and rules have drifted from enforcement to decoration
- Phase B2 equation check (`severity ≤ min(evidence, chain, impact)`) catches the Phemex R2 pattern mechanically

**Canonical source:** `~/arsenal/audit-lifecycle/` — Machine 1 + Machine 2 both reference this path. No Desktop/BUGS duplication.
