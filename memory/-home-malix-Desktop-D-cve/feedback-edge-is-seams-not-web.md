---
name: feedback-edge-is-seams-not-web
description: "The operator's bug-bounty edge is SEAM-hunting (on-chain and web), not \"web only\"; don't pigeonhole"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: cfee37ae-4ecb-491d-b3d4-10fe89cccbc7
  modified: 2026-09-10T11:49:58.034Z
---

Do NOT characterize the operator as a "web/API hunter." Their paid and ranked findings are majoritairement ON-CHAIN:
Royco (reentrance EntryPoint, Medium, rank 1/782, $7,500 — SC), Decentraland #87537 (case-sensitive signer check,
Critical $18k — SC), Alphix (clean SC kill). LiFi (CI/CD) and StakeWise (web) exist too, but SC dominates.

**Why:** I mislabeled their edge as "web/API seams" and steered them to a "web tier"; they corrected me — the Royco
and Decentraland wins are smart-contract.

**How to apply:** Their real edge is the SEAM — the boundary where two systems/modules meet and no one owns the
invariant — which is on-chain (EntryPoint/AA, signature/auth verification, precompile/module boundary, V4 hook,
oracle input off-chain→on-chain) AS MUCH AS web/CI. Their playbook line "28 forteresses SC-core → zéro payé" means
the HARDENED CORE (AMM/vault math everyone audits), NOT smart contracts in general. Seam ≠ core. When picking a
target or tier, aim at the seams across all layers, not "the web tier." See [[feedback_report_no_self_flagellation]].

**REPEATED ERROR (2026-09-10, corrected by user twice now):** I invoked "28 forteresses SC-core → zéro payé" to
argue "Robinhood is a fortress, pivot away, SC doesn't pay." WRONG and the user snapped back: their PAID wins are
SC — Royco (SC), Decentraland (SC), Upshift (SC), etc. The line indicts the hardened CORE math, it is NEVER a
reason to walk from a target or from SC. NEVER again use "SC-core→zéro" (or "it's a fortress") as a pivot/walk
justification. A "core is hard" finding is not a verdict on the target — the SEAMS are a separate surface and the
wins live there. If I've hunted the core and it's hard, that means GO HARDER ON THE SEAMS, not "pivot." A pivot
must rest on "I hunted the SEAMS and they vent to OOS/Low with an EXECUTED artifact per seam," never on core-hardness.
