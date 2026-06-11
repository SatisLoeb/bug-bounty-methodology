# WORKSPACE-TEMPLATE.md — Structure & Tracking

Standard workspace structure, naming conventions, and tracking templates for GraveDigger investigations.

---

## T1: Directory Structure Template

```
{protocol}-recon/
├── RECON.md                          # Protocol intelligence (Phase 1 output)
├── SURFACE-MAP.md                    # Attack surface inventory (Phase 2 output)
├── MASTER-FINDINGS-INDEX.md          # All findings + attack chains (Phase 6 output)
├── evidence/
│   ├── web/                          # Web/API evidence
│   │   ├── api-responses/            # Raw API response JSON files
│   │   ├── js-bundles/               # Downloaded JS bundles
│   │   ├── screenshots/              # UI screenshots
│   │   └── har-files/                # HTTP Archive captures
│   ├── onchain/                      # On-chain evidence
│   │   ├── state-snapshots/          # Contract state at specific blocks
│   │   ├── tx-traces/                # Transaction traces
│   │   └── proxy-resolutions/        # Proxy implementation mappings
│   ├── infrastructure/               # Infra evidence
│   │   ├── dns/                      # DNS records, CT logs
│   │   ├── headers/                  # HTTP response headers
│   │   └── errors/                   # Error message captures
│   └── contracts/                    # Source code snapshots
│       ├── verified/                 # Etherscan-verified sources
│       └── decompiled/               # Decompiled bytecode
├── findings/
│   ├── {PROTO}-F01-{name}.md         # Critical/High findings
│   ├── {PROTO}-W01-{name}.md         # Medium/Warning findings
│   ├── {PROTO}-I01-{name}.md         # Informational findings
│   └── {PROTO}-C01-{name}.md         # Attack chain findings
├── reports/
│   ├── DISCLOSURE-{id}.md            # Formatted disclosure reports
│   ├── PREFLIGHT-{id}.md             # Pre-flight check results
│   └── KILLGATE-{id}.md              # Kill gate assessments
├── attack-chains/
│   ├── CHAIN-01-{name}.md            # Individual attack chain analysis
│   └── CROSS-REF-MATRIX.md           # Finding cross-reference matrix
└── poc/
    ├── foundry/                      # Solidity fork-based PoCs
    ├── scripts/                      # Curl/bash PoC scripts
    └── rust/                         # Rust PoC tests
```

### Quick Init

```bash
PROTO="upshift"  # Change per target
BASE="${PROTO}-recon"
mkdir -p "${BASE}"/{evidence/{web/{api-responses,js-bundles,screenshots,har-files},onchain/{state-snapshots,tx-traces,proxy-resolutions},infrastructure/{dns,headers,errors},contracts/{verified,decompiled}},findings,reports,attack-chains,poc/{foundry,scripts,rust}}
touch "${BASE}/RECON.md" "${BASE}/SURFACE-MAP.md"
echo "# ${PROTO^^} — Master Findings Index" > "${BASE}/MASTER-FINDINGS-INDEX.md"
```

---

## T2: Finding Naming Convention

**Format:** `{PROTOCOL}-{TYPE}{NN}-{SHORT-NAME}.md`

| Component | Rule | Example |
|-----------|------|---------|
| `{PROTOCOL}` | Uppercase short name | `UPSHIFT`, `ETHENA`, `SERAI` |
| `{TYPE}` | Single letter severity class (see below) | `F`, `W`, `I`, `C` |
| `{NN}` | Two-digit sequential (01-99) | `01`, `14` |
| `{SHORT-NAME}` | Kebab-case descriptor | `nav-bypass-write`, `missing-slippage` |

**Type codes:**
| Code | Severity Class | Use When |
|------|---------------|----------|
| `F` | Critical/High | Fund theft, protocol break, auth bypass with write |
| `W` | Medium/Warning | Limited impact, conditional exploit, defense-in-depth gap |
| `I` | Informational | Best practice violation, info leak, no direct exploit |
| `C` | Attack Chain | Combined findings creating escalation path |

**Examples:**
- `UPSHIFT-F01-nav-bypass-write.md`
- `UPSHIFT-W02-missing-rate-limit.md`
- `ETHENA-I03-sentry-dsn-exposed.md`
- `SERAI-C01-identity-aggregate-chain.md`

---

## T3: Finding File Template

```markdown
# {PROTOCOL}-{TYPE}{NN}: {Title}

| Field | Value |
|-------|-------|
| **Severity** | Critical / High / Medium / Low / Informational |
| **Status** | Draft / Kill-Gated / Pre-Flighted / Disclosed / Acknowledged / Fixed |
| **Evidence Level** | Theoretical / Logical / API-Verified / Mainnet-Proven |
| **CWE** | CWE-XXX: Description |
| **CVSS 3.1** | X.X (Vector String) |
| **Affected** | Contract/Endpoint/Component |
| **Chain(s)** | Ethereum / Arbitrum / All |
| **Chain Potential** | None / Enables {ID} / Amplified by {ID} / Part of {CHAIN-ID} |

## Summary

One paragraph. What, where, impact.

## Root Cause

Technical root cause. Code reference with file:line if available.

## Attack Vector

Step-by-step exploitation path.

## Evidence

### [Level]: {Description}

- **Type:** API Response / On-chain State / Code Analysis / PoC Output
- **File:** `evidence/{path}`
- **Captured:** {ISO timestamp}
- **Block:** {number} (if on-chain)

{Verbatim evidence or reference to file}

## Impact

Quantified. Dollar amount or percentage of TVL. Affected users/contracts count.

## Affected Deployments

| Chain | Address | Verified | TVL |
|-------|---------|----------|-----|

## IS / IS NOT

| IS (confirmed risk) | IS NOT (honest limitation) |
|---------------------|---------------------------|

## Recommended Fix

Code-level fix with diff or pseudocode.

## Chain Connections

- **Enables:** {finding IDs this enables}
- **Enabled by:** {finding IDs that enable this}
- **Amplifies:** {finding IDs this makes worse}
- **Part of chain:** {CHAIN-ID if applicable}

## Files

- Evidence: `evidence/{path}`
- PoC: `poc/{path}`
- Kill Gate: `reports/KILLGATE-{id}.md`
- Disclosure: `reports/DISCLOSURE-{id}.md`
```

---

## T4: MASTER-FINDINGS-INDEX Schema

```markdown
# {Protocol} — Master Findings Index

**Investigator:** {name}
**Date Range:** {start} — {end}
**Status:** Active / Complete / Disclosed
**Total Findings:** {N} ({critical} Critical, {high} High, {medium} Medium, {low} Low, {info} Info)
**Attack Chains:** {N}
**Total TVL at Risk:** ${amount}

---

## Executive Summary

{2-3 sentences: scope, key discoveries, overall risk assessment}

## Severity Matrix

| ID | Title | Severity | Evidence Level | Chain Potential | Status |
|----|-------|----------|---------------|-----------------|--------|

## Attack Chains

| Chain ID | Name | Steps | Findings Combined | Combined Impact | Evidence Level |
|----------|------|-------|-------------------|-----------------|---------------|

## Recommendations (Priority Order)

1. **[IMMEDIATE]** {action} — Addresses {finding IDs}
2. **[SHORT-TERM]** {action} — Addresses {finding IDs}
3. **[LONG-TERM]** {action} — Addresses {finding IDs}

## Investigation Timeline

| Date | Phase | Key Action | Findings Produced |
|------|-------|------------|-------------------|

## Disclosure Status

| Finding | Contact Method | Date Sent | Response | Days Elapsed |
|---------|---------------|-----------|----------|-------------|
```

---

## T5: Investigation Status Tracker

```markdown
# {Protocol} Investigation — Status

## Phase Completion

| Phase | Name | Status | Time Spent | Max Allowed | Notes |
|-------|------|--------|------------|-------------|-------|
| 1 | Protocol Intelligence | ⬜ Not Started | 0h | 2h | |
| 2 | Surface Mapping | ⬜ | 0h | 1.5h | |
| 3 | Kill Gate Triage | ⬜ | 0h | 30min/finding | |
| 4 | Deep Analysis | ⬜ | 0h | 3h/finding | |
| 5 | Attack Chains | ⬜ | 0h | 2h | |
| 6 | Preflight & Handoff | ⬜ | 0h | 15min/finding | |

## Finding Inventory

| ID | Title | Phase Found | Evidence Level | Kill Gate | Preflight | Disclosed |
|----|-------|-------------|---------------|-----------|-----------|-----------|

## Decision Log

| Date | Decision | Rationale |
|------|----------|-----------|

## Blocked Items

| Item | Blocker | Attempted Solutions | Status |
|------|---------|--------------------|---------|
```

---

## Usage

1. Run quick init script to create workspace
2. Start with RECON.md (Phase 1 output goes here)
3. Create SURFACE-MAP.md during Phase 2
4. Create finding files in `findings/` as they're discovered
5. Run kill gates, save to `reports/KILLGATE-{id}.md`
6. Build attack chains in `attack-chains/`
7. Compile MASTER-FINDINGS-INDEX.md as capstone
8. Hand off to `/disclose` or `/immunefi-submit` for report formatting
