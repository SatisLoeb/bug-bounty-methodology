---
name: decentraland-critical-decodeauthchain-confirmed
description: "Decentraland (Immunefi #87537) — CONFIRMED Critical case-sensitive signer check in decodeAuthChain (act-as-user); pipeline 3/4, KYC provided, awaiting Paid"
metadata: 
  node_type: memory
  type: project
  originSessionId: f717a0bf-10c1-4266-a602-aaf51119ad21
  modified: 2026-08-13T13:04:19.364Z
---

**Decentraland #87537 — CONFIRMED Critical, 2026-08-13.** "Case-sensitive signer check in decodeAuthChain
leads to state-modifying authenticated actions on behalf of other users." Pipeline
`Reported→Escalated→Confirmed→Paid` at **3/4**; **KYC provided 2026-08-13** (disbursement enclenched);
awaiting Paid. Immunefi report #87537, program = Decentraland.

**Mechanism (case-bug class realized):** the signed-fetch auth payload is `[method,path,ts,metadata].join(':')
.toLowerCase()` — fully normalized — but the downstream signer check in `decodeAuthChain` is case-sensitive
(reads raw). The normalization desync lets a signature be accepted for a different effective identity/resource →
an attacker takes state-modifying authenticated actions on behalf of another user = the top web/app Critical
tier. Direct realization of [[decentraland-casebug-class-immunefi-targets]] (payload lowercased, authz reads raw).
**Surface (per recon):** builder-server (builder-api) `decodeAuthChain` — the LEGACY `validateSignature` fallback
signs `(method+':'+path).toLowerCase()` (no timestamp, no metadata, no /v1 prefix), the weak divergent sibling of
the modern ADR-44 `verify`. NO local `findings/F*.md` file — drafted/submitted directly on Immunefi; the analysis
lives in `~/Desktop/BUGS/decentraland-immunefi-audit/recon/` (SEAM-STATEMENT.md = the crypto↔authz seam thesis,
SOLO-NOTES.md = the builder-server legacy-fallback trace). Distinct from F1 (comms-gatekeeper, OOS-Medium) and F2
(Estate updateOperator, Low).

**Two Critical confirmations in the payment pipeline now, both on the AUTHENTICATED web seam:** this + Mt Pelerin
[[mtpelerin-critical-token-exfil-confirmed]] (#88293, session-token exfil). Strong vindication of the standing
thesis — the payable web ore sits behind the authenticated session/signature seam, not the free surface
(cf. the free-surface nulls: [[ethena-web-immunefi-freesurface-null]], [[spark-web-app-immunefi-intake]],
[[lombard-offchain-web-surface-map]]). Both were hunted with upshift2/darkside seam methodology.

**Doctrine: HOLD.** Do NOT poke the program — a confirmed finding's verdict is set; silence protects it until Paid.
