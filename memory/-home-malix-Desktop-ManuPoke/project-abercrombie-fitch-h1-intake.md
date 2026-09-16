---
name: project-abercrombie-fitch-h1-intake
description: "A&F HackerOne intake 2026-07-29 — NO WILDCARD (4 bare hostnames only), lead = hand-verified Android WebView bridge chain with a provably dead compensating control"
metadata: 
  node_type: memory
  type: project
  originSessionId: 39a5b3a4-4f73-4978-9b3d-9425d8f24dbd
  modified: 2026-07-29T21:25:53.282Z
---

**A&F HackerOne (`abercrombie_fitch_bbp`) — intake done 2026-07-29. NOT engaged (zero packets sent to
A&F beyond one unauthenticated GET per host during recon). Lead is static-only and NOT submitted.**

## Scope is FOUR BARE HOSTNAMES — no wildcard. Settled, don't re-derive.
Live H1 GraphQL + `arkadiyt/bounty-targets-data`: in-scope URL assets are verbatim `abercrombie.com`,
`hollisterco.com`, `corporate.abercrombie.com`, `anfcorp.com` — **no `*.`**. Controls: 168 of 33,890 H1
URL assets in that dataset DO carry a literal `*`, and `data/wildcards.txt` (3,424 entries) has zero A&F
hits across 2023/2024/2025/2026 snapshots. **Behavioural proof:** `corporate.abercrombie.com` was added
in 2024 as its own asset *while `abercrombie.com` was already in scope* — a no-op if bare domains covered
their subtree. Policy prose: `subdomain`=0, `wildcard`=0, `*.`=0.

⚠ **I initially read the two INELIGIBLE carve-outs (`nonmerchvendorprofile.anfcorp.com`,
`applications.abercrombie.com/`) as proof the parent granted subdomains. That inference was WRONG.**
A carve-out is not a grant. See [[feedback-carveout-does-not-prove-wildcard]].

⇒ The whole `*.anfcorp.com` corporate estate is OUT: franchise/wholesale istio portals, GlobalSCAPE EFT
(`mft*`), `vendorportal` WordPress, AEM `publish-abercrombie*`, GitLab, Apigee, PeopleSoft, PingFederate.
Mapped and parked in `~/Desktop/BUGS/anf-2026/`; only unlocks if the program answers the scope question yes.

## THE LEAD — Android WebView origin boundary (shared codebase, both apps)
Asset `com.abercrombie.hollister` / `com.abercrombie.abercrombie` — **1 resolved report each (2%)**.
Hand-verified in jadx + smali (not agent-reported — I read these myself):
1. Host allowlist is `StringsKt.contains(host, entry, ignoreCase=true)` — **substring, not suffix**.
   `C10255te.y = {hollisterco.com, .ca, .co, .cn}`; `NT2.w` is `indexOf(...)>=0` at smali. `.co` is a
   proper prefix of `.com`, so the effective rule is "host contains hollisterco.co".
   `hollisterco.com.attacker.tld` passes — no lookalike registration needed.
2. **The compensating host-rewrite is DEAD CODE in both apps.** Provider passes `Boolean.TRUE`
   (`aR1.smali` / `cR1.smali` line ~64); consumer guard is `else if (!c7628li3.a && …)`
   (`H0.java:330`, `C1033I0.java:387`). `!true` ⇒ branch unreachable. **This is the ESCAPED-guard, and it
   is what makes the finding payable rather than "configure it right"** — cf.
   [[feedback-findings-die-on-the-actor-not-the-mechanism]].
3. `B0.shouldOverrideUrlLoading` does **zero** host validation for http/https (only `startsWith http:`/
   `https:`/`mailto:`/`about:blank`, `endsWith pdf`). Allowlist consulted on the FIRST load only.
4. Payload: `H0.java:373 addJavascriptInterface(L0, "Android")` → `C7274kf` exposes
   `navigateNativeDeepLink(String)` reaching ~50 native routes (checkout, addPayment, payments,
   deleteaccount, signin) and `showOrderConfirmation` which string-concats into JSON
   (`"{\"orderId\":\"" + str + "\"}"`, C7274kf.java:77). Adobe MCMID appended **unconditionally** after
   the if/else (H0.java:342).

**DELIVERY — REFUTED BY EXECUTION 2026-07-29. NO reachable trigger today ⇒ hardening, NOT payable.**
I code-read `SplashScreenActivity:119` (`intent.getDataString()` raw → router) and claimed a co-installed
app could carry an arbitrary URL into the bridged WebView. **5 executed trials killed it**, cold AND after
completing onboarding to HomeActivity: `abercrombie://bag` and `://giftcards` → **HomeActivity** (not their
destinations); gate-passing http host AND its control twin → **both** `com.android.chrome/IntentDispatcher`,
identically ⇒ `gf0` never discriminates, the URL never reaches the `if (z2 && gf0) → WebViewActivity` branch.
0 beacons in every trial. Externally-supplied deep links are not honoured on this build.
Also runtime-confirmed: `WebViewActivity` NOT exported (shell uid 2000 → `SecurityException: not exported
from uid 10174`). **Lesson: the code-read delivery path was the un-executed hypothesis dressed as a
conclusion — exactly what the differential control twin exists to catch.**
[[feedback-trigger-reachability-is-payability-gate]] [[feedback-never-generalize-a-revert-claim-from-one-call-shape]]

**OPEN-REDIRECT HUNT ON abercrombie.com — EXECUTED, NEGATIVE (2026-07-29).** This was the last live
delivery hypothesis for the mobile bridge; it found nothing, so the Android finding stays NOT payable.
Reproducible negative space:
- **WAF blocks every non-browser client**: 403 (149 b, `vary: User-Agent`) on all HTML *and* on
  `/static/**` JS assets, for curl even with full browser headers. **3xx pass**, so `Location` probing works
  by curl, but endpoint *enumeration* requires a real browser session. Methodological note worth reusing.
- 27 redirect-ish query params on a live redirecting path (`/shop/us`) → target unchanged; the query is
  merely **preserved**. ⚠ My first detector substring-matched the canary anywhere in `Location` and fired
  27 false positives — **parse the Location HOST, never substring-match**.
- 14 classic redirector paths (`/redirect`,`/goto`,`/out`,`/r`,…) → all 403.
- 9 path-injection payloads on the one confirmed redirector (`@`, `%2f%2f`, `%00`, `%5c`, `%09`, `../`) →
  every 302 lands on the **constant** `https://www.abercrombie.com/shop/wd`; target is not input-derived.
- 26 JS bundles / 9.0 MB scanned in-page: **0** navigation sinks (`location.assign|replace|href=`) within
  300 chars of a query read, **0** redirect-ish params read from the query string.
- `customer.js` sinks `location.assign(r.redirectUrl)` ×2 and `location.assign(m.redirect)` (near `SIGN_IN`)
  are fed by **server responses**, not the query; no GraphQL `$redirect*` input variable exists in
  customer or checkout bundles.
- `originalStore` is derived from the path, not the query — not attacker-controlled.
POST-based redirects and marketing/email link handlers still not covered.
[[feedback-dedup-as-reproducible-negative-space]]

**AUTHENTICATED PASS (operator connected a session 2026-07-29) — STRONG CANDIDATE, NOT YET CLOSED.**
Stack tell: cookies `WC_AUTHENTICATION_*`/`WC_SESSION_ESTABLISHED` ⇒ **WebSphere Commerce** underneath.
The legacy WCS `URL=` param is a decoy — `/webapp/wcs/stores/servlet/<Cmd>?URL=` 301s to `/shop/<Cmd>?URL=`
and `AddressBookForm?URL=<canary>` lands on `/shop/account/settings/address?URL=<canary>`: **carried, never
honoured**. The real parameter is the modern one it bounced through: **`/shop/account/signin?redirectUrl=`**.
EXECUTED evidence:
- Anonymous fetch (`credentials:'omit'`, operator session untouched) of
  `/shop/account/signin?redirectUrl=https://example.org/canary` returns 200 with the **absolute external URL
  serialized 5× into the page HTML, including the JSON hydration state** (`"redirectUrl":"https://example.org/…"`).
  No rewriting. Same for `//example.org/canary` and `https://www.abercrombie.com.example.org/c`
  (host-prefix — which the *mobile* substring allowlist would ALSO accept).
- `customer.js`: **7** navigation sites (`location.assign|replace|href`) consume `redirectUrl`;
  **0** validation tokens (`startsWith` / `hostname` / `new URL(` / `.test(` / leading-slash) within
  −400/+250 chars of ANY of them.
**INCONSISTENCY RESOLVED — there is NO external-specific validation.** I briefly inferred one because an
external value bounced to `/shop/account` while a relative one did not. **The control killed that**: an
*internal* `/shop/bag` ALSO bounces to `/shop/account`. The real rule is "already authenticated ⇒ go to
`/shop/account`", except when the value is itself under `/shop/account/*` (then no redirect at all). The
value is echoed **unchanged in every single case** — never rewritten, never dropped, for
`https://…`, `//…` and the `www.abercrombie.com.example.org` host-prefix alike. Lesson, again:
[[feedback-never-generalize-a-revert-claim-from-one-call-shape]] — one call shape looked like a guard; the
control twin showed it was just the signed-in short-circuit.

**KILLED 2026-07-29 — `redirectUrl` IS validated on the document-navigation path. NO open redirect.**
The 5×-echo came from `fetch(credentials:'omit')`, i.e. a **subresource** request. On a real **top-level
navigation** (what a victim's click actually is) the server rewrites the value and adds the legacy `URL=`
twin as the tell of the rejection path:

| `redirectUrl` sent (top-level nav) | result | canary in DOM |
|---|---|---|
| `https://example.org/canary` | → `%2Fshop%2Faccount` + `URL=` twin | 0 |
| `//example.org/canary` (protocol-relative) | → `%2Fshop%2Faccount` + `URL=` twin | 0 |
| **`/shop/bag` (CONTROL)** | **survives unchanged, no twin** | — |

The control is what makes it a verdict: a relative in-site path passes through untouched, so the rewrite is
**input validation with an off-domain reject**, not a page that always forces its own default. Guard is not
a naive "starts with `/`" either — protocol-relative is caught.
⚠ **The operator's own screenshot was already the answer and I misread it**: I saw
`signin?redirectUrl=%2Fshop%2Faccount&URL=%2Fshop%2Faccount` and concluded they had arrived via an internal
bounce, because I assumed the `URL=` twin was app-generated. The twin is *added by the normalizer*. Read the
artifact the operator hands you before theorising about how they got it.
Residual (not exploitable, worth one line at most): navigation path normalises, fetch path echoes raw —
a real inconsistency, but a victim's click is a navigation, and the hydration state on the navigation path
contains 0 occurrences, so nothing downstream consumes the raw value.

⇒ **BOTH veins on this program are now closed: the Android bridge cluster has no reachable delivery, and the
open redirect that would have supplied it does not exist. NO payable finding. Don't reopen without a new
surface.**
**CLOSING TEST (operator, one action):** sign out → open
`https://www.abercrombie.com/shop/account/signin?redirectUrl=https://example.org/canary` → sign in →
record where the browser lands. Landing on `example.org` = confirmed open redirect **and** the missing
delivery primitive for the Android WebView-bridge chain (`shouldOverrideUrlLoading` has no gate).

**HARD BLOCKER — 9.15.2 is server-side VERSION-LOCKED.** App lands on
`com.abercrombie.feature.inappupdate.lockout.LockOutActivity`, which **intercepts the deep link before the
router dispatches** (top activity stays LockOut, no WebViewActivity in stack, 0 harness requests).
APKPure serves only 9.15.2/11.15.2; Play HEAD = **10.1.0 / 12.1.0**; third-party-mirror download blocked.
⇒ Whether the defect survives in HEAD is UNKNOWN and is the gate on the whole finding, not polish.
Get HEAD via Play-on-emulator (AVD `anf_poc` has `com.android.vending`+GMS) then `adb pull`, or from a
handset. [[feedback-diff-forward-to-head-not-just-scope-changelog]]

**Harness is BUILT and reusable** (`~/Desktop/BUGS/anf-2026/poc/` + `RUNTIME-STATE.md`): AVD `anf_poc`
(API 33 x86_64). Trick worth reusing — **`<name>.10.0.2.2.nip.io` wildcard DNS gives an attacker-shaped
hostname pointing at the emulator's host, so no root and no `/etc/hosts` edit is needed** to test a
host-allowlist bypass.

## Second target — `corporate.abercrombie.com` (2 reports, zero scope risk)
WordPress VIP; VIP contractually disclaims **customer** code. Custom namespace `anfco/v1`: 14 routes
registered with empty `args` (no validate/sanitize callback), unparameterised calls return **500**.
`GET /wp-json/anfco/v1/asset?asset_id=<small int>` → **302** into the Q4 Inc IR document store (archived:
24236, 24896). Sequential int is the access token; UUID dereferenced server-side. MNPI framing if staged
8-K/10-Q are reachable. **Archive-derived, NOT probed.**

## Economics — calibrate before spending
Fixed table: Low $250 / Med $750 / **High $2,500 / Critical $4,000**, and top bounty EVER paid = $4,000
(hard cap). 544 reports received/90d ≈ 6/day, $20,500 paid/90d ⇒ **~5% pay rate, $37.68 per report
received**. 56 resolved in 4 years. **Zero public disclosures** on either handle ⇒ dedup is unmeasurable.
Policy: brands share architecture, **file ONE report not two**; and known-CVE/scanner findings are
**pre-declared duplicates**. Policy also says private program — no public writeups.

## Dead (executed kills, don't re-derive)
Fastly takeover of `staging-nonmerchvendorprofile` (GlobalSign cert issued 2026-06-30 ⇒ name claimed);
all 97 CNAME targets resolve (no dangling); no DNS wildcard on either apex; GlobalSCAPE EFT CVEs are
admin-server:1100 only and **CVE-2023-40044 is Progress WS_FTP, a different product** — citing it is an
instant credibility loss; VIP blocks xmlrpc/wp-cron/brute-force/user-enum; the "Demandware Basic-auth
credentials" in both apps ship **empty** behind a dead branch (NOT a leak — do not submit).
iOS 383915209/339041767: `minimumOsVersion 18.0` vs public jailbreak ceiling 17.0.1 ⇒ **0 reports is an
acquisition moat, not an unclaimed field.** Android is the proxy for the same backend.

Artifacts: `~/Desktop/BUGS/anf-2026/mobile/{pkg}/STATIC-FINDINGS.md` + jadx/apktool trees (817 MB).
