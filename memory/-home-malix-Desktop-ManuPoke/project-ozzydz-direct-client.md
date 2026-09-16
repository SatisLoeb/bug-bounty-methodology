---
name: project-ozzydz-direct-client
description: "ozzydz.com = DIRECT CLIENT (no platform scope), pre-launch static landing page; 7-finding report drafted 2026-07-26, not yet delivered."
metadata: 
  node_type: memory
  type: project
  originSessionId: ff50872c-50bf-48e8-bf35-807815464801
  modified: 2026-07-26T18:55:19.538Z
---

`https://ozzydz.com/` is a **direct client** of the operator — direct disclosure, no bounty
platform, no scope document. Engaged 2026-07-26.

Target = OzzyDz LLC (Wyoming), pre-launch landing page for *Ozzy*, an Algerian social-commerce
app (short video + live shopping + COD/CIB/Edahabia, launch summer 2026). Static HTML on
Hostinger, FR/EN/AR. Genuinely tiny surface: no backend, no subdomains (CT log = 1 cert,
ozzydz.com + www only), 487 bytes of JS.

**Report drafted, NOT yet delivered:** `~/Desktop/ManuPoke/ozzydz-fresh/RAPPORT-ozzydz.md`
(French, 7 findings). Artefacts in `ozzydz-fresh/recon/`.

Headline findings — the value was NOT in infra, it was in **site-says-X / site-does-not-X**:
- F-01 Critical: all 6 forms are `action="#" method="post"`. Executed: POST → HTTP 200,
  byte-identical body. 100% of waitlist + contact submissions silently lost since ≥2026-06-25.
- F-02 High: `privacy.html` §2/§3/§5/§6 + `terms.html` §5 assert collection/retention/erasure
  rights that F-01 proves don't happen.
- F-03 High: `.todo-note` dev notes rendered in production in 3 languages (deliberately styled
  amber dashed box in styles.css) — including an Arabic translation of the TODO.
- F-04 High: DMARC `p=none` with no `rua` (inert both ways) + SPF includes Hostinger only while
  MX is Google Workspace → legit mail survives on DKIM alone, so `p=reject` would BREAK their
  own mail until SPF is fixed. Fix order matters: SPF first, then quarantine, then reject.
- F-05 Medium: `ozzydz.dz` (the credible ccTLD for the Algerian target market) + 10 variants all
  unregistered.

**Did NOT send a spoofed email** for F-04 — offered a controlled test to a client-owned mailbox
on explicit consent instead. Keep that line if the client pushes for a live artifact.

**Negative space worth not re-paying:** `/.git/*` returns 403 not 404, which LOOKS like an
exposed repo — it is a server rule denying VCS directory names by exact match. Proof: `.svn/`
and `.hg/` also 403 while `.gitignore`/`.gitkeep`/`.github/`/`.gitzzz999/` all 404 (so not a
`.git*` prefix rule), and 8 bypasses (`%2e`, `%2e%67`, `%2f`, `//`, `./`, `../` traversal, case,
trailing dot) all held. Residual advice given: Hostinger hPanel has a Git-deploy feature, so
confirm server-side no `.git` sits in webroot — the HTTP rule is the only thing separating it.

**Why this one is a different shape from the usual corpus:** no code repo, no payout rubric,
no dup risk. The deliverable is business+legal impact ranked for the client's own launch
timeline, not a severity map. [[feedback-payable-impact-not-just-theft]]
[[feedback-manual-poke-mandatory-bracket]]

---

## PHASE 2 (same day) — ozzydz.com was NOT the real perimeter

Operator pointed at the Play app `com.pipo.ozzy`. Its listing's privacy-policy URL leaked a
**second domain**, and behind it the whole production stack that ozzydz.com never referenced:

- `api.joinozzy.com` — Django REST + SimpleJWT + Channels/Daphne behind an AWS ALB (51.44.94.222)
- `app.joinozzy.com` — Vite/React seller dashboard on Vercel
- `media.joinozzy.com` — Cloudflare, serves the app's legal docs
- App is **LIVE in production**: 9 stores, 20 products, real orders, public video feed — while
  ozzydz.com still sells a waitlist for "launch summer 2026" and never links to Play.

Second report: `~/Desktop/ManuPoke/ozzydz-fresh/RAPPORT-app-et-api.md`. Artefacts in `app/`.

- **A-01 Critical — RESOLVED in the authenticated pass, and it was NEITHER branch: BOTH payment
  rails are unconfigured.** `POST wallet/buy/ {"pack_id":"pack_30000","gateway":"stripe"}` →
  **HTTP 500 `Invalid API Key provided: sk_test_*******lder`** — Stripe masks the middle but leaks
  the tail `lder` = the literal string `sk_test_placeholder`. `gateway:"slickpay"` (the Algerian
  CIB/Edahabia rail) → HTTP 500, key rejected. Same on `subscriptions/initiate/`. So merchant subs
  (3000–7000 DZD/mo), `client_annual`, and wallet top-ups (`pack_30000` = 3000 DZD / 10 EUR) ALL
  return 500. Zero revenue possible on any rail; users see a server error. Frontend `pk_test_`
  key is real though — created `tok_1TxWZFGhAiI3POT1u5vDOU2S`, `livemode:false`.
- **A-07 NEW High — raw upstream exceptions echoed to any registered user.** Leaks the masked
  Stripe secret tail + mode, the internal env var name `SLICKPAY_PUBLIC_KEY`, and a hardcoded
  sandbox credential `57|74wHgIsMKIGomdIEgyBW5bSZ5Gw3vFYcfjPTF3wL`. **The code path is the defect,
  not today's value** — the moment a real `sk_live_` is set (i.e. fixing A-01), the same handler
  publishes the live key's mask. Fix A-07 BEFORE A-01.
- **A-08 NEW Medium — arbitrary permanent content storage under the brand domain.** presign is
  well built (server-generated key, extension allowlist, extension↔MIME cross-check, content-type
  in `X-Amz-SignedHeaders` → override gives 403 SignatureDoesNotMatch, 900s expiry, bucket not
  listable). But NO content validation: HTML body with the signed `image/jpeg` type → 200, served
  from media.joinozzy.com with **no `nosniff`**. NOT stored XSS — say so plainly; the MIME pin
  holds. Test object to purge: `posts/images/2026/07/43afac356ed04ca9a95d01fc461cbb12.jpg`.
- **A-02 High — two different data controllers for one product:** ozzydz.com = OzzyDz LLC
  (Wyoming); app legal docs = **EURL OZZY AUDIOVISUEL (Algeria, loi 18-07/25-11)**; Play dev
  account = `OzzyDz`. Fourth name "Shop Stream" only in the app's legal docs.
- **A-03 High — CHAINED with report #1.** App policy §6 routes loi-18-07 rights (art. 32/34/35/36)
  to a DPO at `contact@ozzydz.com` (decoded from Cloudflare `data-cfemail`) — the exact address
  whose form is dead (F-01) on a domain with DMARC p=none (F-04). Statutory rights channel
  silently discards every request. **This composition is the best finding of the engagement.**
- **A-04 Medium — unauthenticated `/api/products/` serves `revenue`,`orders_count`,`views_count`,
  `stock`;** `/api/stores/` serves `phone`(6/9)+`owner_username`+`total_orders_count`. Classic
  unguarded sibling: `products/my/` is 401, `products/` is not. Measured honestly: `revenue`=0.0
  everywhere TODAY (no volume yet) but stock/views/orders ARE populated → structural not yet
  voluminous. Say it that way; don't inflate.
- **A-05 Medium — `next` pagination links are `http://`** (missing SECURE_PROXY_SSL_HEADER behind
  the ALB) + **no HSTS on the API**. ALB 301s so bodies aren't served cleartext — but the initial
  request carrying `Authorization: Bearer` already went out in the clear. Cadre it precisely.

**API is the SOLID part — negative space:** 16/18 endpoints uniform 401, CORS strict allowlist
(evil.example gets NO ACAO), no /admin, no OpenAPI schema, DEBUG off, sourcemap 403, zero server
secrets in the 329KB bundle. Better built than the landing page.

**AUTHZ IS THE SOLID PART — six angles, nothing ceded.** Registration `role` is a strict
ChoiceField: only `client`/`merchant` (admin/staff/superuser/moderator all rejected). JWT carries
identity ONLY (no role/staff_role) so privileges are read from the DB. **No mass assignment**:
PATCH `users/me/` with `pi_balance:999999`/`staff_role:"admin"`/`subscription_status:"active"`/
`kyc_status:"verified"` all return **200 but change NOTHING** (DRF read_only_fields) — verified by
re-reading state, not inferred from the status code; `role:"merchant"` is an explicit 403. All
`admin/*` → 403 Administrator/Moderator required from a client account. No IDOR with a real store
UUID. CORS strict allowlist. **Do not re-audit this surface.**

**Test artefacts left on prod (documented in the report for the client to purge):** account
`sectest_audit_2026` / `loopt1793+ozzy-sectest@gmail.com` / id `dad40c57-54d7-429d-a734-f59eb71ecfe1`
(kept deliberately so the client can reproduce A-01), plus the 52-byte R2 object above.

## PHASE 3 — WebSocket layer done; APK BLOCKED

**Route-discovery oracle:** a real WS handshake to an unrouted path returns **HTTP 500**, a real
route returns **403**. That differential found `/ws/chat/<uuid>/`, which nothing else revealed
(the live feature is absent from the web bundle). Only 2 WS routes exist server-wide:
`/ws/notifications/` and `/ws/chat/<uuid>/`.

- **A-09 Medium — JWT only accepted in the WS URL query string.** `?token=<JWT>` opens;
  `?access_token=`, `?jwt=` and `Sec-WebSocket-Protocol` all 403. So the query param is
  mandatory, not optional → token lands in ALB/APM/proxy logs. Compounds with A-05.
- **A-10 Low-Med — 60/62 unrouted WS paths throw 500** (Channels URLRouter with no default
  route). Unauthenticated error-log/Sentry-quota amplification + the enumeration oracle above.
- **A-11 Observation — NO live-streaming backend exists.** No `lives/`/`streams/`/`broadcasts/`,
  no Agora/LiveKit/RTC token endpoint, no broadcast WS route — yet "live shopping" is a headline
  pillar on the site AND in the Play title ("Live Shop"). Phrase it as "not reachable on this
  API", not "doesn't exist" — a fully client-side third-party SDK can't be excluded without the
  APK.

**WS authz HOLDS (negative space):** joining a foreign `/ws/chat/<uuid>/` returns
`{"code":"not_participant"}` **and the socket closes with code 1000** — specifically verified it
does NOT linger in the group after the refusal (the subtle Channels bug). `/ws/notifications/`
takes no parameter, bound to the token's user. Anonymous → 403 on both.

**APK = BLOCKED, needs the client's artifact.** Play won't serve the APK without device auth;
public mirrors (apkcombo/apkpure/apkmirror) only carry **1.0.0 (2026-07-06)** while Play serves
**1.1.0 (2026-07-26)**. Deliberately did NOT analyse the stale unverified binary — would report
already-fixed defects. Report now formally requests the exact 1.1.0 AAB/APK.
[[feedback-diff-forward-to-head-not-just-scope-changelog]]

**Still un-run:** the **SlickPay webhook / wallet-crediting path** — unreachable until A-01 is
fixed, and the single most sensitive route in the product (unsigned callback, payment-notification
replay, non-idempotent crediting).

**Method note that paid twice:** verified before claiming, both times. `.git` 403 was a VCS-name
rule not a repo; the app policy's "[email protected]" was Cloudflare obfuscation not a broken
contact. Both would have been false findings. [[feedback-replicate-protocol-check-before-claiming-extraction]]
