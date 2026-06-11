# darkside — external dependency manifest

SKILL.md references files OUTSIDE this folder. If one moves/changes/is-absent, the skill degrades **silently** (references go hollow but it still looks functional) — the failure mode the germe was re-suspended to escape, now in dependency form. This manifest lets you detect desync. Last verified: **2026-06-11.**

## Hard dependencies (skill hard-blocks, mis-routes, or loses its admission gate if absent)
| Path | Role | If missing |
|---|---|---|
| `~/.claude/skills/darkside/DARKSIDE-HUNT.md` | **Primary companion** (internal tactical doc, listed here as the load-bearing reference). Holds the GATE §0 (fortress score / N-KILLs=STOP / depth-is-earned), the two-door catalogues (§1 Door A primary / §2 Door B fallback), the 5-axes-as-analyzer §3, the delta-hunt §4, the MANUAL LOOP §5, the THIEF INVENTORY + chain-triage §6, and the EXIT §7 (drop-on-EV ≠ drop-on-fatigue). | Skill has no manual loop, no fortress gate, no exit rule — it is the GATE+DOORS+LOOP+EXIT body. Restore before any engagement. |
| `~/.claude/skills/firmaudit/SKILL.md` (§🔗 CHAIN-TRIAGE) | The THIEF INVENTORY fuses with this section. Door-A/B candidates enter the primitive inventory Pn; admission gate = "does this dark place store a primitive toward a concrete THEFT path?"; pair-hunt + shared-ROOT + anti-inflation (every hop executed, attacker net-positive) are defined there. | The validator half of the skill is gone. Door A/B would localize dark candidates but nothing admits/rejects them by chainability-to-theft — the exact "localizes but never validates" failure the skill exists to fix. |
| `~/arsenal/audit-lifecycle/bin/preflight-mechanical.sh` | KILL-GATE Q1-Q10 + 22/24 PREFLIGHT enforcement at the close of the manual loop (hard-blocks on gate failure). | Kill-gate/preflight run by hand from the templates below; no hard-block, weaker findings can slip through. |
| `~/Desktop/BUGS/KILL-GATE-TEMPLATE.md` | The Q1-Q10 checklist text the manual-loop KILL-GATE step applies per candidate. | Kill-gate questions from memory only; design-intent / reachability / industry-known checks degrade. |

## Reference (read-as-reference — the germe's evidence base, NOT auto-invoked)
| Path | Role |
|---|---|
| `~/arsenal/audit-lifecycle/bin/` (`init-target.sh`, `preflight-mechanical.sh`) | Lifecycle scripts the manual loop calls at KILL / submit (source of truth; markdown is human reference, script wins on drift). |
| `~/Desktop/BUGS/PREFLIGHT-CHECK.md` | 24-point rubric backing the preflight gate. |
| `…/memory/feedback_test_dont_read_dev_attack_tests_method.md` | **DOOR A primary source** — mine the devs' adversarial test suite, find the untested SIBLING at the same pattern (injective voucher = the only Critical). The germe itself. |
| `…/memory/feedback_dev_paranoia_map_comments_invariants.md` | **DOOR B primary source** — grep `CRITICAL\|should never\|must never\|impossible\|INCONSISTENT STATE` + `*_invariants_check.go`; comment = LEAD not finding; disconfirmer = ENUMERATE EVERY WRITER, never "by inspection"; fail-safe severity gate (PAUSE/skip/log = DoS-not-theft = often Info). |
| `…/memory/feedback_thief_mode_unwritten_invariant_door_c.md` | **DOOR C primary source** — thief-mode not catalogue-mode: diff target vs canonical form → list design DEVIATIONS → make explicit the UNWRITTEN invariant (tell: dev comment defends one side, silent on the other) → attack the belief by an untrusted actor (composition of 2-3 deviations). The F-STALE-NAV win that A/B + a catalogue-mode pipeline missed. Runs PARALLEL to A/B, no fan-out, mandatory on fortresses. |
| `…/memory/feedback_chain_triage_score_pairs_not_isolation.md` | Source for the thief-inventory pair-hunt + anti-inflation discipline (twin of the firmaudit §CHAIN-TRIAGE hard dep). |
| `…/memory/feedback_unbiased_fork_poc.md` | The unbiased-PoC controls the manual-loop PoC step must satisfy (config parity, no-mocks-on-tested-leg, honest baseline+victim, attacker-pays-full-freight, real-mechanism price/time, run-the-disconfirmer). |
| `…/memory/feedback_gravedigger_manual_darkcorner_method.md` | Why dark corners are dug BY HAND one-to-the-bottom (broad agent fan-out cannot replace it); structure-by-real-EV, aim-the-disconfirmer-at-the-load-bearing-leg. |
| `…/memory/feedback_fortress_target_selection_ev_gate.md` | Upstream fortress-score / EV-gate feeding GATE §0 (fortress = NO-GO or fresh-delta-only). |
| `…/memory/feedback_no_shallow_dismissal_go_to_bottom.md` | The fail-fast-DIRECTS-not-RETAINS discipline: a gated branch redirects to the sibling branch of the SAME surface, never condemns the surface. |

## NOT dependencies (engagement OUTPUTS the skill creates — do not pre-expect)
`analysis/DEFENSIVE-COVERAGE-MATRIX.md` (Door A worklist), `analysis/DEV-PARANOIA-MAP.md` (Door B), `THIEF-INVENTORY-<target>.md` / `CHAIN-TRIAGE-<target>.md` (primitives Pn + pairs), `findings/*`, `_negative-results.md`, signed VERDICT cards.

## Desync check (run before a serious engagement)
```bash
for f in ~/.claude/skills/darkside/DARKSIDE-HUNT.md \
  ~/.claude/skills/firmaudit/SKILL.md \
  ~/arsenal/audit-lifecycle/bin/preflight-mechanical.sh \
  ~/arsenal/audit-lifecycle/bin/init-target.sh \
  ~/Desktop/BUGS/KILL-GATE-TEMPLATE.md ~/Desktop/BUGS/PREFLIGHT-CHECK.md \
  ~/.claude/projects/-home-malix-Desktop-BUGS/memory/feedback_{test_dont_read_dev_attack_tests_method,dev_paranoia_map_comments_invariants,thief_mode_unwritten_invariant_door_c,chain_triage_score_pairs_not_isolation,unbiased_fork_poc,gravedigger_manual_darkcorner_method,fortress_target_selection_ev_gate,no_shallow_dismissal_go_to_bottom}.md; do
  [ -e "$f" ] && echo "OK   $f" || echo "MISS $f  <-- skill degraded"
done
grep -q "CHAIN-TRIAGE" ~/.claude/skills/firmaudit/SKILL.md || echo "MISS firmaudit §CHAIN-TRIAGE anchor  <-- thief-inventory fusion broken"
```
A `MISS` means SKILL.md points at something gone — fix the path or restore the file before trusting that section. A missing **Door-A source** or the **firmaudit §CHAIN-TRIAGE anchor** is the worst kind: the skill still runs Door B and the 5 axes, so it looks alive while having lost the bounded entry point and the admission criterion — re-collapsing into the contemplative abstraction this skill was built to replace.
