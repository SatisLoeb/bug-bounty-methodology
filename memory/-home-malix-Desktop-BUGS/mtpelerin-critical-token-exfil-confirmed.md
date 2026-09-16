---
name: mtpelerin-critical-token-exfil-confirmed
description: "Mt Pelerin (Immunefi #88293) — CONFIRMED Critical session-token exfil via addrcb callback + substring token-attach seam; pipeline 3/4, awaiting Paid"
metadata: 
  node_type: memory
  type: project
  originSessionId: f717a0bf-10c1-4266-a602-aaf51119ad21
  modified: 2026-08-13T12:14:10.852Z
---

**Mt Pelerin F1 — CONFIRMED Critical, 2026-08-13** (Immunefi report #88293, submitted @MalikX31). Program does
NOT use Immunefi triage → the Confirmed verdict is Mt Pelerin's OWN call (100% de-risked on their side).
Pipeline `Reported→Escalated→Confirmed→Paid` now at **3/4**; next = Paid / reward assignment. Resolve SLA
deadline ~2026-08-26. Reward amount TBD (est. ceiling ~$5K Critical; p_bounty raised 0.55→0.85 on Confirm).

**The bug (seam class):** on the app.mtpelerin.com widget, the axios request-interceptor attaches the logged-in
user's session Bearer if the request URL merely *contains the substring* `mtpelerin`/`smex`/`localhost` (not a
hostname check), while the widget's `addrcb`/`txcb` callback URL is taken verbatim from the URL query with NO
host validation. The two halves disagree on "what is a Mt Pelerin host" → a callback `https://mtpelerin.evil.com/collect`
passes the substring test → adding a receiving address POSTs the user's token to the attacker. PROVEN: captured a
393-char HS256 JWT cross-origin from Origin app.mtpelerin.com, replayed against `api.mtpelerin.com/persons/findOne`
→ 200 (live KYC/PII) vs 401 without → Data theft. Delivery = crafted link to the REAL domain (`?addr=..&addrcb=..`),
victim just does the normal onramp add-address. Carefully pre-argued NOT phishing / NOT framing (checkAccess blocks
iframes) / NOT un-prompted-action. Closed-source, read from the deployed bundle `app~748942c6.efb2764d.js`
(interceptor ~253962, predicate `l` ~253036, addrcb/txcb ~124583).

**Doctrine now: HOLD.** Do NOT poke the program — let it ride to Paid; don't over-communicate (a confirmed
finding's verdict is set, silence protects it). This is the same seam pattern as [[doctrine-seam-rattachement-is-the-value]]
and the session-gated-web-ore thesis ([[ethena-web-immunefi-freesurface-null]], [[lombard-offchain-web-surface-map]]):
the PAYABLE web ore was behind an authed session, and hunting it there paid. Dossier: ~/Desktop/BUGS/mtpelerin-audit/
(findings/F1-token-exfil-callback-interceptor.md, submissions/F1-REPORT.md, local OUTCOMES.jsonl updated to confirmed).
