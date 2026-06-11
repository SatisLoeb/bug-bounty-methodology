#!/usr/bin/env python3
"""
scope-parser.py — best-effort scope + OOS extraction from a program page.

Handles 3 common shapes of program page HTML:
  - HackerOne — section "Scope" + section "Out of Scope" with h3/h4 headers
  - Cantina   — structured JSON embedded in __NEXT_DATA__ script tag
  - Bugcrowd/Intigriti — h2/h3 "In Scope" / "Out of Scope" patterns

If the URL produces client-rendered content (SPA), parses whatever HTML is
available and annotates the output as "partial — populate manually."

Usage:
  scope-parser.py <url-or-file> --output <scope-check-path> --target <name>
"""
import argparse
import json
import re
import sys
from urllib.request import Request, urlopen
from urllib.error import URLError, HTTPError


def fetch(url_or_file: str) -> str:
    if url_or_file.startswith(('http://', 'https://')):
        req = Request(url_or_file, headers={
            'User-Agent': 'Mozilla/5.0 (scope-parser)'
        })
        try:
            with urlopen(req, timeout=15) as r:
                return r.read().decode('utf-8', errors='ignore')
        except (URLError, HTTPError) as e:
            print(f"ERROR fetching {url_or_file}: {e}", file=sys.stderr)
            sys.exit(1)
    else:
        with open(url_or_file) as f:
            return f.read()


def extract_h1(html: str):
    """HackerOne program page — look for scope table and OOS section."""
    scope_items = []
    oos_items = []

    # H1 embeds structured data in __NEXT_DATA__ or similar
    nextdata_m = re.search(
        r'<script id="__NEXT_DATA__"[^>]*>(.+?)</script>', html, re.DOTALL
    )
    if nextdata_m:
        try:
            data = json.loads(nextdata_m.group(1))
            # Walk the tree looking for "scopes" and "outOfScope"
            def walk(obj, results):
                if isinstance(obj, dict):
                    for k, v in obj.items():
                        if k in ('scopes', 'structured_scopes'):
                            if isinstance(v, list):
                                for s in v:
                                    if isinstance(s, dict):
                                        ident = s.get('asset_identifier') or s.get('identifier')
                                        if ident:
                                            results.append(ident)
                        elif k in ('outOfScope', 'out_of_scope', 'exclusions'):
                            if isinstance(v, list):
                                for s in v:
                                    if isinstance(s, str):
                                        oos_items.append(s)
                        walk(v, results)
                elif isinstance(obj, list):
                    for it in obj:
                        walk(it, results)

            walk(data, scope_items)
        except json.JSONDecodeError:
            pass

    # Fallback: HTML pattern — look for "Scope" and "Out of scope" sections
    if not scope_items:
        # Simple pattern: h3/h4 with "Scope", followed by list items
        scope_section = re.search(
            r'(?i)<h[234][^>]*>\s*(?:in\s+)?scope\s*</h[234]>(.+?)(?:<h[234]|$)',
            html, re.DOTALL
        )
        if scope_section:
            for li in re.finditer(r'<li[^>]*>(.+?)</li>', scope_section.group(1), re.DOTALL):
                text = re.sub(r'<[^>]+>', '', li.group(1)).strip()
                if text:
                    scope_items.append(text[:200])

    if not oos_items:
        oos_section = re.search(
            r'(?i)<h[234][^>]*>\s*out\s+of\s+scope\s*</h[234]>(.+?)(?:<h[234]|$)',
            html, re.DOTALL
        )
        if oos_section:
            for li in re.finditer(r'<li[^>]*>(.+?)</li>', oos_section.group(1), re.DOTALL):
                text = re.sub(r'<[^>]+>', '', li.group(1)).strip()
                if text:
                    oos_items.append(text[:300])

    return scope_items, oos_items


def extract_cantina(html: str):
    """Cantina competition page."""
    scope_items = []
    oos_items = []

    # Cantina embeds data in __NEXT_DATA__
    nextdata_m = re.search(
        r'<script id="__NEXT_DATA__"[^>]*>(.+?)</script>', html, re.DOTALL
    )
    if nextdata_m:
        try:
            data = json.loads(nextdata_m.group(1))
            # Walk for scope fields
            def walk(obj):
                if isinstance(obj, dict):
                    for k, v in obj.items():
                        if k in ('scope', 'inScope', 'in_scope') and isinstance(v, str):
                            scope_items.append(v[:500])
                        elif k in ('outOfScope', 'out_of_scope', 'exclusions') and isinstance(v, str):
                            oos_items.append(v[:500])
                        walk(v)
                elif isinstance(obj, list):
                    for it in obj:
                        walk(it)
            walk(data)
        except json.JSONDecodeError:
            pass

    return scope_items, oos_items


def extract_generic(html: str):
    """Fallback extraction — any HTML with 'Scope'/'Out of Scope' headers."""
    scope_items = []
    oos_items = []

    # Generic h2/h3 headers
    for match in re.finditer(
        r'(?i)<h[123456][^>]*>\s*(?:in\s+)?scope\s*</h[123456]>(.+?)(?:<h[123456]|$)',
        html, re.DOTALL
    ):
        for li in re.finditer(r'<li[^>]*>(.+?)</li>', match.group(1), re.DOTALL):
            text = re.sub(r'<[^>]+>', '', li.group(1)).strip()
            if text and len(text) < 300:
                scope_items.append(text)

    for match in re.finditer(
        r'(?i)<h[123456][^>]*>\s*(?:out\s+of\s+scope|exclusions?|not\s+in\s+scope)\s*</h[123456]>(.+?)(?:<h[123456]|$)',
        html, re.DOTALL
    ):
        for li in re.finditer(r'<li[^>]*>(.+?)</li>', match.group(1), re.DOTALL):
            text = re.sub(r'<[^>]+>', '', li.group(1)).strip()
            if text and len(text) < 400:
                oos_items.append(text)

    return scope_items, oos_items


def detect_platform(src: str) -> str:
    if 'hackerone.com' in src:   return 'h1'
    if 'cantina.xyz' in src:     return 'cantina'
    if 'code4rena.com' in src:   return 'c4'
    if 'bugcrowd.com' in src:    return 'bugcrowd'
    if 'intigriti.com' in src:   return 'intigriti'
    if 'hackenproof.com' in src: return 'hackenproof'
    return 'unknown'


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('source', help='URL or HTML file')
    ap.add_argument('--output', required=True, help='Output SCOPE.md path')
    ap.add_argument('--target', default='unknown')
    args = ap.parse_args()

    html = fetch(args.source)
    platform = detect_platform(args.source)

    print(f"[scope-parser] source:   {args.source}")
    print(f"[scope-parser] platform: {platform}")

    # Try platform-specific first, then generic
    scope, oos = [], []
    if platform == 'h1':
        scope, oos = extract_h1(html)
    elif platform == 'cantina':
        scope, oos = extract_cantina(html)

    if not scope and not oos:
        scope, oos = extract_generic(html)

    print(f"[scope-parser] extracted: {len(scope)} scope items, {len(oos)} OOS items")

    # Deduplicate preserving order
    scope = list(dict.fromkeys(scope))
    oos = list(dict.fromkeys(oos))

    with open(args.output, 'w') as f:
        f.write(f"# Scope — {args.target}\n\n")
        f.write(f"**Parsed from:** `{args.source}`\n")
        f.write(f"**Platform:** {platform}\n")
        f.write(f"**Auto-extracted:** {len(scope)} scope, {len(oos)} OOS\n\n")

        if not scope and not oos:
            f.write("⚠️ **Auto-extraction failed.** The target page is likely client-rendered (SPA) or uses a non-standard structure. Populate this file manually.\n\n")

        f.write("---\n\n")
        f.write("## Program page URL\n\n")
        f.write(f"```\n{args.source}\n```\n\n")

        f.write("## In-scope assets\n\n")
        if scope:
            f.write("```\n")
            for s in scope:
                f.write(f"{s}\n")
            f.write("```\n\n")
        else:
            f.write("```\n[paste the scope list — domains, contracts, repos]\n```\n\n")

        f.write("## Out-of-scope\n\n")
        if oos:
            f.write("```\n")
            for s in oos:
                f.write(f"{s}\n")
            f.write("```\n\n")
        else:
            f.write("```\n[paste the OOS list verbatim]\n```\n\n")

        f.write("## Core Ineligible Findings (H1 standard — paste N/A if not H1)\n\n")
        f.write("""```
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

""")

        f.write("## Program-specific notes\n\n")
        f.write("```\n[any special rules: reward structure, disclosure timeline, contact requirements, triager reputation, known-issue list link]\n```\n\n")

        f.write("---\n\n")
        f.write("## Status\n\n")
        if scope and oos:
            f.write("- [x] Scope populated (auto-extracted)\n")
            f.write("- [x] OOS populated (auto-extracted)\n")
        else:
            f.write("- [ ] Scope populated (requires manual review/edit)\n")
            f.write("- [ ] OOS populated (requires manual review/edit)\n")
        f.write("- [x] Program page URL recorded\n")
        f.write("- [ ] Notes captured\n\n")

        f.write("**Review the auto-extracted content above — fields may be incomplete or over-extracted.** ")
        f.write("Once verified, per-finding `scope-check.md` can be instantiated via `on-finding.sh --stage 1`.\n")

    print(f"[scope-parser] wrote: {args.output}")


if __name__ == '__main__':
    main()
