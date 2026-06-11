# Strix Integration Guide

Strix is an AI-powered web application security scanner. It complements manual smart contract auditing by covering the web/API attack surface that DeFi protocols expose.

## When to Use Strix

| Target Type | Use Strix? | Rationale |
|-------------|-----------|-----------|
| Frontend web apps (React, Next.js) | **YES** | XSS, CSRF, auth bypasses, API key exposure |
| REST/GraphQL APIs | **YES** | Injection, broken auth, rate limiting, IDOR |
| Admin panels / dashboards | **YES** | Default credentials, privilege escalation, exposed endpoints |
| Subdomain enumeration | **YES** | Forgotten staging/dev instances, takeover opportunities |
| Infrastructure (DNS, TLS, headers) | **YES** | Misconfigurations, missing security headers |

## When NOT to Use Strix

| Target Type | Use Strix? | Rationale |
|-------------|-----------|-----------|
| Smart contracts (Solidity, Vyper) | **NO** | Use Foundry, Slither, manual review |
| On-chain logic | **NO** | Strix cannot analyze EVM bytecode |
| Cryptographic implementations | **NO** | Requires domain-specific analysis |
| Token economics / DeFi mechanics | **NO** | Requires financial modeling, not web scanning |
| Private/internal networks | **NO** | Strix scans public-facing surfaces only |

## Setup

### Prerequisites

- Docker installed and running
- LLM API key (for AI-powered analysis features)
- Target URL or domain

### Installation

```bash
# Pull Strix Docker image
docker pull strixsec/strix:latest

# Run with API key
docker run -it \
  -e LLM_API_KEY="your-api-key" \
  -v $(pwd)/strix-results:/results \
  strixsec/strix:latest
```

### Configuration

```yaml
# strix-config.yml
target:
  url: "https://app.protocol.xyz"
  scope:
    - "*.protocol.xyz"
    - "api.protocol.xyz"
  exclude:
    - "docs.protocol.xyz"

scan:
  modules:
    - web_vulns      # XSS, SQLi, CSRF
    - api_security   # Auth, IDOR, rate limits
    - subdomain_enum # Subdomain discovery
    - header_check   # Security headers
    - tls_audit      # Certificate/TLS config

  rate_limit: 10  # requests per second (be respectful)
  timeout: 30     # seconds per request
```

## Workflow: Strix Findings → Quality Gates

**Strix findings pass through the EXACT SAME quality gates as manual findings.**

```
Strix scan → Raw findings → False positive filter → Manual verification → Quality gate → Disclosure
```

### Step 1: Run Scan

```bash
docker run -it \
  -v $(pwd)/strix-config.yml:/config.yml \
  -v $(pwd)/strix-results:/results \
  strixsec/strix:latest scan --config /config.yml
```

### Step 2: Filter False Positives

Strix will produce many findings. Most web scanners have high false positive rates. **Manual verification is mandatory.**

| Finding Type | Typical FP Rate | Verification Method |
|-------------|----------------|-------------------|
| XSS (reflected) | 30-50% | Manually craft payload, verify execution in browser |
| XSS (stored) | 10-20% | Verify payload persists and executes for other users |
| SQLi | 20-40% | Verify with `sqlmap` or manual boolean/time-based tests |
| CSRF | 40-60% | Check if action has real impact, verify no anti-CSRF token |
| IDOR | 20-30% | Verify with two different authenticated sessions |
| Open redirect | 50-70% | Verify redirect works to attacker-controlled domain |
| Security headers | 5-10% | Low FP, but verify impact (HSTS on non-sensitive page = low) |
| Subdomain takeover | 30-50% | Verify CNAME dangling, attempt claim |

### Step 3: Manual Verification

For each finding that passes the false positive filter:

1. **Reproduce manually** — Can you trigger the vulnerability without Strix?
2. **Assess real impact** — Does this affect users/funds, or is it cosmetic?
3. **Check if it's in web scope** — Some protocols only care about smart contract bugs
4. **Build PoC** — Same quality as manual findings: reproducible, clear, documented

### Step 4: Apply Quality Gates

**Run the exact same quality gate from `/disclose`:**
- Target Assessment Card
- Production Reachability (is the vulnerable endpoint live?)
- Duplicate Check
- Anti-Dismissal Research
- 24-point Quality Gate

### Step 5: Disclose

Use `/disclose` to format the report. Web findings use the same template with adapted sections:

- **CVSS vector** will differ (AV:N is standard for web)
- **PoC** will be HTTP requests / browser steps instead of Foundry tests
- **Fix** will be web-specific (CSP headers, input sanitization, auth checks)

## Web Finding PoC Format

```markdown
## Proof of Concept

### Endpoint
`POST https://api.protocol.xyz/v1/endpoint`

### Request
```http
POST /v1/endpoint HTTP/1.1
Host: api.protocol.xyz
Content-Type: application/json
Authorization: Bearer <token>

{"param": "<script>alert(1)</script>"}
```

### Response
```http
HTTP/1.1 200 OK
Content-Type: text/html

...<script>alert(1)</script>...
```

### Steps to Reproduce
1. Authenticate as regular user
2. Send the above request
3. Visit [URL] — script executes in browser context
4. Attacker can [steal session / exfiltrate data / etc.]

### Impact
[Concrete impact with affected user count / data type]
```

## DeFi Protocol Web Attack Surface

Most DeFi protocols have a larger web surface than they realize:

| Component | Common Vulnerabilities | Impact |
|-----------|----------------------|--------|
| Frontend dApp | XSS → wallet draining | Critical (funds at risk) |
| API gateway | Auth bypass → unauthorized actions | High |
| Admin dashboard | Default creds → protocol manipulation | Critical |
| Subgraph/indexer | GraphQL injection → data leak | Medium |
| Bridge UI | Phishing via open redirect | Medium |
| Documentation site | Subdomain takeover → phishing | Low-Medium |
| CI/CD pipeline | Secret exposure → supply chain | Critical |

## Limitations

- Strix is a **supplementary tool**, not a replacement for manual auditing
- **Never submit unverified Strix findings** — always reproduce manually
- Strix cannot assess **business logic** vulnerabilities (e.g., "this API allows unlimited minting")
- Web findings may have **lower bounties** than smart contract findings on most programs
- Some protocols **explicitly exclude web/frontend** from their security scope — check before investing time
