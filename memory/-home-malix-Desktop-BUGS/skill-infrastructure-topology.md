---
name: skill-infrastructure-topology
description: "Where the operator's custom skills live, how Claude Code loads them, the 3-location sync, and which skills are missing on this machine"
metadata: 
  node_type: memory
  type: project
  originSessionId: 676ee768-18be-4105-b623-333fd6940088
---

The operator's custom audit skills (firmaudit, darkside, gravedigger, mrrobbot, report-nerve, chill, expand-surface, exploit-primitive-mindset, upshift, upshift2, screenshot, immunefi-submit, disclose) live in THREE locations, kept aligned by `~/arsenal/tools/sync-skills.sh`:

- **Source of truth (git):** `~/Desktop/methodology-backup/skills/` — committed via "sync methodology backup". 13 methodology skills.
- **Working copy:** `~/arsenal/skills/`
- **Loadable by Claude Code:** `~/.claude/skills/<name>/SKILL.md` — **this is the ONLY path Claude Code (v2.1.185) scans for personal skills.** `~/arsenal/skills/` is NOT scanned; no setting makes it discoverable.

Loading facts: `~/.claude/skills/` being NEWLY created needs a CC restart (file-watcher); thereafter edits hot-load. Skill name = the `name:` frontmatter field (authoritative), NOT the dir name — so dir `security-disclosure` with `name: disclose` is invoked `/disclose`. Frontmatter MUST be valid YAML: a `description:` plain-scalar containing `: ` (e.g. `nobody owns: audited`) is INVALID and silently fails to load — wrap such descriptions in a folded block scalar (`>-`), which is what was done to firmaudit/report-nerve/exploit-primitive-mindset/screenshot/upshift/upshift2 (backups `.bak-frontmatter`).

**5 skills (`extract`, `power`, `wide`, `orca`, `invfuzz`) are NEW — first formalized 2026-06-22, never existed on machine-2 (operator: "ces skills sont nouveau je ne les ai jamais sync avec machine 2"). There is NO canonical version elsewhere; these ARE the canonical version.** Now installed (18 skills total). Provenance: `power` + `extract` = operator-dictated verbatim; `orca` formalized from CLAUDE.md Rule 43; `invfuzz` from `citrea-fresh-2026-06-22/invfuzz-headerchain/INVARIANTS.md` (real executed usage); `wide` from `bitget-wide/analysis/` (real usage). The 3 formalized-from-artifact ones carry a note "refine as you use it" (not "replace with machine-2 version" — there is none). They will reach machine-2 only when the operator pushes `methodology-backup` git (which now holds all 18) and pulls there. Veins: power=AUTHZ-probe (sondage par exécution), extract=MATH-EXTRACTIBLE (chaîne de gates par vitesse-de-mort), invfuzz=INVARIANT-DIFFERENTIAL (harness différentiel vs lib de référence + reachability-gate), wide=ALLOCATION-stage0 (ratio capacité/plafond, où creuser), orca=package-ROUTING. **Corpus is wired into the hunting skills** via `~/arsenal/tools/corpus-query.sh <shape>` (reads c4-patterns/PATTERN-TAXONOMY.md 163 + solodit-corpus indexes in place); a `## PATTERN BANK (corpus-query)` hook is in firmaudit/darkside/mrrobbot/gravedigger/orca. To add/replace a skill: drop it in `~/Desktop/methodology-backup/skills/` then run `sync-skills.sh` (validates + propagates; auto-converts colon-bearing descriptions to block scalars). `find-skills` is a system skill symlinked from `~/.agents/skills/`, kept out of the methodology backup and protected from `--mirror` deletion via the script's `KEEP_EXTRA` list. Relates to [[feedback-verify-before-working-no-theater]] (the whole topology was discovered by execution, not assumed).
