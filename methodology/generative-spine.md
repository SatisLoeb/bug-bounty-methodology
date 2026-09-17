# Generative Spine — the half that earns (2026-09-17)

**Why this is now the front of the method.** The playbook documents the half that never made a dollar. Every
paid/confirmed win — ENS Chief, Decentraland, Upshift, Royco, RSK, Granite-A — came out of *generation*, never
out of a gate. The gates only ever *prevented* bad submissions; they produced no revenue. A method whose loss
function has only a precision term (the gates, the 3 axes, materiality) has the empty set as its optimum and
ratchets toward NO-GO. This document is the missing term's positive half: the organ that GENERATES attacks. It
runs FIRST. `finding-acceptance-standard.md` (the gates) is demoted to **stage 2 — validation of what this
stage generated**, never the method itself. The recall term is `recall-ledger.md`.

## Admission criterion — the WIN-SEED (symmetric to the corpse-rule, opposite sign)
The corpse-rule admits a **filter** when a finding died of its absence — it can only learn from losses, and a
generator cannot "die of its absence," so the corpse-rule structurally cannot birth one. The **win-seed** admits
a **generator** on the opposite warrant: **it PRODUCED a win**, or a recall-corpse proved I lacked it. A
generator's licence is *productivity*, not falsifiability-from-loss. Rule: **every paid or confirmed finding is
mined for the move that generated it, and that move is written here as a replicable generator** — before, or
alongside, mining the loss for a filter. If a win adds no generator here, half the lesson was thrown away.

## The primary loop — GENERATE before you filter
Per surface, BEFORE any gate runs: **produce N concrete attack-hypotheses that the dev did not imagine.** The
kernel is the 2nd Maxim, turned into a question you must answer in writing: *"what input / what state did the
author NOT consider here?"* Output = a written list of specific attacks to then execute and gate. **A surface
with zero generated hypotheses is UN-HUNTED, not clean** — it may not be filed as a NO-GO (see recall-ledger
discipline 1). Understanding the code is not the goal; it is the model you then attack.

## The generators (proven earners — each carries the win that seeded it)
These are **invention-prompts, not a checklist.** You never ask "does this surface match P1?" (that is a filter,
and it recreates the pathology). You ask the kernel question, and use these as scaffolding for *inventing* the
attack the author missed.
1. **Cold-blackbox re-engagement** — re-read as if never seen, no memory of prior passes; defeats the
   understanding=blindness trap. *Seed: ENS #92483 Critical Chief (3× cold re-read).* [[ens-critical-chief-cold-reengagement]]
2. **The edge-primitive / guarded-wrong-variable** — the guard exists and is correct but guards the variable
   ADJACENT to the one the attacker controls; hunt the unguarded sibling. *Seed: ENS (token authed, assignee
   not) / Granite-A (price genuine, not current) / RSK (binding correct, wrong log read).* [[edge-primitive-guarded-wrong-variable]]
3. **Seam-density selection (Phase -1)** — hunt where boundaries meet (signer↔app, off-chain↔on-chain,
   deployed-config↔code, pool↔error-path), not hardened core-math. *Seed: Upshift / Decentraland / Royco (all
   seam-dense SC).* [[feedback-seam-density-is-the-surface-selection-axis]]
4. **The sourcing-primitives P1–P9** used as GENERATIVE PROMPTS (each = "how would I invent an attack of this
   shape here?"), never as a match-menu. *Seed: RSK=P1 wrong-selection, Upshift=P3 authn-trusts-off-chain.*
   `seam-primitive-sourcing-map.md`
5. **Dirty-numbers** — attack with cents-carrying prices, non-divisible/prime amounts, mismatched decimals;
   round inputs are a silent false-negative for the whole precision class. *Seed: Granite floor-twice seizure.*
   [[feedback-test-in-dirty-numbers]]
6. **Differential-as-killshot** — same input, one variable flipped, opposite result → isolates the defect off
   the excluded thing and pre-empts the by-design/OOS reframe before it is raised. *Seed: Granite-A.*
7. **Become-the-actor (C0)** — the first hop that turns any owner-gated / privileged sink into an UNPRIVILEGED
   Critical (init-hijack, clone-front-run, _msgSender spoof, role-admin gap, storage-collision). Run on every
   privileged sink BEFORE writing OOS. *Composer; seeds the ENS migration half.*
8. **Breadth / surface-enumeration** — BEFORE going deep on the chosen core primitive, enumerate EVERY
   attack-surface class the target exposes (factory, vault/partner, adapter, cross-chain-transfer, off-chain /
   non-consortium message fields, governance, dust/rounding, …) and generate ≥1 hypothesis per surface. Depth
   without breadth is a structural generation-gap: you find nothing on the periphery because you never looked.
   *Seed: recall-corpse RC-01 — on Lombard I went deep on the mint core (P1/P4/P7) and missed 6 competition
   Mediums (ProxyFactory hijack, PartnerVault depeg, CLAdapter validation, cross-chain DoS, offchainTokenData
   interchange), all on surfaces I never enumerated.* [[feedback-method-was-all-filters-add-generation-and-recall]]

## The anti-recursion test (apply to this doc and every organ added anywhere)
For each organ ask: **does it OUTPUT attack-hypotheses (generator) or take a candidate and say yes/no (filter)?**
Only generators belong here. If a "generator" is really "run these 7 and check the box," it has decayed into a
filter — burn it and go back to the kernel question.

## The loop closes on recall
`generate` (here) → `execute + gate` (finding-acceptance-standard) → NO-GO **only with a kill-list** →
`recall-check.sh` confronts the kill-list with public findings → a **generation-gap corpse** (a bug I never
hypothesized) names a generator I was missing → that generator is added here under the win-seed criterion →
generate. The recall-ledger is what tells us whether this spine is actually widening generation or just
producing prettier NO-GOs. Watch that metric, not the gate pass-rate.
