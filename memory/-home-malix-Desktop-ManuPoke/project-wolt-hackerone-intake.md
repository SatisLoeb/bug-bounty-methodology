---
name: project-wolt-hackerone-intake
description: "Wolt HackerOne intake — GO-NARROW on cross-service authz of a single-issuer JWT; scope is 17 assets not 7; crowding hidden behind a suspended Intigriti predecessor (862 subs, EUR 79,618 paid)"
metadata: 
  node_type: memory
  type: project
  originSessionId: aa133eae-ffd9-4481-be07-c0925a4f8b9d
  modified: 2026-07-29T10:20:51.705Z
---

**Wolt bug bounty (HackerOne, public, launched 2026-07-27). Intake done 2026-07-29. Verdict GO-NARROW. NOT yet engaged — zero authenticated testing performed.**
Workspace `~/Desktop/BUGS/wolt-2026/` (TARGET-DOSSIER.md + recon/ + artifacts/).

**Scope correction (the pasted scope was partial):** 17 scopes, not 7. Includes a **bounty-eligible `*.wolt.com` WILDCARD (critical max)** — so `courier-api`, `daas-public-api`, `corporate-service`, `consumer-api`, `gatekeeper`, `imageproxy` etc. are all in scope — plus **4 Tier-1 mobile apps** (`com.wolt.android`, `com.wolt.courierapp`, iOS 943905271 / 1477299281).

**"0 resolved reports" is a trap, not a freshness signal.** Verified against a DoorDash control returning `11` via the same unauthenticated `hackerone.com/graphql` field ⇒ H1 does not suppress the count; Wolt's zero is real but the queue is 6 days old. The predecessor **Intigriti program is SUSPENDED with 862 submissions received / EUR 79,618 paid** and H1's policy carries a ~102-name "Legacy Hall of Fame ... previously on the Intigriti platform". Both platforms gag disclosure (`allows_private_disclosure: false`) ⇒ **zero public corpus ⇒ [[feedback-dedup-as-reproducible-negative-space]] is NOT EXECUTABLE here.** Say so in the report instead of papering over it. Tier-1 crit = EUR 3,500; Tier-2 = EUR 2,500; legacy decision SLA +3 weeks.

**Seam:** the mapping from "validly signed by authentication.wolt.com" → "may call THIS service as THIS actor class". No artifact expresses it: the IdP publishes **no OIDC discovery doc** (207-byte Werkzeug 404, triangulated ×3), Wolt's own published token carries `"aud": []`, `WOLT_AUTH_AUDIENCE: null` so the browser sends `?audience=wolt-com` as a **client-supplied query param at mint**, and ~30 services each hand-wrote their own edge (three different default `Access-Control-Allow-Origin` values; auth resolves AFTER routing on every host probed). Scope text says verbatim ×3 that a consumer JWT is accepted and merely "limited".

**Ranked (top 4):** 1) `POST ops.wolt.com/set-session-cookie` — Bearer→employee-session exchange, same issuer, clientId `opstools`. 2) `merchant.wolt.com/api/ops-tools/brand-logos/visibility/{env}/{country}` — PUT route, **read sibling `/brand-logos/fin` returns 200 + 91KB unauth**, and `staging` → 400 param error *before* the 401 ⇒ validation precedes authz. 3) `restaurant-api /v1/waw-api/user-permissions` — corporate grant oracle called from the CONSUMER bundle. 4) **courier plane — lowest dup in the program**, structurally starved (no courier accounts ever issued on either platform, and the program says "it would be very interesting if you can interact with the courier APIs without actually having a courier account"); route names require pulling `com.wolt.courierapp`.

**RoE, blocking:** `X-HackerOne-Research: <h1user>` on every request — *"testing without headers can result in the forfeiture of the eligible bounty"*. Signup alias `<h1user>@wearehackerone.com`. Designated test entities: user_id `670fa3e9ead6e49d65cc3614`, venue_id `670e7897e3c56dcc5b5a0989`, test venue `wolt.com/en/fin/helsinki/venue/test-670e7897e3c56dcc5b5a0989-sh0p` (real purchase unavailable). Courier + merchant accounts "Not available at the moment". "Mass creating of entities" excluded ⇒ hand-create ≤2 accounts.

**Open operator gates:** confirm handle `malikb31s`; SMS-verify the account or not (unverified may be grant-limited ⇒ false negative on the permission oracle); country choice must match the FIN test venue; scope ruling needed on `*.woltapi.com` (4 dev hosts hardcoded in PROD bundles) and on `unified-gateway.dashapi.com` (where ops' real authz lives — DoorDash already marked HARD BLOCKED in `~/Desktop/BUGS/doordash-recon/PHASE0-DECISION.md`).

**Kill condition (4 requests):** fresh consumer token decodes with a service-specific non-empty `aud` ∧ `/v1/waw-api/user-permissions` returns `[]` ∧ merchant visibility route returns the byte-exact 26-byte 401 ∧ `set-session-cookie` mints no real cookie ⇒ NO-GO. Do not proceed to cart/group-order IDOR on hope — the exclusion list shows the classic web classes were farmed across those 862 submissions.

[[feedback-report-count-distribution-picks-the-asset]] [[feedback-check-prior-audits-and-competitions-at-intake]] [[feedback-trigger-reachability-is-payability-gate]] [[feedback-read-both-or-clauses-in-exclusions]]
