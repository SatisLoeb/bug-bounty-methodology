# Scope Check — {FINDING_ID}

**MANDATORY: fill this BEFORE any kill-gate, severity-commit, or draft.** Blocks draft creation via `on-finding.sh --stage 2`.

Enforces CLAUDE.md rule #27 (check scope exclusions BEFORE drafting). Prevents the HRB-001 / F-002 failure mode where 2-4h of drafting is invested on a finding that was always OOS.

---

## Finding metadata

```
Finding ID:       {FINDING_ID}
One-line title:   [describe the finding in 10 words max]
Primary asset:    [domain or contract]
Date:             [YYYY-MM-DD]
```

---

## Step 1 — Program scope (paste from program page)

**In-scope assets:**
```
[paste the scope section exactly as published — domains, contracts, repos]
```

**Source:** [URL of program page or local SCOPE.md path]

---

## Step 2 — Out-of-Scope list (paste from program page)

**Program-specific OOS:**
```
[paste the "Out of Scope" / "Exclusions" section exactly as published]
```

**H1 Core Ineligible Findings** (applies to all HackerOne programs unless overridden — paste "N/A" if not a H1 program):
```
- Theoretical vulnerabilities without proof of concept
- Clickjacking on pages with no sensitive actions
- Self-XSS
- Missing HTTP security headers (without demonstrated impact)
- SPF / DKIM / DMARC records
- Outdated browsers / libraries (without demonstrated impact)
- Social engineering / phishing
- Denial of service
- CSRF on unauthenticated forms
- Information disclosure of non-sensitive data
- Open redirect (without additional impact)
- Tabnabbing
- Known CVEs in third-party components (without demonstrated impact on the asset)
- Missing best practices in SSL/TLS configuration
- Missing Subresource Integrity (standalone)
- Use of known vulnerable third-party component (without PoC)
- Issues requiring unlikely user interaction or physical access
- Credentials found in credential dumps
```

---

## Step 3 — OOS Cross-Reference Grid

**Instructions:** For each OOS token below, ask: "does my finding include this characteristic?" Check MATCH or NOMATCH. If MATCH, the finding is **presumed OOS** — the only way to PROCEED is with a specific justification per H1's "unless additional security impact" or program language.

| OOS token | MATCH / NOMATCH | Justification if MATCH |
|-----------|-----------------|------------------------|
| Theoretical / no current exploit | [ ] / [ ] | |
| Clickjacking / framable page | [ ] / [ ] | |
| Self-XSS | [ ] / [ ] | |
| Missing HTTP header (standalone) | [ ] / [ ] | |
| Missing SRI (standalone) | [ ] / [ ] | |
| SPF / DKIM / DMARC | [ ] / [ ] | |
| Outdated browser / library | [ ] / [ ] | |
| Social engineering / phishing | [ ] / [ ] | |
| Denial of service | [ ] / [ ] | |
| CSRF on unauth form | [ ] / [ ] | |
| Info disclosure of non-sensitive data | [ ] / [ ] | |
| Open redirect (no additional impact) | [ ] / [ ] | |
| Tabnabbing | [ ] / [ ] | |
| Known CVE (without demonstrated impact) | [ ] / [ ] | |
| Missing best practice SSL/TLS | [ ] / [ ] | |
| Supply-chain risk requiring external compromise | [ ] / [ ] | |
| Physical access required | [ ] / [ ] | |
| Credentials from dump | [ ] / [ ] | |
| Other program-specific exclusion (specify) | [ ] / [ ] | |

---

## Step 4 — Scope match verification

The finding's primary asset is:
```
[paste the asset URL / contract address]
```

Check against in-scope assets listed in Step 1:
- [ ] Asset is explicitly listed in-scope
- [ ] Asset is covered by a wildcard (e.g., `*.example.com`)
- [ ] Asset is NOT in scope → **KILL**

---

## Step 5 — Verdict

```
Result: [ ] PROCEED — finding is in-scope AND no OOS match, or OOS match has valid "additional impact" justification
        [ ] AMEND   — finding needs reframing to avoid OOS match (document reframe plan below)
        [ ] KILL    — finding is OOS and cannot be salvaged

If AMEND, reframe plan:
_______________________________________________
_______________________________________________

If KILL, log in OUTCOMES.jsonl with held_reason = scope_exclusion_oos
to prevent re-investigation.
```

**Signed by operator:** `[x] SCOPE_CHECK_SIGNED_PROCEED` (or `SCOPE_CHECK_SIGNED_KILL` / `SCOPE_CHECK_SIGNED_AMEND`)

The signature line above is machine-read by `scope-validator.sh`. Exact string required: `[x] SCOPE_CHECK_SIGNED_PROCEED`. Any other value blocks `on-finding.sh --stage 2`.

---

## Why this gate exists

Without this gate, the failure mode is:
1. Finding surfaces during recon.
2. Operator (human or LLM) sees interesting behavior and starts drafting.
3. 2-4h later, draft is complete.
4. Preflight or post-submission feedback reveals the finding is OOS.
5. Sunk cost.

With this gate, the check is forced at minute 0 of finding investigation. 10 min of scope-check work prevents 2-4h of sunk drafting.

Lesson codification: this gate is the executable form of `feedback_check_scope_before_writing.md`. Before this gate existed, the feedback was a textual memory that fired reactively (after the mistake). The gate fires proactively (before the mistake).
