---
name: nuva-immunefi-no-go
description: "NUVA (Immunefi, Animoca RWA) closed NO-GO — two proven defects, wrong payer; the live EV is the session-gated web surface"
metadata: 
  node_type: memory
  type: project
  originSessionId: 4c7e8c64-208c-48a0-88d4-ad330b0b9f3d
  modified: 2026-07-31T20:31:15.450Z
---

NUVA (Animoca + Nuva Labs, Immunefi, max $40K SC / $20K web). Closed **NO-GO 2026-07-31**, 0
submissions. Workspace `~/Desktop/BUGS/nuva-audit/` (`CLOSE.md`, `recon/`, `poc/`).

Funds at risk are real: `nvPRIME` 0xC360…87D1 holds 6,777,211.66 PRIME @ $1.05 ≈ **$7.12M**,
`balanceOf == totalAssets` exactly. Not a phantom-TVL target.

**Solidity core is thin.** Standard OZ 4626, `_decimalsOffset()=12`. `YieldVault.convertToAssets`
is `pure`/identity, so any stale-rate thesis is structurally dead. wYLDS showing 333M shares vs
970 USDC is the RWA custody model, NOT a finding — do not re-chase it.

**Provenance: two PROVEN defects, unsubmittable.** Deployed module = `provlabs/vault v1.1.0`
(tagged 2026-06-04, ~2 months stale — pin it from the chain's own `build_deps`). #230 stranded
escrow: version-differential PoC green (v1.1.0 queue 1→0 stranded; fix a41548a 1→1 preserved) but
reachability DEAD (no untrusted `TotalShares` decrement). Liveness (#236+#257+#265 undeployed):
measured 7.9 µs/paused-vault/block permanent, $0.15/vault → $15K = 17.9% of a 4.42 s block.
**Wrong payer**: the bug is in the CHAIN module, NUVA's assets are a vault account + CosmWasm
proxy, and all three fixes are already merged upstream (deployment-lag, not 0-day). No
ProvLabs/Provenance bounty exists — only `security@provenance.io`, no rewards.

**The live EV is the WEB surface, and only it.** Full route map extracted from the manifest (in
`recon/WEB-SURFACE.md`): same-origin admin back-office + ~30 v1 endpoints. CORS refuted by
execution. Four angles HARNESS-SUSPENDED behind a Privy session that was declined —
`holdings/$addr`+`transfers/$addr` authn≠authz, AML enforcement location, `rpc/$chain` proxy,
admin BFLA. Probes are written and ready in `recon/WEB-CLOSE.md`; resume = provision the session.

Reinforces [[feedback-target-diet-is-the-binding-constraint]] and
[[feedback-scope-asset-dates-are-not-build-dates]]. See also
[[feedback-reachability-is-kill-gate-not-severity-modifier]] — both Provenance defects died on
that leg, not on mechanism.
