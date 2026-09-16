---
name: feedback-webfetch-summarizer-truncates-immunefi-scope
description: "WebFetch's summarizer silently truncates long/paginated Immunefi scope pages; an asset-count mismatch is the tell — get the authoritative list (browser) before any OOS/GO call"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 225aa0fd-f40f-4d49-be74-cdfdb3270750
  modified: 2026-08-10T19:33:00.072Z
---

On Livepeer (2026-08-10) WebFetch TWICE reported "12 Arbitrum assets, no L1Migrator, no Mainnet/L1 group" and I nearly declared the operator's target (L1Migrator `0x2a69…`) out of scope. The RENDERED scope page actually lists **23 assets** including L1Migrator (added THAT DAY), BridgeMinter (`0x8dDD…B405`), LivepeerGovernor, Treasury, BondingVotes — a whole Ethereum-L1 asset group the summarizer dropped. The summarizer even printed "Total: 23 assets" while enumerating only 12; **I noticed the 23-vs-12 gap and rationalized it away instead of chasing it.**

**Why:** the scope/OOS verdict is the single highest-leverage Phase-0 decision (it gates weeks of work and whether anything is payable). Basing it on a lossy summarizer digest of a JS-rendered / paginated page manufactures a FALSE NULL — the exact "concede a gate you didn't exhaust" failure, applied to scope.

**How to apply:**
- For any Immunefi/bounty scope, get the AUTHORITATIVE asset+impact list — read the rendered page via the browser (`get_page_text` / a fresh tab on the scope URL) or the structured scope data. Never let a WebFetch SUMMARY be the basis for an OOS/GO call.
- Treat any self-reported total that disagrees with the enumerated count (23 said vs 12 shown) as PROOF the fetch is truncated — resolve it before concluding.
- An asset "Added on <today>" is a FRESH scope addition = uncrowded, high-p_bounty early surface. When the operator hands a target with a date, the date may BE the scope-add date (the signal), not just "today".

Links [[feedback-openapi-is-not-the-full-api-surface]] [[feedback-verify-before-working-no-theater]].
