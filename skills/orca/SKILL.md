---
name: orca
description: >
  Package-source ROUTING front-end for any target made of npm packages or GitHub repos (wallets,
  Electron apps, mobile binaries, SDK-backed dApps, web/desktop clients). Produces a routing PLAN
  that decides WHERE to spend audit depth before a single line is read, on the operator's two-axis
  maxim (Rule 43): NPM SOURCE is NOT DEPLOYED CODE, and a PUBLIC FORK is NOT a CUSTOM DEVIATION.
  Classifies every source package on (A) deployed-code vs SDK/library-upstream and (B) custom-to-org
  vs public-fork-of-a-standard, then routes each to the right depth and the right downstream skill
  (firmaudit / darkside Door A or C / extract / power / differential-fuzz) or to map-only. Carries a
  MANDATORY P0 verification gate: a routing plan is itself an agent output, so its load-bearing facts
  (the npm description, the actual repo, what is actually deployed) are verified by one WebFetch
  BEFORE "go". Invoke FIRST on any package/repo target, before firmaudit or darkside, to avoid
  spending days auditing source that is not the deployed artifact or a fork of a standard nobody
  deviates from. Trigger on "/orca", "route this package", "where do I start on this npm/repo target",
  or when handed a target that is primarily a set of @org/* packages or GitHub repos.
---

# /orca — package-source routing for npm / GitHub targets

> **No corpus hook by design (corpus-integration fix, 2026-06-23).** orca routes PACKAGES (deployed-vs-SDK, custom-vs-public-fork) — it does NOT use protocol-shape class-density. The downstream SC skill (firmaudit/mrrobbot/extract) pulls `corpus-query <shape>` once a target is routed to it; orca itself never needs it.


> Formalized 2026-06-22 from CLAUDE.md Rule 43 + the /orca Exodus test (operator's own methodology).
> This is the canonical version (these skills are new, never existed elsewhere); refine as you use it.

You are routing, not auditing. The deliverable is a PLAN: for each package/repo in the target,
where audit depth goes and which downstream skill receives it. The single failure this skill exists
to prevent is spending days at depth on the wrong artifact — source that is not what's deployed, or
a public conformance fork that has no canonical-deviation to find.

## When to invoke

FIRST, on any target that is primarily npm packages or GitHub repos: a wallet, an Electron/desktop
client, a mobile app, an SDK-backed dApp, a web client, a library suite. Run /orca before firmaudit
or darkside so they get pointed at the deployed artifact and the custom code, not at SDK upstream or
a standard's reference fork.

## THE MAXIM (Rule 43) — two errors this skill kills

1. **NPM SOURCE ≠ DEPLOYED CODE.** Finding a package's source on npm/GitHub is NOT finding the code
   that runs. The deployed artifact is the Electron `.asar`, the mobile binary, the on-chain address,
   the bundled web JS — not the pretty source tree. Rule 5 (repo ≠ deployed) applies at the PACKAGE
   level: source = map only; depth goes to the deployed artifact.
2. **PUBLIC FORK ≠ CUSTOM DEVIATION.** A package implementing a STANDARD (a JSON-Schema validator, a
   crypto primitive, a serialization codec, a parser) is a public CONFORMANCE implementation, not the
   org's custom logic. Auditing it as if it were a canonical deviation is wasted depth; it gets a
   differential-fuzz-vs-reference pass and a dup/GHSA check, never Door C.

## THE TWO-AXIS CLASSIFICATION (run on every package in the target)

**Axis A — deployed-code vs SDK/library-upstream.**
- `@org/headless`, `@org/sdk`, `@org/core`, `@org/kit` = ABSTRACTION / upstream. The org's product
  consumes it; the bug that pays is in how the DEPLOYED artifact uses it, not in the SDK source.
  → route DEPTH to the deployed artifact (asar / mobile binary / on-chain addr); SDK = MAP ONLY.
- A package that IS the deployed client/contract = deployed-code → eligible for real depth.

**Axis B — custom-to-org vs public-fork-of-a-standard.**
- A parser/validator/codec implementing JSON-Schema, a crypto primitive, a serialization format =
  public CONFORMANCE impl → **darkside Door A + DIFFERENTIAL-fuzz-vs-reference-lib + dup/GHSA note.**
  NEVER Door C (Door C is only for canonical-deviations from a standard's intended form).
- Code custom to the org (its own business logic, its own protocol glue) = the real custom surface →
  firmaudit / darkside Door C / extract / power as the seam dictates.

## ROUTING TABLE (axis-A × axis-B → where depth goes)

| | custom-to-org | public-fork-of-a-standard |
|---|---|---|
| **deployed-code** | full depth: firmaudit + darkside Door C + extract/power on the seam | differential-fuzz vs the reference lib + dup/GHSA; depth only on the org's deviations |
| **SDK / upstream** | map the API, route depth to the DEPLOYED consumer of the SDK | map only; the standard's own repo is not the target |

## P0 STEP-5 — the verification gate (MANDATORY, before any "go")

A routing plan is an AGENT OUTPUT. Verify its load-bearing facts BEFORE committing depth:
- Read the **npm description** and the **actual repo** of each package you classified.
- Confirm what is actually DEPLOYED (one WebFetch of the registry / the release artifact).
- Re-check each axis call against that primary source.

One WebFetch here corrects days of mis-routing. This gate is non-negotiable.

## THE EXODUS TEST (worked example — why the gate exists)

Two days of mis-routing, both fixed by one WebFetch of the npm registry:
- `@exodus/headless` was mis-read as "the client source" — it is an **SDK** (Axis A: upstream →
  the deployed Exodus client is the artifact, headless = map only).
- `@exodus/schemasafe` was mis-read as "custom un-ploughed code" — it is a **public JSON-Schema
  conformance fork** (Axis B: standard impl → differential-fuzz + GHSA, NEVER Door C).

The mis-routing came from trusting the package NAME/tree instead of the registry description. The
P0 gate (read the npm description + repo before "go") is exactly this lesson encoded.

## OUTPUT — the routing plan

For each package/repo in the target, emit one row:
`<package> | Axis A: deployed|SDK | Axis B: custom|public-fork | → ROUTE: <skill/artifact> | depth: full|differential|map-only`
plus the P0-gate verification note (npm description + repo confirmed) per row. Hand the
depth-eligible rows to the downstream skills (firmaudit / darkside / extract / power); mark the
map-only and SDK-upstream rows so no one spends depth there.

See also: CLAUDE.md Rule 43, Rule 5 (repo ≠ deployed), darkside Door A vs Door C.
