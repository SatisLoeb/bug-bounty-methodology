---
name: protocole-forteresse-v2
description: "Fortress-null HUNT protocol v2 (source of truth = repo file), supersedes MANIFEST-injective-funding-hunt.md"
metadata: 
  node_type: memory
  type: project
  originSessionId: 123dd578-164e-4675-8beb-aa21faeef483
---

The fortress-null **hunt** protocol is now `~/Desktop/BUGS/PROTOCOLE-FORTERESSE-v2.md` (written 2026-07-05, operator-approved). It supersedes `MANIFEST-injective-funding-hunt.md` as the reference hunt protocol.

Spine (fixed execution order, no hot choice): `CP1(+exit gate) → G2 breadth → [survivors] → G3 seam → G4 /darkside → CP5→7 verify → G8 PoC → CP9 compile → CP10 size → G11/G12 submit+log`. Seam (G3) runs **before** darkside (G4) because ≥3 audits = classics already dead.

The load-bearing v2 addition = **CP1 exit gate** (anti-sunk-cost floor): G2 list empty OR every G2 surface fails CP6-reachability → fortress dead, OUTCOMES line, leave, no re-entry until new code deployed on-chain. Guard-rail: the exit gate kills the target, NOT the obligation to pierce — "G2 empty" and "CP6 fails" are themselves verdicts requiring an executed artifact (else it's "gated → moving on"). See [[protocol-fortress-null-hunt]].

**THREE terminal verdicts (round-3, added 2026-07-05 from the first real engagement, LI.FI — NOT two):** BYPASS · NULL-FORTERESSE-GAGNÉ · **HARNESS-SUSPENDU** (surface reachable/CP6-passes but un-verifiable without an out-of-band capability — test-env/creds/session; prod-testing prohibited). A suspend is legal ONLY with a BUILT harness + the named missing capability + a re-fire trigger, else it's "gated → moving on" (Maxim-1 concession). A suspend keeps the fortress OPEN (armed), doesn't count as dead for the CP1 exit gate, and gets its own OUTCOMES row. Distinct from reachability-null: reachability-null = the TARGET blocks; suspend = YOUR capability is missing. NB: G3-Lieu-A (v2's centre of gravity) STILL un-validated — the LI.FI engagement read solo, no fan-out fired it.

Chain: `PROTOCOLE-sourcing-cibles.md` (day-0 GO/SKIP) → `PROTOCOLE-FORTERESSE-v2.md` (hunt) → `PROTOCOLE-dispute-post-soumission.md` (submitted → resolved). See [[lifi-delta-seam-earned-null]] (the engagement that produced the suspend state).
