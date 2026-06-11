# SQLi Automated Hunt Strategy

## Pipeline Integration

**Auto-trigger in gravedigger Phase 2:** When target has a web surface with parameterized URLs, run `autosqli.sh` in parallel with other recon.

**Where it fits:**
```
Phase 2.X: Automated SQLi Discovery
  → Run: ~/Desktop/BUGS/sqli-scanner/autosqli.sh <domain>
  → Feeds findings into Phase 3 Kill Gate
  → Critical SQLi = immediate report (no need for complex chain)
```

## Tool Chain

```
gau + waybackurls    → Passive URL collection (Wayback, CommonCrawl, OTX)
katana               → Active JS-aware crawling
uro                  → Smart URL deduplication (removes same-pattern duplicates)
httpx                → Alive check + tech fingerprinting
sqlmap               → SQLi detection + exploitation (time-based blind, error-based, union)
```

## High-Value Enterprise Targets (Large Legacy Surface)

These programs have massive web surfaces with legacy CGI/PHP/ASP endpoints:

### Tier 1 — Mature Programs, High Payouts
| Program | Platform | Max Bounty | Surface | Legacy Likelihood |
|---------|----------|-----------|---------|-------------------|
| IBM | HackerOne | $10K+ | *.ibm.com (thousands of subdomains) | VERY HIGH — CGI scripts, old events sites |
| Microsoft | MSRC | $15K+ | *.microsoft.com | HIGH — legacy ASP.NET, old portals |
| Oracle | HackerOne | $10K+ | *.oracle.com | VERY HIGH — Java EE, legacy JSP/servlets |
| SAP | HackerOne | $10K+ | *.sap.com | HIGH — ABAP web, old portals |
| Cisco | HackerOne | $5K+ | *.cisco.com | HIGH — old product pages, support portals |
| Dell | Bugcrowd | $5K+ | *.dell.com | MEDIUM — old partner/support portals |
| HP | HackerOne | $5K+ | *.hp.com, *.hpe.com | MEDIUM — old support/driver pages |
| Adobe | HackerOne | $10K+ | *.adobe.com | MEDIUM — old marketing sites |
| Salesforce | HackerOne | $15K+ | *.salesforce.com | MEDIUM — legacy endpoints |

### Tier 2 — Growing Programs, Moderate Payouts
| Program | Platform | Surface |
|---------|----------|---------|
| Sony | HackerOne | *.sony.com — old product/region sites |
| Uber | HackerOne | *.uber.com — old admin/partner portals |
| PayPal | HackerOne | *.paypal.com — old merchant tools |
| Shopify | HackerOne | *.shopify.com — old admin endpoints |
| Airbnb | HackerOne | *.airbnb.com — old region-specific sites |

## What Makes SQLi Findings on Enterprise Targets Valuable

1. **Legacy code is everywhere** — Big companies have decades of web infrastructure
2. **CGI/PHP/ASP endpoints** are lowest-hanging fruit — often no ORM, raw SQL
3. **Subdomains matter** — events.ibm.com, partners.oracle.com, support.cisco.com
4. **WAF bypass is sometimes needed** — Cloudflare/Akamai protection, but legacy paths often bypass
5. **No exploit chain needed** — SQLi → data extraction = Critical, direct report

## Detection Strategy

### Priority Targets (ordered by SQLi likelihood)
1. `.cgi` scripts (Perl/C CGI — almost never parameterized, often raw SQL)
2. `.php` endpoints (especially old WordPress, Joomla, custom CMS)
3. `.asp`/`.aspx` endpoints (legacy ASP classic, old ASP.NET WebForms)
4. `.jsp`/`.do`/`.action` endpoints (Java legacy — Struts, old Spring)
5. `.pl` scripts (Perl web scripts)
6. `.cfm` endpoints (ColdFusion — notoriously SQLi-prone)

### Parameter Names to Prioritize
```
id, uid, pid, cid, nid, sid         — primary keys
user, username, name, email         — user lookup
search, q, query, keyword, term     — search functions
sort, order, orderby, sortby        — ORDER BY injection
filter, cat, category, type         — WHERE clause
page, limit, offset, start          — LIMIT injection
file, path, dir, doc, report        — file inclusion crossover
year, month, date, from, to         — date range queries
lang, locale, country, region       — localization queries
ref, source, campaign, affiliate    — tracking params
```

### sqlmap Optimization for Bug Bounty

```bash
# Fast scan (first pass — time-based only, 5s delay)
sqlmap -m targets.txt --batch --level=2 --risk=2 --technique=T --time-sec=5 --threads=10 --smart

# Deep scan (second pass — all techniques on suspicious targets)
sqlmap -u "https://target.com/page.php?id=1" --level=5 --risk=3 --technique=BEUSTQ --dbs

# WAF bypass
sqlmap -u "..." --tamper=space2comment,between,randomcase --random-agent

# Specific DBMS
sqlmap -u "..." --dbms=mysql   # or mssql, oracle, postgresql
```

## Integration with Injection Proxy Bridge

For exotic encodings (base64 params, JSON bodies, SOAP/XML), chain with:
```bash
cd ~/Desktop/BUGS/injection-proxy && source .venv/bin/activate
python3 proxy.py --detect "<captured_value>"
python3 proxy.py --profile profile.yaml --engine sqlmap
```

## Workflow

```
1. Pick target from Tier 1/2 list
2. Run: ./autosqli.sh <domain> [--deep]
3. Review findings in results/<domain>/sqli/
4. Verify manually (reproduce with curl)
5. If confirmed: /disclose or HackerOne submit
6. Move to next target

Time per target: 30-60 min passive, 2-3h deep
Expected hit rate: 1 in 5-10 targets for legacy endpoints
EV per Critical SQLi: $5K-$10K on enterprise programs
```
