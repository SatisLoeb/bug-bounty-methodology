# Audit Lifecycle

Single source of truth for audit lifecycle events across all skills (gravedigger, mrrobbot, manual).
Skills delegate per-phase hooks to scripts in `bin/`. Templates in `templates/`. Helper libs in `lib/`.

## Why

Gates, pre-gate severity commit, and OUTCOMES instrumentation must fire AUTOMATICALLY regardless
of which skill initiates the audit. Putting enforcement inside each skill creates drift. Putting
enforcement in a shared lifecycle means every entry point converges on the same procedure.

## Architecture

```
audit-lifecycle/
├── bin/                          # lifecycle scripts — invoked by skills or manually
│   ├── init-target.sh            # on target start (idempotent)
│   ├── on-finding.sh             # on finding candidate (before draft write)
│   ├── preflight-mechanical.sh   # before submit (4 deterministic gates, hard block)
│   ├── on-submit.sh              # at send time (OUTCOMES append with timestamps)
│   └── on-hold.sh                # at hold decision (held_reason + uncertainty_source)
├── templates/                    # copied into workspace on init
│   ├── SEVERITY-COMMIT.md        # pre-gate framing commit, artifact-required
│   ├── PROGRESS.md               # workspace context recovery + gate stack checklist
│   └── OUTCOMES-schema.json      # canonical schema for OUTCOMES.jsonl entries
├── lib/                          # helpers, invoked by bin/ scripts
│   ├── target-router.sh          # emits ROUTING.md with activated checklists
│   ├── artifact-validator.sh     # SEVERITY-COMMIT artifact_proves check
│   └── marker.sh                 # .lifecycle-status marker I/O
└── tests/                        # retroactive simulation + integration tests
```

## Lifecycle events

| Event | Script | Trigger |
|---|---|---|
| target start | `bin/init-target.sh` | First action of any audit session |
| finding candidate | `bin/on-finding.sh` | Before opening draft file |
| draft ready | `bin/preflight-mechanical.sh` | Before submit, after draft + all gates |
| submit | `bin/on-submit.sh` | At send time |
| hold | `bin/on-hold.sh` | At hold decision |

## Enforcement

- `.lifecycle-status` marker written in workspace by each script with timestamp
- `preflight-mechanical.sh` refuses if `init-target` or `on-finding` markers missing for this finding
- `OUTCOMES.jsonl` records `preflight_run: true/false` — if false rate > 20% over 30 days,
  the infrastructure is being ignored and must be re-bound to workflow

## Rules invoked (CLAUDE.md)

| Rule | Name | Enforced by |
|---|---|---|
| #26 | RPC namespace probe | target-router (web/DeFi target) |
| #29 | Authenticated session testing | target-router (web/API target) |
| #30 | Authorization consistency matrix | on-finding + preflight |
| #33 | Lock contention cross-subsystem | target-router (blockchain node) |
| #35 | 5 fund theft checks | target-router (SC target) |
| #36 | Chain Proof Gate (D7) | preflight-mechanical |
| #37 | Weight Card (D8a + D8b) | preflight-mechanical |
| #38 (NEW) | Lifecycle init mandatory | init-target marker |
| #39 (NEW) | SEVERITY-COMMIT artifact-required | on-finding + artifact-validator |

## Skill integration (Phase C — not yet done)

`~/.claude/skills/gravedigger/SKILL.md` and `~/.claude/skills/mrrobbot/SKILL.md` will be
modified to invoke `bin/` scripts at the corresponding phase boundaries.

## Phase A vs Phase B

**Phase A (current skeleton):**
- Directory + templates + skeleton scripts with orchestration logic
- `init-target.sh`, `on-finding.sh`, `on-submit.sh`, `on-hold.sh` fully functional
- `preflight-mechanical.sh` and `artifact-validator.sh` implement minimal checks
- CLAUDE.md rules #38 + #39 added

**Phase B (after diagnostic validates patterns on 10-12 retroactive failures + WEEX-002 positive control):**
- `preflight-mechanical.sh` populated with validated grep patterns (D7 hedge, D8a narrative, D10 compliance)
- `artifact-validator.sh` verifies artifact resolves + `artifact_proves` field present + severity matches min()
- D8b cast-call readback check wired for TVL-claim findings

**Phase C (skill integration, 0.5 day):**
- Modify gravedigger/SKILL.md and mrrobbot/SKILL.md
- Wire lifecycle invocations at phase boundaries

**Phase D (validation, 0.5 day):**
- Retroactive simulation on 3 historical targets (SC, web, blockchain node)
- Measure invocation overhead (target < 5 sec on init)
- Verify no friction on nominal path

## Configuration

Environment variables:
- `LIFECYCLE_ENFORCE` — `soft` (warnings only) or `hard` (blocks). Default: `soft` during first 30 days.
- `TARGET_HINTS` — classifier keywords for target-router.sh (solana / smart.contract / blockchain.node / web / mobile / defi).
- `WORKSPACE` — override default workspace path.

## Sanity

Every script has `# INVOCATION CONDITION:` commented in its header documenting when it must run.
If unsure, read the header.
