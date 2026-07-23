---
name: lifi-delta-seam-earned-null
description: "LI.FI CLOSED cleanly 2026-07-05 — SC delta + read-only surface earned-null; fee-config BFLA web-tier-only (SC-tier disconfirmed), harness parked"
metadata: 
  node_type: memory
  type: project
  originSessionId: 123dd578-164e-4675-8beb-aa21faeef483
---

LI.FI (Cantina $1M, 271 subs — SATURATED). Workspace `~/Desktop/BUGS/lifi-audit`. Re-entry 2026-07-05 over the prior June NO-GO, driven by a real 603-commit post-audit delta (clone was stale; re-cloned to `src/lifi-contracts-head` @ af18ac4, April snapshot kept at `src/lifi-contracts` for diffing).

**Earned fortress-null on the read-only surface** (all artifact-backed, in `_negative-results.md` Session 3 + `TRIAGE-CARD.md`):
- SC-classic: null (prior 2 sessions). SC-delta 4 new/changed contracts (IntentEscrowV2, OutputValidator, SupersetFacet, EcoFacet refund-asymmetry): null standalone — same confession-model as SC-classic (minimal on-chain validation, trust delegated to backend-calldata OOS / third-party settler not-in-src / "Diamond holds no funds" prior-null). IntentEscrowV2 V1→V2 = amount-math refactor only, F-003 unchanged. NEAR delta = comment-only.
- Backend-sig facets (Unit/AcrossV4Swap/NEAR): REFUTED — all bind receiver + callDataHash in the signed EIP-712 hash (read the typehashes). FeeCollector: SOUND (withdraw msg.sender-bound).

**Sole live lead = integrator fee-config BFLA seam (SUSPENDED).** The integrator fee-wallet is server-side config (portal.li.fi) baked as `integratorAddress` into every user's calldata → FeeCollector (confirmed via contractCalls quote decode). IF integrator A can write B's fee-wallet via a portal-API BFLA → cross-user fee redirection (on-chain impact, backend-generated, not self-crafted). On-chain leg sound; the vuln (if any) is the **portal config-write authz**. EV **web/portal-tier $2.5K-$25K** (steals integrator FEES not principal, so NOT $1M SC) — UNLESS the integrator config also holds a receiver/destination default (principal-redirect = SC-tier, unconfirmed). Harness spec in `recon/SEAM-STATEMENT.md`; **verification is prod-testing-prohibited → needs LI.FI test-env (program offers on request) or throwaway integrator accounts.**

**CLOSED cleanly 2026-07-05** (operator: "on close la target proprement"). SC-tier upside DISCONFIRMED read-only (CP5 on my own hypothesis): the integrator config is FEES-ONLY (fee-wallet + fee-% + integrator-string; NO receiver/routing/principal field, per docs.li.fi) → a fee-config BFLA redirects FEES not principal → web-tier $2.5-25K cap, NOT worth a test-env round-trip. Harness PARKED (`recon/SEAM-STATEMENT.md`). **Re-open ONLY on:** (1) a new deployed facet in src/, or (2) FREE authed portal access to run the parked fee-BFLA harness. Solo continuous-context read (no fan-out) was correct for the 1100-LOC delta — see [[feedback-agent-fanout-recreates-audit-blindspot]], [[protocole-forteresse-v2]]. This engagement produced the HARNESS-SUSPENDED verdict now encoded as v2's 3rd terminal state.
