---
name: royco-day-cantina-entrypoint-reentrancy
description: "Royco Day (Cantina $30K, closes 2026-08-17) — CONFIRMED HIGH via passing PoC. EntryPoint has NO reentrancy guard; attacker-supplied oracle poke() reenters executeDeposit before the escrow write; 2X pulled for X escrow"
metadata: 
  node_type: memory
  type: project
  originSessionId: ca8b34fa-8fd2-45f5-86fb-0070e17b52af
  modified: 2026-08-10T21:11:14.193Z
---

Royco Day private Cantina competition, commit `fa6d24971a5b1993e4d067fc223c85c8139346c0`,
repo cloned at `~/Desktop/BUGS/royco-day`. Scope = `src/` only. Pot is $7.5K if only Mediums,
$30K if any High. Mandatory coded PoC.

**Scope is only TWO payable impacts:** (A) funds to a non-whitelisted address / an address not
specified by a whitelisted one; (B) funds permanently locked. The carve-out "incorrect amounts
sent to whitelisted parties (reversible)" kills the whole classic value-extraction family —
rounding / share inflation / premium mis-accounting are all dead on arrival. Also OOS: oracle-NAV-
share-price *manipulation*, whitelisted parties acting maliciously, MEV, centralization.

**The finding (impact A, theft of commingled escrow):**
- `RoycoDayEntryPoint` has NO reentrancy guard anywhere (not in it, `RoycoUUPSBase`, `RoycoBase`,
  or `RoycoAuth`) — while the kernel uses `nonReentrant` on every mutating entrypoint.
- `executeDeposit` reads the request into MEMORY (`:170`), then makes an external call at `:175`
  → `_validateRequestExecution` → `_pokeOracle` (`:616`) → `oracle.poke()`, and only writes the
  escrow back at `:196-204`. Classic read-to-memory / external-call / late-write.
- `IRoycoPriceOracle.poke()` is NON-view (`IRoycoPriceOracle.sol:35`), so the oracle executes code.
- Reachability, all confirmed in the devs' own deploy scripts: market deployment is PERMISSIONLESS
  (`script/deploy/core/DeployCore.s.sol:113-118`, comment literally says "Market deployment is
  PERMISSIONLESS"), and ALL EntryPoint LP selectors are PUBLIC_ROLE
  (`script/deploy/core/DeployPeriphery.s.sol:99-107`).
- The deployer supplies `collateralAssetOracle`, validated ONLY by non-zero + `code.length > 0`
  (`MarketDeploymentValidationLogic.sol:120` → `:276-284`).
- A permissionless deployment auto-registers its own tranches on the SINGLETON EntryPoint with
  DEPLOYER-CHOSEN configs, because the factory holds ADMIN_ENTRY_POINT_ROLE:
  template `:442-445` → `RoycoFactoryGatekeeper.sol:86-103` → `modifyTrancheConfigs`.
- The EntryPoint commingles escrowed assets across ALL markets, so re-executing one escrow drains
  other markets' users' deposits.
- Key structural point: the reentry at `:175` happens BEFORE the kernel is ever entered, so the
  kernel's `nonReentrant` structurally cannot cover it.

**Why it is not a dup:** the whole EntryPoint postdates Hexens' audited commit `c006198`
(+1370/−0). The devs' own reentrancy probe (`test/mocks/MockReentrancyProbe.sol`,
`test/concrete/Tranches/Test_RedeemReentrancyWindow.t.sol`) fires from an ERC20 transfer hook
into the KERNEL, where `nonReentrant` catches it — the oracle-poke-into-EntryPoint sibling is
untested. There is also no invariant suite on the EntryPoint, the only contract custodying escrow.

**Framing risk to pre-empt in the report:** a triager may reflex "attacker-supplied oracle =
oracle manipulation = OOS." It is not price manipulation — the oracle is a REENTRANCY vector into
an unguarded periphery contract; no price is misreported and no NAV is misvalued.

Build note: `via_ir = true` + vendored Balancer monorepo ⇒ very slow, memory-hungry build
(~488 files). Never run `pkill -f "forge build"` — it matches its own command line and self-kills
(see [[feedback-verify-before-working-no-theater]]).

Related: [[feedback-agent-fanout-recreates-audit-blindspot]] (the sweep found the lead; I verified
every load-bearing fact myself), [[doctrine-defense-shadow-confession]] (their kernel-side
reentrancy defense named exactly where they stopped).

**STATUS UPDATE 2026-08-10: CONFIRMED via passing real-contract PoC.**
PoC: `test/concrete/EntryPoint/Test_PoC_EntryPointReentrancy.t.sol` + attacker oracle
`test/mocks/PoC_ReentrantOracle.sol`. Run: `forge test --match-path
test/concrete/EntryPoint/Test_PoC_EntryPointReentrancy.t.sol -vv` (via_ir build ~7min first time).
Observed: attacker escrows X=40e18 into JT; one executeDeposit pulls 80e18 (2X) from the commingled
EntryPoint pool; attacker minted 80e18 (2X) JT shares for X escrow; victim's 100e18 escrow
unrecoverable (cancel AND execute both revert). Disconfirmer test (oracle NOT armed) = single settle,
victim recovers fully — isolates the bug to the reentry. Real kernel/tranches/accountant/factory/
gatekeeper on the path; the only mock is the attacker's own oracle (= the permissionless
deployer-supplied payload, not scaffolding). 2 tests passed, 0 failed.

**PoC strengthened 2026-08-10:** victim is now an innocent SENIOR-tranche depositor while the
attack drives through the JUNIOR tranche — they share only the EntryPoint's commingled
collateral-asset balance (ST/JT deposit the same collateral). Removes any "victim chose the
attacker's tranche" objection; single-market instance of the general cross-market (singleton
EntryPoint commingles per-asset across all markets) case. Still 2 passed: 2X pulled for X escrow.

**Finding-2 (EntryPoint LP-whitelist laundering) = NO-GO, design-intent.** A sweep agent found that
the EntryPoint holds ST/JT/LPT_LP_ROLE + is PUBLIC_ROLE, so a non-LP address pulls collateral via
the EntryPoint (its own PoC test/concrete/EntryPoint/Test_ZQ_EPWhitelistBypass.t.sol passes). BUT the
audited commit had ENFORCE_TRANCHE_WHITELIST_ON_TRANSFER (canCall-based transfer whitelist); at HEAD
it is DELIBERATELY removed (empty _preTrancheBalanceUpdate hook, zero canCall in src/), leaving
blacklist/sanctions as the intended compliance boundary, which the EntryPoint honors. The LP-role
gate on DIRECT deposit/redeem is an access-channeling mechanism (funnel users to the front-running-
protected EntryPoint), not the compliance perimeter the scope's "non-whitelisted" language protects.
Dies on Kill-Gate Q1 design intent. Do NOT submit. Submitting finding-1 only.

Report drafted: `submissions/H-01-entrypoint-reentrancy-escrow-doublespend.md`.

**REACHABILITY GATE CLOSED 2026-08-10 (the key hardening).** The first PoC installed the evil oracle
via ORACLE_ADMIN.setCollateralAssetOracle + set the gate via ENTRY_POINT_ADMIN — the exact "admin
installed a malicious oracle = centralization/OOS" dismissal handle. Rewrote so the ATTACK uses ZERO
privileged role: (1) evil oracle installed via vm.etch at the kernel's wired oracle address (models a
market DEPLOYED with a deployer-chosen oracle; deploy is permissionless, oracle validated only
code>0); (2) gateByOracleUpdate=true applied through the REAL executeMarketDeployment invoked by a
ROLELESS address (setUp asserts the config landed on the singleton EntryPoint); (3) attacker + victim
are roleless (requestDeposit/executeDeposit are PUBLIC_ROLE; the EntryPoint carries the LP roles).
Only admin left = ambient protocol wiring (role graph + template enablement), exactly as DeployCore/
DeployPeriphery scripts, never in the attack. Both tests still pass (2X pulled for X). Gotcha: the
etched oracle needs a no-op setUpdatedAt/setPrice/setRevertMode surface or the fixture's
_warpAndRefreshFeed reverts. FactoryScaffold binds executeMarketDeployment to PUBLIC_ROLE (line 136),
mirroring DeployCore:118. Lesson [[feedback-reachability-is-kill-gate-not-severity-modifier]]: a green
PoC proves the MECHANISM; the admin-shortcut left the REACHABILITY leg unproven — that leg gates all
tiers, so I had to reach the same state with no admin before calling it ready.

**vm.etch REMOVED 2026-08-11 (operator caught it — the reachability proof was un-minted).** The etch
version proved "if this oracle were wired in, the attack works", not "an attacker can wire it in" —
the Hedera-01 un-minted-proof shape. Two verifications settled the fix: (Q1) the collateral oracle
IS a deploy parameter — MarketParams.collateralAssetOracle (template:166) → RoycoDayKernelInitParams
(template:538) → kernel initialize, routed by executeMarketDeployment (PUBLIC_ROLE); the admin
setCollateralAssetOracle only CHANGES an existing market's oracle. (Q2) the KERNEL inherits
ReentrancyGuardTransient (RoycoDayKernel.sol:26) + nonReentrant on every mutating entrypoint; the
EntryPoint inherits it NOWHERE — the unguarded-sibling shape, holds independent of the oracle install
path, now the report's spine. Fix: override the fixture's `_deployMarket` (all deploy helpers are
`internal`, reusable) with a verbatim copy, ONE line changed — construct a real PoC_ReentrantOracle
instead of MockPriceOracle, cast to the MockPriceOracle-typed state var (works: PoC_ReentrantOracle
now has the full read+no-op-setter surface). Kernel initialize bakes it in as the deploy param. No
etch, no admin. Both tests still pass (2X pulled for X). PoC_ReentrantOracle can't `extends
MockPriceOracle` because its poke() must be non-view (MockPriceOracle narrows poke to view; Solidity
forbids widening view→non-view on override). Report spine reframed: kernel-guarded vs
EntryPoint-unguarded sibling. Lesson: don't let a cheatcode stand in for the reachability leg when
the real deploy path is available — [[feedback-reachability-is-kill-gate-not-severity-modifier]].

**queueTrancheConfigs seam checked & closed 2026-08-11 (operator's last item).** Operator flagged
that setUp's `registrationTemplate.queueTrancheConfigs(...)` at line ~223 was called by address(this)
(no prank) — if role-gated, "no privileged role in the attack" would be partially false. Verified:
(1) `grep -rn queueTrancheConfigs src/ script/` = NOT in production — it is a TEST-ONLY function on
MockMarketRegistrationTemplate, an unguarded stand-in for the deployer-supplied
MarketParams.entryPointTrancheConfigs the REAL template reads from its own params; (2) it has ZERO
access control (plain external). So who calls it is irrelevant. Hardened anyway: wrapped
queueTrancheConfigs + executeMarketDeployment in vm.startPrank(ROLELESS_DEPLOYER)/stopPrank so the
whole deployer-side sequence is roleless — nothing left to squint at. The ONLY genuinely-admin step
in the registration is `registerTemplate` (RoycoFactory.sol:82, restricted=ADMIN_FACTORY_ROLE) =
template enablement, which is by-design (README: templates are admin-curated, then anyone deploys
through them); the attacker CONSUMES an enabled template, never registers one. Both tests still pass
(2X for X). Reachability leg fully minted. Operator's verdict: submit.

**SUBMITTED 2026-08-11 as Cantina finding #1.** Title: "EntryPoint reentrancy: a market's oracle
poke() double-spends commingled escrow". Severity submitted High (Impact High + Likelihood High).
Description = submissions/CANTINA-description-ready.md (report minus H1 + Severity line, those are
Cantina form fields). Secret gist attached in the report + description:
https://gist.github.com/SatisLoeb/6447ac909749ec64b8b105c3400a0f37 (README self-links its own URL;
2 PoC files byte-verified). QUEUE.jsonl row appended (status=submitted). Awaiting triage; competition
closes 2026-08-17. p_bounty ~0.5 (fresh post-audit code, clean CEI-on-escrow class, no design/trusted-
actor/incorrect-amount shape). When outcome lands: write OUTCOMES.jsonl row with
composition_skills_applied.

**OUTCOME 2026-08-11: DUPLICATE (valid High, reward TBD).** Judge (persimmon) marked finding #1 as
"duplicate of Finding" ~4 min after a shiv assign/unassign. Severity stands High (Likelihood Medium x
Impact High). This is NOT a rejection: Cantina COMPETITIONS have no first-to-submit priority (all
window submissions pooled; 44 researchers); a valid duplicate of a High SHARES the reward pool for
that cluster, finalized at close 2026-08-17. Dup is to a peer submission ("You do not have permission
to view this finding" = another competitor's private finding), not a "Known Issue"/prior-audit OOS dup
(which would not pay). LESSON: dup risk on a CLEAN, obvious bug in fresh post-audit code is structurally
HIGH in a 44-researcher competition — the more legible/strong the finding, the more likely others also
find it. Not contestable on timing. The EV was real (validated High, partial payout) but split N-ways;
for solo-max-EV, fresh-but-SUBTLE seams (the ones the swarm misses) beat clean-but-obvious ones.
See [[protocol-fortress-null-hunt]] (P(class-bug survives)~0) — here the inverse: P(clean-bug-is-unique
in a big comp)~low.

**2ND-FINDING HUNT 2026-08-11 (nullguard) — MEASURED near-exhaustion, RE-SOURCE.** Re-attacked Royco
for a distinct in-scope finding. nullguard reset: "Royco saturated" was repo-level (rejected); the
core is FRESH post-audit (low saturation). Executed veins:
- V-01 waterfall-brick (B): EXECUTED-NULL. Built test/concrete/Accountant/Test_HUNT_MultiLegWaterfallBrick.t.sol
  on the devs' own WaterfallSyncDriver (tryRunSync = brick oracle). 12,000 config-space fuzz runs
  (fuzzed ST/JT split, minCoverage, liquidation threshold, dust, term duration + N>=3-leg NAV
  sequences with fixed-term-cross warps) — 0 bricks, 0 conservation breaks. The devs fenced the
  SINGLE dip->recover (Test_SeniorLeverageViaImpermanentLossRecovery_PoC regression: pooled-IL
  coverage-debt ordering); the multi-leg/reset/wipe SIBLINGS are also null.
- LPT idle-premium valuation asymmetry (real): LPT DEPOSIT prices vs lptRawNAV only (RoycoVaultTranche
  :140-145, excludes idle premium shares, intentional "no slippage drop" comment); LPT REDEMPTION pays
  lptRawNAV + idle-premium-shares (AssetLedgerLogic:53-58). A late LPT depositor captures a pro-rata
  slice of accrued idle premium = dilution of existing LPTs. DROP: Phase-0 exclusion (incorrect-amount-
  to-whitelisted-LP-reversible + share-price/first-depositor class + intentional dev comment). OOS.
- oracle-clock wedge (B): DROP — oracle admin-replaceable (README) so any fail-shut wedge is admin-
  fixable -> not permanent (B).
- factory-seed-escape (A): READ-TIGHT — deployer=marketDeployer() funds+receives genesis shares; CREATE3
  baseSalt binds the caller (no cross-deployer hijack); dead-share lock underflow-guarded. No thread.
LESSON: the scope pays ONLY escape-to-non-whitelisted + permanent-lock. Permanent-lock is dev-hardened
+ fuzz-null; the whole value-extraction family (incl. the real LPT dilution) is OOS by the carve-out.
A 2nd distinct in-scope finding on this narrow scope in a 44-researcher comp is low-probability.
Honest RE-SOURCE (measured, with executed-null citation), NOT a lazy fortress. Better solo-EV on a
fresh non-swarmed target. See [[feedback-depth-is-an-edge-only-where-ore-remains]] (depth pays only
where ore remains; here the in-scope ore is measured-thin) + [[ev-gate-check-program-responsiveness-not-just-severity]].
