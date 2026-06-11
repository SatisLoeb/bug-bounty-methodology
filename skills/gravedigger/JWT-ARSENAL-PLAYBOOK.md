# JWT-ARSENAL-PLAYBOOK.md — Automated JWT Library Vulnerability Discovery

Activated when JWT/JWS/JWE authentication is detected during recon. Replaces manual JWT testing vectors (4, 4b, 16, 17, 18) with the automated 8-tool JWT Arsenal.

**Location:** `~/Desktop/BUGS/jwt-nullgate-research/jwt-arsenal/`
**Venv:** `~/Desktop/BUGS/jwt-nullgate-research/pocs/.venv/`

---

## Detection Triggers

Run JWT detection during Phase 2 (Surface Mapping). ANY of these signals activates the arsenal:

| Signal | Detection Method | Confidence |
|--------|-----------------|------------|
| JWT in auth response | `Authorization: Bearer eyJ...` in API response headers | HIGH |
| JWKS endpoint | `/.well-known/jwks.json` returns 200 | HIGH |
| OpenID config | `/.well-known/openid-configuration` contains `jwks_uri` | HIGH |
| JWT in cookies | `Set-Cookie: *=eyJ...` | HIGH |
| JWT library in deps | `package.json` has `jsonwebtoken`/`jose`, `requirements.txt` has `pyjwt`/`python-jose`/`authlib`, `pom.xml` has `nimbus-jose-jwt` | HIGH |
| JWT in JS bundles | `grep -oP 'eyJ[a-zA-Z0-9_-]*\.eyJ[a-zA-Z0-9_-]*\.[a-zA-Z0-9_-]*' bundles.js` | MEDIUM |
| Framework default | FastAPI (python-jose default), Spring Security (nimbus default), Express + passport-jwt | MEDIUM |
| Auth header format | `Authorization: Bearer` present but token not JWT-shaped | LOW — still probe |

### One-Command Detection + Execution

```bash
cd ~/Desktop/BUGS/jwt-nullgate-research/jwt-arsenal
source ../pocs/.venv/bin/activate

# Option A: From evidence directory (gravedigger workspace)
python detect_and_run.py --evidence "{protocol}-recon/evidence" --output "{protocol}-recon/evidence/jwt-arsenal"

# Option B: From target URL (black-box)
python detect_and_run.py --url "https://api.target.com" --output "{protocol}-recon/evidence/jwt-arsenal"

# Option C: From dependency file
python detect_and_run.py --deps /path/to/requirements.txt --output "{protocol}-recon/evidence/jwt-arsenal"

# Option D: Known library (skip detection)
python detect_and_run.py --lib python-jose --version 3.3.0 --source /path/to/lib --output "{protocol}-recon/evidence/jwt-arsenal"

# Detection-only mode (Phase 2 triage)
python detect_and_run.py --evidence "{protocol}-recon/evidence" --detect-only
```

The `detect_and_run.py` script:
1. Scans evidence/URL/deps for JWT signals (tokens, JWKS, library, framework)
2. Auto-identifies the library (python-jose, authlib, jsonwebtoken, etc.)
3. Selects tools: source available → all 8 tools, black-box → Tools 5,7,8
4. Runs the pipeline with 10 polyglot runners (5 languages)
5. Outputs report to workspace evidence directory

---

## Phase 2 Integration: JWT Library Identification

When JWT is detected, identify the specific library and version:

### From Source Code (if available)

```bash
# Python
grep -rP "import jwt|from jose|from authlib|from jwcrypto" --include="*.py" | head -5

# Node.js
grep -rP "require\(['\"]jsonwebtoken['\"\)]|from ['\"]jose['\"]" --include="*.js" --include="*.ts" | head -5

# Java
grep -rP "com\.nimbusds\.jose|org\.jose4j|com\.auth0\.jwt" --include="*.java" | head -5

# Go
grep -rP "go-jose|lestrrat-go/jwx" --include="*.go" | head -5

# Ruby
grep -rP "require.*jwt" --include="*.rb" | head -5
```

### From Runtime Signals

| Signal | Library |
|--------|---------|
| Error: `jose.exceptions.JWTError` | python-jose |
| Error: `jwt.exceptions.DecodeError` | PyJWT |
| Error: `authlib.jose.errors` | Authlib |
| Error: `JsonWebTokenError` | jsonwebtoken (Node) |
| Header: `X-Powered-By: Express` + JWT | likely jsonwebtoken |
| Header: `Server: uvicorn` + JWT | likely python-jose (FastAPI default) |
| `actuator/` endpoints + JWT | likely nimbus-jose-jwt (Spring) |
| Error contains `com.nimbusds` | nimbus-jose-jwt |

### From JWKS Endpoint

```bash
# Fetch JWKS and analyze key types
JWKS=$(curl -s "https://{api}/.well-known/jwks.json")
echo "$JWKS" | jq '.keys[] | {kty, alg, use, kid}'
# kty=RSA + alg=RS256 → standard setup
# kty=EC + alg=ES256 → ECDSA setup
# Multiple keys → key rotation in place
```

---

## Phase 4 Integration: Arsenal Execution

### Step 1: Tool 8 — Config-to-Vuln Mapper (5 min)

Maps identified library + version to known vulnerabilities. Run FIRST — gives you the hit list.

```bash
cd ~/Desktop/BUGS/jwt-nullgate-research/jwt-arsenal
source ../pocs/.venv/bin/activate

python3 -c "
from tool8_config_vuln_mapper.mapper import ConfigVulnMapper, ReconInput
mapper = ConfigVulnMapper()
result = mapper.map(ReconInput(
    lib='{library}',           # e.g., 'python-jose', 'authlib', 'jsonwebtoken'
    lib_version='{version}',   # e.g., '3.3.0'
    observed_alg='{alg}',      # e.g., 'RS256' (from JWKS or JWT header)
    key_source='{source}',     # 'jwks_endpoint', 'config', 'unknown'
))
import json
print(json.dumps(result, indent=2))
"
```

**Action on output:**
- `CONFIRMED_VULNERABLE` → proceed directly to Tool 5/7 for PoC
- `POTENTIALLY_VULNERABLE` → run full arsenal
- `NOT_AFFECTED` → still run Tool 7 for unknown divergences

### Step 2: Tool 7 — Cross-Library Differential (30 min, automated)

Tests 45+ adversarial tokens across all available runners. Every divergence is a finding lead.

```bash
python3 -m pipeline.runner \
  --lib "{library}" \
  --source "{source_path}" \
  --tools "7" \
  --verbose
```

**If no source code available** (black-box only):

```bash
python3 -c "
from tool7_cross_lib_diff.runners.python_runner import PythonRunner
from tool7_cross_lib_diff.runners.node_runner import NodeRunner
from tool7_cross_lib_diff.runners.go_runner import GoRunner
from tool7_cross_lib_diff.runners.ruby_runner import RubyRunner
from tool7_cross_lib_diff.runners.java_runner import JavaRunner
from tool7_cross_lib_diff.orchestrator import DiffOrchestrator
from tool7_cross_lib_diff.token_suite import Tool7TokenSuite

# Run against all available libs to see which accept adversarial tokens
runners = [
    PythonRunner('authlib'), PythonRunner('python-jose'), PythonRunner('pyjwt'),
    NodeRunner('jsonwebtoken'), NodeRunner('jose'),
    GoRunner('go-jose'), RubyRunner(), JavaRunner('nimbus-jose-jwt'),
]

suite = Tool7TokenSuite()
orch = DiffOrchestrator(runners, suite)
matrix = orch.run_matrix(verbose=True)
findings = orch.detect_findings()

# The target's library behavior can be compared against this matrix
# to identify which library it most closely matches
print(orch.to_json())
"
```

### Step 3: Tool 5 — Algorithm Fuzzer (30 min, automated)

Guided state machine transitions — focuses on algorithm confusion paths.

```bash
python3 -m pipeline.runner \
  --lib "{library}" \
  --tools "5" \
  --verbose
```

### Step 4: Static Analysis (if source available) — Tools 1, 2, 3, 4, 6 (45 min total, automated)

```bash
python3 -m pipeline.runner \
  --lib "{library}" \
  --source "{source_path}" \
  --tools "1,2,3,4,6" \
  --verbose
```

### Step 5: Full Pipeline (if you want everything at once)

```bash
python3 -m pipeline.runner \
  --lib "{library}" \
  --source "{source_path}" \
  --tools "1,2,3,4,5,6,7,8" \
  --verbose
```

---

## Finding Integration: Arsenal → Gravedigger Workspace

Arsenal findings feed directly into the gravedigger workspace structure.

### Mapping Arsenal Findings to Gravedigger Finding Files

| Arsenal Tool | Finding Type | Gravedigger Severity | Kill Gate Notes |
|-------------|-------------|---------------------|-----------------|
| Tool 7: accept when should reject | Behavioral divergence | HIGH-CRITICAL | Q2: reachable if target uses this lib |
| Tool 5: algorithm confusion success | Algorithm bypass PoC | CRITICAL | Q5: trigger = JWKS pubkey + DER convert |
| Tool 1: null-gate candidate | Type confusion path | HIGH | Q4: check if guards exist elsewhere |
| Tool 2: bypass path | Verification skip | HIGH-CRITICAL | Q2: trace full call path in target |
| Tool 3: RFC violation | Spec non-compliance | MEDIUM-HIGH | Q6: check if known issue for this lib |
| Tool 4: decoupled key/alg | Key confusion | HIGH | Q1: design intent check |
| Tool 6: unvalidated header | Injection surface | MEDIUM-HIGH | Q5: depends on app key lookup impl |
| Tool 8: known vuln match | Known CVE/finding | CRITICAL | Already confirmed — go to PoC |

### Auto-Generate Finding Files

After running the arsenal, convert findings to gravedigger workspace format:

```bash
# Save arsenal output to workspace
ARSENAL_REPORT="output/reports/pipeline_report.json"
WORKSPACE="{protocol}-recon"

# Copy report
cp "$ARSENAL_REPORT" "$WORKSPACE/evidence/jwt-arsenal-report.json"

# For each CRITICAL/HIGH finding, create a finding file
python3 -c "
import json, os

with open('$ARSENAL_REPORT') as f:
    report = json.load(f)

workspace = '$WORKSPACE'
os.makedirs(f'{workspace}/findings', exist_ok=True)

for i, finding in enumerate(report.get('findings', []), 1):
    sev = finding.get('severity', 'MEDIUM')
    if sev not in ('CRITICAL', 'HIGH'):
        continue

    slug = finding['title'][:40].replace(' ', '-').replace('/', '-')
    filename = f'{workspace}/findings/JWT-{sev[0]}{i:02d}-{slug}.md'

    with open(filename, 'w') as f:
        f.write(f'# {finding[\"title\"]}\\n\\n')
        f.write(f'**Severity:** {sev}\\n')
        f.write(f'**Tool:** {finding.get(\"tool\", \"jwt-arsenal\")}\\n')
        f.write(f'**Library:** {finding.get(\"library\", \"unknown\")}\\n')
        f.write(f'**Token ID:** {finding.get(\"token_id\", \"N/A\")}\\n\\n')
        f.write(f'## Detail\\n\\n{finding.get(\"detail\", \"\")}\\n\\n')
        f.write(f'## Kill Gate Status\\n\\nPENDING — run kill gate before deep dive\\n')

    print(f'Created: {filename}')
"
```

---

## Decision Tree: When to Run What

```
JWT detected in target?
├─ NO → Skip JWT Arsenal, continue standard gravedigger
└─ YES
   ├─ Library identified?
   │  ├─ YES → Tool 8 (config-to-vuln mapper) first
   │  │  ├─ Known vulns found → Tool 5 + 7 for PoC
   │  │  └─ No known vulns → Full pipeline (Tools 1-8) if source available
   │  └─ NO → Tool 7 (cross-lib diff) to fingerprint behavior
   │     └─ Compare divergence pattern to known libs → identify lib → retry
   │
   ├─ Source code available?
   │  ├─ YES → Full pipeline: Tools 1-8 (60 min automated)
   │  └─ NO → Black-box only: Tools 5, 7, 8 (30 min automated)
   │
   └─ Findings?
      ├─ CRITICAL/HIGH → Create finding files, run kill gate, deep dive
      ├─ MEDIUM → Note in SURFACE-MAP.md, chain with other findings
      └─ INFO/divergences → Record, may chain later
```

---

## Time Budget Integration

| Gravedigger Phase | Without Arsenal | With Arsenal |
|------------------|----------------|-------------|
| Phase 2: Surface Mapping | 90 min | 90 min + 5 min (detection) |
| Phase 4: Deep Analysis (JWT vectors) | 60 min manual per vector | **5 min automated** (replaces vectors 4, 4b, 16, 17, 18) |
| Phase 4: Arsenal full run | N/A | 30-60 min automated (runs in background) |
| **Net effect** | 5h manual JWT testing | **35 min automated + review** |

The arsenal replaces ~5h of manual JWT testing with ~35 min of automated analysis. The remaining time is reviewing findings and running kill gates.

---

## Example Integration Flow

```
/gravedigger some-defi-protocol

Phase 1: Recon → discover FastAPI backend (uvicorn header)
Phase 2: Surface mapping → JWT Bearer tokens in API responses
         → DETECT: "FastAPI + JWT" → likely python-jose
         → Auto-run: Tool 8 with lib="python-jose"
         → Output: JOSE-001 (CRITICAL), JOSE-002 (HIGH) applicable

Phase 3: Kill gate for JOSE-001
         → Q2: reachable? YES — FastAPI default JWT middleware uses python-jose
         → Q5: trigger? YES — JWKS endpoint public, DER conversion trivial
         → Q6: known? YES but unfixed (lib unmaintained)
         → VERDICT: PROCEED

Phase 4: Deep analysis
         → Auto-run: Tool 5 (TR-002 DER confusion) → CONFIRMED
         → Auto-run: Tool 7 (cross-lib diff) → python-jose accepts T04
         → Finding file created with PoC token
         → All 18 auth vectors tested (5 JWT vectors via arsenal, 13 standard)

Phase 5: Attack chains
         → JWT bypass + missing rate limiting = automated account takeover
         → Chain score: CRITICAL

Phase 6: Preflight → /disclose
```
