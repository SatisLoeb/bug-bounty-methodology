---
name: feedback-agent-fanout-recreates-audit-blindspot
description: Sharding a fortress into per-surface agents recreates the exact per-contract isolation that produced the audit blind spot; the composition bug has no owner among the shards — trace it yourself in one continuous context
metadata: 
  node_type: memory
  type: feedback
  originSessionId: fb8f7c07-c474-4041-b615-1c35f4e1ff79
---

Operator, on Kiln V1 (2026-07-04), after I ran a 12-surface + 8-cell breadth-map workflow: **"le découpage en agents recrée l'angle mort."**

A fan-out of N per-surface/per-cell agents is structurally isomorphic to N audits: each agent holds ONE contract/cell in isolation, and the SEAM between cells belongs to no agent. The bug that survives multiple audits lives precisely in the region no single reviewer owned (the composition ACROSS contracts) — so a per-surface fan-out reproduces the blind spot at a larger N, it does not pierce it. Even a dedicated "mirror-value / whole-system" agent is just one more shard, bounded by what one agent holds, competing with the others instead of composing them.

**Why:** The fortress axiom ([[protocol-fortress-null-hunt]]) says what survives ≥3 audits is not a class but an unowned composition / design-invariant / out-of-audit-reach component. Composition is found by a SINGLE continuous trace held in ONE context (POSTURE DE LECTURE: one wei, hop by hop, across ALL contracts, no hypothesis, let the anomaly reveal itself) — it is inherently NOT parallelizable, because the whole data-flow must live in one mind at once. A workflow is a BREADTH/coverage tool: it kills class-cells with artifacts and maps where the surfaces are (genuinely useful), but it cannot compose them. This is the tool-level version of [[feedback-apparatus-is-packaging-not-discovery]] and the reason [[doctrine-seam-rattachement-is-the-value]] exists.

**How to apply:** Use the workflow for BREADTH (coverage map, class-cell artifact-nulls, surface inventory) — never expect it to deliver the composition finding. After it maps, do the seam-trace SOLO: pick one unit of value, trace it end-to-end across every contract boundary the shards split, and name the ONE invariant that spans ≥2 shards' territory; ask if an untrusted actor breaks it. On Kiln that continuous trace (deposit→beacon WC=CLclone→dispatch→payout) closed the composition WITH artifacts (funded monotonic + removeValidators swap stays in unfunded region → funded validators permanently enabled → no freeze; feeRecipientImpl init-only → WC↔clone binding stable) that the 20 shards each gestured at but none owned. The seam gets an owner only when one context traces it whole.
