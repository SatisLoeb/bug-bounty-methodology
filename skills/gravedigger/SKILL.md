---
name: gravedigger
description: Systematic deep security research methodology. Use when conducting comprehensive security assessments of DeFi protocols, web applications, or smart contracts. Encodes the complete investigation workflow from reconnaissance through attack chain construction and disclosure handoff.
---

# GraveDigger — Systematic Deep Security Research

You are a systematic security researcher executing the GraveDigger methodology. This methodology was extracted from campaigns that produced 40+ findings, 3 mainnet-proven, 7 attack chains, and $332M TVL exposed. Follow it mechanically — the results come from the process, not improvisation.

## Skill Resources

Read the relevant companion files BEFORE executing each phase:

| File | Purpose | When to Read |
|------|---------|-------------|
| `~/arsenal/tools/reverse-lookup.py` | **Phase 0: Reverse dependency lookup** — cross-ref SBOM vs research_db | Start of EVERY investigation (before recon) |
| `~/arsenal/tracking/research_db.jsonl` | Cumulative lib research database (findings, clean, status) | Updated after every fuzzing campaign |
| `RECON-PLAYBOOK.md` | Phase 1-2: Protocol intelligence + surface mapping | Start of every investigation |
| `DEEP-ANALYSIS-PLAYBOOK.md` | Phase 4: Auth analysis, math proofs, JS bundles, infra | After kill gate triage |
| `JWT-ARSENAL-PLAYBOOK.md` | **JWT Arsenal integration** — 8-tool automated JWT vuln discovery | When JWT/JWS/JWE detected in Phase 2 (auto-activated) |
| `OAUTH2-OIDC-PLAYBOOK.md` | **OAuth2/OIDC state machine** — 12 attack vectors on the token issuance flow | When OAuth2/OIDC detected in Phase 2 (auto-activated) |
| `ATTACK-CHAIN-PLAYBOOK.md` | Phase 5: Cross-referencing, chain construction, evidence hierarchy | After deep analysis |
| `PERSISTENCE-PATTERNS.md` | P1-P7: Obstacle decision trees | Whenever you hit a dead end |
| `WEB-API-CHECKLIST.md` | W1-W6: Web/API specific procedures | For any web/API target |
| `WORKSPACE-TEMPLATE.md` | Directory structure, naming, templates | Start of investigation |
| `/home/malix/Desktop/BUGS/KILL-GATE-TEMPLATE.md` | Phase 3: 9-question kill gate | Before deep-diving any finding |
| `/home/malix/Desktop/BUGS/CHAIN-PROOF-GATE.md` | **Chain Proof Gate (D7)** — Stage 1 hedge grep + Stage 2 ethical variant generator. **MANDATORY** before submitting any auth-bypass / hardcoded-credential / signature-forge / JWT-token / session-hijack / IDOR-write / password-reset / account-binding finding | Phase 6 — BEFORE preflight, on every auth-class finding |
| `/home/malix/Desktop/BUGS/WEIGHT-CARD.md` | **Weight Card (D8)** — 5-slot dashboard with hard gate on W1 (computed loss) or W5 (paid precedent) numerical anchor. **MANDATORY** for every finding claiming severity ≥ Low with dollar impact. Complementary to Chain Proof Gate — D7 = "does exploit execute?", D8 = "is impact priced?" | Phase 6 — BEFORE preflight, on every non-Informational finding |
| `/home/malix/Desktop/BUGS/REPORT-STANDARD.md` | **Production report template** — Transak voice, epistemic precision, chain factoring. Contains mandatory `Chain Acceptance Verification` section + `Weight Accounting` section after Proof of Concept | Phase 6 — ALL report writing |
| `/home/malix/Desktop/BUGS/PREFLIGHT-CHECK.md` | Phase 6: 24-point quality gate. Contains gating criteria D7 (chain proof) + D8 (weight anchor) | Before disclosing any finding |
| `~/arsenal/tools/precedent-scan.sh` | Emits copy-paste-ready W5 precedent table for the Weight Card. Wraps H1-HUNTING-PATTERNS + H1-STATISTICS + OUTCOMES.jsonl. Usage: `./precedent-scan.sh "IDOR"` or `"SSRF"` or `"auth bypass"` | Phase 6 — populate W5 fast |
| `/home/malix/Desktop/BUGS/CRITICAL-HUNT-CHECKLIST.md` | Smart contract hunting patterns | For EVM targets |
| `/home/malix/Desktop/BUGS/SOLANA-HUNT-CHECKLIST.md` | Solana-specific patterns | For Solana targets |
| `/home/malix/Desktop/BUGS/NEXTJS-HUNT-CHECKLIST.md` | Next.js / RSC attack surface | For Next.js targets (auto-detect) |
| `/home/malix/Desktop/BUGS/DEFI-FULLSTACK-CHECKLIST.md` | **Full-stack DeFi protocol audit** (API + frontend + infra + contracts + keys) | For ANY DeFi with web app + API + contracts |
| `~/arsenal/methodology/H1-HUNTING-PATTERNS.md` | **HackerOne hacktivity patterns** — 60+ patterns: IDOR, SSRF, RCE, race conditions, auth bypass, business logic, API, cache, AI/LLM. 13 categories with grep detection + chain potential. | For ANY web/API target (auto-activate in Phase 2) |
| `~/arsenal/methodology/H1-STATISTICS.md` | Bounty ROI analysis, payout distribution by vuln type, target selection heuristics, industry patterns | Phase 0.5 deep mode decision + target prioritization |

**Integration with other skills:**
- `/disclose` — Format findings for direct disclosure to protocol teams
- `/immunefi-submit` — Format findings for Immunefi submission

---

## Arguments

```
/gravedigger <target>              # Start new investigation
/gravedigger <target> --resume     # Resume existing investigation
/gravedigger <target> --phase N    # Jump to specific phase
/gravedigger <target> --cross-ref  # Run cross-reference matrix on existing findings
/gravedigger <target> --promote    # Attempt evidence promotion on all findings
/gravedigger <target> --status     # Show investigation status
```

| Argument | Description |
|----------|-------------|
| `<target>` | Protocol name, domain, or contract address |
| `--resume` | Load existing `{target}-recon/` workspace and continue |
| `--phase N` | Start at phase N (1-6), skipping earlier phases |
| `--cross-ref` | Run §5.1 cross-reference matrix on all findings in workspace |
| `--promote` | Run §5.3 evidence promotion on all findings |
| `--status` | Display investigation status tracker from workspace |

---

## Execution Flow

### Phase -1: Lifecycle Init (MANDATORY — precedes all other phases)

**Enforces CLAUDE.md rule #38. FIRST COMMAND of any new investigation, regardless of skill or entry path.**

```bash
# Replace <target> with protocol name; set TARGET_HINTS for target-router classification
TARGET_HINTS="smart.contract solidity" \
  ~/arsenal/audit-lifecycle/bin/init-target.sh <target>
```

**Classifier hints for target-router.sh:**
- `smart.contract solidity` / `smart.contract evm` — EVM Solidity
- `solana anchor` — Solana/Anchor program
- `blockchain.node p2p` — L1/L2 node P2P layer (Rule #33 methodology)
- `web api rest` — Web/API surface (auto-activates H1 patterns, Rule #26/29/30)
- `mobile android` / `mobile ios` — Mobile app
- `defi fintech payment` — Fintech / Open Banking / Payment (regulatory framing)
- Multiple keywords: `solana web` — mixed classification

**Bootstraps:**
- `{target}-recon/` or `{target}-audit/` workspace with `findings/`, `evidence/`, `submissions/` subdirs
- `ROUTING.md` with mandatory checklists per target class + blind spot warnings (ZK / MPC / rollup / AI)
- `PROGRESS.md` with gate stack checklist + context recovery protocol
- `SEVERITY-COMMIT-template.md` + `OUTCOMES.jsonl` + `.lifecycle-status` marker

**Idempotent.** Re-running on existing workspace updates timestamps, re-runs routing. Safe to re-invoke after context compression or `--resume`.

**If this step is skipped:** `preflight-mechanical.sh` at Phase 6 refuses PASS (D0-init marker missing), and every OUTCOMES.jsonl entry records `preflight_run: false` — visible in monthly metrics as infra-ignored signal.

---

### Phase 0: Reverse Dependency Lookup (5 min)

**RUNS FIRST — before recon, before scanning, before anything else.**

Cross-reference the target's dependency tree against `research_db.jsonl` — your cumulative database of every lib you've researched, fuzzed, or broken. If the target uses a lib you've already found bugs in, you have instant downstream reports to write before spending a single hour on the target's own code.

```
0.1 SBOM extraction (per ecosystem):

    NPM:   cat package-lock.json | jq -r '.packages | to_entries[] | select(.key != "") | {name: (.key | split("node_modules/") | last), version: .value.version} | "\(.name)@\(.version)"' | sort -u > sbom-npm.txt
    PyPI:  cat Pipfile.lock | jq -r '.default | to_entries[] | "\(.key)@\(.value.version | ltrimstr("=="))"' > sbom-pypi.txt
           OR: pip freeze 2>/dev/null | sed 's/==/@/' > sbom-pypi.txt
    Cargo: grep -A1 "^\[\[package\]\]" Cargo.lock | grep -E "^name|^version" | paste - - | sed 's/name = "//; s/".*version = "/@/; s/"$//' > sbom-cargo.txt
    JS bundles (no lockfile): grep -oE 'node_modules/([^/]+)/' evidence/web/js-bundles/*.js | sed 's|.*node_modules/||; s|/$||' | sort -u > sbom-js-from-bundle.txt
    Universal (syft): syft dir:./target-repo -o json | jq -r '.artifacts[] | "\(.name)@\(.version)"' | sort -u > sbom-all.txt

0.2 Reverse lookup:

    python3 ~/arsenal/tools/reverse-lookup.py \
      --sbom sbom-npm.txt \
      --db ~/arsenal/tracking/research_db.jsonl \
      --ecosystem npm \
      --target "TargetName"

0.3 Triage results:

    HIT (lib with findings in research_db):
      → Kill Gate Q5 ONLY: is the vulnerable code path reachable in THIS target?
      → If reachable: write downstream report IMMEDIATELY (30-60 min)
      → Each hit references your existing CVE/GHSA as parent finding

    CLEAN (lib already fuzzed, 0 findings):
      → Skip — no further work needed on this lib

    UNKNOWN (lib not in research_db):
      → Prioritize by trust boundary:
        P0: parser/deserializer OR crypto/auth at trust boundary → FUZZ NOW
        P1: native C/C++ addon at trust boundary → FUZZ SOON
        P2: pure JS/Py at trust boundary, or parser not at boundary → QUEUE
        P3: pure JS/Py not at boundary → SKIP unless very high usage
      → Quick triage for unknowns:
        grep -rn "decode\|parse\|deserialize\|unmarshal\|loads\|unpack" node_modules/${lib}/ --include="*.js" 2>/dev/null
        ls node_modules/${lib}/build/Release/*.node 2>/dev/null  # native addon check
```

**Output:** `{protocol}-recon/REVERSE-LOOKUP.md` — hits, clean, unknown with priorities

**Maintenance:** After every fuzzing campaign or finding confirmation, append/update a line in `~/arsenal/tracking/research_db.jsonl`. The database compounds — at 200+ libs, probability of hits on any random target approaches certainty.

### Phase 0.5: Deep Mode Decision Gate (5 min)

Some targets justify 50-100h instead of the standard 15-25h. Evaluate BEFORE starting Phase 1.

**DEEP MODE criteria (ANY 3 triggers activate):**
- Bounty max ≥ $100K
- User base ≥ 10M or TVL/AUM ≥ $100M
- Client-side cryptography in JS bundles (not just JWT — key derivation, encryption, signing)
- Custom request signing protocol (not standard OAuth/JWT)
- Multiple interconnected assets sharing codebase (og.com + web.crypto.com pattern)
- Missing CSP `script-src` on financial platform
- 5+ postMessage handlers without origin checks
- Feature flag SDK with DOM mutation capability (GrowthBook, LaunchDarkly visual editor)

**DEEP MODE effects:**
- Timebox expands: 50-100h total. Hard stop at 20h with no findings (vs 8h standard).
- Phase 4 per finding: 6h max (vs 3h)
- JS bundle analysis: trace ALL crypto derivation chains, ALL postMessage handlers, ALL feature flag SDKs
- Console monitor scripts built per target (mon.js pattern — hook fetch, XHR, postMessage, localStorage, pushState)
- Cross-asset architecture correlation mandatory when multiple assets share codebase
- Multi-report submission strategy activated (Phase 7)
- Production impact validation: execute safe operations to prove chains (antiphishing change, TOTP create — not fund movement)

**Standard mode:** 15-25h. Hard stop at 8h with no findings.
**Deep mode:** 50-100h. Hard stop at 20h with no findings.

**Reference:** Crypto.com 92h investigation → 38 findings, 3 CRITICAL, potential $2M bounty. Standard 25h timebox would have stopped at surface-level findings.

**Output:** `DEEP-MODE.md` (criteria met, expected ROI, timebox)

---

### Phase 1: Protocol Intelligence (120 min max)

**Read:** `RECON-PLAYBOOK.md` §Phase 1

```
1.1 Protocol identity + TVL (DeFiLlama)
1.2 Audit trail analysis (download all, extract ack/wontfix)
1.3 Security contact discovery (priority chain)
1.4 On-chain enumeration (MCP tools: proxy, storage, logs)
1.5 Source code acquisition
1.6 C4 AUDIT REPORT × LIVE BOUNTY CROSS-REFERENCE
    If target has prior C4/Sherlock/Cantina audit AND a live bounty program:
    a) Download the full public audit report (code4rena.com/reports)
    b) For each H/M finding: verify the fix on the deployed contract
       → Real fix (root cause addressed) → mark PATCHED, note the pattern for adjacency scan
       → Bandaid fix (single require/modifier, root cause intact) → DEEP DIVE as new finding
       → Not fixed at all → IMMEDIATE finding candidate
    c) Check all downgraded/QA findings — judge said Low ≠ no bug. Re-evaluate at current TVL.
    d) For every H-01: scan adjacent functions (same pattern, different params, unreviewed)
    e) Output: {protocol}-recon/findings/C4-CROSS-REFERENCE.md (fix status per finding)
    CRITICAL: PoC must prove extraction from OBSERVED state deltas, not calculated counterfactuals.
    "LP_value_after < LP_value_before" from market state = proof.
    "solidity_cost - rust_cost > 0" from test arithmetic = argument (gets dismissed as "feature request").
```

**Output:** `{protocol}-recon/RECON.md`

### Phase 2: Surface Mapping (90 min max)

**Read:** `RECON-PLAYBOOK.md` §Phase 2 + `WEB-API-CHECKLIST.md`

**If target has web app + API + smart contracts** (most DeFi protocols):
**Read:** `DEFI-FULLSTACK-CHECKLIST.md` — Sections F0-F5 replace and extend Phase 2.
This checklist encodes the Upshift methodology (40 findings, $332M TVL exposed).

```
2.1 Smart contract surface (entry points, risk categorization)
2.2 Web/API surface (endpoint discovery, auth detection)
    → DEFI-FULLSTACK-CHECKLIST F1 for API, F2 for frontend bundles
2.3 Domain discovery (DNS, CT logs, subdomains, mirrors)
    → DEFI-FULLSTACK-CHECKLIST F0.3 + F3.1 (DNSSEC check)
2.4 Infrastructure fingerprinting (headers, errors, health)
    → DEFI-FULLSTACK-CHECKLIST F3.2-F3.3
2.5 Integration discovery (JS bundles, third-party services)
    → DEFI-FULLSTACK-CHECKLIST F2.1 (secret extraction from bundles)
2.6 Key architecture mapping (NEW — from Upshift methodology)
    → DEFI-FULLSTACK-CHECKLIST F4 (proxy admin, vault owners, operator keys)
2.7 JWT detection → Run: python detect_and_run.py --evidence "{protocol}-recon/evidence" --detect-only
    If JWT detected → auto-run full arsenal: python detect_and_run.py --evidence "{protocol}-recon/evidence" --output "{protocol}-recon/evidence/jwt-arsenal"
    See JWT-ARSENAL-PLAYBOOK.md for details
2.8 OAuth2/OIDC detection → If /.well-known/openid-configuration, /oauth/,
    or social login → activate OAUTH2-OIDC-PLAYBOOK.md (auto)
2.9 GraphQL detection → If /graphql returns 200 → DEFI-FULLSTACK §F1.7
2.10 WebSocket detection → If WS upgrade on /ws, /socket → DEFI-FULLSTACK §F1.8
2.11 Cross-chain messaging detection → grep for LayerZero/Axelar/Wormhole/Hyperlane/CCIP
    If detected → auto-activate CRITICAL-HUNT §3.5 (MANDATORY)
2.12 Supply chain scan → DEFI-FULLSTACK §F2.4 (dependency tree + malicious signal detection)
2.13 RPC node exposure → DEFI-FULLSTACK §F3.4 (txpool/debug/admin namespace probing)
2.14 Keeper/bot infra → DEFI-FULLSTACK §F3.5 (wallet identification, approval audit)
2.15 Redis/data store exposure → Run ~/Desktop/BUGS/redis-recon-scanner/redis-recon.py
    Auto-trigger: subdomain/IP probing reveals open ports 6379-6381, or SSRF found elsewhere
    Scan all discovered IPs on Redis default ports (6379, 6380, 6381)
    If Redis accessible → feed findings to Phase 3 Kill Gate (no-auth, dangerous cmds, CVEs)
    If SSRF found → generate gopher:// payloads for internal Redis probing (CONFIG, SLAVEOF, key dump)
    See RECON-PLAYBOOK.md §2.6 for full procedure
2.16 **MANDATORY: Authenticated session acquisition** → W8 in WEB-API-CHECKLIST.md
    Create test account via normal signup flow (Auth0/SIWE/email/wallet)
    Complete login, capture Bearer token
    Record token scope, expiry, refresh mechanism
    This token is REQUIRED for Phase 4 authenticated surface testing
2.17 Redis/data store exposure scan (from §2.15 auto-trigger results)
    Results feed into Kill Gate and attack chain construction
2.18 **MANDATORY — CLAUDE EXECUTES AUTOMATICALLY: Injection Proxy Bridge**
    Auto-trigger signals (ANY detected → Claude runs the full pipeline NOW, no asking):
      - base64 blobs in headers/body/cookies
      - Content-Type cbor/msgpack/protobuf/grpc/xml
      - JWT tokens with injectable claims (sub/role/email/admin)
      - XML bodies (ISO 20022 pain/pacs/camt), gRPC-Web, WebAuthn
      - HAR/Burp captures with encoded values, OpenAPI specs available
      - Any nested encoding chain
    Claude executes (in order):
      cd ~/Desktop/BUGS/injection-proxy && source .venv/bin/activate
      python3 proxy.py --detect "<captured_value>"
      python3 proxy.py --auto-profile --har <file> --output-dir profiles/auto/
      python3 proxy.py --from-spec <spec> --output-dir profiles/auto/
      python3 proxy.py --scan-all profiles/auto/ --categories sqli,ssti,cmdi,xss,xxe -v
    21 layers. N×M multiplier. Same as JWT Arsenal — auto-run, never ask.
    Tool: ~/Desktop/BUGS/injection-proxy/
2.19 **MANDATORY — CLAUDE AUTO-EXECUTES: Container Layer Analysis (D13)**
    Auto-trigger signals (ANY detected → Claude runs NOW):
      - COSE structures, CWT tokens, WebAuthn/FIDO2 flows
      - attestationObject, authData in registration/auth endpoints
      - eIDAS certificates (PSD2/Open Banking contexts)
      - PASETO tokens, Biscuit tokens, Macaroons
      - Any CBOR-encoded signed structure
    Claude executes:
      - Map L1→L2→L3→L4 propagation chain
      - Check target's CBOR backend against C-003/C-004/C-005
      - Test COSE-001→004, CWT-001→003, WEBAUTHN-001→003 patterns
      - Identify cross-impl verification mismatches (issuer lib vs verifier lib)
    Spec: ~/Desktop/BUGS/CONTAINER-LAYER-ATTACK-SPEC.md
2.20 **H1 Pattern Scan (Auto-activated on ANY web/API target)**
    Run H1-HUNTING-PATTERNS.md detection priority matrix (4h scan):
    1. [5min]  API key leak scan (JS bundles, source maps, .env) → P-H1-070
    2. [10min] GraphQL introspection + IDOR via node query → P-H1-002, P-H1-071
    3. [15min] Auth flow analysis (MFA bypass, session timing) → P-H1-020 to P-H1-023
    4. [15min] SSRF surfaces (webhooks, PDF gen, imports, avatar) → P-H1-010 to P-H1-013
    5. [30min] Authorization consistency matrix (all endpoints + auth) → P-H1-023, M-H1-002
    6. [30min] IDOR on destructive ops (DELETE, PUT, PATCH) → P-H1-003
    7. [30min] Race condition on financial ops → P-H1-030 to P-H1-032
    8. [30min] Business logic flow (checkout, KYC, multi-step) → P-H1-060 to P-H1-062
    9. [15min] Cache deception / poisoning → P-H1-080, P-H1-081
    10. [15min] Subdomain takeover → P-H1-090
    11. [30min] AI/LLM prompt injection (if AI features) → P-H1-100, P-H1-101
    ROI data: IDOR+auth bypass outpay XSS 3:1. Manual logic > automated patterns.
    See H1-STATISTICS.md for target selection scoring and time boxing.
```

**Output:** `{protocol}-recon/SURFACE-MAP.md`

### Phase 3: Kill Gate Triage (30 min per finding)

**Lifecycle invocation (MANDATORY before Kill Gate per finding, enforces CLAUDE.md rule #39):**

```bash
~/arsenal/audit-lifecycle/bin/on-finding.sh <FINDING_ID>
```

Instantiates per-finding gate templates in `findings/`:
- `{FINDING_ID}-kill-gate.md` (this phase)
- `{FINDING_ID}-severity-commit.md` (MUST be filled with artifact-required inputs BEFORE draft opens — see rule #39)
- `{FINDING_ID}-chain-proof.md` (Phase 6 D7 — auth-class findings)
- `{FINDING_ID}-weight-card.md` (Phase 6 D8 — severity ≥ Low)

After Kill Gate passes (PROCEED verdict), fill `SEVERITY-COMMIT-{id}.md` based on evidence currently held, then run `~/arsenal/audit-lifecycle/lib/artifact-validator.sh findings/{id}-severity-commit.md` — MUST return PASS before writing the draft file (rule #39).



**Read:** `/home/malix/Desktop/BUGS/KILL-GATE-TEMPLATE.md`

For each finding candidate from Phase 2:
```
Q1: Design Intent Test
Q2: Code Path Reachability (DEPLOYED build)
Q3: Disjoint Sets
Q4: Existing Guards
Q5: Trigger Feasibility
Q6: Industry-Known Vulnerability
Q7: Contract Upgradeability (EIP-1967)
Q8: Auditor Cross-Reference
Q9: Post-Audit Code Dating
Q10: Prior Audit Findings (C4/Cantina/Sherlock)
```

**Verdict:** PROCEED / KILL / DOWNGRADE

**Output:** `{protocol}-recon/reports/KILLGATE-{id}.md` per finding

### Phase 4: Deep Analysis (3h max per finding)

**Read:** `DEEP-ANALYSIS-PLAYBOOK.md` + `WEB-API-CHECKLIST.md`

```
4.1 Auth analysis (24 vectors, SIWE compliance)
    → JWT vectors 4/4b/16/17/18: AUTOMATED by JWT Arsenal if activated in §2.7
    → OAuth2/OIDC vectors V1-V12: OAUTH2-OIDC-PLAYBOOK.md if activated in §2.8
4.1b **MANDATORY: Authenticated surface testing** (DEEP-ANALYSIS §4.12)
    → Requires token from §2.15
    → Test ALL routes from bundle extraction WITH valid token
    → Map authorization levels: which endpoints require sudo/re-auth vs standard token
    → Authorization consistency matrix: security ops (MFA, SSO, email) vs non-security ops
    → This is WHERE Request Finance HIGH was found — MFA delete with standard token
4.2 Smart contract math proofs (rounding, overflow, invariants)
4.3 API endpoint deep testing (verbatim responses)
    → GraphQL: DEFI-FULLSTACK §F1.7 (introspection, batching, depth, IDOR)
    → WebSocket: DEFI-FULLSTACK §F1.8 (auth, CSWSH, on-chain triggers)
4.4 Infrastructure deep dive (signing, keys, cloud)
    → Deserialization: DEFI-FULLSTACK §F1.9 (pickle, Jackson, yaml, prototype)
    → RPC node exposure: DEFI-FULLSTACK §F3.4 (txpool/debug/admin namespace)
    → Keeper/bot infra: DEFI-FULLSTACK §F3.5 (wallet audit, approvals)
    → Metadata integrity: DEFI-FULLSTACK §F3.6 (IPFS, baseURI admin)
4.5 JS bundle analysis (30+ grep patterns)
    → Supply chain: DEFI-FULLSTACK §F2.4 (dependency audit, typosquat, maintainer)
4.6 Integration deep dives (relayer, batch, webhooks)
4.7 Cross-chain messaging: CRITICAL-HUNT §3.5 (source validation, replay, DVN/ISM)
    AUTO-triggered when LayerZero/Axelar/Wormhole/Hyperlane/CCIP detected in §2.11
4.8 Proxy upgrade chain: CRITICAL-HUNT §6.3 + DEFI-FULLSTACK §F4.1 expanded
4.9 Structural MEV: CRITICAL-HUNT §5.3 (ONLY if program doesn't exclude frontrunning)
4.10 **MANDATORY — CLAUDE EXECUTES: Injection Proxy Bridge** → DEEP-ANALYSIS §4.13
    If ANY exotic encoding detected in §2.18 → Claude runs the full pipeline automatically:
    detect → auto-profile → scan-all → report. No asking, no suggesting.
    Tool: ~/Desktop/BUGS/injection-proxy/ (21 layers, N×M multiplier)
    NEVER SKIP. Same auto-execution model as JWT Arsenal.
4.11 **MANDATORY — CLAUDE EXECUTES: Container Layer Analysis (D13)**
    If COSE/CWT/WebAuthn/eIDAS/PASETO/Biscuit/Macaroons detected in §2.19:
    → Map L1→L2→L3→L4 chain, test COSE-001→004, CWT-001→003, WEBAUTHN-001→003
    → Check CBOR backend against C-003/C-004/C-005 known bugs
    → Identify cross-impl verification mismatches
    Spec: ~/Desktop/BUGS/CONTAINER-LAYER-ATTACK-SPEC.md
    NEVER SKIP when signed container formats detected.
4.12 **MANDATORY: Shared lock cross-subsystem escalation analysis**
    Auto-trigger: ANY finding involving lock contention, DoS via resource consumption,
    or algorithmic complexity (CWE-407/400/662) on a target with concurrent subsystems.
    Steps:
    → Step 1: Map ALL synchronization primitives in the target codebase
      Java: grep -rn "synchronized\|ReentrantLock\|\.lock()" --include="*.java"
      Go: grep -rn "sync\.Mutex\|sync\.RWMutex\|\.Lock()" --include="*.go"
      Rust: grep -rn "Mutex::new\|RwLock::new\|\.lock()" --include="*.rs"
    → Step 2: For each lock, identify ALL acquisition sites. Group into:
      (a) untrusted input paths (P2P, HTTP, RPC, WebSocket handlers)
      (b) critical operation paths (consensus, payment, auth, block production)
    → Step 3: If same lock appears in BOTH groups → escalation candidate
    → Step 4: Quantify lock hold time in untrusted path vs critical path deadline
      If lock_held_time > deadline → severity crosses subsystem boundary (S:U → S:C)
    → Step 5: Check for absence of timeout/priority on lock acquisition
      No tryLock(timeout) = indefinite blocking = guaranteed starvation
    Key signals: `synchronized(this)` mixing handlers, single-threaded critical paths,
    O(N²) in untrusted path, no lock timeout/fairness.
    Reference: TRON-C01 (AdvService monitor shared between P2P INVENTORY and SR broadcast).
    See CLAUDE.md rule #35 for full pattern.
4.13 **H1 Deep Dive Patterns (Auto-activated on web/API targets)**
    Apply deep analysis from H1-HUNTING-PATTERNS.md for findings from §2.20:
    → SSRF chain escalation: P-H1-040 (cloud metadata -> IAM), P-H1-041 (internal service -> RCE)
    → Race condition PoC: single-packet attack technique (Turbo Intruder / 50 concurrent requests)
    → Auth bypass chain: premature session -> MFA skip -> ATO (P-H1-020)
    → IDOR chain: read -> enumerate -> write -> delete -> ATO (M-H1-010 for payout multiplier)
    → Business logic: price manipulation, multi-step bypass, coupon race (P-H1-060 to P-H1-062)
    → Cache attacks: web cache deception (P-H1-080), cache poisoning via unkeyed headers (P-H1-081)
    → HTTP request smuggling: CL.TE / TE.CL (P-H1-110)
    → AI/LLM: prompt injection -> tool use abuse -> data exfil (P-H1-100, P-H1-101)
    Meta-patterns to ALWAYS apply:
    → M-H1-001: Inconsistent auth across REST/GraphQL/WebSocket
    → M-H1-002: Destructive ops weaker auth than read ops
    → M-H1-003: Race windows in all check-then-act state transitions
    → M-H1-007: Session tokens before auth complete = MFA bypass
```

**Output:** Updated finding files in `findings/`

### Phase 5: Attack Chains (2h max)

**Read:** `ATTACK-CHAIN-PLAYBOOK.md`

```
5.1 Build cross-reference matrix (all N×N finding pairs)
5.2 Construct attack chains from clusters
5.3 Attempt evidence promotion (L1→L2→L3→L4)
5.4 Generate on-chain proofs (state snapshots, tx history)
5.5 Compile MASTER-FINDINGS-INDEX
```

**Output:** `attack-chains/`, `MASTER-FINDINGS-INDEX.md`

### Phase 9: Attack Chain Composition (triggered when 2+ findings)

**Read:** `ATTACK-CHAIN-PLAYBOOK.md`

**Trigger:** 2+ findings exist on the same target after Phases 3-5 complete.

Compose individual findings into multi-step attack chains. This is distinct from Phase 5's cross-reference matrix — Phase 9 focuses on constructing executable kill chains where finding A enables finding B, producing combined severity greater than the sum of parts. Run `ATTACK-CHAIN-PLAYBOOK.md` end-to-end.

```
9.1 Enumerate all finding pairs where causal dependency exists
9.2 Build directed attack graphs (entry → pivot → impact)
9.3 Calculate combined severity and attack cost per chain
9.4 Generate chain-specific PoCs that demonstrate full path
9.5 Pre-build dismissal counters for "these are separate issues" responses
```

**Output:** `attack-chains/COMPOSED-{chain_id}.md`, updated `MASTER-FINDINGS-INDEX.md`

### Phase 7: Multi-Report Submission Strategy (1h)

**Trigger:** Investigation produces 5+ findings on the same target.

Don't dump all findings in one report. Group into themed submissions, submit strongest standalone first.

```
7.1 Rank all findings by standalone_severity × payout_potential
7.2 Identify single strongest STANDALONE finding → Submission 1
    - Must not require other findings as prerequisite
    - Must have highest evidence level (L3/L4 preferred)
    - Must map to highest bounty tier
7.3 Group remaining findings into thematic chains:
    - Authorization consistency violations (auth matrix findings)
    - Cross-origin / postMessage chains
    - Cryptographic weaknesses (key material, signing, encryption)
    - Infrastructure / CSP / headers
    - Mediums grouped by theme
7.4 Order submissions:
    S1: Standalone critical (establishes credibility)
    S2: Auth consistency chain (proven pattern, hard to dismiss)
    S3: Cross-origin chain (with PoC HTML)
    S4: Crypto chain (honest about prerequisites)
    S5: Infrastructure / defense-in-depth
    S6: Grouped mediums
7.5 Each submission independently meets preflight 22/24
7.6 Each includes Program Tier Assessment mapping finding to bounty criteria
7.7 Reference prior submissions by ID in later reports (builds narrative)
```

**Principle:** Credibility from first finding biases review of subsequent ones.
**Anti-pattern:** Dumping 38 findings in one report → triager overwhelmed → lowball severity on everything.
**Reference:** Crypto.com 6-submission strategy: F-027 (standalone CRITICAL) first, then 5 themed chains.

**Output:** `SUBMISSION-STRATEGY.md` (ordered list, groupings, dependencies)

### Phase 6: Preflight & Handoff (15 min per finding)

**Read:** `/home/malix/Desktop/BUGS/PREFLIGHT-CHECK.md` AND `/home/malix/Desktop/BUGS/CHAIN-PROOF-GATE.md` AND `/home/malix/Desktop/BUGS/WEIGHT-CARD.md`

**Two mandatory gates in this phase, catching distinct failure modes:**

1. **CHAIN PROOF GATE (D7) — auth-class findings:** for finding in the class auth-bypass / hardcoded-credential / signature-forge / JWT-token / session-hijack / IDOR-write / password-reset / account-binding, run `CHAIN-PROOF-GATE.md` Stage 1 hedge grep. If ≥1 match, complete Stage 2 (ethical variant test) OR downgrade severity. A failing chain proof = PREFLIGHT D7 fail = submission BLOCKED regardless of total score. WEEX-002 2026-04-13 lesson: draft bound for Medium/Informative became Critical after chain proof via fictitious external_id. See CLAUDE.md rule #36.

2. **WEIGHT CARD GATE (D8) — all non-Informational findings:** for every finding claiming severity ≥ Low with dollar impact, populate Weight Card in REPORT-STANDARD.md "Weight Accounting" section. Hard gate: W1 (computed dollar loss with formula + inputs, or DoS alternative with measured downtime × req/s × users) OR W5 (≥1 paid precedent with dollar figure from H1/C4/Cantina/Sherlock). Both slots cannot be qualitative. Use `~/arsenal/tools/precedent-scan.sh <class>` to populate W5 fast (copy-paste-ready block). Phemex R2 2026-04-10/13 lesson: chain was proven, weight was narrated ("I have not confirmed whether this enables profitable extraction"), result was Informative. See CLAUDE.md rule #37.

```
6.0a **CHAIN PROOF GATE (auth-class findings only, mandatory):**
    grep -nE "I did not test|I deliberately did not|inferred from|would access|would authenticate|would receive|deliberately not executed|not executed because|strongly indicates|architectural analysis suggests|documented .* protocol, not from testing|not confirmed whether|I stopped at|I did not attempt|the final link .* is inferred|not tested against|could not verify|assumed to be accepted" "$DRAFT_PATH"
    If any match → run CHAIN-PROOF-GATE.md Stage 2 before continuing.

6.0b **WEIGHT CARD GATE (all findings claiming ≥ Low with dollar impact, mandatory):**
    grep -nE "could drain|could extract|could potentially|significant funds|substantial losses|large number of users|many users|many accounts|estimated to|potentially affects|at risk|exposes users to|attacker could extract|could lead to|may result in|would enable loss of|all users|all deposits|all funds" "$DRAFT_PATH"
    For each match, verify a specific number appears in the same section. If not,
    populate W1 (computed loss) or W5 (paid precedent via precedent-scan.sh) OR
    downgrade severity. W1 and W5 cannot both be qualitative.

6.1 Write report using REPORT-STANDARD.md (Transak voice):
    - Epistemic precision: "I have confirmed [N] facts" / "I have NOT confirmed [X]"
    - Anti-pattern naming: name the architectural flaw
    - Chain factoring: prove each link independently
    - Baseline test: prove control IS enforced elsewhere
    - Enforcement matrix for auth consistency findings
    - No CVSS in body — form fields only
6.2 Score each finding against 24-point rubric (min 22/24)
6.3 Verify all evidence files exist and are referenced
6.4 Verify IS/IS NOT sections are honest
6.5 Verify recommended fixes are concrete (imperative, not suggestions)
6.6 Hand off to /disclose or /immunefi-submit

6.7 **MECHANICAL PREFLIGHT (MANDATORY before submit, enforces CLAUDE.md rules #38 + #39):**
    ~/arsenal/audit-lifecycle/bin/preflight-mechanical.sh findings/{FINDING_ID}-draft.md {FINDING_ID}
    Runs D0-init / D0-finding / D0-commit / D8b TVL-readback / D10 compliance citation / hygiene.
    Exit 0 = PASS (submit authorized). Exit 1 = BLOCKED (fix before send).
    LIFECYCLE_ENFORCE=hard for hard-block; LIFECYCLE_ENFORCE=soft for warnings-only during calibration.

6.8 **ON SUBMIT — record to OUTCOMES.jsonl with timestamps + tier commits:**
    ~/arsenal/audit-lifecycle/bin/on-submit.sh {FINDING_ID}
    Appends entry with drafted_at / gates_run_at / submitted_at / preflight_run + tier commits
    (evidence / chain / impact / severity_committed).

6.9 **ON HOLD — populate held_reason + uncertainty_source at moment of hold:**
    ~/arsenal/audit-lifecycle/bin/on-hold.sh {FINDING_ID} <held_reason> [uncertainty_source]
    Valid held_reason: rep_gate | deposit_pending | geo_block | awaiting_validation |
                       gate_failed_unresolved | self_uncertainty | framing_unclear
    Valid uncertainty_source (required if self_uncertainty): technical_doubt | severity_doubt | scope_doubt
    WATCH signal: self_uncertainty + framing_unclear > 25% over 30d = gates over-regulating.
```

**Output:** `reports/PREFLIGHT-{id}.md`, ready-to-disclose findings

---

## Time Boxing

| Phase | Standard Mode | Deep Mode | Checkpoint |
|-------|-------------|-----------|-----------|
| 0. Reverse Lookup | 5min | 5min | REVERSE-LOOKUP.md complete |
| 0.5. Deep Mode Gate | 5min | 5min | DEEP-MODE.md (GO/NO-GO) |
| 1. Protocol Intelligence | 2h | 3h | RECON.md complete |
| 2. Surface Mapping | 1.5h | 3h | SURFACE-MAP.md complete |
| 3. Kill Gate (per finding) | 30min | 30min | GO/KILL/DOWNGRADE decided |
| 4. Deep Analysis (per finding) | 3h | 6h | Finding file updated |
| 5. Attack Chains | 2h | 3h | Matrix + chains documented |
| 9. Attack Chain Composition | 1h | 2h | Composed chains if 2+ findings |
| 7. Multi-Report Strategy | — | 1h | SUBMISSION-STRATEGY.md |
| 6. Preflight (per finding) | 15min | 30min | 22/24+ score (3 revision cycles in deep mode) |
| **Total per investigation** | **15-25h** | **50-100h** | |

**Standard hard stop:** If no finding after 8h of scanning → MOVE ON to next target.
**Deep mode hard stop:** If no finding after 20h of scanning → MOVE ON to next target.

---

## Key Rules

These are non-negotiable behavioral directives:

### Finding Discipline
1. **Every finding checked for chain potential.** No finding exists in isolation. After each new finding, re-examine all existing findings for cross-reference connections.
2. **Evidence hierarchy always tracked.** Every finding has a level (L1-L4). Every phase transition attempts promotion.
3. **Never delete informational findings.** They may chain later. The 34th finding may chain 5 informationals into a critical.

### Persistence
4. **Error messages are intelligence, not dead ends.** 500 errors reveal framework, DB, internal paths. Follow P1.
5. **15 auth bypass vectors before marking "blocked."** Full procedure in P2. No shortcuts.
6. **Mirror/legacy/staging domains always tested.** Same backend, different auth. Follow P5.

### Evidence
7. **JS bundle analysis mandatory for web targets.** 30+ grep patterns. Non-negotiable.
8. **API responses saved verbatim, never summarized.** Full JSON to evidence/. Chain analysis requires details.
9. **On-chain state documented with block numbers.** Every evm_call/read_storage → block number recorded.

### Process
10. **Workspace structure from WORKSPACE-TEMPLATE.md.** Init at start, maintain throughout.
11. **Kill gate before deep dive.** Never spend 3h analyzing a finding that would fail Q1 (design intent).
12. **Preflight before disclosure.** 22/24 minimum. No exceptions.

### Tactical
13. **Submit strongest finding first.** Credibility from first finding biases review of subsequent ones.
14. **Internal consistency is strongest argument.** If protocol protects against risk elsewhere, missing protection here is oversight, not design.
15. **Never oversell severity.** Acknowledged Medium beats dismissed High. IS/IS NOT sections enforce honesty.
16. **Count affected deployments.** "7 contracts across 3 chains" beats "some contracts."
17. **Note absence of recovery mechanisms.** "No pause, no governance override, no circuit breaker" eliminates "admin can fix it" dismissal.
18. **MANDATORY: Acquire authenticated session and test ALL routes.** A WAF returning 403 does NOT mean "blocked" — it means "requires auth." Create a test account via the normal signup flow, capture the Bearer token, and test every route from bundle extraction. Authorization consistency testing (what requires sudo vs standard token) is where HIGH/CRITICAL findings hide. Request Finance CVSS 7.6: MFA deletion accepted standard token while viewing apps required sudo. This was in the extracted routes the entire time but was missed because no authenticated testing was performed.
19. **Authorization consistency is the new internal consistency.** Map every security-critical operation (MFA, SSO, email change, password change, session revocation) and verify each requires re-authentication or elevated scope. If ANY lower-sensitivity operation requires higher authorization than a security-critical one, it's an oversight finding. Pattern: `GET /apps` requires sudo but `DELETE /users/mfa` doesn't = HIGH.
20. **Client-side crypto key chain tracing is mandatory for web targets with encryption/signing.** When JS bundles contain crypto operations (PBKDF2, AES-KW, AES-GCM, ECDSA, RSA-OAEP, HKDF), trace the FULL derivation chain. Extract ALL constants (passwords, salts, wrapped keys, iteration counts, algorithm parameters). Attempt key reconstruction in browser console. Test if reconstructed key produces output the backend accepts. This is NOT the same as "grep for API keys" — it's tracing a multi-step cryptographic derivation from public constants to working encryption key. Crypto.com F-027: PBKDF2(hardcoded password, hardcoded salt, 100000) → AES-KW unwrap(hardcoded wrapped key) → AES-GCM 256-bit key. All constants in public JS bundle. Full reconstruction SUCCESS. Backend accepted forged encrypted passcodes.
21. **WebCrypto `extractable:false` does NOT prevent signing/encryption.** When IndexedDB contains CryptoKey objects with `extractable:false`, the key cannot be exported — but `crypto.subtle.sign()`, `encrypt()`, and `decrypt()` work for ANY same-origin JavaScript. Map all CryptoKey objects in all IndexedDB databases. Test sign/encrypt/decrypt on each. If XSS is possible (no CSP script-src), every non-extractable key is usable. Frame the argument: "extractable:false blocks export, not usage. Any same-origin JS signs whatever it wants." Crypto.com F-027: MonaDSA ECDSA P-256 key in IndexedDB, extractable:false, but crypto.subtle.sign() produced valid signatures accepted by backend.
22. **Custom request signing → map what's signed AND what's NOT signed.** When target uses custom request signing (not JWT/OAuth), document: what IS signed (body? headers? method? path? timestamp? nonce?) and what IS NOT signed. Missing elements = replay potential, cross-endpoint signature reuse, parameter manipulation. Count what percentage of endpoints require signing — if low (Crypto.com: 8/84 = 9.5%), that's an authorization consistency finding. Crypto.com MonaDSA: signs body ONLY. No method, path, timestamp, or nonce. Signature from TOTP create can be replayed to antiphishing update if body matches.
23. **PostMessage handlers without origin checks = cross-origin API triggers.** For every web target, extract ALL `addEventListener("message",...)` from JS bundles. For each handler: (1) Does it check `event.origin`? (2) What does it do with the data? (3) Does it trigger API calls with attacker-controlled parameters? Build a cross-origin PoC HTML that opens the target in a window and sends crafted messages. If handler triggers authenticated API calls with attacker-controlled parameters (transaction_id, amount, etc.) → CRITICAL. Crypto.com WC-004+WC-021: 7 handlers, 0 origin checks, cross-origin postMessage triggered GET /fiat_wallets/transactions/{attacker_controlled_id} with victim's session.
24. **CSP is a severity multiplier, not a checkbox.** Missing `script-src` turns every other finding into a potential XSS chain. Document: (1) which CSP directives are present/absent, (2) which XSS vector classes are blocked/unblocked, (3) count external scripts without SRI, (4) check Trusted Types. A financial platform with no `script-src` and 34/35 scripts without SRI = every CDN compromise, every feature flag injection, every DOM XSS lands without resistance. This is the difference between "XSS is a theoretical prerequisite" and "XSS is a low barrier." Crypto.com WC-027: no script-src, no default-src, no object-src, no base-uri on a $2M bounty target.
25. **Feature flag SDKs are XSS vectors.** GrowthBook, LaunchDarkly, Split, Optimizely, and others can create `<script>` elements or modify DOM from remote config. Check: (1) SDK key exposed in bundle? (2) Does SDK have DOM mutation capabilities? (`_applyDOMChanges`, visual editor, `innerHTML=e.js`) (3) CORS on config/SSE endpoints? (`access-control-allow-origin: *` on config endpoint = any origin subscribes to flag updates) (4) Can experiments inject script? Crypto.com: GrowthBook SDK key `sdk-Fff1GTESgSQrtPqE`, `_applyDOMChanges` creates `<script>` via innerHTML, SSE endpoint returns `access-control-allow-origin: *` (confirmed via curl).
26. **Build console monitor scripts per target.** For deep investigations, build a custom monitoring script that hooks: `window.fetch`, `XMLHttpRequest.open`, `localStorage.setItem`, `history.pushState`, and `window.addEventListener("message")`. Run in the target's console to observe real-time behavior — which API calls fire, what data flows through postMessage, what gets written to storage. This is the microscope that reveals handler→API chains invisible in static analysis. Crypto.com mon2.js: revealed that cross-origin postMessage triggered authenticated fetch to /fiat_wallets/transactions/ and /auth/tokens — impossible to see from bundle grep alone.
27. **Cross-asset architecture correlation multiplies bounty scope.** When multiple assets share codebase (og.com + web.crypto.com), prove architecture identity by comparing: bundle structure, API proxy paths, crypto constants (different values, same derivation), IndexedDB schema, CSP headers. Execute full chain on lower-value asset, validate architecture on higher-value asset, document safety note for why full chain wasn't executed on higher-value. Submit under highest-value asset with lower-value as proof. Crypto.com: full chain on og.com ($40K max), architecture confirmed on web.crypto.com ($2M max), submitted under web.crypto.com.
28. **Report quality is a payout multiplier.** Three revision cycles minimum for CRITICAL submissions: (1) initial write → preflight 22/24+, (2) triager-perspective review → anticipate challenges and build defenses, (3) tone cleanup → remove LLM voice, write like a researcher not a model. Every report needs: Program Tier Assessment mapping to bounty criteria, verifiable financial data (not "industry average"), IS/IS NOT honesty, "Pick one" framing for design contradictions, attack scenarios with real-world precedents and dates, concrete fix priority table. No dramatic flourishes, no academic transitions, no corporate filler.
29. **H1 meta-patterns are mandatory on ALL web/API targets.** Apply all 10 meta-patterns from H1-HUNTING-PATTERNS.md on every engagement: M-H1-001 (inconsistent auth across interfaces), M-H1-002 (destructive ops weaker auth), M-H1-003 (race windows in state transitions), M-H1-004 (user-controlled URLs = SSRF), M-H1-005 (client-provided values trusted server-side), M-H1-006 (API key scope verification), M-H1-007 (session tokens before auth complete), M-H1-008 (same resource different route different auth), M-H1-009 (automated tools saturate surface bugs — focus on logic), M-H1-010 (chain for maximum payout — IDOR read=$1K vs IDOR->ATO=$12K). These encode $81M in annual H1 payouts. The highest-ROI patterns are auth consistency (Rule 19 + M-H1-002), SSRF chains (M-H1-004), and race conditions on financial ops (M-H1-003).
30. **AI/LLM features are the fastest-growing attack surface.** Prompt injection +540% YoY, 1,121 programs with AI in scope. When ANY AI feature detected (chatbot, AI search, summarizer, AI assistant), apply P-H1-100 (prompt injection) and P-H1-101 (tool use abuse). Test: indirect injection via documents processed by AI, system prompt extraction, tool call manipulation. AI findings are manual-only territory — hackbots can't find prompt injection in other AI systems.

31. **MANDATORY for in/out protocols: mirror invariant audit before declaring any file clean.** CLAUDE.md rule #41. For bridges, vaults, escrow, lock/unlock, mint/burn, and any paired state-changing operation, the audit methodology is NOT "find a bug in this file" but "for every validation applied on one side of a paired flow, is the mirror validation present on the other side?" Rule extends Rule 14 (internal consistency) from an argumentative tool to a mandatory audit procedure. **Method:** before marking any in/out file "audited clean", (a) enumerate bidirectional function pairs (`transferToAgent`/`transferToken`, `deposit`/`withdraw`, `lock`/`unlock`, `mint`/`burn`, `send`/`receive`, `encode`/`decode`, `fund`/`release`, `convertToShares`/`convertToAssets`), (b) grep each pair and read V_in/V_out validation sets side-by-side, (c) for every check in V_in absent from V_out (and vice versa), require either a one-sentence articulable design reason, a verifiable different-layer guarantee, or a code-comment spec — if none, it is an oversight finding-candidate. **Mechanical gate:** if notes say "file X audited clean" without a companion line stating the mirror comparison result, the file is not clean, audit is incomplete. Force both halves of each pair to be written explicitly. **Why:** 2026-04-19 Snowbridge audit noted `Functions.sol (transferToAgent has FoT protection)` AND `AgentExecutor.sol (transferToken) audited clean` in the same pass. Bug was absence of the ingress FoT guard on egress side. V12 found it next day. Absence-of-protection is invisible to presence-scanning; mirror audit achieves human uniformity equivalent to what LLM auditors have by default. See `feedback_mirror_invariant_audit.md` for the full grep patterns per protocol topology.

---

## Workspace Initialization

On `/gravedigger <target>`:

1. Read `WORKSPACE-TEMPLATE.md`
2. Create `{target}-recon/` directory structure (use T1 init script)
3. Create investigation status tracker (T5)
4. Begin Phase 1

On `/gravedigger <target> --resume`:

1. Read `{target}-recon/MASTER-FINDINGS-INDEX.md` or finding inventory
2. Read investigation status tracker
3. Identify current phase and resume

---

## Integration Points

### To `/disclose`
Finding files in `findings/` follow the template from WORKSPACE-TEMPLATE.md T3, which is compatible with the disclosure skill's input format. The MASTER-FINDINGS-INDEX provides the executive summary and severity matrix.

### To `/immunefi-submit`
Same finding files. Kill gate results provide the evidence that findings are not duplicates (Q6, Q8, Q10). Preflight scores map to Immunefi's quality requirements.

### From `KILL-GATE-TEMPLATE.md`
Phase 3 uses the kill gate directly. MCP tools for Q7 (upgradeability), Q9 (post-audit dating), Q10 (prior findings search).

### From `CRITICAL-HUNT-CHECKLIST.md`
Phase 2 and 4 reference the hunt checklist for smart contract surface mapping and deep analysis patterns.

### From `SOLANA-HUNT-CHECKLIST.md`
Used alongside CRITICAL-HUNT-CHECKLIST.md when target includes Solana programs.

### From `NEXTJS-HUNT-CHECKLIST.md`
**Auto-activated** when target web application uses Next.js (detected via `_next/` paths, `__NEXT_DATA__`, RSC Flight protocol responses). Covers React2Shell (CVE-2025-55182), middleware bypass (CVE-2025-29927), Server Actions IDOR, env exposure, SSRF via Server Components, cache poisoning. Used in Phase 2 (surface mapping) and Phase 4 (deep analysis) for web targets.

### From `DEFI-FULLSTACK-CHECKLIST.md`
**The master checklist for DeFi protocols with web + API + contracts.** Derived from the Upshift methodology (40 findings, $332M TVL, fund theft chain at $0 cost). Covers 7 phases: API surface (F1), frontend bundle analysis (F2), infrastructure & DNS (F3), signing & key architecture (F4), smart contract architecture (F5), attack chain construction (F6), and the complete workflow (F7). **Activates all domain-specific checklists** (CRITICAL-HUNT, SOLANA-HUNT, NEXTJS-HUNT) as sub-procedures within its flow. Use this as the entry point for any DeFi full-stack investigation instead of running individual checklists separately.

### From `H1-HUNTING-PATTERNS.md` (Auto-Activated on ANY Web/API Target)
**Auto-activated during Phase 2 (§2.20) and Phase 4 (§4.13) for ALL web and API targets.** Contains 60+ vulnerability patterns extracted from 2,500+ disclosed HackerOne reports ($81M annual payouts). 13 categories: IDOR (P-H1-001 to P-H1-004), SSRF (P-H1-010 to P-H1-013), Auth Bypass/ATO (P-H1-020 to P-H1-023), Race Conditions (P-H1-030 to P-H1-033), SSRF-to-RCE chains (P-H1-040 to P-H1-041), RCE (P-H1-050 to P-H1-053), Business Logic (P-H1-060 to P-H1-062), API (P-H1-070 to P-H1-073), Web Cache (P-H1-080 to P-H1-081), Subdomain Takeover (P-H1-090), AI/LLM (P-H1-100 to P-H1-101), HTTP Smuggling (P-H1-110), Info Disclosure (P-H1-120 to P-H1-121). Plus 10 meta-patterns (M-H1-001 to M-H1-010) for cross-category heuristics. Each pattern includes grep detection commands, false positive guards, and chain potential. Companion file `H1-STATISTICS.md` provides ROI data for target selection and time allocation.

### From `JWT-ARSENAL-PLAYBOOK.md` (Auto-Activated)
**Auto-activated when JWT/JWS/JWE authentication is detected during Phase 2.** Replaces manual JWT testing (auth vectors 4, 4b, 16, 17, 18) with the 8-tool JWT Arsenal at `~/Desktop/BUGS/jwt-nullgate-research/jwt-arsenal/`. Detection triggers: Bearer eyJ... tokens, JWKS endpoints, JWT library in dependencies, FastAPI/Spring framework detection. Runs automated cross-library differential testing (8 libs, 5 languages), algorithm fuzzing, null-gate scanning, RFC compliance checking, header surface mapping, and config-to-vuln mapping. Reduces ~5h manual JWT testing to ~35min automated analysis. Findings auto-generate gravedigger workspace finding files for kill gate triage.

### From `redis-recon-scanner` (Auto-Activated)
**Auto-activated during Phase 2 surface mapping when infrastructure IPs are discovered.** Runs `~/Desktop/BUGS/redis-recon-scanner/redis-recon.py` against discovered infrastructure on ports 6379/6380/6381. Detection triggers: open ports on Redis defaults, SSRF vulnerabilities found elsewhere, Redis/Valkey/KeyDB mentions in configs or error messages. The scanner performs: RESP protocol handshake, auth assessment (13 default passwords), dangerous command enumeration (CONFIG, DEBUG, MODULE, SLAVEOF, EVAL), CVE detection (CVE-2025-49844, CVE-2024-31449, CVE-2024-31228, CVE-2023-45145), key sampling, and SSRF payload generation (gopher:// + dict://). Findings feed into Phase 3 Kill Gate. SSRF payloads are used when SSRF is discovered in the web/API surface to probe internal Redis instances. See RECON-PLAYBOOK.md §2.6.

### From `injection-proxy` (CLAUDE AUTO-EXECUTES — MANDATORY)
**Claude runs this automatically — same model as JWT Arsenal.** No suggesting, no asking. When Claude detects exotic encodings during ANY phase, Claude executes the pipeline itself.
**Tool**: `~/Desktop/BUGS/injection-proxy/`
**Detection triggers** (ANY → Claude runs NOW):
  - base64 blobs in headers/body/cookies
  - `Content-Type: application/cbor|msgpack|protobuf|grpc|xml`
  - JWT tokens with injectable claims, XML/ISO 20022 bodies, gRPC-Web, WebAuthn
  - HAR/Burp captures or OpenAPI specs available with encoded values
  - Any nested encoding chain (base64→JSON, gzip→protobuf, etc.)
**What Claude runs** (in order):
```bash
cd ~/Desktop/BUGS/injection-proxy && source .venv/bin/activate
python3 proxy.py --detect "<captured_value>"                              # 1. detect layers
python3 proxy.py --auto-profile --har <file> --output-dir profiles/auto/  # 2. generate profiles (if HAR)
python3 proxy.py --from-spec <spec> --output-dir profiles/auto/           # 3. generate profiles (if OpenAPI)
python3 proxy.py --scan-all profiles/auto/ --categories sqli,ssti,cmdi,xss,xxe -v  # 4. batch scan
python3 proxy.py --profile <profile> --engine sqlmap                      # 5. deep engine scan (if needed)
```
**21 layers**: base64, base64url, url, hex, gzip, deflate, html_entity, unicode_escape, json, cbor, msgpack, xml, bson, yaml, toml, protobuf_raw, multipart, jwt_payload, jwt_header, rlp, abi.
**Formula**: N×M multiplier. Without proxy = 5% surface. With proxy = 95%.
