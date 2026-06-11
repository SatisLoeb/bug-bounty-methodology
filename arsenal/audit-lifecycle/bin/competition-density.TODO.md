# competition-density.sh — known limitations & follow-ups

## Current state (2026-04-21)

Works for:
- **C4** — public report page parse extracts H/M finding counts when report is published
- **HackenProof** — best-effort HTML parse of hall-of-fame (often blank)
- **H1** — JSON-embedded metrics `resolved_report_count` and `total_bounties_paid` on public program pages

Doesn't work for:
- **Cantina** — page is client-rendered React SPA; HTML has no numeric metrics
- **Sherlock** — same SPA pattern
- **Immunefi** — anti-scrape + SPA

## Fix options

### Option A — Headless browser (Playwright / Puppeteer)
- Pros: works on all SPAs
- Cons: heavy dep (~300MB), slow (5-10s per query), needs Chrome
- Verdict: only worth it if competition-density becomes daily-use

### Option B — Reverse-engineer each platform's internal API
- Cantina uses `api.cantina.xyz` — test `/v1/competitions/<slug>`
- Sherlock uses `sherlock.xyz/_next/data/*` — public JSON in Next.js data blobs
- Pros: fast, no browser
- Cons: brittle (breaks on platform updates), per-platform effort

### Option C — Leverage existing platform integrations
- The `/gravedigger` skill already fetches Cantina submissions via manual workflow
- Extract the parser from there if it exists

## Recommendation

Start with Option B for Sherlock and Cantina (1-2h each).
Fall back to manual entry if parser breaks — the script should accept
`--manual-count N --manual-researchers M` flags for quick override.

## Manual override flags (to add)

```
competition-density.sh --platform cantina --submissions 104 --researchers 28 <url>
```

When platform API isn't scrapable, operator enters known values from dashboard.
Script applies verdict heuristic to the manual inputs.
