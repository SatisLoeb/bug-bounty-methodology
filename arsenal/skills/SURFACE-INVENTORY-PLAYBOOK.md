# SURFACE-INVENTORY PLAYBOOK — enumerate EVERY surface at engagement start, before any hunt

**Mandatory first-phase step on every engagement. Produces `SURFACE-INVENTORY.md` in the target workspace — the living memory of every surface, in-scope and adjacent, with a status per surface that updates through the engagement. The completeness twin of `COVERAGE-LEDGER-PLAYBOOK.md`: the coverage-ledger enumerates in-scope FILES before a NULL-COÛTEUX close (end of engagement); THIS enumerates ALL SURFACES (web routes, hosts, endpoints, contracts, modules, off-chain seams) at the START, so no money-exit surface is ever silently left un-hunted.**

## The defect this fixes (Injective web, 2026-06-11 — the operator's catch)

Skills map the surfaces they intend to ATTACK, not the full surface set. On the Injective web engagement, the recon produced API-MAP / SEAM-STATEMENT / PROGRESS — rich, but each was an artifact of *where the hunt went*, not an exhaustive inventory. Result: 49 BFF routes were catalogued but only ~6 ever audited (authz→#134, faucet, custody, bridge-mint, referrals, mobile-IDOR); the other ~43 were listed-but-never-attacked. To find the virgin surfaces for a re-engagement, the operator had to ASK me to manually cross-reference the ledger and produce the list — work that should have existed from day one. **The hunt-driven map is incomplete BY CONSTRUCTION: it covers what you chose to chase. The inventory must be hunt-INDEPENDENT — enumerate everything first, then the status column records what got chased.**

The operator's directive (2026-06-11): *"au début de chaque engagement une étape où on cartographie automatiquement TOUTES les surfaces, dans un .md du dossier target, pour mémoire."* Auto-exhaustive (an agent sweep runs at init, not a stub the recon fills lazily — lazy = the incompleteness above). Perimeter = **in-scope + adjacent (flagged)** — the adjacent flag is what would have captured bff-api (hardcoded backend of the 5 listed apps, not itself listed) and the React-Native mobile surface from day one.

## WHEN it runs
- **Phase 0, automatically, before the first hunt.** `init-target.sh` writes the `SURFACE-INVENTORY.md` stub; the **Phase-0 surface sweep** (an agent fan-out) fills it exhaustively ONCE. This is hunt-independent — it runs before class-selection / before any finding.
- It is **not** the coverage-ledger (that runs at the END, before a NULL-COÛTEUX close, on in-scope FILES). Both exist; they bracket the engagement. Surface-inventory opens it, coverage-ledger closes it.

## WHAT to enumerate — by target class (enumerate ALL that apply; hybrid targets get every applicable block)

### Web / API targets
Cast the widest net; every row is one surface.
- **Every route / endpoint** — from: the typed API client in the JS bundles (grep the generated client tree, e.g. `cI(a)`/`ZU`/route-map objects), any OpenAPI/Swagger (`/openapi.json`, `/api/docs`), the lazy-loaded chunks (resolve content-hashed names from `__vite__mapDeps` / the live entry, then FETCH and grep them — do not stop at the entry bundle; the Injective mobile-auth lived in an off-disk chunk + an RN app), and live probing (sitemap, robots, common paths). One row per `{method, path}`.
- **Per route, record:** method · auth requirement (cookie/Bearer/none — read the auth interceptor regex) · body/params shape · whether it MUTATES state or only reads · the host it lives on.
- **Every host** — dedupe across all bundles: first-party APIs, BFF/backends, proxies, staging/devnet, third-party (custody, RPC, analytics, CDN). Flag each.
- **Every off-chain seam** — relayers, keepers, notifiers, faucets, signers, webhook receivers (where the backend holds a key / signs / fronts funds).
- **Native/companion apps** — React-Native / Expo / mobile bundles (Play/App-Store ids found in web bundles), desktop apps — these carry routes the web SPA only stubs. Flag as ADJACENT and note "pull from store to map."

### Smart-contract / chain targets
- **Every contract / module** — `find *.sol` / `find *.go` + `ls x/*/` (delegate the file-level rigor to `COVERAGE-LEDGER-PLAYBOOK.md`; the surface-inventory records each as a surface row with status).
- **Every deployed address** — proxies (EIP-1967 impl+admin), the live deployed surface (deployed code ≠ repo is its own surface).
- **Every cross-chain / bridge seam** — message handlers, attestation verifiers, relayers.

### Off-chain / infra targets
- CI/CD, container layers, dependency pipeline, RPC namespaces, admin panels, internal APIs.

## THE INVENTORY FILE FORMAT (`SURFACE-INVENTORY.md`)

```markdown
# SURFACE INVENTORY — <target>
> Generated: <date> (Phase-0 auto-sweep) · Last status update: <date>
> Perimeter: in-scope + adjacent (flagged). Status legend below.

## Scope anchor
<one line: what the program lists as in-scope, + the adjacency rule used>

## Surfaces
| # | Surface (method+path / contract / host / seam) | Class | Scope | Mutates? | Auth | STATUS | Artifact / why |
|---|---|---|---|---|---|---|---|
| S1 | POST /api/v1/bridge/notified | web-route | IN-SCOPE | yes | none | UNAUDITED | — |
| S2 | bff-api.injective.network | host | ADJACENT | — | — | MAPPED | hardcoded backend of 5 listed apps |
| ... | ... | ... | ... | ... | ... | ... | ... |

## Status legend
- UNAUDITED — enumerated, never probed (the virgin list — this is what a re-engagement reads first)
- IN-PROGRESS — currently being audited
- COVERED+artifact — audited, executed artifact exists (cite it)
- KILLED+reason — audited, no finding, executed disconfirmer (cite it)
- LIVE-FINDING — a finding came out of it (cite the report id)
- OOS — out of scope (quote the scope line that excludes it)

## Coverage summary
Enumerated: N · UNAUDITED: x · COVERED/KILLED: y · LIVE: z · OOS: w
```

## STATUS DISCIPLINE (the living-memory part)
- Every surface starts **UNAUDITED**. The status column is updated as the engagement proceeds (on-finding / kill-gate / null all bump the relevant row).
- **A re-engagement reads the UNAUDITED rows FIRST** — that is the entire point: the virgin-surface list exists automatically, no manual cross-reference needed.
- **Adjacency flag is load-bearing.** A surface that is not literally in the listed scope but is reachable through an in-scope app (a shared backend, a hardcoded host, an off-disk chunk, a companion app) is `ADJACENT`, NOT omitted. Adjacent surfaces are where scope-leverage findings live (bff-api → #134 rode the helixapp.com login into the "unlisted" backend). Mark them; let the kill-gate/scope-validator decide submittability later — never drop them at enumeration time.
- **You have NOT finished hunting while any IN-SCOPE row is UNAUDITED — no "engagement complete" / NULL-COÛTEUX close is legal until every in-scope surface has been attacked** (an UNAUDITED row is an un-hunted money-exit, exactly where the theft you're missing lives; same gate spirit as the coverage-ledger; adjacent UNAUDITED rows are allowed to remain but must be listed).

## RELATIONSHIP TO OTHER PIECES
- `COVERAGE-LEDGER-PLAYBOOK.md` — the END-of-engagement file-level completeness gate (SC files before a NULL-COÛTEUX close). Surface-inventory is the START-of-engagement surface-level map. Both mandatory, they bracket the engagement.
- `init-target.sh` — writes the stub + triggers the Phase-0 sweep (see lifecycle wiring).
- `firmaudit` / `darkside` / `upshift` — consume the inventory: they pick which UNAUDITED surface to attack next; they update the status column as they go. They do NOT re-enumerate.
- The Phase-0 sweep is auto-exhaustive (agent fan-out) per the operator's directive — token cost is a non-constraint; a silently-unmapped surface is the only cost that counts.
