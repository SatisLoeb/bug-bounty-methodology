---
name: feedback-direct-disclosure-no-live-infra-probe
description: "Upshift = NDA+contract+KYC, live read/recon authorized; but NEVER fire an exploit on live — state-mutating PoC is ALWAYS fork-based"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: b884ca02-6db2-4efd-b25a-86eed5d163e8
---

CORRECTION (2026-06-24): earlier this session I inferred "direct disclosure ⇒ never probe the
target's live infra" after the operator interrupted one `curl` to `api.upshift.finance`. **That broad
inference was WRONG.** The operator later clarified: **they are under CONTRACT + signed NDA with
Upshift** — live web/API probing is fully authorized. The interrupt was about that one moment, not a
standing rule.

**Why this matters:** the over-broad inference fenced me out of the entire web/API surface (where the
prior engagement's *Critical* lived — the unauth API→on-chain operator-trigger) and made me file the
on-chain `getChangePercentage` cap-bypass as "operator-trust, low" instead of properly examining it.

**How to apply:**
- When the operator interrupts/declines ONE action, treat it as scoped to that action; if it changes
  the whole approach, ASK for the boundary rather than inferring a broad prohibition (AskUserQuestion).
- For **Upshift specifically**: authorized engagement (NDA + contract) — web/API/live-infra probing is
  in-bounds; recon need not be limited to on-chain/third-party.
- Still: probing a target's live infra is outward-facing — confirm authorization exists (here it does),
  then proceed. Relates to [[doctrine-surgical-reports-fight-to-the-end]].

UPDATE (2026-06-30): operator confirmed contract + **KYC'd with Upshift** + good faith proven → active
independent audit fully authorized. **The ONE invariant that never bends: NEVER fire a state-mutating
exploit on the LIVE production system** ("evidemment jamais d'exploit sur le live"). Live = READ/recon
only (GETs, OpenAPI diff, on-chain reads, doc mining). Every exploit / state-delta demonstration is
**fork-based PoC** (`vm.createSelectFork`, observed delta, zero mocks) — not for legal reasons but
because you never fire an exploit at a vault holding ~$260M real LP funds. **Live read = active ·
exploit = fork.** STANDING AUTHORIZATION (operator, 2026-06-30, verbatim "on touche tout ce qu'on
veut, autorisé à tout faire sauf exploiter une faille en live"): the engagement is FULLY authorized —
live on-chain reads (`cast call`/`cast storage`/EIP-1967 slot reads), live API recon, endpoint
enumeration, everything — with the SOLE exception of firing a state-mutating exploit on live (that
stays fork-based PoC). Do NOT ask per-read-action permission anymore; just don't exploit live. The
earlier per-action interrupts were that-moment scoping, now superseded by this standing grant. See [[doctrine-seam-rattachement-is-the-value]].
