# Scope — {TARGET}

**Populated by operator at the start of engagement.** Referenced by `on-finding.sh --stage 1` when instantiating per-finding scope-check files.

---

## Program page URL

```
[paste the full URL of the program page on HackerOne / Immunefi / Bugcrowd / direct]
```

## In-scope assets (copy exactly from program page)

```
[paste the scope list — domains, contracts, repos, URLs]
```

## Out-of-scope (copy exactly from program page)

```
[paste the OOS list verbatim]
```

## Core Ineligible Findings (H1 standard — paste N/A if not H1)

```
- Theoretical vulnerabilities without proof of concept
- Clickjacking on pages with no sensitive actions
- Self-XSS
- Missing HTTP security headers (without demonstrated impact)
- SPF / DKIM / DMARC records
- Outdated browsers / libraries (without demonstrated impact)
- Social engineering / phishing
- Denial of service
- CSRF on unauthenticated forms
- Information disclosure of non-sensitive data
- Open redirect (without additional impact)
- Tabnabbing
- Known CVEs in third-party components (without demonstrated impact on the asset)
- Missing best practices in SSL/TLS configuration
- Missing Subresource Integrity (standalone)
- Use of known vulnerable third-party component (without PoC)
- Issues requiring unlikely user interaction or physical access
- Credentials found in credential dumps
```

## Program-specific notes

```
[any special rules: reward structure, disclosure timeline, contact requirements,
 triager reputation, known-issue list link, prior public disclosures, etc.]
```

---

## Status

- [ ] Scope populated (in-scope + OOS pasted above)
- [ ] Program page URL recorded
- [ ] Notes captured

When the three boxes are ticked, per-finding scope-check via `on-finding.sh --stage 1` can begin.
