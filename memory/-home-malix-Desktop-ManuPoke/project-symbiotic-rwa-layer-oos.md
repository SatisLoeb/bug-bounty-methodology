---
name: project-symbiotic-rwa-layer-oos
description: Symbiotic Cantina bounty — the fresh RWA/ll-adapter layer (all the good leads) is OUT-OF-SCOPE + undeployed; drafted Midas report is triple-dead. In-scope = 8x-audited core V2.
metadata: 
  node_type: memory
  type: project
  originSessionId: 3c399e15-ef33-40ad-abe1-f8688fee64f0
---

Symbiotic **Cantina bounty** (id `acca29a4-d405-4405-a3b3-8c3feb10d1e3`), **fixed-tier** reward
Critical $500k / High $100k / Med $10k — **NOT funds-at-risk/TVL-scaled** (so dust-TVL doesn't cap a
real bug), mainnet testing PROHIBITED (local PoC expected). Scope commit `symbioticfi/core@3b6add2…6e27`
(+ periphery/rewards/burners/hooks pinned commits). Folder: `~/Desktop/ManuPoke/symbiotic-intake-blind-2026-07-14`
(checkout HEAD = `7b400ed`, which is **NOT** the scope commit — 3b6add2 isn't even in its history).

**IN scope:** Core V1 + VaultV2, UniversalDelegator, WithdrawalQueue, AdapterRegistry, ProtocolFeeRegistry
+ adapters **Morpho / Aave / App / RestakingApp** only.
**OUT of scope (not listed):** ll-adapter, LiquidLane, MidasAccount, ALL RWA accounts
(Asseto/Securitize/Settlement/OpenEden/DigiFT/Superstate/EtherFi/Lido/Figure/Makina/Pareto/Noon/Gaib/Theo/ThreeJane/InfiniFi),
and **ThreeFAdapter** (even though ThreeFAdapterFactory IS deployed on mainnet). A catch-all clause lets you
submit unlisted "risk-to-user-funds" components *for consideration* — discretionary, not a guarantee.

**The trap:** the whole exciting fresh surface (Door-C negative space, NS-1 SUM-over-accounts, NS-2 VIRGIN
un-audited account families, the band-bypass generalization = STAGE1-INVENTORY "Stage-2" worklist) lives
**entirely in the OOS ll-adapter layer** AND is not deployed on mainnet. The drafted `REPORT-band-bypass.md`
(CutoffMidasAccount oracle band-bypass, 4 green Foundry PoCs at test/probe/L1_CutoffMidasRoundWalk.t.sol)
is **triple-dead**: (1) dup of Bailsec-mGLOBAL **Issue_06** [operator's own STAGE1-INVENTORY says so],
(2) OOS (ll-adapter), (3) MidasAccount not deployed on mainnet. **Do NOT submit; do NOT spend a workflow on Stage-2.**

**Mainnet reality (checked 2026-07-20, block ~25.57M, RPC publicnode/drpc):** only factories + 7 adapter
instances live — 4 Morpho / 2 Aave / 1 ThreeF. TVL = dust: Morpho[0]=0xAc57…dD17 totalAssets≈9.9e6 (6-dec ≈ $10),
all other Morpho/Aave = 0, ThreeF[0]=0xBfb1…fdC8 ≈ 5e5. System is pre-TVL/seed-stage.

**Only viable in-scope surface = the Morpho/Aave adapter valuation seam** (original intake thesis:
adapter.totalAssets ↔ external position → VaultV2 share price). Most-audited part (8 audits in folder/audits/).

**FINDING (2026-07-20 reopen, after operator reframed theft-only → full impact taxonomy):**
CONFIRMED in-scope **permanent vault-wide freeze** — green PoC at core/test/probe/AdapterViewRevertFreeze.t.sol
(2 tests pass; run `FOUNDRY_PROFILE=default forge test --match-path test/probe/AdapterViewRevertFreeze.t.sol`;
NOTE must first restore CheckpointsV2.sol from .slither-excluded/ or the project won't compile — operator's
nuke run moved it). Mechanism: MorphoVaultV2Adapter.totalAssets() (adapters/MorphoVaultV2Adapter.sol:59) calls
the bound Morpho vault's previewRedeem UNCAUGHT, though _allocate:92/_deallocate:114 try/catch every WRITE
(the fault-isolation asymmetry = the bug). Consumed uncaught by UniversalDelegator.totalAssets (:87-92) +
VaultV2.getAccrueInterest (:169); accrueInterest runs atop every deposit/withdraw/redeem. NO RECOVERY:
removeAdapter (:146) + forceDeallocate (:315) also call the reverting totalAssets, and _migrate is DISABLED
(VaultV2:482, UniversalDelegator:457). morphoVault bind is immutable (no setter, adapters/MorphoVaultV2Adapter.sol:139).
Trigger: bound Morpho vault's realAssets/previewRedeem reverts — Morpho's OWN vault-v2 source documents this
("LIVENESS REQUIREMENTS: Adapters should not revert on realAssets"; realAssets loops marketIds→expectedSupplyAssets,
reverts on bad market or gas-DoS). Same class on generic ERC4626Adapter (curator may bind any pausable/oracle vault).
**Severity RE-GRADED DOWN to Medium after deep Morpho fork-analysis (2026-07-20) — DO NOT inflate to Critical.**
The bound Morpho vault is "Gauntlet USDC Prime" 0x8c106EEDAd96553e64287A5A6839c3Cc78afA3D0 (USDC, $72.5M; Symbiotic
adapter 0xAc57…dD17 slice = ~$10; Symbiotic vault 0xDBDD…061d). It runs ONE MorphoMarketV1AdapterV2 (0xDF62…a22F)
over 7 markets ALL on the immutable-bound AdaptiveCurveIRM. Deep read (real morpho-org/vault-v2 source, sources in
scratchpad): **NO attacker-forced trigger (T-A) exists** — AdaptiveCurveIRM math is fully bounded/unchecked/saturating
(ExpLib.wExp saturates, no div0, oracle never touched on supply-accrual path), loop growth is allocator-gated, IRM
binding immutable (MMV1AdapterV2:184/213). Only triggers: T-B Morpho-curator adds reverting adapter (7-day timelocked
+ registry-gated + self-fixable), T-C multi-year dormancy (self-healing, anyone can poke), T-D gas-DoS (curator+allocator
-gated, needs 100s of markets; 7 today = ~200k gas trivial). So the freeze is real+permanent+no-recovery on Symbiotic's
side, but reachability = trusted-third-party/natural, NOT an unprivileged attacker → **Medium defensive-coding/integration
finding, not $500k Critical.** Honest framing: "Symbiotic consumes the bound vault's previewRedeem uncaught, inheriting
ALL of Morpho's documented liveness assumptions (VaultV2.sol:131-139 'Adapters should not revert on realAssets') with
zero isolation and zero recovery." NON-DUP (8 audits named revert-brick only on OOS ll-adapter). Aave path NULL.
Green mock PoC proves mechanism+no-recovery at Medium (test/probe/AdapterViewRevertFreeze.t.sol). A real-Gauntlet
fork PoC would demo T-B (curator-triggered) — un-built; would NOT raise severity.
**RESOLVED 2026-07-20 — DO NOT SUBMIT (operator rabat-joie, correct):** the finding has NO reachable adverse trigger.
My own report text convicts it ("not an attacker-drivable exploit... none of it a Symbiotic-side exploit"). All 3 entry
paths are trusted-role (Morpho curator, timelocked = governance risk, OOS on most programs) or non-triggerable external
conditions (Morpho gas-DoS / a bound vault reverting on its own). The green PoC proves PROPAGATION (IF previewRedeem
reverts THEN vault freezes) NOT REACHABILITY (an attacker causes the revert) — the mock's setRevertOnPreview(true) IS
the fabricated condition, the same trap as a fabricated price band. This is structurally identical to "F1" (a real
mechanism whose impact is conditional on an event I can't trigger/prove) → **it is a HARDENING, not a payable bounty
finding**; even "Medium/bank it" was wrong. The read/write fault-isolation asymmetry IS a real robustness defect worth a
COURTESY hardening disclosure to Symbiotic (out-of-bounty), but not a submission. To make it payable one must FIND a
non-privileged trigger that reverts realAssets/previewRedeem on the actually-bound vault — already deep-hunted and EMPTY
on the Gauntlet config (bounded IRM), so that's real new research with low EV, not a reformulation. Report file kept as
REPORT-adapter-view-freeze.md but flagged do-not-submit. Decision = RE-SOURCE. See [[feedback-trigger-reachability-is-payability-gate]]. Cheap within-scope re-source not yet done: in-scope symbioticfi/{periphery,rewards,burners,hooks}
repos (same $500k fixed-tier bounty) are UNEXAMINED (only core V1+V2 was swept) — but also heavily audited
(Statemind/OtterSec-Core&Rewards). Fresh external pick from prior triage [[project-cantina-nuke-triage-2026-07]] = Rheo
(Makina/Boros already exhausted). LESSON: the deep dive correctly LOWERED severity — exhausting the gate cut both ways
[[feedback-invariant-that-passes-is-not-a-finding]].

Also surfaced + KILLED by rigorous verify (don't re-derive): C1 no-HWM perf-fee = intended Morpho model;
C2 removeAdapter dust-grief = atomic multicall recovery; C3 RestakingAppAdapter freeAssets underflow = invariant
holds by construction (slash increments slashed BEFORE burn, reentrant-safe); C6 slasher cumulativeSlash = correct
by design (delegator-domain). See [[feedback-payable-impact-not-just-theft]], [[feedback-today-impact-before-poc]],
[[feedback-commit-anchored-scope-pays-deployment-impact]], [[feedback-execute-the-central-link]].
