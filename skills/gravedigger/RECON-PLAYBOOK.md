# RECON-PLAYBOOK.md — Phase 0-2: Reverse Lookup, Intelligence & Surface Mapping

Concrete reconnaissance procedures. Every section has exact commands, MCP tool invocations, curl templates, and grep patterns.

---

## Phase 0: Reverse Dependency Lookup (5 min)

**Runs FIRST on every target.** Cross-references the target's dependency tree against your research database. If the target uses a lib you've already broken, you have instant downstream reports before touching the target's own code.

See `SKILL.md` Phase 0 for full procedure. Quick reference:

```bash
# 1. Extract SBOM
cat package-lock.json | jq -r '.packages | to_entries[] | select(.key != "") | {name: (.key | split("node_modules/") | last), version: .value.version} | "\(.name)@\(.version)"' | sort -u > sbom-npm.txt

# 2. Run lookup
python3 ~/arsenal/tools/reverse-lookup.py \
  --sbom sbom-npm.txt \
  --db ~/arsenal/tracking/research_db.jsonl \
  --ecosystem npm \
  --target "TargetName"

# 3. If hits → write downstream reports before Phase 1
# 4. If unknown parsers/crypto at trust boundary → add to fuzzing queue
```

**Output:** `{protocol}-recon/REVERSE-LOOKUP.md`

---

## Phase 1: Protocol Intelligence (120 min max)

### 1.1 Protocol Identity & TVL

**DeFiLlama TVL lookup:**
```bash
# Get protocol TVL
curl -s "https://api.llama.fi/protocol/{slug}" | jq '{name, tvl: .tvl, chainTvls, mcap}'

# Search for protocol by name
curl -s "https://api.llama.fi/protocols" | jq '.[] | select(.name | test("{name}"; "i")) | {name, slug, tvl, chains, category}'

# TVL by chain breakdown
curl -s "https://api.llama.fi/protocol/{slug}" | jq '.chainTvls | to_entries[] | {chain: .key, tvl: .value.tvl[-1][1]}'

# Funding rounds
curl -s "https://api.llama.fi/raises" | jq '.[] | select(.name | test("{name}"; "i"))'
```

**Protocol identity checklist:**

| Field | Source | How |
|-------|--------|-----|
| Name & aliases | Website, docs, GitHub | Manual |
| Corporate entity | Companies House, OpenCorporates, Crunchbase | Web search |
| Team members | LinkedIn, GitHub, Twitter | Web search |
| Funding rounds | Crunchbase, DeFiLlama raises | curl above |
| Category | DeFiLlama | Protocol lookup |
| Chains deployed | DeFiLlama + docs | Protocol lookup |
| TVL per chain | DeFiLlama | TVL breakdown |
| Token (if any) | CoinGecko | `curl -s "https://api.coingecko.com/api/v3/coins/{id}"` |
| Launch date | Blog, GitHub | `git log --reverse --oneline | head -1` |
| App URL(s) | Docs, DNS | Manual |
| API URL(s) | App source, docs | JS bundle analysis, OpenAPI probing |

**Output:** Protocol identity table in RECON.md

---

### 1.2 Audit Trail Analysis

**Discovery sources:**
- GitHub repo: `/audits/`, `/security/`, `/docs/audit*`, README mentions
- Trail of Bits: `github.com/trailofbits/publications`
- OpenZeppelin: `blog.openzeppelin.com`
- Spearbit: `github.com/spearbit/portfolio`
- Code4rena: `code4rena.com/reports`
- Sherlock: `audits.sherlock.xyz`
- Cantina: `cantina.xyz`

**For each audit found:**
1. Download the full PDF/report
2. Record: Auditor, date, scope (contracts/commits), findings count by severity
3. Extract all "acknowledged"/"won't fix"/"risk accepted" findings — **these are research gold**
4. Compare audit commit hash to current deployed code:
   ```bash
   git log {audit_commit}..HEAD --oneline | wc -l
   ```
5. Use MCP tool for specific file dating:
   ```
   kill_gate_q9_post_audit(repo_path=".", file_path="src/Contract.sol", audit_date="2025-06-15")
   ```

**Audit tracking table:**
```markdown
| Auditor | Date | Scope | Commit | Findings (C/H/M/L) | Ack/WontFix | Post-Audit Changes |
|---------|------|-------|--------|---------------------|-------------|-------------------|
```

---

### 1.3 Security Contact Discovery

**Priority chain (try in order, stop when found):**

| Priority | Method | Command |
|----------|--------|---------|
| 1 | security.txt | `curl -sL https://{domain}/.well-known/security.txt` |
| 2 | SECURITY.md | Check GitHub repo root and `docs/` |
| 3 | security@ email | Check MX: `dns_lookup(domain="{domain}", record_type="MX")` |
| 4 | Bug bounty platform | Search Immunefi, HackerOne, Bugcrowd |
| 5 | PGP key | `gpg --keyserver keys.openpgp.org --search-keys {domain}` |
| 6 | Keybase/Signal | Search team member profiles |
| 7 | On-chain message | Last resort only |

**Record in `evidence/CONTACTS.md`:**
```markdown
| Method | Contact | Verified | Encryption Available |
|--------|---------|----------|---------------------|
```

---

### 1.4 On-Chain Enumeration

**Map all deployed contracts, roles, upgradeability, admin keys.**

**MCP tool commands:**
```
# Resolve proxy implementation
evm_resolve_proxy(chain="ethereum", address="0x...")

# Check contract existence and type
evm_get_bytecode(chain="ethereum", address="0x...")

# Read key state variables
evm_call(chain="ethereum", address="0x...", calldata="0x...")

# Read storage slots
evm_read_storage(chain="ethereum", address="0x...", slot=0)

# Check recent events (upgrades, admin changes)
evm_get_logs(chain="ethereum", address="0x...", topics=["0x..."], limit_blocks=10000)

# Full state snapshot
onchain_state_snapshot(
  rpc_url="https://ethereum-rpc.publicnode.com",
  contract="0x...",
  slots=["0", "1", "2"],
  calls=[
    {"sig": "owner()(address)"},
    {"sig": "totalAssets()(uint256)"},
    {"sig": "paused()(bool)"}
  ]
)

# Upgradeability check
kill_gate_q7_upgradeability(rpc_url="https://ethereum-rpc.publicnode.com", contract="0x...")
```

**Standard EIP-1967 slots to always check:**

| Slot | Purpose |
|------|---------|
| `0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc` | Implementation |
| `0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103` | Admin |
| `0xa3f0ad74e5423aebfd80d3ef4346578335a9a72aeaee59ff6cb3582b35133d50` | Beacon |

**Common event signatures:**

| Event | Topic0 |
|-------|--------|
| `OwnershipTransferred(address,address)` | `0x8be0079c531659141344cd1fd0a4f28419497f9722a3daafe3b4186f6b6457e0` |
| `Upgraded(address)` | `0xbc7cd75a20ee27fd9adebab32041f755214dbc6bffa90cc0225b39da2e5c2d3b` |
| `AdminChanged(address,address)` | `0x7e644d79422f17c01e4894b5f4f588d331ebfa28653d42ae832dc59e38c9798f` |
| `Paused(address)` | `0x62e78cea01bee320cd4e420270b5ea74000d11b0c9f74754ebdbfc544b05a258` |

**Contract inventory template:**
```markdown
| Address | Name | Type | Proxy? | Impl | Admin | Chain | TVL |
|---------|------|------|--------|------|-------|-------|-----|
```

---

### 1.5 Source Code Acquisition

**Priority order:**
1. **Etherscan/Blockscout verified source** — matches deployed bytecode (authoritative)
2. **GitHub repository** — may differ from deployed
3. **Decompilation** — last resort

```bash
# Save verified source
# evidence/contracts/verified/{ContractName}-{address_prefix}.sol

# Clone GitHub at deployment tag
git clone --depth 1 --branch {tag} {repo_url} evidence/contracts/{protocol}-src/
```

**Always cross-reference:** GitHub source vs deployed bytecode when possible.

---

## Phase 2: Surface Mapping (90 min max)

### 2.1 Smart Contract Surface

**Entry point identification:**
```bash
# External/public functions
grep -rn "function.*external\|function.*public" contracts/

# Receive/fallback
grep -rn "receive()\|fallback()" contracts/

# Callbacks
grep -rn "onERC721Received\|onERC1155Received\|tokensReceived\|uniswapV3" contracts/
```

**Categorize by risk:**

| Category | Grep Pattern | Why High Risk |
|----------|-------------|---------------|
| State-changing with value | `payable` | Direct fund handling |
| Admin-only | `onlyOwner\|onlyAdmin\|onlyRole\|require.*msg.sender` | Access control boundary |
| Math operations | `* / % **` on uint | Overflow/rounding |
| External calls | `.call\|.delegatecall\|.transfer\|.send\|IERC20` | Reentrancy, return value |
| Oracle dependent | `getPrice\|latestRoundData\|getAmountOut\|twap` | Manipulation |
| Cross-contract | `IVault\|IPool\|IStrategy\|address(` | Trust boundary |

---

### 2.2 Web/API Surface

**OpenAPI/Swagger discovery:**
```bash
TARGET="https://{api_domain}"
for path in /openapi.json /openapi.yaml /swagger.json /swagger.yaml /api/openapi.json /api/v1/openapi.json /api/v2/openapi.json /api/docs /docs /api-docs /swagger-ui /swagger-ui.html /redoc /api/schema /.well-known/openapi.json /graphql /graphql/schema; do
  status=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "${TARGET}${path}")
  [ "$status" != "000" ] && [ "$status" != "404" ] && echo "$status $path"
done
```

**Endpoint categorization:**

| Category | Pattern | Risk Level |
|----------|---------|------------|
| Authentication | `/auth`, `/login`, `/signup`, `/verify`, `/nonce`, `/siwe` | Critical |
| User data | `/user`, `/profile`, `/account`, `/settings` | High |
| Financial ops | `/deposit`, `/withdraw`, `/swap`, `/transfer`, `/vault` | Critical |
| Admin/internal | `/admin`, `/internal`, `/debug`, `/metrics`, `/health` | Critical |
| Public data | `/markets`, `/prices`, `/stats`, `/tvl` | Low |

**Auth inconsistency detection — for each endpoint:**
```bash
# Without auth
curl -s -o /dev/null -w "%{http_code}" "${TARGET}/endpoint"

# With valid auth
curl -s -o /dev/null -w "%{http_code}" -H "Authorization: Bearer {token}" "${TARGET}/endpoint"

# With invalid auth
curl -s -o /dev/null -w "%{http_code}" -H "Authorization: Bearer invalid" "${TARGET}/endpoint"
```

Document inconsistencies: endpoints returning 200 without auth, or returning different data with/without auth.

---

### 2.3 Domain Discovery

**DNS enumeration (MCP tools):**
```
dns_lookup(domain="{domain}", record_type="ANY")
dns_lookup(domain="{domain}", record_type="TXT")
dns_lookup(domain="{domain}", record_type="MX")
whois_lookup(target="{domain}")
```

**Subdomain probing:**
```bash
for sub in api app staging dev test beta admin dashboard docs blog status monitor metrics grafana kibana internal legacy old v1 v2 sandbox demo preview private; do
  status=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "https://${sub}.{domain}/")
  [ "$status" != "000" ] && echo "$status ${sub}.{domain}"
done
```

**Certificate Transparency logs:**
```bash
curl -s "https://crt.sh/?q=%25.{domain}&output=json" | jq -r '.[].name_value' | sort -u
```

**Mirror/legacy domain probing:**
```bash
for variant in "{name}.finance" "{name}.io" "{name}.xyz" "{name}.app" "{name}-app.vercel.app" "{name}-api.fly.dev" "api.{name}.finance" "private.{name}.finance"; do
  status=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "https://${variant}/")
  [ "$status" != "000" ] && echo "$status ${variant}"
done
```

---

### 2.4 Infrastructure Fingerprinting

**HTTP headers:**
```bash
curl -sI "https://{domain}/" | grep -iE "server:|x-powered|x-frame|content-security|strict-transport|x-request-id|x-runtime|via:|cf-ray|x-amz|x-goog"
```

**Intelligence extraction:**

| Header/Signal | Inference |
|--------------|-----------|
| `Server: uvicorn` | Python backend (FastAPI) |
| `Server: nginx` | Reverse proxy |
| `X-Powered-By: Next.js` | **Next.js detected → activate NEXTJS-HUNT-CHECKLIST.md** |
| `CF-Ray` | Cloudflare protected |
| `X-Request-Id: uuid` | Request tracing |
| `Via: 1.1 google` | Google Cloud |
| Error stack traces | Framework, language, internal paths |

**Health/debug endpoint probing:**
```bash
for path in /health /healthz /ready /ping /status /info /version /debug /debug/vars /debug/pprof /metrics /prometheus /actuator /actuator/health /actuator/env /_internal /env /config; do
  resp=$(curl -s -w "\n%{http_code}" --max-time 5 "https://{domain}${path}")
  code=$(echo "$resp" | tail -1)
  [ "$code" != "000" ] && [ "$code" != "404" ] && echo "=== $code $path ===" && echo "$resp" | head -20
done
```

---

### 2.5 Integration Discovery

**From JavaScript bundles:**
```bash
# Download main JS and extract third-party domains
curl -s "https://{app_domain}/" | grep -oP 'src="(/[^"]*\.js)"' | while read js; do
  curl -s "https://{app_domain}${js}" >> evidence/web/js-bundles/all-bundles.js
done
grep -oP 'https?://[a-zA-Z0-9._-]+\.[a-z]{2,}' evidence/web/js-bundles/all-bundles.js | sort -u
```

**From API responses — look for:**
- `provider`, `relayer`, `oracle` fields
- External URLs in response data
- Service names in error messages
- API version strings suggesting third-party SDKs

**Integration inventory:**
```markdown
| Service | Type | Evidence | Access Level |
|---------|------|----------|-------------|
```

---

### 2.6 Redis / Data Store Exposure

**Auto-trigger conditions (check during §2.3 and §2.4):**
- Port scan reveals 6379/6380/6381 open on any discovered IP/subdomain
- Error messages mention Redis, Valkey, KeyDB, Memcached, or RESP protocol
- SSRF vulnerability found elsewhere (→ generate internal Redis payloads)
- JS bundles contain `redis://`, `REDIS_URL`, `ioredis`, `redis` package imports
- Health/debug endpoints expose cache connection info

**Scanner invocation:**
```bash
# Single host
python3 ~/Desktop/BUGS/redis-recon-scanner/redis-recon.py {host}:{port} --output json > evidence/infrastructure/redis-{host}.json

# Multiple hosts from subdomain probing
python3 ~/Desktop/BUGS/redis-recon-scanner/redis-recon.py {ip1}:6379 {ip2}:6379 --output json > evidence/infrastructure/redis-scan.json

# CIDR range (internal network via VPN/jump host)
python3 ~/Desktop/BUGS/redis-recon-scanner/redis-recon.py {cidr}/24 --output json > evidence/infrastructure/redis-cidr.json

# From file of targets
python3 ~/Desktop/BUGS/redis-recon-scanner/redis-recon.py --input targets.txt --output json > evidence/infrastructure/redis-batch.json
```

**What the scanner checks:**
1. **Auth assessment** — no auth, default passwords (13 common), ACL configuration
2. **Dangerous commands** — CONFIG, DEBUG, MODULE, SLAVEOF, EVAL, FLUSHALL, SHUTDOWN
3. **RCE vectors** — CONFIG SET dir/dbfilename + BGSAVE = arbitrary file write (SSH keys, webshell, crontab)
4. **Data exfiltration** — SLAVEOF attacker:port = full replication, key enumeration
5. **CVE detection** — CVE-2025-49844 (Lua UAF, CVSS 10), CVE-2024-31449 (Lua RCE), CVE-2024-31228 (DoS), CVE-2023-45145 (race)
6. **Key sampling** — 20 random keys with type/TTL/size for data sensitivity assessment

**SSRF → Redis attack chain (when SSRF is found elsewhere):**
```bash
# Generate SSRF payloads for internal Redis probing
python3 ~/Desktop/BUGS/redis-recon-scanner/redis-recon.py --ssrf-payloads

# Key payloads:
# gopher://127.0.0.1:6379/_ + URL-encoded RESP commands
# dict://127.0.0.1:6379/INFO
# dict://127.0.0.1:6379/CONFIG%20GET%20*
```

Use SSRF payloads from scanner output against any discovered SSRF vulnerability. Common internal Redis targets: `127.0.0.1:6379`, `redis:6379`, `cache:6379`, `session-store:6379`.

**Finding classification from scanner results:**

| Scanner Finding | Severity | Kill Gate Path |
|----------------|----------|---------------|
| No auth + dangerous commands | CRITICAL | → Phase 3 Q2 (reachability from attacker position) |
| CONFIG SET available + no auth | CRITICAL (RCE) | → Phase 3 Q5 (trigger feasibility: file write perms) |
| CVE-2025-49844 detected | CRITICAL | → Phase 3 Q6 (known vuln, but: is EVAL accessible?) |
| SLAVEOF available + no auth | HIGH | → Phase 3 Q2 (can attacker reach Redis + receive replication?) |
| Sensitive data in keys | HIGH | → Phase 4 (data classification, PII exposure) |
| Default password accepted | HIGH | → Direct finding (CWE-798) |
| No maxmemory limit | LOW | → Info-only unless chaining with DoS |

**Evidence storage:** `evidence/infrastructure/redis-{host}.json`

---

## Phase 1-2 Exit Checklist

Before moving to Phase 3 (Kill Gate):

- [ ] Protocol identity table complete
- [ ] TVL verified on-chain (not just from API/website)
- [ ] All audits downloaded and risk-accepted findings extracted
- [ ] Security contact identified and recorded
- [ ] All contracts inventoried with proxy/admin status
- [ ] Source code acquired and cross-referenced to deployment
- [ ] Web/API endpoints enumerated and categorized
- [ ] Subdomains and mirror domains probed
- [ ] Infrastructure fingerprinted
- [ ] **Framework detection**: If Next.js detected (\_next/ paths, __NEXT_DATA__, X-Powered-By, RSC headers) → activate `NEXTJS-HUNT-CHECKLIST.md` for remaining phases
- [ ] **Redis/data store scan**: If ports 6379-6381 open, or Redis mentioned in errors/configs/bundles → `redis-recon.py` executed, results in `evidence/infrastructure/`. If SSRF found → gopher:// payloads generated for internal Redis probing
- [ ] **MANDATORY: RPC namespace deep probe (Rule 26 v2)** — For ANY DeFi target with a web frontend:
  1. Find RPC backend URL from JS bundles: `grep -oP 'https://[a-zA-Z0-9._/-]*(rpc|node|json|web3|provider|proxy)[a-zA-Z0-9._/-]*' bundles/*.js | sort -u`
  2. Check if endpoint issues free bearer tokens (GET /auth/token pattern — 1inch: zero-credential JWT)
  3. Test namespace exposure: txpool_status, txpool_content, debug_traceTransaction (real tx hash), debug_storageRangeAt (against known contract like USDT)
  4. If txpool exposed → IMMEDIATELY check eth_sendRawTransaction (combo = zero-cost MEV sandwich kit)
  5. Sweep ALL chain IDs the protocol supports (1, 56, 137, 42161, 10, 8453, 43114)
  6. Check error responses for credential leaks (Request Finance pattern: persistTransaction error leaked full QuikNode URL)
  7. Check CSP connect-src for hardcoded RPC tokens: `go.getblock.io/<TOKEN>`, `*.quiknode.pro/<TOKEN>`
  Internal consistency: if admin is blocked (-32604) but txpool is not → method filter gap, not design.
  Confirmed findings: 1inch ($15K-$50K HackenProof), Request Finance, Tothemoon.
- [ ] Third-party integrations identified
- [ ] **MANDATORY: Authenticated session acquired** — test account created, Bearer token captured, scope/expiry documented. This token is REQUIRED for Phase 4 §4.12 (authorization consistency testing). A WAF 403 is NOT "blocked" — it means "requires auth."
- [ ] **MANDATORY: Exotic encoding detection** — If base64 blobs, CBOR/msgpack/protobuf content types, JWT injectable claims, XML/ISO 20022 bodies, gRPC-Web, or WebAuthn detected → flag for Injection Proxy Bridge activation in Phase 4 §4.13. Run `python3 ~/Desktop/BUGS/injection-proxy/proxy.py --detect "<value>"` on captured values. Record detected layers in SURFACE-MAP.md.
- [ ] All evidence saved to workspace structure (not in memory)
- [ ] RECON.md written with all Phase 1 findings
- [ ] SURFACE-MAP.md written with all Phase 2 findings
