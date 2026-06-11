---
name: expand-surface
description: Attack surface expansion and innovation dispatcher. Routes to 8 novel attack surface playbooks (AA-4337, DA layer, LRT slashing, indexer drift, post-audit drift, ZK circuits, MPC/threshold, compiler bugs) + 3 methodology multipliers (differential fuzzing, ghost finding transfer, academic paper hunt). Use when looking to explore under-explored surfaces, find bugs where others don't look, or pick a new hunting direction beyond SC fund-theft and web auth classics.
---

# Expand-Surface — Innovation and novel attack surface dispatcher

You are executing a surface-expansion workflow. The goal is NOT to audit a specific target — that's `/gravedigger` and `/mrrobbot`. This skill helps pick which novel surface to ramp on, routes to the appropriate playbook, and integrates with the audit-lifecycle so all findings funnel through the same gate stack.

**Core principle (CLAUDE.md rule #40):** NO filter-by-difficulty. Long-cycle methodologies get a cadence recommendation, high-floor methodologies get a filter-advantage note, dismissed-precedent methodologies get a retry-plan. Never a skip.

## Arguments

```
/expand-surface                         # interactive — ask what user wants to explore
/expand-surface <surface>               # route directly to a specific surface playbook
/expand-surface --list                  # list all surfaces with cadence + bounty landscape
/expand-surface --cadence               # list by time-budget (fast / medium / long-cycle / background)
/expand-surface --high-value            # list by payout ceiling (bounty size)
```

## The 11 surfaces

### Short-cycle (first bug in <2 weeks of focused work)

| Surface | Playbook | Bounty range | Why low-competition |
|---|---|---|---|
| AA-4337 / ERC-7579 smart accounts | `AA-ECOSYSTEM-HUNT.md` | $50K-$500K | requires 4337+7579+EIP-712+bundler knowledge simultaneously |
| DA layer + light client bridge | `DA-LAYER-HUNT.md` | $100K-$1M direct | nascent, DAS+Merkle+fraud proof filter |
| LRT slashing verification | `LRT-SLASHING-HUNT.md` | $50K-$500K | complex oracle+delegation interaction |
| Indexer / subgraph drift | `INDEXER-DRIFT-HUNT.md` | $5K-$50K direct | requires running indexer, "frontend adjacent" stigma |
| Post-audit drift | `POST-AUDIT-DRIFT-PIPELINE.md` | Medium-High | needs monitoring infra + domain awareness |

### Medium-cycle (first bug in 2-6 weeks)

| Surface | Playbook | Bounty range | Filter advantage |
|---|---|---|---|
| ZK circuits / proving systems | `ZK-CIRCUIT-HUNT.md` | $250K-$1M+ direct | HIGHEST knowledge floor — minimal competition |
| MPC / threshold signatures | `MPC-THRESHOLD-HUNT.md` | $50K-$5M custody | crypto+distributed systems filter |

### Long-cycle / background (continuous, hit every few months)

| Surface | Playbook | Bounty range | Cadence |
|---|---|---|---|
| Compiler / toolchain bugs | `COMPILER-BUG-HUNT.md` | $100K-$70M historic | 10h/week background fuzzing |
| Differential fuzzing | `DIFFERENTIAL-FUZZING-METHOD.md` | per-surface | background harnesses in rotation |
| Ghost finding transfer | `GHOST-FINDING-TRANSFER.md` | $2K-$20K volume play | weekly scans of forks |
| Academic paper hunt | `ACADEMIC-PAPER-HUNT.md` | $5K-$500K direct | daily RSS triage |

## Workflow

### Step 1: Determine budget + preference

Ask the user:
1. Time budget this cycle — days / weeks / months / continuous background
2. Preferred filter advantage — high-knowledge (ZK/MPC), infrastructure requirement (DA/indexer), composition complexity (AA-4337/LRT), or methodology multiplier (differential/ghost/academic)
3. Existing skills to leverage — web auth (→ AA-4337 natural), SC fund theft (→ LRT, indexer), cryptography (→ ZK, MPC, compiler)

### Step 2: Select surface + playbook

Map user's answer to surface from the table above. Read the corresponding playbook at `~/arsenal/methodology/<SURFACE>.md`.

### Step 3: Route through audit-lifecycle

```bash
# Set TARGET_HINTS per surface (target-router.sh recognizes these):
#   aa-smart-account / aa-4337 / bundler / paymaster
#   da-layer / celestia / eigenda / avail
#   lrt / restaking / eigenlayer / puffer / renzo / kelp
#   indexer / subgraph / thegraph
#   zk-circuit / circom / halo2 / noir / plonky
#   mpc / threshold / frost / dkg
#   compiler / solc / vyper / llvm
#   post-audit-drift
#   differential-fuzzing
#   ghost-finding
#   academic-paper

TARGET_HINTS="<classifier>" \
  ~/arsenal/audit-lifecycle/bin/init-target.sh <workspace-name>
```

`init-target.sh` bootstraps workspace + emits ROUTING.md with the appropriate playbook link.

### Step 4: Apply playbook

Each playbook has:
- Numbered bug classes with grep patterns
- Target inventory with bounty info
- Methodology per target (time budget per step)
- PoC pattern skeleton
- Tool requirements (most stubs exist at `~/arsenal/tools/`)

### Step 5: Submit through standard lifecycle

After finding is confirmed: standard `on-finding.sh` → `SEVERITY-COMMIT` → preflight → submit, same as any other finding class. The severity equation (min of evidence/chain/impact) applies uniformly.

## Target type × surface matrix (quick reference)

When user describes a target, map to surfaces that apply:

| Target description | Primary surface | Secondary (methodology) |
|---|---|---|
| DeFi protocol with bundler integration | AA-4337 | differential fuzzing across 4337 implementations |
| L2 rollup sequencer | DA layer + rollup specifics | differential fuzzing across clients |
| Liquid restaking protocol | LRT slashing | post-audit drift on LRT codebase |
| DEX with complex subgraph | Indexer drift | ghost finding from Uniswap V3 audits |
| Protocol recently audited | Post-audit drift | ghost finding if fork |
| Privacy pool / mixer | ZK circuits | differential fuzzing across circom/halo2 impls |
| MPC custody / threshold wallet | MPC/threshold | academic paper hunt for FROST attacks |
| Cross-chain bridge | Source+sender validation (rule #23) + DA if applicable | differential across relayer impls |
| Compiler-critical (Vyper, old solc) | Compiler bugs | ghost finding for Curve reentrancy class |
| Anything with recent eprint paper hit | Academic paper hunt | cross-reference with deployed primitive |

## Integration with other skills

- `/gravedigger <target>` — once surface selected and target identified, gravedigger does recon+audit
- `/mrrobbot <target>` — for high-bounty single-target deep dives
- `/disclose` — for direct responsible disclosure of findings
- `/immunefi-submit` — BOYCOTTED, never use (CLAUDE.md user_immunefi_boycott.md)

## Cadence decision tree

```
User describes available time this week:

<10h/week background
  → academic-paper-hunt (daily RSS triage, weekly triage)
  → differential-fuzzer (let harness run continuously)
  → ghost-finding-scanner (cron, triage as flags come)
  → post-audit-drift (cron, triage score-10 commits)

10-40h this week
  → AA-4337 ecosystem (ramp + first PoC)
  → indexer drift (ramp + one target audit)
  → LRT slashing (one LRT deep dive)
  → post-audit drift (multiple protocols tracked)

Multi-week commitment
  → ZK circuit (one system deep)
  → MPC/threshold (one library deep + one wallet provider)
  → DA layer (one DA system end-to-end)

Background pipeline (weeks-to-months per hit)
  → compiler bug hunt (fuzzing cycles)
  → academic paper → live protocol (watch + match)
```

## No-filter reminder (CLAUDE.md rule #40)

If at any point during surface recommendation you catch yourself writing "skip X because hard/slow", STOP. Encode X with:
- Its specific cadence (background vs weekly vs multi-week)
- Its filter advantage (what KEEPS competitors out = YOUR edge)
- Its disclosure strategy (direct vs bounty platform vs academic response)

Every surface in this skill exists because it's UNDER-EXPLORED, meaning the filter is the feature. Telling the user to skip the high-filter surfaces defeats the purpose.

## Tool inventory

| Tool | Purpose | Status |
|---|---|---|
| `~/arsenal/tools/post-audit-drift-monitor.sh` | watch recently-audited repos for sensitive commits | Phase A skeleton |
| `~/arsenal/tools/ghost-finding-scanner.sh` | C4/Cantina ingest + fork matcher | Phase A skeleton |
| `~/arsenal/tools/eprint-rss-monitor.sh` | IACR RSS filter + LLM score | Phase A skeleton |
| `~/arsenal/tools/differential-fuzzer.py` | N-impl runner + diff output | Phase A skeleton |
| Existing: `github-monitor.py` | generic commit monitor (extend for post-audit) | Phase B |
| Future: `aa-userop-tracer.sh` | trace UserOp through EntryPoint | not built |
| Future: `lrt-rate-watcher.py` | monitor LRT rate vs underlying slash events | not built |
| Future: `indexer-vs-contract.py` | diff subgraph vs contract state on N users | not built |
| Future: `zk-undercon-fuzzer.py` | fuzz circom/Noir for under-constrained signals | not built |

Tool Phase B work is lazy — build when the surface is being actively hunted, not preemptively.

## References

- CLAUDE.md rule #38 — lifecycle init mandatory first action
- CLAUDE.md rule #39 — SEVERITY-COMMIT artifact-required before draft
- CLAUDE.md rule #40 — no filter-by-difficulty on surface recommendations
- CLAUDE.md rules #33, #34 — existing surface references (lock contention, H1 patterns)
- `~/arsenal/methodology/*.md` — all playbooks live here
- `~/arsenal/audit-lifecycle/bin/*.sh` — lifecycle scripts
