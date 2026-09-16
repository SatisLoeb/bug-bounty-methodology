---
name: bugbounty-playbook
description: The operator's bug-bounty methodology (Playbook v1.4) — governs ALL security-research work; front-load receivability+materiality
metadata:
  type: feedback
---

The operator (Malik/SatisLoeb) hunts bug bounties by a personal Playbook (v1.4, 2026-08-25). It governs every security engagement. Full doc is the operator's; the load-bearing deltas:

**3 orthogonal axes** — a finding must pass all: VALIDITY (true/executed) · RECEIVABILITY (in-scope, non-dup, non-known-issue, right tier) · MATERIALITY (big enough at REAL deployed scale).
**Central lesson:** validity is never where it breaks — it breaks on receivability & materiality. So FRONT-LOAD those gates at Phase 0, before deep build.

**Why:** three-in-two-weeks (StackingDAO, wsts, StakeWise) = perfect technique, dead at receivability. Wasted best work on findings the gates would have killed day 1.

**How to apply:**
- Phase 0 go/no-go BEFORE deep work. Kill unwinnable targets day 1.
- SATURATION is the #1 no-go. Repo-saturation ≥60 → RE-SOURCE to a payable SEAM (web/API/off-chain), do NOT immortal-mode prove-null on an audited SC core. Track: 28 SC-core fortresses → 71% self-nulled, ZERO paid; every payout via a seam.
- The 5 Gates (run at intake, Gate 4+5 first): G1 actor-separation (attacker can CREATE+HOLD the precondition, from IN-SCOPE code not a deploy-script/fixture) · G2 escaped-guard > missing-guard (lead with a guard walked out of its invariant) · G3 stress the PREMISE first, incl. EXTERNAL-protocol premise closed in primary source · G4 dup/known-issue read in PRIMARY SOURCE for the EXACT sink (+ known-issues files & fix branches, not just grepping audits) · G5 materiality at deployed scale (magnitude ≠ mechanism; recense on-chain if impact needs a FORM).
- Entry-vector wall: under Primacy-of-Rules every hop crossing an unlisted asset is a wall; under Primacy-of-Impact only the impact LANDING must be in-scope.
- **Dup is the only uncontrollable parameter** — a dup means your finding was TRUE. Weight private-dup HIGH on over-audited/over-farmed programs. The controllable half = SPEED: clean 5/5 repro → submit (delay only raises exposure).
- A clean KILL closed in primary source BEFORE any fee is worth as much as a finding.
- Executed never asserted; primary-source read > summary > agent; conservative floors that invite verification; concede-the-just hold-the-clean.
- Shallow clone breaks the tombstone → `git fetch --unshallow` before relying on git history.

Applies to [[metronome-synth-audit]] (in progress): 4-firm-audited SC fortress → the play is the FRESH SEAM (Hemi/Base chain ports, pullOracle, cross-chain OFT/CrossChainDispatcher, v1↔v2 migration), never the audited core.
