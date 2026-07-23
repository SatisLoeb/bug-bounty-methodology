---
name: project-superform-v2periphery-executed-null
description: "Superform v2-periphery (Cantina bounty) = unprivileged-fortress, xseam executed-NULL, RE-SOURCE"
metadata: 
  node_type: memory
  type: project
  originSessionId: 028e7fa2-cdd5-4cb1-b8de-55850fc80cdf
---

Cantina bug bounty, **Superform v2-periphery** @ github superform-xyz/v2-periphery HEAD fedb03e (main).
EVM Solidity 0.8.30, ~11k LOC non-vendor. Crit/High = 50% USDC + 50% $UP (Base); Medium = $UP
discretionary; Low/Info = NOT rewarded. ~/Desktop/BUGS/superform-2026.

**Verdict: EXECUTED-NULL for an unprivileged attacker. NO-GO / RE-SOURCE. Zero PoC burned, zero
false finding.** 4 audit firms (cantinacode, GetRecon, 0xMacro, octane) + a mature
`security/security_properties.md` (Properties 1-11) + Chimera invariant fuzz suite = the low fruit is
gone. Reinforces [[feedback-check-prior-audits-and-competitions-at-intake]] and
[[feedback-hunt-dont-narrate-ev]] (fortress→different target, don't re-audit).

Product invariant: a SuperVault share = its live NAV, priced by the validator-attested PPS. Stored V
= `_strategyData[strategy].pps` in SuperVaultAggregator. Writers: `_forwardPPS` (onlyPPSOracle,
applies all 11 properties) + `updatePPSAfterSkim` (manager skim, self-scoped) + createVault init.
**Every PPS-consuming money-move (deposit/mint/requestRedeem/fulfillRedeem/skim) funnels the SAME
`_validateStrategyState` = isPaused + ppsStale-flag + time-expiry.** No unguarded sibling money-move
— the classic xseam shape is ABSENT. Claim path (withdraw/redeem) reads `averageWithdrawPrice` locked
at fulfillment, decoupled from live PPS.

xseam hunt = 6-agent MAP + 9-hypothesis DIG→adversarial-VERIFY workflow (24 agents, 1.5M tok). ALL 9
refuted at source:
- H1 bannedLeaves checked only on GLOBAL merkle path not strategy path (Aggr L1388 inside
  isGlobalProof) = the **intended remediation to Cantina 5.2.1**; strategy root is 100%
  manager-owned so ban-check there is vacuous by design (manager just omits the leaf). Intentional
  asymmetry, not a hole. Both paths manager-gated → OOS.
- H2 updatePPSAfterSkim bypasses P1-11 = dup of **0xMacro L-4** (manager delay/stale, acked "trust
  assumption") + M-1 (HWM). self-scoped, manager-gated.
- H3 deviation-skip when ppsStale: only lets a VALIDATOR-SIGNED pps land uncapped (trusted/OOS);
  store+clear atomic so no favorable-read window; ppsStale only role-settable.
- H4 SuperVault._canAcceptDeposits omits time-expiry that _validateStrategyState has = VIEW-only
  (maxDeposit/preview/convert); every state-changing path reverts PPS_EXPIRED. DoS-flavored, OOS.
- H5 fulfill bounds: upper bound theoreticalAssets=pendingShares*currentPPS hard-caps at fair value;
  avgRequestPPS only lifts the LOWER bound → manager self-DoS, never overpay.
- H6 ppsExpiration(strategy) vs maxStaleness(aggr): documented intended grace window; all writers
  trusted; single PPS scalar consumed identically = no differential stale read.
- H7 permissionless updatePPS submitter: nonce/replay = **Cantina 5.2.4 fix present & works**; digest
  omits config-version but neutralized by LIVE isValidator()+quorum reads; upkeep debit self-scoped.
- H10 escrow rounding: Σ maxWithdraw == escrow balance by construction (paired inc/dec); per-controller
  cap forbids cross-controller drain; only protocol-favorable dust.
- H-quorum snapshot race: isValidator + quorum read LIVE from SuperGovernor (no snapshot); removed
  validator's sig reverts INVALID_VALIDATOR.

**2nd pass — rubric-anchored AUTHORITY-FORGE re-hunt** (operator supplied the full sev/impact rubric;
[[feedback-map-severity-to-program-rubric]]). The trust exclusion has an in-scope DOOR: "bypass/forge/
SIMULATE privileged authority IS in scope", and the In-Scope Impacts name the manager/validator-facing
controls (merkle-hook, banned-leaf, timelocks, quorum). So the real frontier = can an UNPRIVILEGED EOA
forge/simulate manager/validator/governor authority. 10-target workflow (oracle-quorum-forge, merkle-
forge, manager-sim, timelock-bypass, upkeep-drain, share-mint, permanent-freeze, clone-init-hijack,
banned-leaf-crossrole, pps-misprice) → ALL refuted, `live:[] maybe:[]`. Every hook-exec entrypoint is
manager-gated; isMainManager/isAnyManager are pure storage reads with no forge primitive; session keys
manager-granted + 4337 binds strategy to op.callData; every propose* is role-gated and every finalizer
guards the no-proposal state; fund timelocks are `constant`; PPS is a PUSHED slot (not balance-derived)
so donation/inflation inapplicable; createVault only makes attacker manager of their OWN zero-TVL vault
(salt binds creator, CREATE2 deployer=aggregator). Merkle address-binding was CantinaCode 5.2.5 (fixed);
inspect≠build is Octane A1 (hook layer OOS); permanent-freeze is CantinaCode 5.2.6 / 0xMacro. Only NOVEL
notes = non-payable Low/Info (not rewarded): escrow IMPL lacks _disableInitializers (harmless minimal-
proxy target); EIP-712 digest omits validator-config-version (neutralized by live isValidator+quorum);
no cancelActivePPSOracleChange sibling. KEY reframe: the merkle/timelock/quorum controls exist to bound
TRUSTED managers, but every EXECUTION entrypoint is itself role-gated, so bypassing a control still
requires HOLDING the role (OOS) — no forge path lets an unprivileged actor SIMULATE the role.

**NUKE barrage** (2026-07-23): compiled scanners DEAD here — Aderyn compile-fails (bare-src, empty
remappings), Slither can't `forge build` (v2-core nested submodule v4-core fails + modulekit needs pnpm
node_modules, ungettable via git). Only Semgrep(Decurity 42 rules) ran → 12 hits, 0 corroborated, 0 high,
ALL benign (11 basic-arithmetic-underflow on 0.8.30 checked subs each with a prior guard e.g. Aggr:278
`block.timestamp-ts` gated by future-ts check L258, :380 gated by L379; 1 missing-assignment = `_roundId;`
no-op). Near-empty barrage ⇒ says nothing (covers only mechanical substrate). NUKE's 13-class NEGATIVE
SPACE (reentrancy/access-control/oracle/unchecked-call/delegatecall/call-order/erc20/sig-replay/randomness/
dos/flashloan/init/frontrun) == EXACTLY the worklist the 2 workflows already executed to null. No new vein.

Every candidate collapsed to: trusted-role (SuperGovernor/manager/guardian/validator all OOS),
validator-gated write path, OOS (oracle-latency/gas-grief/DoS-no-loss), or view-only. ValidatorBonding
conserves value across all transitions; SuperBank fully onlyBankManager+gov-merkle; Executor session
keys manager-rooted (validateUserOp binds strategy to executed calldata). Real edge (per [[xseam]]) is
the mechanism CHOICE — but here every mechanism's adverse trigger needs a trusted role. **Don't
re-audit on-chain periphery.** If re-sourcing Superform: off-chain validator/oracle infra, v2-core
hooks (the inspect()-vs-build() projection gap noted P2 but hooks are OOS), or a fresh un-audited drop.
