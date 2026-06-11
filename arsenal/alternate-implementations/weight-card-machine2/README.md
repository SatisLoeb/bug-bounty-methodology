# Weight Card — Machine 2 Alternate Implementation

**Purpose:** Parallel implementation of the Weight Card feature built on machine 2 at the same time as machine 1 built `b9916cf` (the canonical version now on main). Both implementations resolve the same plan with the same design decisions from the user critique (gate vs dashboard, W1 escape hatch, W6 fused into PoC, W4 distinct from D7, DoS alternate anchor, precedent-scan copy-paste-ready output). They diverge on wording, structure density, and a few tactical choices.

**This directory is NOT active.** The canonical files on main (`checklists/WEIGHT-CARD.md`, `tools/precedent-scan.sh`, etc.) come from machine 1's commit `b9916cf`. This directory exists so machine 1 can diff and cherry-pick any element from the machine 2 version if it's better.

**Source commit:** `066cd40` (never pushed to remote; dropped via `git reset --hard origin/main` after the conflict). Files extracted from reflog and placed here.

---

## Files in this directory

### Full new files (machine 2 version)

| File | Purpose | Compare against |
|---|---|---|
| `WEIGHT-CARD.md` | Template with Stages 1-4, 5 slots, gate exceptions | `checklists/WEIGHT-CARD.md` (machine 1 canonical) |
| `precedent-scan.sh` | Shell tool — H1 corpus grep + copy-paste W5 block | `tools/precedent-scan.sh` (machine 1 canonical) |
| `INSTRUCTIONS-MACHINE1-WEIGHT-CARD.md` | Sync instructions (direction: machine 2 → 1) | `methodology/INSTRUCTIONS-MACHINE1-WEIGHT-CARD.md` (machine 1 canonical) |
| `feedback_weight_card.md` | Per-machine memory file content | `~/.claude/projects/-home-malix-Desktop-BUGS/memory/feedback_weight_card.md` |

### Snippets for modified files

| File | Purpose | Compare against |
|---|---|---|
| `snippets/CLAUDE-rule-37.md` | Just the rule #37 block | `CLAUDE.md` rule #37 in machine 1 canonical |
| `snippets/PREFLIGHT-D8-row.md` | Just the D8 row added to table | `checklists/PREFLIGHT-CHECK.md` D8 row |
| `snippets/PREFLIGHT-scoring-block.md` | Updated scoring + decision logic | same file |
| `snippets/REPORT-STANDARD-weight-accounting.md` | Full Weight Accounting section | `methodology/REPORT-STANDARD.md` |
| `snippets/gravedigger-weight-card-addition.md` | The MANDATORY line I added in Phase 6 | `skills/gravedigger/SKILL.md` |
| `snippets/mrrobbot-weight-card-addition.md` | The MANDATORY line I added in Phase 4 | `skills/mrrobbot/SKILL.md` |

---

## Key differences machine 2 vs machine 1

### WEIGHT-CARD.md structure
- **Machine 1** (canonical, 282 lines): slot descriptions include explicit `Role:` headers per slot, a table-formatted W3 reversibility audit with Present/Proof/Effective columns, war log seeded with Phemex R2 AND retroactive WEEX-002 row.
- **Machine 2** (this dir, 240 lines): slot descriptions inline without explicit `Role:` headers, W3 is prose-formatted, war log with only Phemex R2. Slightly more compact, same functional coverage.

### CLAUDE.md rule #37
- **Machine 1**: contains the anti-pattern grep pattern embedded **in the rule itself** (visible at session start).
- **Machine 2**: mentions anti-pattern phrases but does not include the full grep pattern in the rule body — it's in the memory file and WEIGHT-CARD.md instead.

### precedent-scan.sh
- **Machine 1** (227 lines): more elaborate extraction helpers (`extract_report_id` with 30+ vendor patterns, `extract_first_dollar`, `extract_class_label`), strict `set -euo pipefail`.
- **Machine 2** (199 lines): simpler greppy approach, `set -u` only, returns 2 rows for IDOR / 4 rows for SSRF (machine 1 returns 2 / 3 respectively). Fallback "W5 EMPTY" message is more verbose in machine 2.

### Anti-pattern phrase grep
- **Machine 1**: `could drain|could extract|could potentially|significant funds|substantial losses|large number of users|many users|many accounts|estimated to|potentially affects|at risk|exposes users to|attacker could extract|could lead to|may result in|would enable loss of|all users|all deposits|all funds`
- **Machine 2**: `could drain|could extract|significant funds|substantial losses|large number of users|many users affected|potentially affects|widespread impact|catastrophic|devastating|severe financial damage|exposes users to|estimated to cost|impact is significant|attacker could (drain|extract|steal)`
- **Union** (if cherry-picking both): would add "widespread impact", "catastrophic", "devastating", "severe financial damage", "impact is significant", "could potentially", "many accounts", "at risk", "could lead to", "may result in", "would enable loss of", "all users", "all deposits", "all funds". Extended coverage at no cost.

### Skills integration
- **Machine 1**: Weight Card added as a **dedicated step 6.0b** (gravedigger) / **top-of-Phase-4 block** (mrrobbot) alongside Chain Proof Gate as 6.0a. More structured, 25 lines each.
- **Machine 2**: Weight Card added as an **inline MANDATORY line** next to the existing Chain Proof Gate MANDATORY line, no numbered step. More compact, 4 lines each.

### Gate exceptions
- **Both**: pure info disclosure at Informational/Low + SC state delta + DoS alternate anchor + response-is-impact.
- **Machine 2**: explicitly lists "Smart contract findings where the forge-test state delta is the anchor" as a distinct exception (W1 implicit).

### Retroactive test framing
- **Machine 1** war log: Phemex R2 only.
- **Machine 2** war log: Phemex R2 + hypothetical WEEX-002 row showing how Weight Card would have market-priced it.

---

## Recommended cherry-picks for machine 1 (if any)

1. **Extended anti-pattern phrase grep** — unioning the two lists gives broader coverage without cost. Consider merging into CLAUDE.md rule #37, WEIGHT-CARD.md anti-pattern section, and feedback_weight_card.md.
2. **Retroactive WEEX-002 war log row** — machine 2's war log includes WEEX-002 as a retroactive positive case. Useful for future reference when explaining why both gates exist.
3. **"W1 implicit for SC state delta" exception phrasing** — machine 2 is more explicit about why SC findings auto-pass W1. Could improve clarity.

Machine 1's canonical version is better on: precedent-scan.sh robustness (more extraction helpers, vendor patterns), skills integration structure (numbered step 6.0b is clearer), W3 table format, rule #37 containing the grep pattern inline.

---

## Source commit reflog reference

```
066cd40 HEAD@{4}: commit: feat: Weight Card — 5-slot dashboard + D8 gate for non-Informational findings
```

Original commit message (truncated):

> Complementary gate to Chain Proof Gate (24cd46d), addressing a distinct
> failure mode: findings with a proven chain but a narrated (not computed)
> impact. Phemex R2 lesson (submitted 2026-04-10, marked Informative
> 2026-04-13): API key escalation had chain proof but no numerical anchor
> for profitable extraction — plateau'd at Informative, 2 rep, $0.
>
> Chain Proof Gate answers "does the exploit execute?".
> Weight Card answers  "is it profitable, market-priced at what?".

Full content of all files in this directory was generated autonomously by Claude on machine 2 in the same session where machine 1 independently built `b9916cf`. No coordination between the two implementations — they converged independently from the same approved plan.
