# PERSISTENCE-PATTERNS.md — "Every Dead End Has a Side Door"

Decision trees for overcoming obstacles. Follow mechanically. These encode the behavioral difference between finding 5 vulnerabilities and finding 34.

---

## P1: Error Messages Are Intelligence

**Trigger:** Endpoint returns 500, 502, 503, or unexpected error.

**WRONG:** "Endpoint is broken, skip it."

**RIGHT:**
```
Step 1: Save FULL error response (headers + body)
        → evidence/web/api-responses/error-{endpoint}-{timestamp}.json

Step 2: Extract intelligence:
        - Framework/language? (Python traceback, Java stack trace, Node.js error)
        - Internal paths? (/app/src/..., /var/www/...)
        - Database? (PostgreSQL, MongoDB, Prisma, SQLAlchemy)
        - Service names? (Redis timeout, RabbitMQ connection refused)
        - Field names? ("field 'user_id' is required" → schema leak)
        - Version info? (framework version in error page)

Step 3: Try different payloads to provoke different errors:
        - Empty body: curl -X POST {url} -H "Content-Type: application/json" -d '{}'
        - Null values: -d '{"key": null}'
        - Wrong types: -d '{"id": "string_not_int"}'
        - SQL injection: -d '{"id": "1 OR 1=1"}'
        - Oversized: -d '{"key": "AAAA...10000 chars"}'
        - Missing Content-Type header
        - XML Content-Type with JSON body

Step 4: Try same endpoint on mirror/staging domains (see P5)

Step 5: Document ALL extracted intelligence even if endpoint itself is unusable
```

**Example:** Upshift `/auth/verify` 500 revealed: Python/uvicorn, FastAPI, SIWE library, database field names.

---

## P2: Auth Block → 15 Vectors Before "Secured"

**Trigger:** Endpoint returns 401/403.

**WRONG:** "Requires auth, can't test further."

**RIGHT:**
```
Step 1: Test all 15 auth bypass vectors (DEEP-ANALYSIS-PLAYBOOK.md §4.1)
        Track: tested/untested/partial per vector

Step 2: Try legacy/staging domains
        staging.{domain}, v1.{domain}, private.{domain} may lack auth

Step 3: Try older API versions
        /api/v1/ → /api/v0/ → /v1/ → /beta/ → remove version prefix

Step 4: Check JS bundles for tokens/secrets
        grep -P "Bearer|token|auth|session" evidence/web/js-bundles/all-bundles.js

Step 5: Try WebSocket equivalent
        wss://{domain}/ws — often unprotected when REST is authed

Step 6: Try different HTTP methods
        POST authed → try GET, PUT, PATCH, DELETE, OPTIONS, HEAD

Step 7: Parameter-based bypass
        ?admin=true, ?debug=1, ?internal=1, ?auth=bypass

Step 8: Header-based bypass
        X-Forwarded-For: 127.0.0.1
        X-Real-IP: 127.0.0.1
        X-Original-URL: /admin
        X-Custom-IP-Authorization: 127.0.0.1

Step 9: Check per-endpoint vs global auth
        One valid token works across all endpoints?
        Some endpoints unprotected while others protected?

Step 10: CORS preflight info leak
         OPTIONS request may return allowed methods/headers

ONLY after ALL vectors + steps 2-10 → mark "auth confirmed secure"
```

---

## P3: "Just Info" → Cross-Reference Matrix

**Trigger:** Finding seems low-impact or informational.

**WRONG:** "Just informational, not worth reporting."

**RIGHT:**
```
Step 1: Add finding to inventory as Informational

Step 2: Cross-reference against EVERY other finding:
        For each existing finding F:
        - Does this info leak ENABLE exploitation of F?
        - Does this info leak AMPLIFY impact of F?
        - Combined with F, does this create a new attack chain?

Step 3: Check chain potential:
        - Internal paths → path traversal → file read → key extraction?
        - API keys → direct API access → bypass UI auth?
        - Admin address → targeted phishing → admin compromise?
        - Infrastructure details → targeted hosting attack → full compromise?
        - Enumeration + any write = targeted attack on specific users?

Step 4: Check if finding reveals NEW attack surface:
        - Internal endpoints in errors?
        - Database schema in validation messages?
        - Third-party services in bundle analysis?

Step 5: If no chain now → keep in inventory, RE-CHECK after every new finding
```

**Example:** Upshift JS bundle: WalletConnect projectId + contract addresses = informational individually. Combined with missing auth on write endpoints = full attack chain.

---

## P4: Theoretical → Proven (Evidence Promotion Ladder)

**Trigger:** Finding valid but evidence weak.

**WRONG:** "Can't prove this, mark as theoretical."

**RIGHT:**
```
Level 1 → Level 2 (Theoretical → Logical):
  - Trace complete code path: entry → vulnerable operation
  - Show ALL guards and why they don't prevent exploitation
  - Document exact call sequence
  - Find similar bugs in same codebase/framework

Level 2 → Level 3 (Logical → API/State Verified):
  Web/API:
    - Make the actual API call, capture response
    - Show endpoint accepts the malicious input
    - Save full request/response to evidence/
  Smart contracts:
    - evm_call / evm_read_storage to verify current state
    - Document block number for all reads
    - evm_get_logs to find historical events confirming code path

Level 3 → Level 4 (Verified → Mainnet-Proven):
  Smart contracts:
    - Foundry fork test at specific block
    - Full attack sequence with before/after balances
    - Document: block number, TX hashes, gas costs, profit
  Web/API:
    - POST unique value → GET confirms persistence
    - Demonstrate without auth if bypass is part of chain
    - Full HTTP request/response chain captured
  Infrastructure:
    - Real signing key usage in historical transactions
    - Map actual admin operations to single key
    - Document: TX hashes, from addresses, timestamps

Promotion attempt: 30 min max per level jump.
If not gatherable: document why and what would be needed.
Re-attempt after new findings unlock new evidence paths.
```

---

## P5: First Test Fails → Variant Testing

**Trigger:** Expected vulnerability not present at primary endpoint.

**WRONG:** "Not vulnerable, move on."

**RIGHT:**
```
Step 1: Mirror/staging/legacy domains
        private.{domain}, staging.{domain}, dev.{domain}
        {domain-old}.com, {name}.io vs {name}.finance
        beta.{domain}, test.{domain}

Step 2: Different chains (multi-chain protocols)
        Ethereum, Arbitrum, Optimism, Base, Polygon, BSC, Avalanche, HyperEVM
        Same contract on different chain may have different version/config

Step 3: Different API versions
        /v1/, /v2/, /api/v1/, /api/v2/

Step 4: URL encoding variants
        %2f for /, %2e for ., %00 null byte
        Double encoding: %252f

Step 5: Case variations
        /Admin, /ADMIN, /admin, /aDmIn

Step 6: Trailing slash
        /endpoint vs /endpoint/

Step 7: Content-Type variations
        application/json, application/x-www-form-urlencoded, multipart/form-data, text/xml

Step 8: Different IP/geolocation
        Geo-restricted endpoints? Different exit nodes.

Step 9: Document all variants attempted
        Even failed attempts prove thoroughness

Decision: ALL variants → no hit → mark tested-negative, move on
Max time: 30 min per endpoint
```

---

## P6: On-Chain Call Fails → Alternative Approaches

**Trigger:** MCP onchain tool returns error.

**WRONG:** "Can't read state, skip."

**RIGHT:**
```
Step 1: Check address correctness
        - Right chain? Right address? Copy-paste error?
        - Is it a proxy? → evm_resolve_proxy first

Step 2: Check RPC
        - Try different chain name
        - evm_get_bytecode to verify contract exists

Step 3: Raw storage reads
        - If evm_call fails, try evm_read_storage
        - Sequential slots: 0, 1, 2...
        - Mappings: keccak256(abi.encode(key, slot))

Step 4: Different function signatures
        - Wrong ABI? Try uint256/uint128, address/bytes20
        - cast calldata for correct encoding
        - Check Etherscan for verified ABI

Step 5: Historical block
        - Current state may differ from exploit conditions
        - Try block from known interesting transaction

Step 6: Different tools
        - forge_inspect for storage layout
        - cast_call with explicit signature
        - cast_decode to verify encoding

Step 7: Block explorer fallback
        - Etherscan read contract tab
        - Blockscout
        - Tenderly simulation
```

---

## P7: Dead End Decision Tree

```
                       Hit obstacle
                            │
                  ┌─────────┴─────────┐
                  │                     │
            Can I try an           Is this the
            alternative?          last surface?
            (P1-P6 above)              │
                  │               ┌────┴────┐
             ┌────┴────┐         │         │
             YES       NO        YES       NO
             │         │         │         │
        Try it     Document    Compile   Move to
        (30 min    as blocked  findings  next surface
         max)      + revisit   + chain
             │     later       them
             │         │         │
        Did it     ─────────────┘
        work?            │
        │           After ALL surfaces:
   ┌────┴────┐     chain existing findings
   YES       NO    (Phase 5)
   │         │         │
Document   Back to  If chains found →
+ continue "Can I    individual "info"
           try an    becomes combined
           alternative?" "critical"
```

**Hard limits:**
- 30 min max per endpoint before trying alternatives
- 5 consecutive dead ends on same surface → shift to different surface
- All surfaces exhausted → compile what you have, chain findings, next protocol
- NEVER spend >3h on a single finding that won't promote past "theoretical"
- **Exception:** >$10M TVL and specific identifiable evidence gap → extend to 5h

---

## Meta-Pattern: The Accumulation Effect

Individual informationals seem worthless. But:

```
Info leak (paths) + Info leak (API keys) + Info leak (admin addrs) = Attack surface map
Surface map + Missing auth on one endpoint = Targeted exploitation
Targeted exploit + Single signing key = Catastrophic compromise
```

**Rule:** Never delete informational findings. Always cross-reference. The 34th finding may chain 5 informationals into a critical.

---

## P8: WAF/CDN Returns 403 → Log In Like a User

**Trigger:** API behind WAF (Cloudflare, AWS WAF, Akamai) returns 403 on all unauthenticated requests.

**WRONG:** "Behind WAF, can't test. Mark as blocked."

**RIGHT:**
```
Step 1: A WAF 403 means "requires auth", NOT "blocked"
        The ENTIRE authenticated API surface is untested

Step 2: Create test account via normal app signup flow
        - Open app in browser
        - Register with test email
        - Complete any verification required

Step 3: Capture Bearer token
        - DevTools → Network → API request → Authorization header
        - Or: Application → Cookies → session token
        - Or: Application → Local Storage → auth token

Step 4: Verify token works on API
        curl -s "${API}/users" -H "Authorization: Bearer $TOKEN"
        200 = full API access unlocked

Step 5: Run EVERY route from JS bundle extraction with the token
        This is where HIGH/CRITICAL findings hide behind the WAF

Step 6: Build authorization consistency matrix (W8/§4.12)
        Map what requires sudo vs standard token
        ANY inconsistency = finding

LESSON: Request Finance API (api.request.finance) — Cloudflare WAF
returned 403 on every unauthenticated request. Investigation concluded
"API inaccessible." Meanwhile, a standard login token unlocked the
entire API surface, revealing MFA deletion without re-auth (CVSS 7.6).
The finding was in the extracted routes THE ENTIRE TIME.
```

---

## Anti-Patterns

| Anti-Pattern | Why It Fails | Do Instead |
|-------------|-------------|-----------|
| Skip endpoint after first 401 | Misses 14 bypass vectors | Full P2 procedure |
| Summarize API responses | Loses chain detail | Save verbatim always |
| Dismiss info leaks | Misses chain potential | P3 cross-reference |
| Give up after 1 failed PoC | Variants on mirrors/chains | P5 variant testing |
| Spend 8h on one finding | Diminishing returns | P7 hard limits |
| Delete "boring" findings | May chain later | Keep everything |
| Test only happy path | Errors ARE intelligence | P1 error exploitation |
| Trust "not found" | May exist on different domain | P5 domain variants |
| Give up at WAF 403 | Entire authed surface untested | P8 login + test with token |
| Only test unauthed | Misses auth consistency bugs | W8 authorization matrix |
