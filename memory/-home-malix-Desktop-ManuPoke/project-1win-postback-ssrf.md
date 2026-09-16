---
name: project-1win-postback-ssrf
description: "1win H1 — F-004 blind SSRF via affiliate postback: SUBMITTED and CLOSED AS DUPLICATE #3643826. Program now 2-for-2 on duped HIGHs. One lead survives: the source-verification PRODUCT gate."
metadata:
  node_type: memory
  type: project
  originSessionId: b21e2ab0-0b36-418d-9c86-89dc0cf6159c
  modified: 2026-07-29T16:16:51.848Z
---

**1win (HackerOne) — F-004 postback SSRF: SUBMITTED 2026-07-26, CLOSED DUPLICATE (#3643826) by
howard13 ~2026-07-27.** $0. Workspace `~/Desktop/BUGS/1win-audit`.

**The program is now 2-for-2 on fully-executed HIGH findings closed as duplicates:**
- F-001 OAuth ATO on `1win.com` (the 91%-of-reports asset) → Duplicate #3328634, 48h.
- F-004 postback SSRF on `1w.run` (the 0-*resolved*-reports asset) → Duplicate #3643826, ~24h.

Switching to the uncrowded asset did NOT fix it. Treat 1win as a saturated program; do not
re-engage on the strength of a clean-looking surface alone.

**The bug (still technically correct, just not novel):** affiliate panel
`POST /api/v2/postbacks {id,url,event}` on `1w.run`. Validator RESOLVES the hostname and checks the
resolved IP (proven: `localtest.me` and `10-0-0-1.nip.io` both rejected with no dotted IP in the
string). Denylist covers IPv4 RFC1918 + `127/8` + `::1` but **omits `169.254.0.0/16`,
`100.64.0.0/10`, `fd00::/8`, `fe80::/10`**. Executed OOB proof: `GET /pb/<event_id>/373511893` from
`3.75.28.208` (AWS eu-central-1), `AHC/2.1` (Java AsyncHttpClient), macros server-side expanded.

**Why it died — the transferable lesson.** The `1w.run` scope row read **0 reports**, which was
taken as freshness. It is not: that column counts **resolved** reports. Zero resolved on an asset
added **2026-02** meant a slow queue with submissions already sitting in it, not virgin surface.
The dup came from someone who filed into that same queue first. See
[[feedback-report-count-distribution-picks-the-asset]] — that memory has been corrected, because
this engagement refuted its original evidence.

**Report quality was not the failure mode.** The submission closed every axis it could reach:
the three-case dispatcher-revalidation fork stated explicitly rather than hedged, the "dedicated
proxies" exclusion clause pre-argued, the blind-row severity self-assigned without inflation, the
save-time timing oracle refuted with measurements (207ms open / 174ms closed / 195ms blackholed,
overlapping ranges), the rate-limited targets flagged as unmeasured rather than silently dropped.
None of that reduces dup risk. Only calendar position does.

**What survives and is still worth something:**
- 94-route affiliate panel map (`evidence/session-20260726/`).
- N-001: cross-tenant isolation on the panel proven CLEAN with 2 controlled accounts + a positive
  control. Do not re-hunt.
- **B-001 — the one open axis.** The APK build pipeline (`/v2/links/{id}/apk`,
  `/v2/links/apk/{jobId}`; RCE row = $3000) is gated behind `verificationStatus=pending` /
  `apkAvailable=false`. That gate is a **PRODUCT gate, not a security gate** — it suppresses a UI
  component. A gate names the EXISTENCE of a control, never its strength; this one is testable in
  a single request. Evidence it is pre-controller: a nonexistent link id returns the SAME generic
  400 as an owned link, whereas every other route answers `errors.linkNotFound` — so link
  resolution never happens and the rejection is body validation, not authz. No 403 ever observed.
  Blocked on DTO field names, which live in the UI component `apkAvailable:false` suppresses.
  **`jobId` authz is separately OPEN** — it is a UUID, and N-001 covered link/source only.

**Untested leftovers:** `/v2/user/auto_withdrawal` tfaCode enforcement when the field is omitted
(needs 2FA on the test account); attribution re-binding via `coreAuthVisit` against an existing
funded player (`ffLastCookie:true` = last-cookie-wins by design). Already closed honestly:
`/tfa/disable` and `/profile/password` are password-gated; `/v2`-vs-`/v3` profile update is a field
addition not a guard gap; `coreAuthVisit` cross-origin CSRF closed (415 on text/plain forces
preflight, no ACAO).

**Live test-account artifacts:** partner key `lw55`, link id 3795025, sourceId 1024495, player
373511893. Test postbacks 306333/306334/306335 deleted.
