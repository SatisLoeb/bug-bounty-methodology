---
name: target-selection
description: Triage scoring for upshift2, generalized from upshift's "TVL + executor pattern" to "seam strength + blast radius + disclosure path". 30-min scoring pass, 0-50 across 5 dimensions. Score 35+ engages. The core discriminator is whether the target HAS a high-value unowned seam -- not whether it has high value alone.
---

# Target selection -- does this target have an unowned seam worth a deep engagement?

## The candidate profile (generalized)

upshift's profile was specific: TVL>$50M + backend signs on-chain txs + executor wallet + contracts-audited-but-backend-not. The generalized profile keeps the *structure* and drops the DeFi specifics:

**Core pattern:** a high-value system with a clear seam between two review regimes, where the seam itself is owned by neither, and a reachable disclosure path exists.

The discriminator is NOT "is this valuable" (Aave is valuable and is a terrible upshift target -- one coherent discipline owns the whole hardened stack). The discriminator is **"is there a boundary here that two separate teams each assume the other handles."**

## Hard criteria for engagement

1. **Material value at stake.** Funds, user data at scale, infrastructure control, or a dependency that fans out to many downstream consumers. The blast radius must justify a multi-day immortal-mode engagement. (For bounty platforms, this is the program's max payout × realistic-acceptance; for direct disclosure, it is the harm-to-users × your conversion odds.)

2. **An identifiable seam.** Run SEAM-THESIS.md Phase 0 first. If the seam-location pass returns a no-seam verdict (one team owns the coherently-reviewed whole), this is not an upshift2 target -- route elsewhere. At least one boundary in `recon/SEAM-CANDIDATES.md` must score "none" on review-coverage.

3. **A reachable disclosure path.** Bounty program (H1/Bugcrowd/Cantina/HackenProof/Immunefi -- Immunefi is now permitted), OR security.txt / SECURITY.md / security@, OR a responsive maintainer/CTO/CEO, OR an upstream GHSA/CVE channel for libraries. No path → the findings have no home.

4. **NOT saturated by an automated reviewer on the class you'll hunt.** For SC-adjacent targets, run `~/arsenal/audit-lifecycle/bin/ai-bot-check.sh <owner/repo>` -- a v12/Olympix/Cantina-AI bot raises dupe risk on the classes it covers (access control, input validation, reentrancy, unchecked arithmetic). upshift2's seam-and-chain classes are largely orthogonal to those bots (they can't reach a cross-team handoff or a multi-finding chain), but adjust the mix if the bot is present.

## Triage scoring rubric (0-10 per dimension, 30-min pass)

`/upshift2 --triage <target>`. Total 35+ engages.

### Dimension 1 -- Seam strength (0-10) -- the upshift2-specific dimension

How clear and how unowned is the seam? This replaces upshift's "architectural mollesse".

| Score | Signal |
|---|---|
| 10 | Two visibly separate teams/vendors/repos/languages; published audit scope explicitly stops at the boundary; the handoff is documented but unreviewed |
| 8 | Two disciplines clearly present; boundary inferable from architecture; no review demonstrably covers the handoff |
| 6 | A seam exists but is partially co-owned; one team has *some* visibility across the boundary |
| 4 | Mostly one discipline with a thin seam (e.g., a single third-party integration) |
| 2 | Coherent single-team ownership with one minor external edge |
| 0 | No seam -- one discipline owns the coherently-reviewed whole |

### Dimension 2 -- Surface size (0-10)

How much reachable surface does the seam expose? (subdomains, routes, services, bindings, tools, dependencies)

| 10 | Large multi-service / multi-binding / multi-tool surface, 50+ reachable entry points |
| 8 | 3-4 services + 30+ entry points |
| 6 | 2-3 services + 15-30 entry points |
| 4 | 1-2 services + 5-15 entry points |
| 2 | Single service + <5 entry points |
| 0 | No reachable surface |

### Dimension 3 -- Privileged-actor / blast-radius concentration (0-10)

How concentrated is the authority on the far side of the seam? (the generalized "executor pattern")

| 10 | A single trust anchor (key/role/account/upgrade-authority/admin) controls the whole blast radius, no multisig/timelock/separation |
| 8 | Authority split across 2-3 actors but each is single-key |
| 6 | Authority behind a low-threshold multisig / weak quorum |
| 4 | Authority behind a reasonable multisig / proper RBAC separation |
| 2 | Authority behind multisig + timelock / defense-in-depth |
| 0 | No concentrated authority (actions are user-initiated only, no privileged plane) |

### Dimension 4 -- Review recency / drift (0-10) -- INVERTED

How much has accumulated since the last review of the seam's two sides?

| 10 | Last review >12 months ago, system shipped features since |
| 8 | 6-12 months, multiple post-review changes |
| 6 | 3-6 months, few changes |
| 4 | 1-3 months |
| 2 | <1 month |
| 0 | Currently under active review |

### Dimension 5 -- Disclosure / EV signal (0-10)

How likely is a substantive disclosure to land (paid or acked)?

| 10 | Active program with recent Critical-tier payouts, OR a maintainer with a strong GHSA/CVE acceptance history |
| 8 | Active program without recent payouts, OR strong direct-disclosure history (acked <14d) |
| 6 | No program but the team publicly engages security researchers |
| 4 | No program, no engagement, but well-resourced (VC/enterprise/foundation backing) |
| 2 | Indie / community-driven |
| 0 | Abandoned (no recent commits, no active team) |

### Total

| Total | Action |
|---|---|
| 40-50 | STRONG ENGAGE -- full immortal-mode session |
| 35-39 | ENGAGE -- standard engagement |
| 25-34 | PARK -- re-triage in 60 days |
| 15-24 | LOW PRIORITY -- only with spare capacity |
| 0-14 | DO NOT ENGAGE |

## Triage card template

`/upshift2 --triage` writes `~/Desktop/BUGS/<target>-recon/TRIAGE.md`:

```markdown
# upshift2 triage -- <target>

## Hard criteria
- [ ] Material value at stake: <what / how much>
- [ ] Identifiable seam (SEAM-THESIS Phase 0 ran): <the seam statement, 1 line>
- [ ] Disclosure path: <channel>
- [ ] Automated-reviewer check (if SC-adjacent): <ai-bot-check result>

## Scoring
- D1 Seam strength:                _/10  -- <why>
- D2 Surface size:                 _/10  -- <why>
- D3 Blast-radius concentration:   _/10  -- <why>
- D4 Review recency/drift:         _/10  -- <why>
- D5 Disclosure/EV signal:         _/10  -- <why>
- TOTAL: _/50

## Selected vector pack
<web2 | infra | crypto-lib | ml> -- because <seam statement points here>

## Verdict
<STRONG ENGAGE | ENGAGE | PARK | LOW | DO NOT ENGAGE>
```

## Anti-pattern: chasing value alone (the same trap as upshift)

A high-value target with a hard, coherent surface is NOT an upshift2 target. The methodology specifically exploits the *seam* -- the boundary two teams each assume the other handles. If the seam is not present (one discipline owns the hardened whole), the vectors will not produce, and immortal mode will burn a session against a wall. SEAM-THESIS.md Phase 0 is the gate that catches this BEFORE the engagement, not after 20 hours.

The mirror anti-pattern: a low-value target with a beautiful seam. The seam will produce findings, but if the blast radius and disclosure EV don't justify the depth, it is a teaching exercise, not an engagement. D1 high + D3/D5 low = PARK, not ENGAGE.
