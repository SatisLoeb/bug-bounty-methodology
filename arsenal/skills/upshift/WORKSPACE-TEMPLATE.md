---
name: workspace-template
description: Directory structure init for Upshift-class engagements. Mirrors the structure that worked at ~/Desktop/BUGS/upshift-recon/. Init script creates recon/, evidence/{web,onchain}/, findings/W##/ + CHAIN-##/ + KILLED-##/ + NEW-##/, reports/, disclosure-thread/, re-verification/{daily-checks,drift-alerts}/ + the standard lifecycle files (PROGRESS.md, OUTCOMES.jsonl, ROUTING.md, SEVERITY-COMMIT-template.md, DISCLOSURE-MANIFEST.yaml).
---

# Workspace template -- directory structure for Upshift-class engagements

## The structure that worked

The Upshift engagement produced 48 findings in part because the workspace structure made it easy to add new findings without thrashing. This file encodes the structure so any new engagement starts with the same scaffolding.

```
~/Desktop/BUGS/<target>-recon/
├── PROGRESS.md                          # human-readable status, updated per pass
├── OUTCOMES.jsonl                       # structured outcomes (per finding submitted)
├── ROUTING.md                           # which CLAUDE-rules-*.md to load (output of target-router.sh)
├── SEVERITY-COMMIT-template.md          # severity declarations per finding
├── TRIAGE.md                            # output of /upshift --triage <target>
├── DISCLOSURE-MANIFEST.yaml             # structured manifest of primitives for re-verification
│
├── recon/                               # output of /gravedigger phases 0-2
│   ├── ARCHITECTURE.md                  # high-level protocol architecture
│   ├── ENTRY-POINTS.md                  # all user-facing entry points
│   ├── INVENTORY-PASS-1.md              # primitives found in Pass 1
│   ├── INVENTORY-PASS-2.md              # primitives added in Pass 2
│   ├── INVENTORY-PASS-3.md              # asymmetry findings from Pass 3
│   ├── PRIMITIVES-MAP.md                # full primitives map for Pass 4 chain construction
│   └── SCOPE.md                         # scope as declared by protocol team / bounty program
│
├── evidence/                            # raw artifacts (curl outputs, JS bundles, on-chain reads)
│   ├── web/
│   │   ├── js-bundles/                  # captured JS bundles, named by hash
│   │   ├── endpoint-probes/             # per-endpoint curl outputs
│   │   ├── infrastructure/              # subdomains, DNS, headers, TLS
│   │   ├── attack-chains/               # multi-step PoCs
│   │   └── findings/                    # per-finding evidence (UPSHIFT-W*.md style)
│   └── onchain/
│       ├── tx-traces/                   # decoded transaction calldata
│       ├── storage-reads/               # eth_getStorageAt outputs
│       ├── log-filters/                 # eth_getLogs filtered query outputs
│       └── contract-bytecode/           # cast code outputs for diff/verification
│
├── findings/                            # per-finding directories
│   ├── W001/                            # one directory per primary-pass finding
│   │   ├── SUMMARY.md                   # one-paragraph description, severity, vector
│   │   ├── REPORT.md                    # full kabayanerve-voice report (REPORT-STANDARD format)
│   │   ├── POC.md                       # standalone PoC (curl/script/Foundry test)
│   │   ├── KILL-GATE.md                 # 10-question kill gate output
│   │   ├── PREFLIGHT.md                 # 24-point preflight check output
│   │   └── MIRROR-AUDIT.md              # Pass 3 mirror invariant audit (if applicable)
│   ├── W002/
│   │   └── ...
│   ├── NEW001/                          # Pass 2 expansion findings (NEW-01-05 class)
│   │   └── ...
│   ├── CHAIN001/                        # Pass 4 chain findings
│   │   ├── CHAIN-PROOF.md               # the combined chain proof
│   │   ├── COMPONENTS.md                # references to component findings
│   │   └── COMBINED-IMPACT.md           # numeric impact (TVL drainable, time, attacker cost)
│   └── KILLED/                          # findings that did not pass kill gate
│       └── W099/
│           ├── REASON.md                # why killed (referencing kill-gate question)
│           └── EVIDENCE-ARCHIVE/        # preserve evidence in case retry warranted later
│
├── reports/                             # finalized disclosure-ready reports
│   ├── EXECUTIVE-WORSTCASE.md           # 1-page exec summary of the headline chain
│   ├── DISCLOSURE-CRITICAL.md           # standalone Critical for Stage 1 email
│   ├── DISCLOSURE-F1.md                 # standalone F1 / second-priority finding
│   ├── WORSTCASE.md                     # full technical version (1500+ lines)
│   ├── ALEX-EMAIL-DISCLOSURE.md         # the actual Stage 1 email body (annotated)
│   ├── ALEX-FOLLOWUP-FORTRESS.md        # the actual Stage 4 fortress email body
│   └── BUNDLE-INDEX.md                  # index of all reports in the bundle, for delivery format selection
│
├── disclosure-thread/                   # inbound and outbound communications
│   ├── 2026-MM-DD-stage1-out.md         # outbound email
│   ├── 2026-MM-DD-stage1-ack-in.md      # inbound ack
│   ├── 2026-MM-DD-stage2-linkedin-out.md
│   ├── 2026-MM-DD-stage3-reverify-out.md
│   ├── 2026-MM-DD-stage4-fortress-out.md
│   └── THREAD-TIMELINE.md               # chronological log of all comms
│
└── re-verification/                     # daily monitor outputs (see RE-VERIFICATION-MONITOR.md)
    ├── DISCLOSURE-MANIFEST.yaml         # SYMLINK to root manifest (or copy)
    ├── daily-checks/                    # one yaml per day
    ├── drift-alerts/                    # one md per drift event
    ├── route-inventory/                 # daily JS bundle route diffs
    ├── impl-tracking/                   # per-contract implementation slot tracking
    └── cron.log                         # cron output log
```

## Init script

```bash
#!/usr/bin/env bash
# ~/arsenal/audit-lifecycle/bin/upshift-init.sh
# Usage: upshift-init.sh <target-name>

set -e

TARGET="$1"
if [ -z "$TARGET" ]; then
  echo "Usage: $0 <target-name>"
  exit 1
fi

ROOT="$HOME/Desktop/BUGS/${TARGET}-recon"

if [ -d "$ROOT" ]; then
  echo "Workspace already exists at $ROOT"
  echo "Refusing to clobber. If you want to re-init, archive first:"
  echo "  mv $ROOT ${ROOT}.archived-$(date -u +%Y-%m-%d)"
  exit 1
fi

mkdir -p "$ROOT"/{recon,evidence/web/{js-bundles,endpoint-probes,infrastructure,attack-chains,findings},evidence/onchain/{tx-traces,storage-reads,log-filters,contract-bytecode},findings/KILLED,reports,disclosure-thread,re-verification/{daily-checks,drift-alerts,route-inventory,impl-tracking}}

# Create lifecycle files via existing audit-lifecycle init
~/arsenal/audit-lifecycle/bin/init-target.sh "${TARGET}-recon" || true

# Per-engagement seed files
cat > "$ROOT/PROGRESS.md" <<EOF
# Engagement progress -- ${TARGET}

## Current pass
- [ ] Phase -1: Lifecycle init
- [ ] Phase 0: Target selection (TRIAGE.md scored)
- [ ] Phase 1: Recon (architecture, entry points, scope)
- [ ] Phase 2: Surface scan (10 vectors in parallel) -- INVENTORY-PASS-1.md
- [ ] Phase 3a: Hunt Pass 2 expansion (NEW-01-05) -- INVENTORY-PASS-2.md
- [ ] Phase 3b: Hunt Pass 3 mirror invariant -- INVENTORY-PASS-3.md
- [ ] Phase 3c: Hunt Pass 4 chain construction -- PRIMITIVES-MAP.md
- [ ] Phase 4: Verification (live re-verification of each finding)
- [ ] Phase 5: Reports (per finding + executive worstcase)
- [ ] Phase 6: Disclosure (Stage 1 sent)
- [ ] Phase 7: Monitor (re-verification cron registered)
- [ ] Phase 8: Harden (fortress follow-up sent)

## Key dates
- Engagement started: $(date -u +%Y-%m-%d)
- Stage 1 disclosure target: TBD
- 14d ack window: TBD
- 30d re-verification: TBD

## Findings count
- Pass 1: 0
- Pass 2: 0
- Pass 3: 0
- Pass 4 chains: 0
- Killed: 0
- Total submitted: 0
EOF

cat > "$ROOT/SEVERITY-COMMIT-template.md" <<EOF
# Severity commit template -- per finding

For each finding, before writing the report, commit to the severity tier:

## Finding W###
- Tier (Critical / High / Medium / Low / Informational): [TIER]
- Combined-chain participant? (Y/N): [Y/N]
- Required artifacts:
  - Critical/High with on-chain impact: [tx hash, block number, decoded calldata, state diff]
  - Critical/High auth-class: [Chain Proof Gate D7 output]
  - Severity ≥ Low with $ impact: [Weight Card D8a + D8b]
  - All findings: [PoC, kill-gate output, preflight ≥22/24]
- Theoretical-bug-kill rule check: [does this ship as standalone, or only as chain component?]
EOF

cat > "$ROOT/disclosure-thread/THREAD-TIMELINE.md" <<EOF
# Disclosure thread timeline -- ${TARGET}

| Date (UTC) | Direction | Channel | Subject / Action |
|---|---|---|---|
| $(date -u +%Y-%m-%d) | -- | -- | Engagement initialized |
EOF

cat > "$ROOT/re-verification/DISCLOSURE-MANIFEST.yaml" <<EOF
target: ${TARGET}
state: pre_engagement
state_entered: $(date -u +%Y-%m-%dT%H:%M:%SZ)
acker: null
ack_channel: null
ack_email_thread: null
disclosure_email_sent: null
fortress_email_sent: null
fortress_window_open_until: null
delivery_format_chosen: null

primitives: []  # populated as findings are confirmed live
EOF

# Symlink manifest so monitor can find it
ln -s "$ROOT/re-verification/DISCLOSURE-MANIFEST.yaml" "$ROOT/DISCLOSURE-MANIFEST.yaml"

# Touch routing file (will be filled by target-router.sh)
touch "$ROOT/ROUTING.md"

# Initialize OUTCOMES.jsonl if not created by init-target.sh
[ -f "$ROOT/OUTCOMES.jsonl" ] || touch "$ROOT/OUTCOMES.jsonl"

echo "Workspace initialized at: $ROOT"
echo ""
echo "Next steps:"
echo "  1. Run /upshift --triage ${TARGET} to score the target"
echo "  2. If score >= 35, run /upshift --engage ${TARGET} to begin"
echo ""
echo "Workspace structure:"
tree -L 2 -d "$ROOT"
```

## Per-finding template

When a finding is created (during Pass 1-3), the directory at `findings/W###/` should be initialized with the following templates:

### `findings/W###/SUMMARY.md`

```markdown
# W### -- [name]

**Vector:** V[1-10] (per SURFACE-ATTACK-PATTERNS.md)
**Pass:** [1, 2, or 3]
**Severity (initial guess):** [Critical / High / Medium / Low / Informational]
**Chain participant?** [Y/N + chain ID if Y]
**Status:** [draft / kill-gate-pending / preflight-pending / ready-to-submit / submitted / acked / patched]

## Primitive

[1-2 sentences naming the primitive]

## Concrete evidence

[Curl command + response, OR eth_call + return value, OR grep + match]

## Why this matters

[1-3 sentences: what does an attacker do with this primitive]

## Open questions

- [Mirror invariant question for Pass 3: e.g., "Does the same endpoint behave differently with method X?"]
- [Chain question for Pass 4: e.g., "Does this combine with W### to enable Y?"]
```

### `findings/W###/REPORT.md`

Use the REPORT-STANDARD template at `~/Desktop/BUGS/REPORT-STANDARD.md`. The kabayanerve voice rules from DISCLOSURE-PROTOCOL.md apply: first person, no em-dashes, epistemic precision, evidence inline.

### `findings/W###/POC.md`

For each finding type:
- HTTP API: standalone curl script that reproduces the bug
- On-chain SC: Foundry test using `vm.createSelectFork()` against the deployed contract
- JS bundle leak: 2-line curl + grep that extracts the leaked secret
- SIWE bypass: 3-line script doing two consecutive nonce GETs
- AWS Lambda: standalone curl proving the body validator gap

### `findings/W###/KILL-GATE.md`

Output of running `~/Desktop/BUGS/KILL-GATE-TEMPLATE.md` against the finding. 10 questions, each with PASS/FAIL/N/A and explanation. Verdict: PROCEED / KILL / DOWNGRADE.

### `findings/W###/PREFLIGHT.md`

Output of running `~/Desktop/BUGS/PREFLIGHT-CHECK.md` against the finding. 24-point rubric. Minimum 22/24 to submit.

## Per-chain template

When a chain is identified during Pass 4, the directory at `findings/CHAIN###/` should contain:

### `findings/CHAIN###/CHAIN-PROOF.md`

```markdown
# Chain ### -- [chain name]

## Components
- W### ([severity]): [brief]
- W### ([severity]): [brief]
- (optional) W### ([severity]): [brief]

## Combined attack
[Step-by-step what an attacker does, with concrete commands]

## Combined severity
[Always > max(component severities)]

## Combined impact
- Funds at risk: $[X] ([source: TVL of vault Y at block Z])
- Time to execute: ~[N] minutes end-to-end
- Attacker cost: [gas / 0 if operator pays]
- Number of users affected: [N]
- Recovery feasibility: [explicit: pause? governance override? circuit breaker?]

## Why the components alone don't justify this severity
[The component-only argument that would dismiss each individual finding]

## Why the chain is undismissable
[The asymmetry / amplification that makes the chain qualitatively different]
```

### `findings/CHAIN###/COMPONENTS.md`

References to the component finding directories. Updated bidirectionally: each component's `SUMMARY.md` should also reference the chain.

### `findings/CHAIN###/COMBINED-IMPACT.md`

Detailed impact math. For dollar impact, cite the source (TVL endpoint, vault balance, etc.) and timestamp the read.

## What goes in `evidence/`

Raw artifacts only. The processed, narrated version goes in `findings/W###/`. The split is important because:
- Raw evidence persists across edits to the finding (e.g., if you re-write the report you don't lose the original curl output)
- Raw evidence is useful for the protocol team's own forensics if they want to reproduce
- Raw evidence is what gets attached to the disclosure email when the team asks for "the original captures"

## What goes in `reports/`

Reports are the **disclosure-ready**, recipient-facing versions. They differ from `findings/W###/REPORT.md` in that:
- Reports may combine multiple findings (executive worstcase)
- Reports use the kabayanerve voice optimized for the specific recipient (Stage 1 vs Stage 4)
- Reports are the artifacts attached to the disclosure email

## What goes in `disclosure-thread/`

Every email, LinkedIn DM, Signal message, and call note. Format per file: timestamp, direction, channel, body (or summary for voice calls). Update `THREAD-TIMELINE.md` on every interaction.

## What goes in `re-verification/`

See RE-VERIFICATION-MONITOR.md. The cron writes here daily. The monitor reads from `DISCLOSURE-MANIFEST.yaml` (root, symlinked).

## Common pitfalls

1. **Mixing evidence and findings.** Keep `evidence/` raw, keep `findings/` narrated. Don't lose raw captures by overwriting them with narrated versions.

2. **Skipping the SUMMARY.md and going straight to REPORT.md.** During Pass 1, you do not yet know the full context. Write SUMMARY.md first, REPORT.md after Pass 4 chain construction.

3. **Putting killed findings in `findings/KILLED/` without a REASON.md.** This wastes the kill -- if you don't document why, you'll re-investigate the same dead end in 6 months.

4. **Not symlinking DISCLOSURE-MANIFEST.yaml.** The cron looks for it at `re-verification/DISCLOSURE-MANIFEST.yaml`. Without the symlink, the cron silently fails.

5. **Not updating THREAD-TIMELINE.md after every interaction.** Six months later when you re-verify Upshift after a year of no engagement, the timeline is what reconstructs the relationship state. Without it, you re-engage cold.
