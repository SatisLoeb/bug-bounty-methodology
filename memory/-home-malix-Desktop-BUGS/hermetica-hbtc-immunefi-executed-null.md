---
name: hermetica-hbtc-immunefi-executed-null
description: "Hermetica hBTC (Immunefi $100K, Stacks/Clarity) — executed NO-GO; harness + ledger kept, re-open triggers named"
metadata: 
  node_type: memory
  type: project
  originSessionId: e07ea929-6b1e-4339-bda9-00fe2cca4e71
  modified: 2026-08-02T00:22:10.846Z
---

**2026-08-02. Hermetica hBTC, Immunefi $100K, Stacks/Clarity, SC-only scope. Verdict: NO-GO / NULL-COÛTEUX.**
Workspace `~/Desktop/BUGS/hermetica-fresh/` — full ledger in `notes/LEDGER.md`.

Deployer `SP1S1HSFH0SQQGWKB69EYFNY0B1MHRMGXR3J1FH4D`; 13 scope assets = its 13 contracts (Immunefi's table is
offset one row vs its own explorer links — match by deploy-txid suffix). TVL ~51 BTC, all in `reserve-hbtc-v1`.

**Why null (target property, not effort):** two audits with EVERY High/Medium Resolved (ineligible set is only
CA L-01, CA QA-01, CA L-06, GB I-4); accounting is a **virtual** `total-assets` var so donation/inflation is
structurally impossible; every conversion floors in the protocol's favour; PROTOCOL role held by contracts only,
old vaults de-registered. Decisive reachability fact: **`net-assets` (51.138 BTC) exceeds `deposit-cap` (50 BTC),
so every `deposit` reverts `err u103001`** — the only untrusted capital-entry path is shut.

**Reusable harness (the real asset):** clarinet **3.23.1** (system clarinet 3.6 is too old for Clarity 4
`as-contract?`) at `hermetica-fresh/bin/clarinet`, with `[repl.remote_data] enabled=true` = true mainnet fork,
driven by a plain node script via `@stacks/clarinet-sdk` (NOT `@hirosystems/...`, and skip vitest —
`vitest-environment-clarinet` dropped `getClarinetVitestsArgv`). `simnet.callPublicFn(..., sender)` impersonates
ANY principal, so real whales/owners are usable. `runSnippet` returns raw hex, not a ClarityValue.
See `poc/fork/attack2.mjs`. This pattern generalizes to every Stacks target.

**Executed, kept for re-use:** whale full exit (39.4% of supply) → deviation **0 bps**, so the 7bps guard does
NOT lock out large holders. `redeem` is permissionless but pays `claim.user`. Confirmed defect: permissionless
`fund-claim` force-settles a victim's claim and permanently kills their `cancel-redeem` (`err u103005` vs `ok`
control) — real but Low (victim gets full NAV; ~3.4bps/day). `redeem-many` uses `(ok (map redeem-internal ...))`
which genuinely returns `ok` wrapping errs, while its two sibling batch fns use `fold`+`try!` — latent
double-spend, but `fund-claim` funds the exact gross so no balance deficit is reachable.

**RE-OPEN TRIGGERS:** (a) owner raises `deposit-cap` above net-assets → deposit path becomes live again;
(b) `exit-fee` set non-zero, or any change making the vault hold less than the sum of funded claim grosses →
the `redeem-many` `map` bug becomes a real double-spend, submit immediately; (c) a new vault version deployed;
(d) a GUARDIAN is finally appointed (today NOBODY holds it, so every `disable-*` kill switch is dead code).

Method notes worth keeping: [[feedback-workflow-agents-coverage-not-verdict]] fired again — an agent claimed the
vault's 1,512 stray sats were "permanently frozen"; execution refuted it (they are claim #50's funded gross,
released by `redeem(50)`). Gate-4-before-reading paid off here: reading both audit PDFs first took ~10 min and
defined the whole eligible surface. See [[feedback-depth-is-an-edge-only-where-ore-remains]].
