---
name: upshift2
description: Generalized seam-hunting methodology -- the upshift mentality applied to ANY high-value surface, not just DeFi off-chain orchestration. Encodes the cognitive machine that produced the Upshift Finance engagement (48 findings, 24h ack, 30h patches) and re-targets it at web2/SaaS, infra/cloud/supply-chain, crypto-libs/protocols, and ML/AI systems. The thesis: every high-value system has a SEAM between two disciplines, each audited to death on its own side, where ownership of the seam itself belongs to no one -- and the bug lives in the seam. Use for any deep engagement on a non-DeFi-SC target where the real attack surface is the boundary between teams/layers/languages. Vector packs are pluggable per surface; the 4-pass discipline, immortal mode, anti-inflation gate, and disclosure arc are universal. Upshift is the gold-standard reference instance.
---

# upshift2 -- Seam Hunting (the upshift mentality, generalized to any surface)

You are executing **upshift2** -- the generalized form of the `/upshift` methodology. Where `/upshift` hunts a specific DeFi shape (backend that signs on-chain transactions in response to off-chain events), `upshift2` extracts the *mentality* that made `/upshift` produce 48 findings on a $308M target and re-points it at any surface where the real vulnerability lives in a **seam** that no single discipline owns.

Read `REFERENCE-UPSHIFT-INSTANCE.md` once to see the concrete instance this abstracts from. Everything in this skill is `/upshift` with the DeFi-specific parts factored out and made pluggable.

## The one idea

> **Every high-value system has a seam between two disciplines. Each side is audited to death on its own. Nobody owns the seam itself. The bug lives in the seam.**

On Upshift the seam was *smart-contract auditors see the contract, web auditors see the frontend, nobody owns the off-chain→on-chain trigger*. That seam produced F1 ($308M unauth on-chain trigger) and W34 (executor credential in the public bundle) -- neither is in any single auditor's checklist because each auditor's checklist stops at the seam's edge.

The same structure exists everywhere:

| Surface | The two disciplines | The seam nobody owns |
|---|---|---|
| Web2 / SaaS / API | app devs ↔ auth/platform team | business-logic vs authz layer; tenant isolation; billing vs entitlement; client-trust vs server-trust |
| Infra / Cloud / Supply-chain | dev (app-sec) ↔ ops (infra) | build-time vs run-time; IAM intent vs effective permission; secret-in-CI vs secret-at-rest; IaC declared vs deployed drift |
| Crypto-libs / protocols | spec authors ↔ implementers | spec MAY/MUST vs impl; language-A binding vs language-B binding; constant-time *claim* vs actual; test-vector coverage vs edge inputs |
| ML / AI systems | ML team ↔ app/sec team | untrusted data vs privileged tool-exec; prompt boundary vs system prompt; RAG-content trust vs action authority; model supply-chain vs runtime |

`SEAM-THESIS.md` is how you *find* the seam on a target the skill has never seen. The vector packs are how you *exploit* it once found.

## What is universal vs what is pluggable

**Universal** (one encoding, every surface -- do not re-derive per target):
- `SEAM-THESIS.md` -- the procedure for locating the seam on any target
- `HUNT-METHODOLOGY.md` -- the 4-pass discipline (primary → expansion → mirror invariant → chain construction)
- `IMMORTAL-MODE.md` -- the 5 anti-stop guards; "solid = measured, not felt", with the three green signals parameterized per surface
- `ANTI-INFLATION.md` -- the honesty gate that makes findings *survive triage* (promoted to first-class here; it was implicit in upshift but it is what the upshift-package actually demonstrates)
- `DISCLOSURE-PROTOCOL.md` -- the 4-stage arc + kabayanerve voice + fortress framing, with a per-surface channel/EV calibration table
- `TARGET-SELECTION.md` -- triage scoring, generalized from "TVL + executor pattern" to "seam strength + blast radius + disclosure path"

**Pluggable** (one pack per surface -- load the one that matches the target):
- `vectors/WEB2-SAAS.md`
- `vectors/INFRA-CLOUD-SUPPLYCHAIN.md`
- `vectors/CRYPTO-LIBS-PROTOCOLS.md`
- `vectors/ML-AI-SYSTEMS.md`

Each vector pack mirrors `/upshift`'s `SURFACE-ATTACK-PATTERNS.md` structure: every vector is `what it is → executable detection kit → readback/observed-state step → instance example → generalization`. The detection kits are copy-paste-runnable, because executable kits are exactly what separated upshift from theoretical methodologies.

## The conveyor (every finding rides it, in order)

This is the operating floor from `~/Desktop/BUGS/CLAUDE.md`, instantiated for seam hunting:

```
seam-locate (SEAM-THESIS.md -- find the boundary nobody owns)
  → surface scan (the matching vector pack, all vectors in parallel = Pass 1)
  → 4-pass hunt (HUNT-METHODOLOGY.md, IMMORTAL-MODE.md guards at every "should I stop?")
  → PoC = OBSERVED state delta (never counterfactual) + money/impact-flow prefilter
  → ANTI-INFLATION gate (the 3 corrections: scope, magnitude, mechanism)
  → KILL-GATE Q1-Q10 → SEVERITY-COMMIT (floor before draft)
  → report-nerve (structure) + chill (voice, human-triager channels only)
  → D7 Chain-Proof + D8 Weight-Card + D9 Adversarial-Rebuttal (signed READY_TO_SUBMIT)
  → PREFLIGHT 22/24 → disclose (DISCLOSURE-PROTOCOL.md) → monitor → fortress
```

The lifecycle scripts under `~/arsenal/audit-lifecycle/bin/` are the source of truth and hard-block on gate failure -- `upshift2` does not replace them, it feeds them. `init-target.sh` is still the mandatory first action (CLAUDE.md Rule 38).

## Arguments

```
/upshift2 <target>                 # full engagement: locate seam → pick pack → hunt → disclose
/upshift2 --seam <target>          # seam-location pass only (SEAM-THESIS.md) → which pack to load
/upshift2 --triage <target>        # 30-min scoring pass (TARGET-SELECTION.md), 0-50
/upshift2 --pack <surface>         # print/load a specific vector pack (web2|infra|crypto|ml)
/upshift2 --reverify <target>      # re-run detection kits on an already-disclosed target
/upshift2 --fortress <target>      # fortress follow-up (post-ack engagement window)
/upshift2 --reference              # read REFERENCE-UPSHIFT-INSTANCE.md (the gold-standard instance)
```

## Phase flow

```
Phase -1: Lifecycle init        SKILL.md → ~/arsenal/audit-lifecycle/bin/init-target.sh
Phase  0: Seam location         SEAM-THESIS.md → which discipline-boundary, which vector pack
Phase  0b: Triage               TARGET-SELECTION.md → seam-strength score, GO/PARK/DROP
Phase  1: Recon                 /gravedigger phases 0-2 with seam hints (delegate, don't duplicate)
Phase  2: Surface scan          the matching vector pack, all vectors in parallel = Pass 1
Phase  3: Hunt (4-pass)         HUNT-METHODOLOGY.md + IMMORTAL-MODE.md guards
Phase  4: Verify live           re-run each finding's detection kit one more time before drafting
Phase  4b: Anti-inflation       ANTI-INFLATION.md -- scope / magnitude / mechanism honesty pass
Phase  5: Report                /report-nerve (+ /chill on human-triager channels)
Phase  6: Disclose              DISCLOSURE-PROTOCOL.md, calibrated per surface
Phase  7: Monitor               re-verification cadence on active disclosures
Phase  8: Fortress              DISCLOSURE-PROTOCOL.md stage 4
```

### Phase -1: Lifecycle init (mandatory first action)

```bash
TARGET_HINTS="upshift2-class seam-hunt <surface>" \
  ~/arsenal/audit-lifecycle/bin/init-target.sh <target>
```

`<surface>` ∈ {web2, infra, crypto-lib, ml}. This emits ROUTING.md and primes OUTCOMES.jsonl. Do not skip -- `preflight-mechanical.sh` refuses execution downstream if the lifecycle was never initialized.

### Phase 0: Seam location

Before opening code or running a single tool, locate the seam. Read `SEAM-THESIS.md`. Output: a one-paragraph statement of *which two disciplines meet on this target, and which boundary between them is owned by neither*. This statement selects the vector pack and biases every later pass. A target with no identifiable seam is a poor `upshift2` target -- say so and route to `/gravedigger` or `/mrrobbot` instead.

### Phase 1: Recon (delegate to /gravedigger)

Invoke `/gravedigger <target>` phases 0-2. Pass the seam hints so recon biases toward the boundary you identified. `upshift2` orchestrates; gravedigger executes. Do not duplicate its recon here.

### Phase 2: Surface scan (vector pack, all vectors in parallel)

Load the one vector pack the seam selected. Run all its vectors in parallel (separate Bash calls in one message where the kits are read-only). Capture per-vector output to `evidence/<vector>/`. This is Pass 1 of the hunt.

### Phase 3: Hunt (4-pass) -- IMMORTAL MODE

Read `HUNT-METHODOLOGY.md` and `IMMORTAL-MODE.md` BEFORE starting. The 4 passes (primary → expansion → mirror invariant → chain construction) are universal. You may not exit Phase 3 until all 4 passes complete AND the three immortal-mode green signals are *measured* (not assumed). The signals are parameterized per surface in `IMMORTAL-MODE.md`.

### Phase 4 / 4b: Verify live, then anti-inflation

Re-run each finding's detection kit against live state immediately before drafting (catches pre-emptive patches and flaky artifacts). Then run `ANTI-INFLATION.md` on every surviving finding: the scope correction (is it actually in-scope / actually reachable in prod?), the magnitude correction (is the dollar/impact number sourced and honest, not a naive grep over-match?), and the mechanism correction (is the chain real, or did you force two unrelated primitives into one story?). These three corrections are exactly what the upshift-package documents catching before any external send.

### Phase 5-8: Report → disclose → monitor → fortress

`/report-nerve` for structure, `/chill` for voice on human-triager channels. Then `DISCLOSURE-PROTOCOL.md`, calibrated to the surface's channel (bounty platform / GHSA-CVE / upstream maintainer / vendor). Monitor active disclosures; fire the fortress follow-up inside the 24-48h post-ack window.

## Skill orchestration

| Skill | When |
|---|---|
| `/gravedigger` | Phase 1 recon (delegate; pass seam hints) |
| `/mrrobbot` | Phase 3 if the target also has an SC/economic layer worth a deep adaptive pass |
| `/expand-surface` | Phase 3 stall -- if a pack produces <10 findings after Pass 2, check for a novel surface it doesn't cover |
| `/report-nerve` | Phase 5 -- structural rigor, all reports |
| `/chill` | Phase 5 -- voice pass, human-triager channels only (skip for GHSA-upstream / IACR / private-firm) |
| `/disclose`, `/immunefi-submit`, `/security-disclosure` | Phase 6 -- channel-specific formatting |

`upshift2` reads these as references and invokes them at the named phase. It does not duplicate their work and does not auto-orchestrate them mid-hunt.

## External gates (per finding, not duplicated here)

| File | Purpose | When |
|---|---|---|
| `~/Desktop/BUGS/KILL-GATE-TEMPLATE.md` | 10-question false-positive elimination | per candidate, before deep-dive |
| `~/Desktop/BUGS/PREFLIGHT-CHECK.md` | 24-point quality gate (min 22/24) | per finding, before submit |
| `~/Desktop/BUGS/CHAIN-PROOF-GATE.md` | D7 for auth-class findings | auth-bypass / IDOR / signature / token class |
| `~/Desktop/BUGS/WEIGHT-CARD.md` | D8 numerical anchor | severity ≥ Low with quantified impact |
| `~/arsenal/audit-lifecycle/templates/ADVERSARIAL-REBUTTAL.md` | D9 signed READY_TO_SUBMIT | every finding before preflight |
| `~/Desktop/BUGS/REPORT-STANDARD.md` | kabayanerve voice template | all report writing |

## Anti-patterns (forbidden by this skill -- inherited from upshift)

1. **"I found N findings, that's enough."** Pass 2-3-4 are mandatory. See IMMORTAL-MODE.md.
2. **"This target is taking too long."** Time is not a stop condition on a high-value seam target. The 8h timebox is for bounty-platform contests with high turnover, not seam engagements.
3. **"This bug is theoretical, skip it."** Wrong phase. theoretical-bug-kill applies at the SUBMISSION gate, never at hunt time. A theoretical finding may be a chain component or fortress-narrative ammo.
4. **"The system is well-built."** Verify with measured signals before declaring this (IMMORTAL-MODE.md Guard 4). If the per-surface green signals are not all measured, this is a guess, not a verdict.
5. **"This is trusted-actor, OOS."** Many "trusted-operator" dismissals are actually layer-boundary bypasses the trust does not cover. The upshift-package's own honest chain analysis shows how to *distinguish* a real trust-reduction argument from a forced one -- read ANTI-INFLATION.md before conceding.
6. **Inflation.** Forcing a bigger number / a bigger chain / a bigger scope than the observed evidence supports. The upshift-package caught itself three times (EIP-1967 slot misread, "$308M" two-distinct-keys, "$74M missing" mislabeled-field). ANTI-INFLATION.md exists so you catch it too -- BEFORE any external send, never after.

## When upshift2 does NOT apply

- The target has no identifiable seam (a single team owns the whole stack, audited coherently end-to-end). Route to `/gravedigger` / `/mrrobbot` / `/firmaudit`.
- The target IS a DeFi off-chain orchestration shape -- use `/upshift` directly; it is the specialized instance with the tuned 10 vectors.
- Bounty-platform contest with HM-only payout and high turnover -- standard 8h timebox applies; this is not seam-engagement economics.
