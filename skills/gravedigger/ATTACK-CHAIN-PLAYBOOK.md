# ATTACK-CHAIN-PLAYBOOK.md — Attack Chain Composition & Worst-Case Scenario Builder

Final phase of every target engagement. Takes individual findings and composes them into multi-step attack chains that maximize impact. Runs AFTER all testing phases, BEFORE report writing.

**Why this matters for payouts:** A Medium info leak + a Medium IDOR + a Low missing rate limit = Critical fund theft chain. Programs evaluate the CHAIN impact, not individual findings. Three $2K Mediums become one $20K+ Critical when properly composed.

**Pipeline integration:** Runs as the penultimate step in every target workflow, after all testing phases and before Kill Gate/Pre-Flight/submission. Outputs: ranked attack chains with full step-by-step exploitation paths, cost analysis, and detection assessment.

---

## When To Run

```
Target workflow:
  1. Recon                    (§F0 / Phase 0-1)
  2. API Surface              (§F1 / Phase 2)
  3. Frontend/Mobile          (§F2 / MOBILE-API-RECON)
  4. Infrastructure           (§F3)
  5. Key Architecture         (§F4)
  6. Smart Contracts          (§F5)
  7. Domain-Specific Testing  (§FIN / §OB / JWT Arsenal / etc.)
  8. Reverse Lookup hits      (REVERSE-LOOKUP Step 0 downstream reports)

  ════════════════════════════════════════════
  9. ATTACK CHAIN COMPOSITION  ← THIS PHASE
  ════════════════════════════════════════════

  10. Kill Gate per chain      (KILL-GATE-TEMPLATE)
  11. Pre-Flight per report    (PREFLIGHT-CHECK)
  12. Submit
```

**Trigger condition:** 2+ findings on the same target. If only 1 finding, skip this phase — submit the individual finding directly.

---

## Phase 1: Finding Inventory

List every finding from the engagement with its chaining properties.

```
For each finding, document:

┌──────────────────────────────────────────────────────────────────┐
│ ID:           F-001                                              │
│ Title:        Unauthenticated POST /api/v2/transfer              │
│ Type:         Missing Auth                                       │
│ Severity:     Medium (standalone)                                │
│ Prerequisite: None (unauthenticated)                             │
│ Provides:     Write access to transfer endpoint                  │
│ Data gained:  None                                               │
│ Access gained: Can trigger transfers                             │
│ Reversible:   No                                                 │
│ Detectable:   No events emitted (F-007)                          │
└──────────────────────────────────────────────────────────────────┘
```

**Key fields for chaining:**
- **Prerequisite:** What does the attacker need before exploiting this? (nothing, valid account, specific data, admin access)
- **Provides:** What does successful exploitation give the attacker? (data, access, capability)
- **Detectable:** Can the target detect this step? (events emitted, monitoring, logs)

---

## Phase 2: Directed Graph Construction

Build a directed graph where:
- **Nodes** = findings + the attacker's starting state + target end states
- **Edges** = "finding X provides what finding Y requires"

```
START (unauthenticated attacker with internet access)
  │
  ├──→ F-002 (API key in bundle)     [requires: nothing]
  │      │
  │      └──→ F-003 (internal API IDOR) [requires: API key]
  │             │
  │             └──→ F-005 (admin email from IDOR) [requires: internal API access]
  │                    │
  │                    └──→ F-006 (password reset no rate limit) [requires: target email]
  │                           │
  │                           └──→ END: Account Takeover
  │
  ├──→ F-001 (unauth transfer endpoint) [requires: nothing]
  │      │
  │      └──→ END: Unauthorized Transfer (but needs valid params)
  │             │
  │             └──← F-003 provides valid account IDs
  │
  ├──→ F-004 (DNSSEC absent)          [requires: nothing]
  │      │
  │      └──→ F-008 (DNS hijack → phishing) [requires: DNSSEC absent + registrar vuln]
  │
  └──→ F-007 (no events on transfers)  [requires: nothing]
         │
         └──→ AMPLIFIER: any transfer-based chain is undetectable
```

### Graph Construction Rules

For every pair (A, B):
1. **Does A enable B?** — A provides what B requires as prerequisite
2. **Does B enable A?** — B provides what A requires
3. **Does A amplify B?** — A increases B's impact/scope (missing logging, missing rate limit, no timelock)
4. **Does B amplify A?** — B increases A's impact/scope

**Amplifier types:** missing_logging, missing_rate_limit, missing_detection, no_timelock, no_pause, single_key

### Automated Graph Construction

```python
def build_chain_graph(findings):
    """
    Build directed graph of finding dependencies.
    Edge from A to B means: A provides what B requires.
    """
    graph = {}

    for f in findings:
        graph[f.id] = {
            "finding": f,
            "enables": [],      # findings this one enables
            "enabled_by": [],   # findings that enable this one
            "amplifies": []     # findings this one makes worse
        }

    for a in findings:
        for b in findings:
            if a.id == b.id:
                continue

            # Direct enablement: A provides what B requires
            if a.provides and b.prerequisite:
                if satisfies(a.provides, b.prerequisite):
                    graph[a.id]["enables"].append(b.id)
                    graph[b.id]["enabled_by"].append(a.id)

            # Amplification: A makes B's impact worse
            # e.g., "no monitoring" amplifies any exploitation chain
            if a.type in ["missing_logging", "missing_rate_limit",
                          "missing_detection", "no_timelock"]:
                graph[a.id]["amplifies"].append(b.id)

            # Data flow: A leaks data that B needs
            if a.data_gained and b.prerequisite:
                if data_satisfies(a.data_gained, b.prerequisite):
                    graph[a.id]["enables"].append(b.id)

    return graph
```

---

## Phase 3: Chain Enumeration

Walk the graph to find all paths from START to critical end states.

### Target End States (What Matters)

```
CRITICAL end states (fund theft / total compromise):
  - Direct fund drain (transfer/withdraw without authorization)
  - Proxy upgrade (change contract implementation)
  - Admin key compromise (control signing keys)
  - Account takeover on privileged account
  - API secret theft (partner dashboard /secret/{id})
  - Identity document forgery (mDL, KYC bypass)

HIGH end states (significant damage):
  - Mass data exfiltration (PII, financial data)
  - Persistent unauthorized access
  - Service disruption (DoS on critical flow)
  - Partial fund manipulation (fee bypass, rounding exploit)
  - Cross-origin session hijack

MEDIUM end states (limited damage):
  - Individual account data access (IDOR)
  - Session hijacking
  - Information disclosure (internal architecture)
  - User enumeration at scale
```

### Path Enumeration Algorithm

```python
def enumerate_chains(graph, max_depth=6):
    """
    Find all paths from START findings (no prerequisites)
    to critical end states.
    """
    chains = []

    # START nodes: findings with no prerequisites
    start_nodes = [
        f_id for f_id, data in graph.items()
        if data["finding"].prerequisite is None
           or data["finding"].prerequisite == "none"
    ]

    def dfs(current, path, visited):
        if len(path) > max_depth:
            return

        path.append(current)
        visited.add(current)

        # Check if current path reaches a critical end state
        end_state = assess_end_state(path, graph)
        if end_state:
            chains.append({
                "path": list(path),
                "end_state": end_state,
                "severity": end_state_severity(end_state),
                "amplifiers": find_amplifiers(path, graph)
            })

        # Continue exploring
        for next_id in graph[current]["enables"]:
            if next_id not in visited:
                dfs(next_id, path, visited)

        path.pop()
        visited.remove(current)

    for start in start_nodes:
        dfs(start, [], set())

    # Sort by severity (Critical first), then by chain length (shorter = easier)
    chains.sort(key=lambda c: (
        {"CRITICAL": 0, "HIGH": 1, "MEDIUM": 2}.get(c["severity"], 3),
        len(c["path"])
    ))

    return chains
```

---

## Phase 4: Chain Analysis & Scoring

For each chain, compute the exploitation profile.

### Chain Scorecard

```
┌─────────────────────────────────────────────────────────────────────┐
│ CHAIN: F-002 → F-003 → F-001 → Fund Drain                         │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│ STEPS:                                                              │
│   1. [F-002] Extract API key from JS bundle (public, 5 min)        │
│   2. [F-003] Use API key to enumerate accounts via IDOR (10 min)   │
│   3. [F-001] Trigger transfer using enumerated account IDs (1 min) │
│                                                                     │
│ AMPLIFIERS:                                                         │
│   [F-007] No events emitted → drain is silent                      │
│   [F-009] No rate limiting → can drain all accounts in sequence    │
│                                                                     │
│ SCORING:                                                            │
│   Attack cost:           $0 (no gas, no capital, no infra)         │
│   Time to exploit:       16 minutes                                │
│   Skill required:        Low (curl + basic scripting)              │
│   Prerequisites:         None (internet access only)               │
│   Reversibility:         No (funds transferred)                    │
│   Detection probability: None (no events, no monitoring)           │
│   TVL at risk:           $XXM (all accounts accessible via IDOR)   │
│                                                                     │
│ INDIVIDUAL SEVERITIES:                                              │
│   F-002: Low  │  F-003: Medium  │  F-001: Medium  │  F-007: Low   │
│                                                                     │
│ CHAIN SEVERITY:  ██████████ CRITICAL                               │
│   Justification: $0-cost unauthenticated fund theft,               │
│   undetectable, affects all users                                   │
│                                                                     │
│ CHAIN IMPACT vs INDIVIDUAL:                                         │
│   Sum of individual severities: Low + Medium + Medium + Low        │
│   Chain severity: CRITICAL                                          │
│   → Chain is 3+ severity levels above sum of parts                 │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

### Scoring Dimensions

```
1. ATTACK COST
   $0          → No capital required (most dangerous)
   $1-$1K      → Requires some gas/infra
   $1K-$100K   → Requires significant capital (flash loan)
   >$100K      → Requires sustained capital

2. TIME TO EXPLOIT
   < 1 hour    → Scriptable, automatable
   1-24 hours  → Requires manual steps
   > 24 hours  → Requires sustained access

3. SKILL REQUIRED
   Low         → curl + browser devtools
   Medium      → scripting + API knowledge
   High        → crypto/smart contract expertise
   Expert      → novel technique required

4. DETECTION PROBABILITY
   None        → No logs, no events, no monitoring catches this
   Low         → Logs exist but aren't monitored in real-time
   Medium      → Monitoring exists but chain bypasses it
   High        → Chain triggers alerts

5. REVERSIBILITY
   Irreversible → Funds gone, can't recover
   Partial      → Some recovery possible (timelock, pause)
   Reversible   → Protocol can fully recover

6. BLAST RADIUS
   Single user  → One account affected
   Multi user   → Subset of users affected
   All users    → Everyone affected
   Protocol     → Protocol itself compromised (upgrade, admin key)
```

---

## Phase 5: Report Generation

### Single-Chain Report (For Bounty Submission)

Each chain becomes ONE submission. Lead with the chain, not the individual findings.

```
TITLE: [Chain Impact] via [Step 1] + [Step 2] + [Step N]
  Example: "Unauthenticated Fund Drain ($XXM at risk) via API Key
  Leak + Account Enumeration + Unprotected Transfer Endpoint"

SEVERITY: Based on CHAIN impact, not individual findings

BRIEF:
  One paragraph describing the full chain from attacker's starting
  position to end state. Lead with the worst outcome.

ATTACK FLOW:
  Step-by-step with exact commands/requests for each step.
  Each step references the individual finding.
  Show data flowing from one step to the next.

AMPLIFIERS:
  List factors that make the chain worse (no detection, no rate
  limit, no timelock, etc.)

INDIVIDUAL FINDINGS:
  Detail each finding separately (for the team to fix each one).
  But frame them as "links in the chain" not standalone bugs.

IMPACT:
  Quantified: TVL at risk, users affected, attack cost.
  Use Immunefi/HackerOne severity language.

REMEDIATION:
  Per finding: specific fix for each link.
  Chain-level: which single fix BREAKS the entire chain?
  Priority: fix the link that's cheapest to fix AND breaks the
  most chains simultaneously.
```

### Multi-Chain Report (When Multiple Chains Exist)

```
If the target has multiple chains, submit the STRONGEST chain first.

SUBMISSION 1: Strongest chain (highest severity, lowest cost)
  → Establishes credibility

SUBMISSION 2-N: Additional chains (if they have INDEPENDENT paths)
  → Only submit if they use DIFFERENT entry points
  → If chains share findings, reference the first submission

DO NOT submit 5 chains that all start with the same info leak.
Submit 1 chain using the info leak, mention the other paths exist.
```

---

## Phase 6: Chain-Breaking Analysis

After building chains, identify the **minimum fix set** that breaks ALL chains. This goes in your remediation section and demonstrates structural thinking.

```
FINDINGS:        F-001  F-002  F-003  F-004  F-005  F-006  F-007

CHAIN A (Critical):  ■      ■      ■                       ■
CHAIN B (High):      ■             ■      ■
CHAIN C (High):             ■      ■             ■
CHAIN D (Medium):                  ■                       ■      ■

CHAIN-BREAKING ANALYSIS:
  - Fixing F-003 (IDOR) breaks chains A, B, C, D → highest priority
  - Fixing F-001 (unauth transfer) breaks chains A, B
  - Fixing F-002 (API key leak) breaks chains A, C
  - Fixing F-007 (no events) reduces severity of A, D but doesn't break them

RECOMMENDATION:
  Priority 1: Fix F-003 → breaks ALL chains
  Priority 2: Fix F-001 → defense in depth
  Priority 3: Fix F-007 → all chains become detectable
```

This analysis is extremely valuable in reports because:
- Shows holistic system understanding, not just individual bugs
- Gives the team a prioritized fix plan
- Demonstrates that one fix can eliminate multiple attack paths
- Programs love this — saves their team time, shows senior-level thinking

---

## Evidence Hierarchy

### Four Levels

| Level | Name | Definition | Strength |
|-------|------|-----------|----------|
| **L1** | Theoretical | Code analysis shows vulnerability exists. No runtime proof. | Weakest — dismissible as "design intent" |
| **L2** | Logical | Code path traced entry→vuln, guards shown absent, similar bugs documented. | Moderate — requires effort to dismiss |
| **L3** | API/State Verified | API call confirms behavior, OR on-chain state confirms precondition. | Strong — concrete evidence |
| **L4** | Mainnet-Proven | Full exploit on fork, OR write confirmed on production API, with before/after state. | Strongest — undismissable |

### Promotion: L1 → L2
- Complete code path traced (entry → vulnerable operation)
- All intermediate guards identified + shown non-blocking
- Similar vulnerability documented in same framework/pattern

### Promotion: L2 → L3
- API response confirming vulnerable behavior (saved verbatim)
- On-chain state confirming vulnerable precondition (with block number)
- Error response revealing internal state consistent with vulnerability

### Promotion: L3 → L4
- Full exploit executed with observable state change
- Before/after state comparison with block numbers or timestamps
- Exact reproduction steps from zero to impact

---

## On-Chain Proof Generation

### State Snapshot Procedure

```
onchain_state_snapshot(
  rpc_url="https://ethereum-rpc.publicnode.com",
  contract="0x...",
  slots=["0", "1", "2"],
  calls=[
    {"sig": "totalAssets()(uint256)"},
    {"sig": "totalSupply()(uint256)"},
    {"sig": "balanceOf(address)(uint256)", "args": ["0x_target"]},
    {"sig": "owner()(address)"},
    {"sig": "paused()(bool)"}
  ]
)
```

**State table format for reports:**
```markdown
### On-Chain State at Block {N} ({date})

| Variable | Value | Significance |
|----------|-------|-------------|
| `totalAssets()` | 13,164,451 USDC | Funds under management |
| `owner()` | 0xABC...123 | Single admin key |
| `paused()` | false | No emergency brake |
```

---

## MASTER-FINDINGS-INDEX Template

```markdown
# {Protocol} — Security Research Report

**Researcher:** {handle}
**Period:** {start} — {end}
**Status:** Active / Complete / Disclosed

## Executive Summary
{3-5 sentences: scope, findings, risk level, most critical finding}

**Statistics:**
- **Findings:** {N} ({C}C / {H}H / {M}M / {L}L / {I}I)
- **Attack Chains:** {N} combining {N} individual findings
- **Evidence:** {N} mainnet-proven, {N} API-verified, {N} logical

## Severity Matrix
| ID | Title | Severity | Evidence | Chain | Status |
|----|-------|----------|----------|-------|--------|

## Attack Chain Summary
| ID | Name | Findings | Impact | Evidence |
|----|------|----------|--------|----------|

## Chain-Breaking Analysis
| Fix | Breaks Chains | Priority |
|-----|---------------|----------|

## Recommendations
### Immediate (24-48h)
### Short-Term (1-2 weeks)
### Long-Term (1-3 months)
```

---

## Checklist

```
ATTACK CHAIN COMPOSITION CHECKLIST

Prerequisites:
  □ 2+ findings on the same target
  □ All testing phases complete
  □ Each finding documented with: prerequisite, provides, detectable

Phase 1 — Inventory:
  □ All findings listed with chaining properties
  □ Prerequisite and provides fields filled for each

Phase 2 — Graph:
  □ Directed graph constructed (findings as nodes, enablement as edges)
  □ START nodes identified (no prerequisites)
  □ Amplifier findings identified (missing logging, rate limiting, etc.)

Phase 3 — Enumeration:
  □ All paths from START to critical end states enumerated
  □ Chains sorted by severity then by length

Phase 4 — Scoring:
  □ Each chain scored on 6 dimensions
  □ Chain severity assessed (usually higher than sum of parts)
  □ Attack cost quantified ($0 = most dangerous)
  □ Detection probability assessed

Phase 5 — Report:
  □ Strongest chain selected for primary submission
  □ Report leads with chain impact, not individual findings
  □ Step-by-step exploitation path with exact commands
  □ Amplifiers documented
  □ Individual findings detailed as chain links
  □ Impact quantified (TVL, users, cost)

Phase 6 — Chain-breaking:
  □ Minimum fix set identified
  □ Priority order determined
  □ Included in remediation section

Final check:
  □ Would the report convince a non-technical executive that this is urgent?
  □ Could a junior dev reproduce the chain from the report alone?
  □ Is the strongest argument in the first paragraph?
```

---

## Integration with Existing Pipeline

### Kill Gate Adjustment

When evaluating a CHAIN (not individual finding):

- **Q5 (Trigger Feasibility):** Evaluate for the FULL CHAIN. Each step must be feasible AND transitions must be feasible.
- **EV Calculation:** Use CHAIN severity for payout estimate, not individual. A chain of 3 Mediums that composes to Critical: `EV = P(acceptance) × Critical_payout_tier`, NOT `EV = 3 × P(acceptance) × Medium_payout_tier`.

### Submission Strategy

```
immunefi-submit / security-disclosure:
  - Chain-based reports score higher on B1 (assertive intro)
  - Chain-based reports score higher on D1 (strongest argument leads)
  - Quality gate: "Is this finding part of a chain? If yes, submit the chain."
```

### Updated Workflow (all target types)

```
CRITICAL-HUNT-CHECKLIST §8:
  ... existing steps 1-7 ...
  8. ATTACK CHAIN COMPOSITION (30-60 min)  ← INSERT
     → Only if 2+ findings
     → Build graph, enumerate chains, score, generate report
  9. KILL GATE per chain (not per finding)
  10. PRE-FLIGHT per report
  11. SUBMIT strongest chain first

DEFI-FULLSTACK §F6:
  → REPLACE current §F6 with this methodology
  → Current §F6 is a sketch; this is the full process

FINANCIAL-SYSTEMS §1.3:
  → Add chain composition after §FIN-1 through §FIN-4
  → Fintech chains: info leak → account enum → payment bypass → silent drain

SKILL.md (immunefi-submit):
  → Chain-based reports score higher on B1 (assertive intro)
  → Chain-based reports score higher on D1 (strongest argument leads)
  → Add to quality gate: "Is this finding part of a chain? If yes, submit the chain."
```
