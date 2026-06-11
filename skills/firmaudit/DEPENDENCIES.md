# firmaudit — external dependency manifest

SKILL.md references files OUTSIDE this folder. If one moves/changes/is-absent, the skill degrades **silently** (references go hollow but it still looks functional). This manifest lets you detect desync. Last verified: **2026-06-08, all 13 present.**

## Hard dependencies (skill hard-blocks or mis-routes if absent)
| Path | Role | If missing |
|---|---|---|
| `~/arsenal/audit-lifecycle/bin/init-target.sh` | Rule-38 first action (workspace init) | run init manually; Phase 0 has no scaffold |
| `~/arsenal/audit-lifecycle/bin/phase0-intel.sh` | scripted Phase 0 points 1-5,8 | fill Phase 0 by hand |
| `~/arsenal/methodology/SC-PATH-PATTERNS.md` | Phase T T4 path-graph edges (SC-P-01..16) | path graph from memory only |
| `~/arsenal/methodology/H1-HUNTING-PATTERNS.md` | Phase T T4 web edges (M-H1-*) | web path graph from memory only |

## Reference skills (read-as-reference, NOT auto-invoked — §Operating mode)
| Path | Role |
|---|---|
| `~/.claude/skills/exploit-primitive-mindset/SKILL.md` | class-before-code intake lens |
| `~/.claude/skills/gravedigger/SKILL.md` | Path C (web/API) cadence |
| `~/.claude/skills/mrrobbot/SKILL.md` | Path D (SC >$50K) cadence |
| `~/.claude/skills/upshift/HUNT-METHODOLOGY.md` | Path B (off-chain orchestration) cadence |
| `~/.claude/skills/upshift2/SKILL.md` | seam-thesis source (Phase S) + vector packs |

## Playbooks (loaded per target class in the Adaptive Plan)
| Path | Class |
|---|---|
| `~/Desktop/BUGS/WEB2-ON-SC-PROGRAMS-PLAYBOOK.md` | web2 layer on SC programs |
| `~/Desktop/BUGS/CRYPTO-LIB-HUNT-PLAYBOOK.md` | N-way crypto-lib bugs |
| `~/Desktop/BUGS/INFRA-ADJACENT-TO-SC-PLAYBOOK.md` | relayers/bridges/oracles/keepers |
| `~/Desktop/BUGS/LIQUIDATION-READPATH-PLAYBOOK.md` | lending-protocol off-chain liquidation-SDK/keeper read-path (7 proven bug classes, Morpho-validated) |
| `~/.claude/skills/darkside/SKILL.md` (+ its `DARKSIDE-HUNT.md` tactical doc) | **MANDATORY lens (§🌑)** — now the standalone **darkside** skill: Door A defensive-coverage matrix (PRIMARY) / Door B dev-paranoia (FALLBACK) / thief-inventory admission gate / 5-axes analyzer / manual loop / exit gate. firmaudit invokes it at Pass-1. |
| `~/Desktop/BUGS/FIRM-AUDIT-PROMPT.md` | raw paste-mode equivalent of this skill (keep in sync) |

## NOT dependencies (engagement OUTPUTS the skill creates — do not pre-expect)
`analysis/*` (AUDIT-CONDITIONS, RECON-PROBES, INVENTORY-PASS-{1,2}, PRIMITIVES-MAP, ROOT-CAUSE-MAP), `recon/*` (SEAM-STATEMENT/CANDIDATES, DISCIPLINES-MAP), `findings/*`, `TRIAGE-CARD.md`, `PHASE0-INTEL.md`, `_negative-results.md`, `CHAIN-TRIAGE-<target>.md`.

## Desync check (run before a serious engagement)
```bash
for f in ~/arsenal/audit-lifecycle/bin/init-target.sh ~/arsenal/audit-lifecycle/bin/phase0-intel.sh \
  ~/arsenal/methodology/SC-PATH-PATTERNS.md ~/arsenal/methodology/H1-HUNTING-PATTERNS.md \
  ~/.claude/skills/darkside/SKILL.md ~/.claude/skills/darkside/DARKSIDE-HUNT.md \
  ~/.claude/skills/{exploit-primitive-mindset,gravedigger,mrrobbot,upshift2}/SKILL.md \
  ~/.claude/skills/upshift/HUNT-METHODOLOGY.md ~/Desktop/BUGS/FIRM-AUDIT-PROMPT.md \
  ~/Desktop/BUGS/{WEB2-ON-SC-PROGRAMS,CRYPTO-LIB-HUNT,INFRA-ADJACENT-TO-SC}-PLAYBOOK.md; do
  [ -e "$f" ] && echo "OK $f" || echo "MISS $f  <-- skill degraded"
done
```
A `MISS` means SKILL.md points at something gone — fix the path or restore the file before trusting that section.
