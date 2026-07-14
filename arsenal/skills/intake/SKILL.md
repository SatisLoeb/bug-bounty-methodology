---
name: intake
description: >-
  Target intake dispatcher — the FRONT DOOR for any new audit target. Given a repo / scope URL /
  package / protocol-name, it classifies the target, builds a corpus-loaded TARGET-DOSSIER.md
  (class-density -> detection tell -> named pattern -> discovery method -> the VEIN/skill to
  activate), and SUGGESTS the right hunting skill ranked with reasoning. It NEVER auto-invokes the
  chosen skill (no-auto-orchestration, the U-1 rule) — it proposes, the operator confirms and
  launches. Composes the existing classifiers (target-router.sh, saturation-score.sh, timebox-check.sh,
  phase0-intel.sh) and the corpus (corpus-query --route). Use FIRST on any new target, before
  picking a hunting skill. Trigger on "/intake", "nouvelle cible", "par ou commencer sur X",
  "quel skill pour X", "brief moi sur cette cible", "on regarde X".
---

# intake — target dispatcher (classify → brief → SUGGEST the skill)

You are the FRONT DOOR. The operator presents a target; you (1) classify it, (2) build a
corpus-loaded dossier, (3) RECOMMEND the right hunting skill. You do NOT hunt — the chosen skill
hunts. You do NOT launch anything — the operator confirms, then launches.

## 🛑 THE ONE RULE — you SUGGEST, you NEVER auto-invoke
A dispatcher that auto-launches another skill recreates the **U-1 auto-orchestration bug** (a skill
firing `/disclose` or cascading a multi-skill engagement from a passive trigger — the exact conflict
the darkside audit found in upshift and fixed). So you END your run with a RANKED recommendation +
the dossier + a single line: *"confirme et je lance `/X`, ou tu lances toi-même."* Then STOP. The
operator stays in the loop between intake and engagement. Building a dossier and naming a skill is
NOT invoking it.

## Input
A repo path, a scope URL, a package name, or just a protocol name + "audited? / TVL?". Read-only:
you classify and brief; you don't clone-and-hunt here.

## Phase 1 — Classify (COMPOSE the existing brains; never re-implement them)
The classification machinery already exists. Run it, read its verdicts — don't duplicate the logic.

```bash
# canonical bootstrap (Rule 38) — emits ROUTING.md + saturation + timebox in one shot, IF you have a workspace/clone:
TARGET_HINTS="<keywords>" ~/arsenal/audit-lifecycle/bin/init-target.sh <target-name>

# or run the classifiers directly for a lighter triage:
TARGET_HINTS="<keywords>" ~/arsenal/audit-lifecycle/lib/target-router.sh <name>   # -> domain + checklists + gate-stack
~/arsenal/audit-lifecycle/bin/saturation-score.sh --workspace <path>              # -> saturation score (audit_count × top-tier × delta); HIGH → RE-SOURCE to a payable surface
~/arsenal/audit-lifecycle/bin/timebox-check.sh <target-dir>                        # -> STANDARD_8H vs L1_EXCEPTION
~/arsenal/audit-lifecycle/bin/phase0-intel.sh <repo> [owner/repo] [audit-base-commit]  # -> repo recon + audit-count + post-audit delta
```
`TARGET_HINTS` keywords: `solana anchor` / `smart.contract solidity` / `web api rest` /
`blockchain.node p2p` / `mobile android` / `defi fintech` / `lrt restaking` / `zk-circuit` /
`mpc threshold` / `relayer bridge oracle` (infra-adjacent) / `cantina c4` (web2-on-SC). Multiple
combine; additive playbooks (web2-on-SC, crypto-lib, infra-adjacent) fire on top.

Then **map the domain → a corpus SHAPE** (for SC): lending / AMM/DEX / vault/yield / bridge /
perp/derivatives / staking/LST / stablecoin / governance / NFT. (`corpus-query --list` for the set.)
WEB/API shapes now have their own corpus (`web-corpus-query.sh`, see Phase 2); pure off-chain shapes have no corpus (route to gravedigger/upshift).

**Override two STALE bits emitted by target-router.sh** (verified 2026-06-23, flag them in the dossier):
- It says *"Immunefi PERMANENT boycott → OUT OF SCOPE"* — **WRONG**: the boycott was LIFTED 2026-06-01.
  Immunefi is a live channel; `/immunefi-submit` is permitted (Step-0 vault/scope scan still applies).
- It points at *"C4-HUNTING-PATTERNS.md (128 patterns)"* — **superseded** by the 163-pattern corpus
  (`corpus-query`). Use the corpus, not the 128 bank.

## Phase 2 — Build the corpus dossier (the new value — the 4 layers)
For an SC shape, pull all four layers:
```bash
corpus-query <shape>            # AIM   : class-density priority + each class's detection_tell + named P-* patterns
corpus-query --route <shape>    # ROUTE : per top class -> the VEIN (skill) to activate + how many methods exist
corpus-query --methods <class>  # HOW   : the discovery techniques (run for the top-2 classes of the shape)
```
Then pull **precedent (W5 anchor) — TWO sources, FILTERED, never a loose protocol grep:**
```bash
# (1) industry anchor (always available, classified): the shape's top class, its H/M counts + example titles
corpus-query --class <top-class>
# (2) operator's OWN track record — ONLY severity-anchoring outcomes (a REJECTED row is NOT a precedent),
#     matched on the shape's actual classes (pass them comma-separated). Usually empty per-shape — that's fine.
python3 - "$HOME/Desktop/BUGS/OUTCOMES.jsonl" "accounting,liquidation,oracle,rounding" <<'PY'
import json, sys
keep = {"bounty_paid", "fixed", "acknowledged"}          # drop rejected / ignored / informative / pending
terms = [t for t in sys.argv[2].lower().split(",") if t]
for l in open(sys.argv[1]):
    l = l.strip()
    if not l: continue
    try: r = json.loads(l)
    except: continue
    if r.get("outcome") not in keep: continue
    blob = (str(r.get("reason","")) + str(r.get("finding","")) + str(r.get("protocol",""))).lower()
    if any(t in blob for t in terms):
        print(f"  {r.get('protocol')}: {r.get('outcome')} {r.get('reward','')}  ({r.get('channel','')})")
PY
```
The corpus `--class` is the load-bearing precedent (industry-validated across 4670 findings); the OUTCOMES
filter only adds YOUR own paid hit if one exists on this shape. If it prints nothing → say "no prior
operator finding on this shape; corpus anchor carries it" — do NOT pad it with rejected rows.
For a WEB/API target there is now a parallel corpus — the **Solodit-for-web** (15.7K disclosed findings / 292 probe
recipes, VRT-anchored). Pull the same 4 layers via its mirror tool:
```bash
~/arsenal/tools/web-corpus-query.sh <shape>       # AIM   : top classes by PAYOUT-density (NOT count — web payouts vary 100x)
~/arsenal/tools/web-corpus-query.sh --route <c>   # ROUTE : detection_tell + the named P-H1-* patterns + the vein
~/arsenal/tools/web-corpus-query.sh --methods <c> # HOW   : the discovery_how PROBE RECIPES (the web killer mode — lead here)
~/arsenal/tools/web-corpus-query.sh --class <c>   # precedent: 2-axis ($ + high_density) + exemplar links
```
Web shapes: REST-API · GraphQL · OAuth-SSO · SaaS-multi-tenant · payment-fintech · file-upload · SSRF-cloud ·
JWT-session · webhook · admin-panel · mobile-API · AI-LLM-app. The web-corpus calibration: **rank by payout-density,
NOT count** (a count-sorted web map ranks XSS#1@low-pay and buries the high earners — ATO/SQLi/RCE). Still pair with
`precedent-scan.sh` for the operator's own track record. For pure off-chain/infra with no web surface, the corpus does not apply.

## Phase 3 — Route to the skill (the decision matrix → SUGGEST, then STOP)
Compose the saturation-score (Phase 1) + the shape's top-class→vein (`--route`) + firmaudit's Path A/B/C/D:

| Target profile | Suggest |
|---|---|
| Audited / **saturated** (saturation-score HIGH) | **Prefer RE-SOURCE to a payable surface (web/API/off-chain/fresh) — the theft that survived the audits lives there, not deeper in the picked-clean core.** Only if a fresh/web/off-chain sub-surface exists on this target: `/darkside` (Door C — the no-CWE composition bug the audits missed) [+ `/firmaudit` for a full engagement] |
| SC fresh / moderate (0-5 audits on scope) | `/exploit-primitive-mindset` (class-select) → then `/mrrobbot` or `/gravedigger` |
| Off-chain DeFi orchestration (executor / keeper / backend signs on-chain) | `/upshift` |
| Web / API | `/gravedigger` |
| Multi-surface (exchange / wallet + extension + web + webview) | `/wide` (allocate depth first) |
| Novel surface (ZK / MPC / AA-4337 / compiler / DA / LRT) | `/expand-surface` |
| npm / GitHub package | `/orca` first (deployed-vs-SDK, custom-vs-fork) |
| "where do I start / is it worth it" + high value, wants depth | `/firmaudit` (the deep engine; reads the others as reference) |

**Then, within the chosen engine, name the depth-VEIN from `--route`**: if the shape's top class is
accounting → the engine runs mrrobbot's check-matrix; rounding → `/extract`; oracle → `/invfuzz`;
access-control → `/power`. The vein is the *technique*; the skill above is the *engine*.

Output: **1-2 skills ranked + the WHY** (saturation-score, shape, top-class→vein, precedent) + the
dossier path. Close with *"confirme et je lance, ou tu lances."* **Do not invoke. Stop here.**

## Phase 4 — Write `TARGET-DOSSIER.md` (the brief the chosen skill READS)
Instantiate this in the target's workspace (survives context compression — the firmaudit Phase-0 /
PROGRESS.md pattern). The chosen skill reads it FIRST and starts pre-loaded.

**WRITE it automatically — NEVER ask permission to write the dossier.** Producing the brief file IS
the skill's job (Phase 4 runs silently). The ONLY thing you ever confirm is Phase 3 (whether to
LAUNCH a suggested skill). A dossier is not an outward-facing action; it needs no sign-off. (If the
operator imposed a blind/no-peek constraint on an already-audited target, write to a FRESH workspace
path — never read or overwrite the existing one.) Template:

```markdown
# TARGET DOSSIER — <target>   (intake <date>)

## Classification
- Domain: <SC/web/off-chain/...>   Shape: <lending/...>   Chains: <...>
- Saturation score: <LOW/MED/HIGH>  (audits: <n>, auditors: <...>, post-audit delta: <y/n>)  [HIGH → RE-SOURCE to a payable surface unless a fresh/web/off-chain sub-surface exists]
- Time-box: <STANDARD_8H / L1_EXCEPTION>   EV gate: <STRONG GO/GO/WEAK GO/SKIP>
- Scope/exclusions: <fund-theft only? frontrunning excluded? KYC? vault balance $X>
- Stale-bit overrides applied: Immunefi NOT boycotted (lifted 2026-06-01); use corpus-163 not C4-128.

## Corpus AIM (corpus-query <shape>)
<top class-density + each tell + the named P-<SHAPE>-* patterns>

## Corpus ROUTE (corpus-query --route <shape>)  — which vein per class
<the per-class -> vein table; DEPTH ROUTE = top-2 classes' veins>

## Corpus HOW (corpus-query --methods <top-2 classes>)
<the discovery techniques for the 2 densest classes>

## Precedent (W5 anchor)
- Industry (corpus --class <top-class>): <class H/M counts + 1-2 example titles>
- Operator's own (OUTCOMES, paid/fixed/acked only — drop rejected): <"<class> paid $X on <protocol>" | "none on this shape">

## RECOMMENDED SKILL(S)
1. /<skill> — <why: saturation/shape/vein/precedent>
2. /<alt>   — <why>
(SUGGESTION ONLY — operator confirms before launch.)
```

## Session brief — what EVERY dossier carries (baked, so the chosen skill is never cold)
- **The corpus exists**: 4670 findings, 163 named patterns, 4588 discovery methods. Query it with
  `corpus-query <shape> | --route <shape> | --methods <class>` — AIM, vein-route, technique.
- **The class→vein map** is empirical (proven on 4670 findings): accounting→check-matrix,
  oracle→invfuzz, rounding→extract, access-control→power, liquidation→mrrobbot:Phase-3.
- **Discovery-door doctrine**: on a fortress the catalogued classes are already swept — the win is
  **Door C** (`/darkside`, the no-CWE composition bug). gravedigger/mrrobbot/exploit-primitive-mindset
  now carry a `/darkside` pointer; use it on any audited target.
- **No-auto-orchestration**: every skill SUGGESTS, the operator launches. `/disclose` is always
  operator-gated. (This dispatcher obeys the same rule it enforces.)
- **`feedback_*` gap**: the deep "Full rule:" elaboration files live on machine-2 (not synced here);
  the rules survive INLINE in each skill. Don't chase a missing `feedback_*.md` — read the inline rule.

## What this skill does NOT do
- It does not hunt (the chosen skill hunts) · does not write a finding · does not launch a skill.
- On a WEB/API target it pulls the web-corpus (`web-corpus-query.sh`); on pure off-chain/infra it routes by domain (gravedigger/upshift/wide), corpus n/a.
- It is a 5-10 min front door, not an engagement. The EV gate can return **SKIP** (dormant vault,
  saturated fortress with no unsaturated surface) — say so plainly and route to a different target.
