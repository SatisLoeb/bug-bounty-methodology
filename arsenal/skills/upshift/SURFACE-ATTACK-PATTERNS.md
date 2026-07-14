# Surface Attack Patterns -- The 10 Vectors

Ten attack vectors that, applied to an Upshift-class target, produce the bulk of the findings. Each vector is independently executable in parallel; together they form Pass 1 of the `HUNT-METHODOLOGY.md` discipline. Each vector has the same five-part structure:

1. **What it is** -- the attack class
2. **Detection kit** -- copy-paste-runnable bash/curl/eth_call commands
3. **On-chain readback if applicable** -- the public-RPC verification step
4. **Upshift example finding ID** -- the concrete instance, traceable in `UPSHIFT-REFERENCE.md` and the source `~/Desktop/BUGS/upshift-recon/evidence/web/findings/UPSHIFT-W*.md`
5. **Generalization to other targets** -- what to look for beyond the Upshift specifics

Variables used across kits:

```bash
export TARGET="<protocol>"             # e.g. upshift
export APP="app.${TARGET}.com"         # frontend host
export API="api.${TARGET}.com"         # main API host
export OTHER_APIS=()                   # additional backends found in JS bundle
export EVM_RPC="https://ethereum-rpc.publicnode.com"  # public read-only Ethereum RPC
export TARGET_CHAIN_RPC="..."          # protocol-specific chain RPC if not Ethereum
export EVIDENCE="${HOME}/Desktop/BUGS/${TARGET}-recon/evidence"
mkdir -p "${EVIDENCE}/web/{js-bundles,endpoint-probes,infrastructure,attack-chains,findings}"
mkdir -p "${EVIDENCE}/onchain"
```

---

## V1 -- Bundle harvest

**What it is.** The frontend JavaScript bundle is shipped to every browser without a WAF. It contains every constant the frontend needs to operate, including (because of careless `process.env` usage and Next.js `NEXT_PUBLIC_*` / Vite `VITE_APP_*` semantics) executor passwords, RPC API keys, Slack webhooks, JWT secrets, internal endpoint URLs, hardcoded admin/operator addresses, and source maps if the build was misconfigured.

This vector is the highest-ROI on Upshift-class targets because it's pure passive recon (no auth required, no rate limit, no logging on the sponsor side) and the bug class is highly recurrent (frontend devs treat `NEXT_PUBLIC_*` as "internal" without realizing it ships to the browser).

**Detection kit.**

```bash
# 1. Get the current bundle hash from the app HTML
BUNDLE_PATHS=$(curl -s "https://${APP}/" | grep -oE '/assets/[A-Za-z0-9_/.-]+\.js' | sort -u)
echo "Bundles found:"
echo "${BUNDLE_PATHS}"

# 2. Download every bundle to evidence/
for p in ${BUNDLE_PATHS}; do
  fname=$(basename "${p}")
  curl -s "https://${APP}${p}" > "${EVIDENCE}/web/js-bundles/${fname}"
  echo "$(wc -c < "${EVIDENCE}/web/js-bundles/${fname}") bytes -- ${fname}"
done

# 3. Grep for known leak patterns across all bundles
cd "${EVIDENCE}/web/js-bundles"

# Hardcoded passwords / secrets / keys (the W34 class)
grep -oE '(VITE_APP|NEXT_PUBLIC|REACT_APP)_[A-Z_]+:"[^"]+"' *.js | sort -u | head -50
grep -oE 'MASTER_PASSWORD[^,;]+' *.js | head
grep -oE 'API_KEY[^,;]+' *.js | head
grep -oE 'JWT_SECRET[^,;]+' *.js | head
grep -oE 'WEBHOOK[^,;]+' *.js | head

# Hardcoded 64-hex hashes (passwords, secrets, keys)
grep -oE '"[a-f0-9]{64}"' *.js | sort -u | head -20

# Hardcoded addresses (admin/operator/executor/keeper candidates)
grep -oE '0x[a-fA-F0-9]{40}' *.js | sort -u | head -50

# RPC endpoints with embedded keys (the NEW-02 class)
grep -oE 'https://[a-zA-Z0-9.-]+\.(helius-rpc|alchemy|infura|quicknode|rpc\.publicnode|ankr|chainstack|blastapi|drpc|llamarpc)\.[a-z]+/[A-Za-z0-9_-]+' *.js | sort -u

# Internal backend URLs (the W7 class)
grep -oE 'https://[a-zA-Z0-9.-]+\.(internal|staging|dev|qa|backend|admin)\.[a-zA-Z0-9.-]+' *.js | sort -u
grep -oE 'WEBSERVER_URL[^,;]+' *.js | head
grep -oE 'BACKEND_URL[^,;]+' *.js | head

# Source maps (game over if present)
for p in ${BUNDLE_PATHS}; do
  curl -sI "https://${APP}${p}.map" | head -1
done
```

**Re-verification.** Re-pull the bundle by current hash. Compare grep output against pre-disclosure baseline. If a leaked secret no longer matches, it was rotated. If the constant name itself is gone, the surface was refactored. If the bundle hash changed but the secret persists byte-identical, the team rebuilt without rotating (the W34 mistake).

**Upshift example.** W34 (master password `0adfa598...` in `index-Bu3SA1OT.js`), NEW-02 (Helius Solana RPC API key), W27 (multiple API keys across providers), W26 (Slack webhook URL).

**Generalization.** Every Next.js / Vite / CRA frontend in this target class has at least 2-3 leaked constants. The high-value targets:
- Executor / operator / admin passwords (allow JWT minting → on-chain action authorization)
- RPC keys (allow rate-limit-free queries against the protocol's RPC; also, some RPC providers' free tiers expose admin namespaces)
- Webhook URLs (allow attacker to inject messages into the team's Slack/PagerDuty)
- Internal backend URLs (open recon for V5 staging recon)

---

## V2 -- Unauth API endpoint sweep

**What it is.** The protocol's API runs on FastAPI / Express / NestJS / similar. Auth is implemented as middleware. The middleware is correctly wired on GET routes (because devs test those manually) but inconsistently wired on POST/PUT/DELETE routes (because devs trust the body validator to catch mistakes). The body validator runs even without auth because of framework behavior. Result: POST endpoints that mutate state can be hit without auth, and the validator merely tells the attacker what fields to provide.

This is the F1 class on Upshift -- the headline finding. It's recurrent because frameworks (FastAPI especially) make this easy to write and hard to detect.

**Detection kit.**

```bash
# 1. Try OpenAPI spec exposure first (fastest, gives full route inventory)
for path in /openapi.json /swagger.json /api/openapi.json /v1/openapi.json /v2/openapi.json /docs /api-docs /swagger-ui /redoc; do
  code=$(curl -s -o /dev/null -w "%{http_code}" "https://${API}${path}")
  [ "${code}" != "404" ] && echo "[OPENAPI] ${code} https://${API}${path}"
done

# If found, save it
curl -s "https://${API}/openapi.json" > "${EVIDENCE}/web/infrastructure/openapi.json" 2>/dev/null
endpoint_count=$(jq '.paths | keys | length' "${EVIDENCE}/web/infrastructure/openapi.json" 2>/dev/null)
echo "OpenAPI endpoints catalogued: ${endpoint_count}"

# 2. If OpenAPI exposed: extract POST/PUT/DELETE/PATCH routes (the high-value targets)
if [ -s "${EVIDENCE}/web/infrastructure/openapi.json" ]; then
  jq -r '.paths | to_entries[] | .key as $p | .value | to_entries[] | select(.key | IN("post","put","delete","patch")) | "\(.key | ascii_upcase) \($p)"' \
    "${EVIDENCE}/web/infrastructure/openapi.json" > "${EVIDENCE}/web/endpoint-probes/mutating-routes.txt"
  wc -l "${EVIDENCE}/web/endpoint-probes/mutating-routes.txt"
fi

# 3. If no OpenAPI: extract routes from JS bundles
grep -oE '"/[a-zA-Z0-9_/{}-]+"' "${EVIDENCE}/web/js-bundles/"*.js | sort -u | grep -E '^"/' > "${EVIDENCE}/web/endpoint-probes/routes-from-bundles.txt"

# 4. Sweep each route with GET + POST{} unauthenticated
# Save (status, path) tuples for the asymmetry analysis
> "${EVIDENCE}/web/endpoint-probes/get-noauth.txt"
> "${EVIDENCE}/web/endpoint-probes/post-noauth.txt"
while read method path; do
  code_get=$(curl -s -o /dev/null -w "%{http_code}" "https://${API}${path}" --max-time 8)
  code_post=$(curl -s -o /dev/null -w "%{http_code}" -X POST "https://${API}${path}" \
    -H "Content-Type: application/json" -d '{}' --max-time 8)
  echo "${code_get} ${path}" >> "${EVIDENCE}/web/endpoint-probes/get-noauth.txt"
  echo "${code_post} ${path}" >> "${EVIDENCE}/web/endpoint-probes/post-noauth.txt"
done < "${EVIDENCE}/web/endpoint-probes/mutating-routes.txt"

# 5. Asymmetry analysis: find routes where GET is auth-gated but POST is not
join -j 2 \
  <(sort -k 2 "${EVIDENCE}/web/endpoint-probes/get-noauth.txt") \
  <(sort -k 2 "${EVIDENCE}/web/endpoint-probes/post-noauth.txt") \
  | awk '$2 ~ /^4[01]/ && $3 ~ /^(2|4[02])/ { print "ASYMMETRY:", $1, "GET="$2, "POST="$3 }'
# Code 422 on POST = body validator runs, auth middleware does NOT
# Code 401 on GET = auth middleware works
# This pair is the F1 class
```

**Re-verification.** Re-run the sweep. A patched endpoint should return 404 (removed) or 401 (auth added) on POST. If it still returns 422 with body schema errors, the patch is incomplete. If GET also went 404, the entire endpoint was refactored (the F1 fix shape).

**Upshift example.** F1 (`POST /integrations/methods` returns 422 unauth, GET returns 401 -- the asymmetry that triggers operator wallet to sign on-chain), W4 (`POST /integrations/otc` -- same class), W17 (`POST` writes to OTC database without auth), W19 (pending redemptions endpoint), W29 (AWS Lambda fake deposit).

**Generalization.** Test every POST/PUT/DELETE/PATCH route in the OpenAPI spec or extracted from the bundle. The asymmetry pattern (401 on GET, 422 on POST) is the structural signal. Pay extra attention to routes that:
- Reference on-chain actions in their path (`/integrations/`, `/methods`, `/whitelist`, `/transfer`, `/swap`, `/execute`, `/tx_batcher`, `/integrations/otc`)
- Reference admin/curator/operator/keeper roles (`/admin/*`, `/curator/*`, `/keeper/*`)
- Look like they belong in an internal CMS (`/scheduled_proxy_admin/*`, `/integrations/methods/extract-methods`)

---

## V3 -- Operator wallet audit

**What it is.** DeFi protocols with backend orchestration have one or more EOA "operator" wallets that sign all the protocol's on-chain transactions. The wallet's private key lives in a Fireblocks / Safe{Wallet} / custom HSM / vanilla `ethers.Wallet.fromMnemonic` setup on the backend. Single-key compromise = full protocol compromise. Multi-sig migration is on the roadmap but not implemented in v1. Same key signs across all chains (cross-chain replication amplifier).

This vector establishes the upper bound on damage for the V4 trigger class. If V4 lets you make the wallet sign arbitrary calldata, V3 tells you what that calldata can do.

**Detection kit.**

```bash
# 1. Find operator/keeper/executor addresses by reading contract state
# Common selectors (compute the rest as needed):
#   operator()            -> 0x570ca735
#   keeper()              -> 0x6e9960c3
#   admin()               -> 0xf851a440
#   pendingOwner()        -> 0xe30c3978
#   getRoleMember(role,0) -> 0x9010d07c

# Vault contract address (from V2 sweep or OpenAPI)
VAULT="<vault_address>"

# Read operator + keeper
SEL_OP=$(python3 -c "from eth_utils import keccak; print(keccak(b'operator()')[:4].hex())")
SEL_KP=$(python3 -c "from eth_utils import keccak; print(keccak(b'keeper()')[:4].hex())")

curl -s -X POST "${EVM_RPC}" \
  -H "Content-Type: application/json" \
  -d "{\"jsonrpc\":\"2.0\",\"method\":\"eth_call\",\"params\":[{\"to\":\"${VAULT}\",\"data\":\"0x${SEL_OP}\"},\"latest\"],\"id\":1}"

# 2. Classify EOA vs contract
ADDR="<address from above>"
CODE=$(curl -s -X POST "${EVM_RPC}" -H "Content-Type: application/json" \
  -d "{\"jsonrpc\":\"2.0\",\"method\":\"eth_getCode\",\"params\":[\"${ADDR}\",\"latest\"],\"id\":1}" \
  | jq -r '.result')
[ "${CODE}" = "0x" ] && echo "${ADDR}: EOA (single-key risk)" || echo "${ADDR}: contract (likely Safe -- check threshold)"

# 3. If Safe, read threshold + owners
SEL_THR=$(python3 -c "from eth_utils import keccak; print(keccak(b'getThreshold()')[:4].hex())")
SEL_OWN=$(python3 -c "from eth_utils import keccak; print(keccak(b'getOwners()')[:4].hex())")
curl -s -X POST "${EVM_RPC}" -H "Content-Type: application/json" \
  -d "{\"jsonrpc\":\"2.0\",\"method\":\"eth_call\",\"params\":[{\"to\":\"${ADDR}\",\"data\":\"0x${SEL_THR}\"},\"latest\"],\"id\":1}"

# 4. Cross-chain replication check (the 2,212-roles-across-14-chains class)
# For each known chain the protocol deploys to, repeat steps 1-2
# Same address signing across all chains = cross-chain compromise amplifier

# 5. ERC20 approval scan -- does the operator have unlimited approvals on stables?
# Use Etherscan-like API for batched approval enumeration if available, or scan the latest 1000 logs
# topics: keccak256(Approval(address,address,uint256)) = 0x8c5be1e5...
# operator EOA in topics[1], unlimited (0xffff...) in data
```

**Re-verification.** Re-read `operator()` after disclosure. If the address changed from EOA to a Safe contract, the team migrated. If the threshold went from 1-of-1 to 3-of-5, the team migrated. If unchanged, the operator wallet remains the single-key risk.

**Upshift example.** NEW-04 (operator wallet `0xE0b7DEab801D864650DEc58CbD1b3c441D058C79` audit -- single key signs across 14 chains for 2,212 roles), F3 operator EOA on coreUSDC vault. W23 (single-key architecture), W39 (sentETH 1-of-1 Safe).

**Generalization.** Every protocol in this class has an operator EOA. The question is what damage radius the EOA controls. Mapping:
- Direct token transfers (operator can move funds) → Critical
- Whitelist/role mutations (operator can grant permissions) → Critical (chains with V4)
- Hedge / rebalance actions (operator can move funds between vaults) → High (operator-trusted)
- Read-only actions (operator queries oracle, posts price) → Medium

`~/Desktop/BUGS/INFRA-ADJACENT-TO-SC-PLAYBOOK.md` Section G covers the keeper-bot specifics; reference for additional patterns.

---

## V4 -- Off-chain → on-chain trigger trace

**What it is.** The defining vector of the Upshift class. The backend exposes one or more API endpoints that, when called, cause the operator wallet (V3) to sign and broadcast an on-chain transaction. The trigger may be:
- Direct ("call this endpoint, get a tx mined")
- Indirect ("call this endpoint, the row is queued, the keeper bot reads the queue and broadcasts")
- Conditional ("call this endpoint, if {price/balance/timestamp} matches, the tx is broadcast")

If the trigger lacks auth (V2), or if the trigger's auth can be obtained from a leaked secret (V1), or if the trigger's required action target can be set by attacker input (mass assignment / IDOR), the off-chain → on-chain chain is complete. This is F1.

**Detection kit.**

```bash
# 1. Find candidate trigger endpoints from V2's mutating-routes.txt
# High-value naming patterns:
grep -iE 'transfer|whitelist|tx_batcher|execute|submit|hedge|rebalance|bridge|swap|sign|broadcast|integration|method' \
  "${EVIDENCE}/web/endpoint-probes/mutating-routes.txt"

# 2. For each candidate, capture the response shape unauthenticated
# The signal: response references a tx hash, a Multicall result, a Fireblocks job, or a "transaction" field
for endpoint in $(grep -iE 'transfer|whitelist|tx_batcher|execute' "${EVIDENCE}/web/endpoint-probes/mutating-routes.txt" | awk '{print $2}'); do
  echo "=== POST ${endpoint} ==="
  resp=$(curl -s -X POST "https://${API}${endpoint}" \
    -H "Content-Type: application/json" -d '{}' --max-time 10)
  echo "${resp}" | head -c 500
  # Look for: tx_hash, txHash, transaction, multicall, Fireblocks, Multicall3:, "broadcast"
  echo "${resp}" | grep -oE '(tx_hash|txHash|transaction|multicall|Fireblocks|Multicall3|broadcast|signed|gas)' | sort -u
  echo
done

# 3. If a candidate returns 422 with body schema, fill the schema and POST again
# Even if the body validator rejects the POST, the FACT that the validator runs
# while the auth middleware doesn't IS the asymmetry. Document it.

# 4. On-chain monitor: watch the operator wallet's tx history while POSTing
# Use a free indexer like Etherscan/Hyperscan/Arbiscan
# If a tx mined within 30 seconds of your POST and the calldata matches your input, you've proven F1
```

**Re-verification.** Re-POST after disclosure. If 404, endpoint was removed (the strong patch). If 401, auth middleware was added (the medium patch -- still verify the middleware is correctly wired by sending a forged Bearer token). If 422 still, the patch is incomplete (auth still missing, only validator changed).

**Upshift example.** F1 -- the entire class. `POST /integrations/methods` triggers operator wallet `0xE0b7De...` to sign a multicall against masterRegistry that whitelists ERC20.transfer for arbitrary subaccount addresses. Proof tx `0x5458171c...` on HyperEVM block 28,676,655.

**Generalization.** This is the highest-impact vector. Any endpoint that triggers an on-chain action without authentication is a Critical regardless of what action it triggers, because the attacker can compose it with V1 and V3 to construct the full chain. Look specifically for:
- Whitelist / permission / role mutation endpoints
- Anything that calls a multicall, batch, or executor pattern
- Endpoints with `Fireblocks`, `Safe`, `multisig`, `executor` in their description (per OpenAPI)
- Endpoints that mutate cross-chain state (cross-chain message bridges)

The `~/Desktop/BUGS/INFRA-ADJACENT-TO-SC-PLAYBOOK.md` covers relayer / gasless meta-tx patterns -- adjacent to V4 but distinct (in the relayer case, the user signs the meta-tx; in V4 the protocol's own wallet signs without user involvement).

---

## V5 -- Staging/dev backend recon

**What it is.** Production has a WAF, a CDN, rate limiting, and a security review process. Staging does not. Many protocols configure staging to read from a production read-replica (so QA tests look realistic). Staging hostnames follow predictable patterns: `staging.*`, `backend-staging.*`, `dev.*`, `qa.*`, `*-staging.*`. Subdomain enumeration finds them; lack of auth on the staging API exposes the production read-replica's data.

**Detection kit.**

```bash
# 1. Subdomain enumeration via subfinder + crt.sh
subfinder -d "${TARGET}.com" -silent | tee "${EVIDENCE}/web/infrastructure/subs-${TARGET}.txt"
curl -s "https://crt.sh/?q=%25.${TARGET}.com&output=json" | jq -r '.[].name_value' >> "${EVIDENCE}/web/infrastructure/subs-${TARGET}.txt"

# Repeat for any sister domains found in V1 bundle harvest
# (Upshift had upshift.finance, augustdigital.io, fractalprotocol.org as 3 brands of one protocol)

# 2. Filter for staging-class names
sort -u "${EVIDENCE}/web/infrastructure/subs-${TARGET}.txt" \
  | grep -iE 'staging|dev|qa|test|preprod|preview|backend-|api-staging|api-dev' \
  > "${EVIDENCE}/web/infrastructure/staging-candidates.txt"

# 3. For each staging candidate, probe basic auth gating
while read host; do
  code=$(curl -s -o /dev/null -w "%{http_code}" "https://${host}/" --max-time 8)
  echo "${code} https://${host}/"
done < "${EVIDENCE}/web/infrastructure/staging-candidates.txt"

# 4. For staging hosts that responded 200, run V2 sweep against them
# The expectation: same OpenAPI spec as prod, no auth on most endpoints
# Even GETs that are auth-gated on prod often work without auth on staging

# 5. Check for production data exposure
# Test: GET /users/{operator_address}/nonce on staging vs prod
# If both return the same nonce → staging is reading production data
curl -s "https://staging.${TARGET}.com/users/${OPERATOR_ADDR}/nonce"
curl -s "https://${API}/users/${OPERATOR_ADDR}/nonce"
# IDENTICAL = production read-replica
```

**Re-verification.** Re-test staging hosts. 503 = service offline (could be temporary or permanent shutdown). 404 = removed. 401 = auth added. If still 200 and identical to prod, the team did not patch.

**Upshift example.** W32 (`backend.staging.fractalprotocol.org` exposes production database as read replica), W28 (dev/QA backends -- some live, some not).

**Generalization.** Most teams have a staging environment. The question is what data and what permissions it exposes. Highest-value findings:
- Staging that reads from prod database (W32 class) -- exposes user data, balances, internal IDs
- Staging that signs from a different (test) wallet but with same role permissions on prod contracts -- attacker can trigger prod actions via staging
- Staging admin panels with default credentials -- complete protocol takeover

---

## V6 -- Lambda / serverless surface

**What it is.** Most protocols now use AWS Lambda / Cloudflare Workers / Vercel Functions for non-critical paths (analytics, deposits logging, email notifications, OAuth callbacks). These functions are deployed outside the main API perimeter and often outside the audit perimeter. They lack auth + body validation + rate limiting.

**Detection kit.**

```bash
# 1. JS bundle grep for serverless endpoint URLs
grep -oE 'https://[a-zA-Z0-9.-]+\.execute-api\.[a-z0-9-]+\.amazonaws\.com/[A-Za-z0-9_/-]+' \
  "${EVIDENCE}/web/js-bundles/"*.js | sort -u
grep -oE 'https://[a-zA-Z0-9.-]+\.cloudfunctions\.net/[A-Za-z0-9_/-]+' \
  "${EVIDENCE}/web/js-bundles/"*.js | sort -u
grep -oE 'https://[a-zA-Z0-9.-]+\.workers\.dev/[A-Za-z0-9_/-]+' \
  "${EVIDENCE}/web/js-bundles/"*.js | sort -u
grep -oE 'https://[a-zA-Z0-9.-]+\.vercel\.app/api/[A-Za-z0-9_/-]+' \
  "${EVIDENCE}/web/js-bundles/"*.js | sort -u

# 2. For each found Lambda / function URL, probe with empty body
# (Do NOT POST a payload that could write -- empty body is enough for asymmetry detection)
for url in $(cat lambda-urls.txt); do
  code=$(curl -s -o /dev/null -w "%{http_code}" -X POST "${url}" \
    -H "Content-Type: application/json" -d '{}' --max-time 10)
  echo "${code} POST ${url}"
done

# Codes interpretation:
# 200 → no validation, accepts arbitrary input → likely writes to DB unauthenticated
# 422 → validator runs, auth doesn't → V2 asymmetry class
# 500 → validator likely added (post-disclosure shape -- see Upshift W29 patch)
# 401/403 → auth gated → safe
# 404 → removed
```

**Re-verification.** Re-POST. Status 500 with empty body suggests body validator was added. Note that you CANNOT confirm whether a properly-formed payload still writes without sending one, which would risk polluting their DB. State the limitation in the disclosure follow-up.

**Upshift example.** W29 -- AWS Lambda at `lakejdgkzc.execute-api.eu-west-1.amazonaws.com/logUpshiftDeposit` accepted arbitrary deposit records writing to production DB without auth.

**Generalization.** Lambda / serverless surfaces are universally under-audited. Look for:
- Deposit / withdrawal logging endpoints (write to user-facing DB)
- OAuth callback handlers (often don't validate state parameter)
- Webhook receivers (often trust the Authorization header from "internal" services that anyone can spoof)
- Email/notification triggers (can be used to spam users with phishing)

---

## V7 -- SIWE / auth state machine

**What it is.** Sign-In With Ethereum (EIP-4361 / SIWE) requires the server to validate eight specific fields of the signed message: domain, address, statement, URI, version, chain ID, nonce, issued-at. Many implementations validate only the ecrecover signature and ignore the eight fields. Combined with a non-rotating nonce (database-persisted, never updated post-use), the server accepts SIWE messages signed for any other domain on any other dApp at any past time, indefinitely.

This is one of the most common high-severity DeFi auth bugs in 2026.

**Detection kit.**

```bash
# 1. Find SIWE endpoints
# Common paths: /auth/sign, /siwe/verify, /auth/login, /auth/nonce
for p in /auth/sign /auth/siwe /siwe/verify /auth/login /auth/nonce; do
  code=$(curl -s -o /dev/null -w "%{http_code}" "https://${API}${p}" --max-time 8)
  [ "${code}" != "404" ] && echo "${code} https://${API}${p}"
done

# 2. Nonce stability test (the signature primitive of W16)
# Pick a known address from V3 (e.g., the operator EOA)
ADDR="0xE0b7DEab801D864650DEc58CbD1b3c441D058C79"
NONCE_PATH="/users/${ADDR}/nonce"  # adapt per protocol's API shape

NONCE_1=$(curl -s "https://${API}${NONCE_PATH}" --max-time 8 | jq -r '.nonce')
sleep 1
NONCE_2=$(curl -s "https://${API}${NONCE_PATH}" --max-time 8 | jq -r '.nonce')
sleep 1
NONCE_3=$(curl -s "https://${API}${NONCE_PATH}" --max-time 8 | jq -r '.nonce')

if [ "${NONCE_1}" = "${NONCE_2}" ] && [ "${NONCE_2}" = "${NONCE_3}" ]; then
  echo "STATIC NONCE confirmed: ${NONCE_1}"
  echo "  → SIWE replay vector live (assuming server validates only ecrecover)"
else
  echo "Nonce rotates: ${NONCE_1} → ${NONCE_2} → ${NONCE_3}"
fi

# 3. Test if SIWE accepts messages with wrong domain / wrong chain / past timestamp
# (Construct test SIWE messages -- requires keypair, do not test against prod with attacker payload)
# Document the 8/8 EIP-4361 field check matrix:
#   - domain: did the server check domain == its own?
#   - address: did the server check address == ecrecover output?
#   - statement: present and unmodified?
#   - URI: matches server URI?
#   - version: == "1"?
#   - chain-id: == server's chain?
#   - nonce: matches the one issued?
#   - issued-at: within freshness window?
# In Upshift's case: only ecrecover was validated. Document each missing field separately.
```

**Re-verification.** Re-run nonce stability test. If two consecutive identical = still static. If different = rotation added. Test the field validation matrix only if you have permission and a test account.

**Upshift example.** W16 -- 1 of 8 EIP-4361 fields validated server-side. Static nonce confirmed (still live as of 2026-04-25 ~01:50 UTC). SIWE signature replay vector active.

**Generalization.** Test every SIWE-implementing DeFi protocol. The success rate is shockingly high. Even teams that use OZ's recommended pattern often miss field validation. The static-nonce primitive is the easiest to detect and the most damaging when present.

---

## V8 -- Slack / PagerDuty / notification webhook leak

**What it is.** Frontend devs add Slack/PagerDuty webhooks for "monitoring" purposes (so the frontend can ping a Slack channel when a user encounters an error). They use `NEXT_PUBLIC_SLACK_WEBHOOK_*` or `VITE_APP_*` env vars, not realizing those ship to the browser. The webhook URL is then permanently exposed; anyone can post arbitrary messages to the team's Slack/PagerDuty.

**Detection kit.**

```bash
# 1. JS bundle grep for webhook patterns
grep -oE '(NEXT_PUBLIC|VITE_APP|REACT_APP)_(SLACK|PAGERDUTY|DISCORD|TELEGRAM)_WEBHOOK[^,;]+' \
  "${EVIDENCE}/web/js-bundles/"*.js | sort -u

grep -oE 'hooks\.slack\.com/services/[A-Za-z0-9/]+' \
  "${EVIDENCE}/web/js-bundles/"*.js | sort -u

grep -oE 'events\.pagerduty\.com[A-Za-z0-9/]+' \
  "${EVIDENCE}/web/js-bundles/"*.js | sort -u

grep -oE 'discord\.com/api/webhooks/[0-9]+/[A-Za-z0-9_-]+' \
  "${EVIDENCE}/web/js-bundles/"*.js | sort -u

# 2. Confirm webhook is live (do NOT post a real attack message; harmless ping only)
# WEBHOOK_URL="https://hooks.slack.com/services/T../B../..."
# curl -s -X POST "${WEBHOOK_URL}" -H 'Content-Type: application/json' \
#   -d '{"text":"security disclosure verification ping (safe to ignore)"}' \
#   -w "HTTP %{http_code}\n"
# 200 = live. 404 = revoked. Always document the test message contents in the disclosure.
```

**Re-verification.** POST the same harmless ping. 404 = webhook revoked. 200 = still live (sponsor must rotate).

**Upshift example.** W26 -- `https://hooks.slack.com/services/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` exposed in `NEXT_PUBLIC_SLACK_WEBHOOK_URL`. Now patched (404).

**Generalization.** Every team that uses Slack for notifications has at least one exposed webhook. The damage radius:
- Spam / phishing into the team's incident channel (medium)
- Trigger fake alerts that mask a real attack (high)
- If the team uses Slack to authorize on-chain actions ("@bot approve withdrawal") the webhook becomes a control-channel hijack vector (critical -- rare but exists)

---

## V9 -- Sentry / analytics correlation

**What it is.** Sentry / Mixpanel / Amplitude / Google Tag Manager are loaded in the frontend. They receive whatever data the frontend hands them, often including user-context fields like wallet addresses, email, internal user IDs. This creates a privacy-side-channel: an attacker who breaches Sentry can correlate every wallet address with every user's internal ID, IP, browser fingerprint.

This is rarely "exploitable" in the fund-theft sense but is a structural privacy bug that often unlocks deeper attacks (KYC bypass, social engineering, regulatory exposure).

**Detection kit.**

```bash
# 1. Find Sentry / analytics init code in JS bundles
grep -oE 'sentry[A-Za-z]*\.io/[0-9]+/[0-9]+' "${EVIDENCE}/web/js-bundles/"*.js | sort -u
grep -oE 'cdn\.amplitude\.com' "${EVIDENCE}/web/js-bundles/"*.js | sort -u
grep -oE 'mixpanel\.com' "${EVIDENCE}/web/js-bundles/"*.js | sort -u
grep -oE 'googletagmanager\.com' "${EVIDENCE}/web/js-bundles/"*.js | sort -u

# 2. Find the Sentry DSN if exposed
grep -oE 'https://[A-Za-z0-9]+@[A-Za-z0-9.-]+\.sentry\.io/[0-9]+' \
  "${EVIDENCE}/web/js-bundles/"*.js | sort -u

# 3. Check what user context is sent to Sentry/analytics
grep -A 3 -E 'setUser|identify|setContext|setTag' "${EVIDENCE}/web/js-bundles/"*.js \
  | grep -oE '(address|wallet|eoa|email|userId|user_id)' | sort -u

# 4. Check for unscrubbed wallet addresses in error reports
# Run the app, trigger a known error, inspect the Sentry payload via DevTools
# Document any wallet addresses that appear in the payload
```

**Re-verification.** No straightforward re-verification kit -- this requires running the app in DevTools and inspecting Sentry payloads. Document the methodology in the finding.

**Upshift example.** W30 -- Sentry DSN exposed, wallet addresses correlated with user contexts in error reports.

**Generalization.** Most DeFi frontends ship with at least Sentry. The question is whether they scrub wallet addresses before sending events. They usually don't.

---

## V10 -- Proxy governance chain

**What it is.** Every upgradeable contract has a chain of authority: EOA → Safe / Timelock → ProxyAdmin → Proxy → Implementation. The chain's effective security is the weakest link. Many protocols have one strong link (a 3-of-5 multisig) and one weak link (an EOA controlling that multisig's owner key, or a 1-of-1 Safe at the top, or a missing Timelock between Safe and ProxyAdmin).

This vector requires reading on-chain storage slots and tracing the chain manually. It's the most time-intensive vector but produces some of the highest-severity findings (unilateral upgrade authority on a $100M+ protocol).

**Detection kit.**

```bash
# For each proxy contract in the protocol's deployed-contracts list:

PROXY="<proxy_address>"

# 1. Read EIP-1967 implementation slot
curl -s -X POST "${EVM_RPC}" -H "Content-Type: application/json" \
  -d "{\"jsonrpc\":\"2.0\",\"method\":\"eth_getStorageAt\",\"params\":[\"${PROXY}\",\"0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc\",\"latest\"],\"id\":1}" \
  | jq -r '.result' | sed 's/^0x000000000000000000000000/0x/'
# That's the IMPLEMENTATION address

# 2. Read EIP-1967 admin slot
curl -s -X POST "${EVM_RPC}" -H "Content-Type: application/json" \
  -d "{\"jsonrpc\":\"2.0\",\"method\":\"eth_getStorageAt\",\"params\":[\"${PROXY}\",\"0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103\",\"latest\"],\"id\":1}" \
  | jq -r '.result' | sed 's/^0x000000000000000000000000/0x/'
# That's the PROXY ADMIN address

# 3. Classify ProxyAdmin: contract or EOA
ADMIN="<from step 2>"
CODE=$(curl -s -X POST "${EVM_RPC}" -H "Content-Type: application/json" \
  -d "{\"jsonrpc\":\"2.0\",\"method\":\"eth_getCode\",\"params\":[\"${ADMIN}\",\"latest\"],\"id\":1}" \
  | jq -r '.result')
if [ "${CODE}" = "0x" ]; then
  echo "PROXY ADMIN IS EOA: ${ADMIN}"
  echo "  → single key compromise = upgrade authority"
else
  echo "PROXY ADMIN IS CONTRACT: ${ADMIN}"
  # 4. If contract: read getOwners() if Safe, otherwise inspect bytecode for Timelock pattern
  SEL_OWN=$(python3 -c "from eth_utils import keccak; print(keccak(b'getOwners()')[:4].hex())")
  curl -s -X POST "${EVM_RPC}" -H "Content-Type: application/json" \
    -d "{\"jsonrpc\":\"2.0\",\"method\":\"eth_call\",\"params\":[{\"to\":\"${ADMIN}\",\"data\":\"0x${SEL_OWN}\"},\"latest\"],\"id\":1}"
  
  SEL_THR=$(python3 -c "from eth_utils import keccak; print(keccak(b'getThreshold()')[:4].hex())")
  curl -s -X POST "${EVM_RPC}" -H "Content-Type: application/json" \
    -d "{\"jsonrpc\":\"2.0\",\"method\":\"eth_call\",\"params\":[{\"to\":\"${ADMIN}\",\"data\":\"0x${SEL_THR}\"},\"latest\"],\"id\":1}"
fi

# 5. Check for Timelock between ProxyAdmin and EOA
SEL_DELAY=$(python3 -c "from eth_utils import keccak; print(keccak(b'getMinDelay()')[:4].hex())")
curl -s -X POST "${EVM_RPC}" -H "Content-Type: application/json" \
  -d "{\"jsonrpc\":\"2.0\",\"method\":\"eth_call\",\"params\":[{\"to\":\"${ADMIN}\",\"data\":\"0x${SEL_DELAY}\"},\"latest\"],\"id\":1}"
# If returns a number → it's a Timelock. If reverts → it's not.

# Document the full chain: PROXY → IMPLEMENTATION; PROXY → ADMIN → (Safe owners | Timelock proposers) → ultimate signers
```

**Re-verification.** Re-read all storage slots after disclosure. Implementation address change = upgrade happened. Admin address change = admin migrated (Safe set up, Timelock added). Owner set change = signer added.

**Upshift example.** NEW-01 (proxy governance chain -- no timelock + weak multisigs on $22M+ TVL), W35 (EOA proxy admin), W39 (sentETH 1-of-1 Safe).

**Generalization.** Every upgradeable protocol has this chain. The findings:
- ProxyAdmin = EOA → critical (single key controls upgrade)
- ProxyAdmin = Safe with threshold 1 → critical (single signer controls upgrade)
- ProxyAdmin = Safe with low threshold relative to TVL → high
- No Timelock between Safe and ProxyAdmin → high (multisig compromise = instant upgrade)
- Timelock with `<24h` minDelay → medium (insufficient response window)
- Same EOA controls multiple Safe owners' keys (private key reuse) → critical (only detectable via ETH movement analysis)

`~/Desktop/BUGS/INFRA-ADJACENT-TO-SC-PLAYBOOK.md` Section H covers MPC / custody patterns -- adjacent to V10.

---

## Cross-vector amplifiers

Some findings span multiple vectors. The amplifiers:

- **V1 + V4 = automatic chain.** A leaked secret (V1) that authenticates as a role (V3) controlling an unauthenticated trigger (V4) is the F1+W34 chain template. **This is the killshot pattern.**
- **V2 + V3 + V4 = compositional Critical.** An unauth endpoint (V2) that triggers a wallet (V3) to take an on-chain action (V4) is Critical even without a leaked secret if mass assignment / IDOR allows arbitrary parameters.
- **V5 + V2 = staging pivot.** Staging (V5) often has more permissive auth than prod, lets you hit V2 endpoints that prod blocks.
- **V7 + V4 = persistent compromise.** SIWE replay (V7) gives durable JWT, V4 gives action authorization. Replay-attack-as-a-service.
- **V10 + (any) = upgrade escalation.** Even a Medium finding on a vault becomes Critical if proxy admin is compromised (the attacker can replace the impl with malicious code).

`HUNT-METHODOLOGY.md` Pass 4 (chain construction) is dedicated to finding these amplifiers. Do not exit Phase 3 without running Pass 4.

## Output organization

Each vector should produce one or more files under `evidence/web/findings/`:

```
evidence/web/findings/
  V01-bundle-harvest-<target>-W<num>-<slug>.md
  V02-unauth-api-<target>-W<num>-<slug>.md
  V03-operator-wallet-<target>-W<num>-<slug>.md
  V04-trigger-trace-<target>-W<num>-<slug>.md
  ...
```

`WORKSPACE-TEMPLATE.md` codifies this layout. Each finding file follows the standard finding structure: title, severity, primitive, proof (curl + on-chain readback if applicable), impact, remediation, re-verification kit (the same one used in this file's vector section).

## When a vector returns nothing

If a vector's detection kit produces no findings, document that explicitly:

```bash
echo "V<N> returned no findings on $(date -u +%Y-%m-%dT%H:%M:%SZ): <one-line reason>" \
  >> "${EVIDENCE}/web/findings/_negative-results.md"
```

Negative results inform the Pass 2 expansion (`HUNT-METHODOLOGY.md`): if V1 returned nothing but the bundle is 6MB, you under-grepped. If V2 returned nothing but OpenAPI is exposed, you didn't enumerate all routes. **A vector returning nothing on a target with the right profile is more often "I didn't dig deep enough" than "the protocol is solid".** See `IMMORTAL-MODE.md` guard #4.
