---
name: aztec-target-state
description: "Aztec Network bounty — pinned deployed commit, surfaces already closed, and the one unresolved thread"
metadata: 
  node_type: memory
  type: project
  originSessionId: 02e5b9fb-6981-4593-96d4-f509bd198ba9
  modified: 2026-08-06T19:53:39.792Z
---

Aztec Network (Cantina bounty, max $50k = 10% of funds affected, floor $10k). Worked 2026-08-06.
Local corpus: `~/Desktop/BlackBox/aztec/` — `l1-deployed/` (pinned), `ignition-contracts/`, `deployed/` (Etherscan sources), `audit-txt/` (all audit PDFs as text).

**Deployed pin (proven, 77/77 files identical to Etherscan-verified source):**
`AztecProtocol/l1-contracts@4da96e677b085fe529343fba33b82772c0bb1d4e` = Release v2.1.9, 2025-12-08.
NOT `aztec-packages` branch `next` (v6.0.0-nightly, 8 months ahead) — the bounty's own GitHub links point at `next`, which is a different artifact. Ignition/TGE side = `ignition-contracts@master`, byte-identical to deployed.
No in-scope contract is a proxy → not upgradeable, not pausable → cumulative-impact reward clause applies.

**Closed with executed evidence (do not re-spend time here):**
- Post-deploy drift on Governance/GSE: 8 months of upstream commits are *pure reformatting*. Semantically frozen.
- Drift on ignition/token-vaults: deployed ≡ repo master; the only diffs are a dead immutable, an unused error, `virtual` keywords, typos.
- FV blind spots checked: OZ `upperLookupRecent` is semantically identical to `upperLookup`; Governance flood gates are open on-chain (`allBeneficiariesAllowed=true`) so the FV's "strictly more general" abstraction matches reality.
- Six-surface parallel hunt + adversarial refutation: zero survivors.

**Scope table is stale — worth reporting to the program on its own:**
`Registry.getCanonicalRollup()` = `0x91fF8bbD…`, not the listed `0x603bb2c0…` (which is superseded but still holds ~9M AZTEC).
`getRewardDistributor()` = `0x555bAAc4…` (121M AZTEC), not the listed `0x3D6A1B00…` (holds 0).

**Unresolved thread (needs docs or the team, not more code reading):**
NCATP ("NoClaim", `claim()` reverts) can be emptied to its beneficiary via `ATPWithdrawableAndClaimableStaker(V2).withdrawAllTokensToBeneficiary()`, which reads only `hasStaked` + `WITHDRAWAL_TIMESTAMP` and never the unlock schedule. `upgradeStaker(version)` is `onlyBeneficiary` with no version constraint, so any NCATP holder can point at V2 (`WITHDRAWAL_TIMESTAMP` = 2026-01-16, already passed). 156 NCATPs hold ~19.6M AZTEC. Largest (`0xCc7A886e…`, 15.16M) already sits on V2 with allowance == balance and has NOT been drained in 7 months — which is the main evidence it is the *intended* exit path rather than a bug. Discriminating question is a design question, not a code one.

Reward math: AZTEC ≈ $0.0139. Cap saturates at $500k affected. Governance holds $10.99M, ProtocolTreasury $7.03M — those are the only pots where the $50k cap is comfortably reachable.

See [[deployed-code-not-head]] and [[recevability-gate-before-poc]].
