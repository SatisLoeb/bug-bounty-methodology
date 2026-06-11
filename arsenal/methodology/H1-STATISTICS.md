# H1 Bounty ROI Analysis & Target Selection Heuristics

**Source:** HackerOne 8th Annual HPSR (2024-2025), disclosed hacktivity analysis, $81M payout data.
**Purpose:** Data-driven target selection and time allocation.

---

## 1. Payout Distribution (2024-2025)

| Metric | Value |
|--------|-------|
| Total annual payouts | $81M (+13% YoY) |
| Top 10 programs | $21.6M (27% of total) |
| Top 100 programs | $51M (63% of total) |
| Average per active program | ~$42K/year |
| Top 100 researchers cumulative | $31.8M |

**Insight:** 27% of payouts come from 10 programs. Concentrate on high-payout programs.

---

## 2. Vulnerability Type ROI

### Bounty per Hour (estimated)

| Vulnerability | Avg Bounty | Avg Time to Find | $/hour | Trend |
|---------------|-----------|-------------------|--------|-------|
| Dependency confusion RCE | $15K-$30K | 4-8h | $2K-$7K | stable (rare) |
| SSRF -> cloud metadata chain | $5K-$17K | 2-6h | $1K-$5K | stable |
| Auth bypass / ATO chain | $3K-$25K | 4-12h | $750-$2K | rising |
| IDOR (write/delete + chain) | $3K-$12K | 2-6h | $1K-$3K | rising +23% |
| Business logic (payment) | $2K-$5K | 3-8h | $400-$1K | rising +37% crypto |
| Race condition (financial) | $1K-$5K | 1-4h | $500-$2K | stable |
| XSS (stored, impactful) | $500-$3K | 1-4h | $300-$1K | declining -10% |
| API key leak (high-priv) | $500-$2K | 0.5-2h | $500-$2K | stable |
| Info disclosure | $100-$1K | 0.5-2h | $200-$500 | declining |
| Subdomain takeover | $200-$2K | 1-3h | $200-$800 | saturated |

### Best ROI strategies:
1. **IDOR hunting on API-heavy apps** — highest volume, good payout, rising trend
2. **SSRF via PDF/webhook/import** — fewer hunters, high payout when cloud metadata reached
3. **Auth consistency audits** — manual-only, no scanner competition, rising payouts
4. **Race conditions on payments** — quick to test, direct financial impact = fast triage

---

## 3. Declining ROI (Avoid or De-prioritize)

| Category | Why Declining | Alternative Focus |
|----------|--------------|-------------------|
| XSS (reflected) | 78% of hackbot findings = XSS, saturated | Stored XSS via cache poisoning instead |
| Basic SQLi | Well-caught by WAFs, automated scanners | GraphQL injection, NoSQL injection |
| Open redirects (standalone) | Low severity unless chained | Chain with OAuth for token theft |
| Missing security headers | Informative tier, often ignored | CSP bypass -> XSS chain instead |
| Rate limiting (standalone) | Almost always informative | Race condition on financial ops instead |

---

## 4. Rising Categories (2025-2026)

### AI/LLM Vulnerabilities
- **+540% prompt injection reports**
- **1,121 programs with AI in scope (+270% YoY)**
- **~50% validity rate for hackbot submissions**
- Focus: prompt injection -> data exfil, tool use abuse, indirect injection via documents

### Authorization / Access Control
- **IDOR reports +29% volume, +23% payouts**
- **Business logic +37% in crypto/blockchain**
- Focus: destructive IDOR, cross-interface auth inconsistency, MFA bypass

### API Security
- **API-first architectures = more API-specific bugs**
- Focus: GraphQL IDOR, REST vs GraphQL auth gaps, API key scope abuse

---

## 5. Target Selection Heuristics

### High-Value Target Indicators
```
Score each indicator (0-3 points):

[3] Bounty program max > $10K for critical
[3] API-heavy application (REST + GraphQL)
[2] Recently added AI features
[2] Multi-step financial flows (payments, transfers, subscriptions)
[2] OAuth/SSO integration with third parties
[2] File upload/import features (PDF, CSV, images)
[2] Webhook/notification URL configuration
[1] Mobile + web app (often different auth stacks)
[1] Recently launched program (< 6 months)
[1] Multiple subdomains (larger attack surface)
[1] GraphQL endpoint (often weaker auth than REST)

Score:
> 15 = DEEP DIVE (20-40h)
10-15 = STANDARD SCAN (8-15h)
5-10  = QUICK CHECK (2-4h)
< 5   = SKIP
```

### Kill Signals (Hard Skip)
- Max bounty < $500 (not worth the time)
- > 500 resolved reports with $0 avg payout (program doesn't pay)
- "Informative" rate > 60% (program dismisses aggressively)
- Scope limited to *.marketing.example.com (no critical assets)
- Program paused or unresponsive > 30 days

### Time Boxing by Program Type

| Program Type | Max Investment | Expected Findings |
|-------------|---------------|-------------------|
| Large tech ($50K+ max) | 40h deep dive | 3-8 valid |
| Mid-tier ($5K-$50K max) | 15h standard | 2-4 valid |
| Small ($1K-$5K max) | 4h quick scan | 1-2 valid |
| New program (first 90 days) | 8h + check weekly | 3-6 valid (less competition) |
| Crypto/DeFi ($100K+ max) | 40h+ deep + SC | 1-3 valid (high payout) |

---

## 6. Industry-Specific Patterns

### Crypto/Blockchain (37% business logic increase)
- Payment flow manipulation (withdrawal, deposit, swap)
- API key scope escalation (trade vs read-only)
- Exchange rate manipulation via race conditions
- KYC bypass via multi-step flow manipulation
- WebSocket auth inconsistency (trading ws vs REST)

### Fintech/Banking
- IDOR on transaction history / statements
- SSRF via document generation (statements, tax forms)
- Race conditions on transfers (double-spend)
- MFA bypass on high-value operations
- PII disclosure via API verbose responses

### SaaS
- Multi-tenant IDOR (cross-organization data access)
- OAuth scope escalation
- Invitation/sharing flow logic flaws
- API key in frontend with excessive permissions
- Subdomain takeover on customer-facing domains

### E-commerce
- Price manipulation in checkout
- Coupon/promo code race conditions
- IDOR on order management
- Payment callback manipulation
- Inventory manipulation (negative quantities)

---

## 7. Submission Strategy (Maximize Payout)

### Quality Multipliers
1. **Demonstrate full chain** — IDOR read is $1K, IDOR -> mass data exfil with script is $5K
2. **Quantify impact** — "affects 50K users" > "could affect some users"
3. **Include fix** — reduces triage time, shows competence
4. **Reproduce in 3 commands** — bash/curl PoC > screenshots
5. **Submit strongest finding first** — establishes credibility for subsequent reports

### Payout Killers (Reduce or Eliminate Bounty)
1. Duplicate (check disclosed reports BEFORE writing)
2. Informative severity (theoretical risk, no PoC)
3. Out of scope (check program policy carefully)
4. Known issue / accepted risk (check program FAQ/policy notes)
5. Self-XSS / logout CSRF / missing headers (almost always N/A)

---

## 8. Timing Patterns

### Best Times to Hunt
- **New program launch** — first 90 days, less competition, low-hanging fruit
- **Scope expansion** — new domains/apps added, fresh attack surface
- **Post-acquisition** — newly integrated systems often have auth gaps
- **Major feature launch** — new code = new bugs, often rushed

### Worst Times to Hunt
- **After major audit** — recent pentest = recently fixed bugs
- **Saturated programs** — > 500 resolved reports, diminishing returns
- **Program with AI hackbot presence** — surface XSS already caught by automation
