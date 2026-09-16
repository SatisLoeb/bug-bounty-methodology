---
name: intuition-immunefi-c-d-are-c4-dups
description: "Intuition (Immunefi $100k) — prior dossier's 2 \"confirmed HIGH\" (deposit_for forced-lock, JIT snapshot) are BOTH published C4 dups = OOS; live path = C4-uncovered surfaces"
metadata: 
  node_type: memory
  type: project
  originSessionId: ca8b34fa-8fd2-45f5-86fb-0070e17b52af
  modified: 2026-08-27T21:29:54.268Z
---

Intuition bug bounty (Immunefi, slug `intuition`, max $100k, **$50/submission**, PoC+KYC, impact-based severity). Workspace: `~/Desktop/BUGS/blackbox/intuition/` (git@github.com:SatisLoeb/blackbox.git). Source cloned at `intuition/src-core`; fork-PoC project at `intuition/ve-poc` (RPC alias `intu` = https://rpc.intuition.systems, chainId 1155, pinned block 7886584).

**The prior dossier's two "confirmed HIGH" findings are BOTH published Code4rena (2026-03) findings = OOS dups. Re-verified 2026-08-27, PoCs pass on fork but the findings are dead:**
- **INTU-C** (`VotingEscrow.deposit_for` pulls from `_addr` not `msg.sender`, no `onlyUserOrWhitelist` → forced-lock temp-freeze) = **C4 published finding [05]**, verbatim. Also inherited from the Stargate DAO ve port (Paladin audited the "lock-for-others" behavior as an intentional migration feature) — so also a design-intent target. DEAD.
- **INTU-D** (TrustBonding reward = ve-balance at single instant `T_end` → JIT emission sniping) = **C4 published finding [07]** + **M-02**, verbatim. AND Diligence R1 explicitly calls reward-gaming known-and-team-accepted. Doubly DEAD.

**Why:** the dossier ranked VotingEscrow "surface non-auditée, faible risque dup" — WRONG: C4 reviewed VE "partially" but DID find & publish both. Lesson = never trust a prior pass's dup-conclusion; pull the actual C4 report and grep it. Cost saved: $100 in submissions + credibility.

**How to apply:** authoritative dup-filter = `intuition/04-DUP-FILTER-c4-published.md`. The Critical dig on the 5 C4-uncovered surfaces (2026-08-27, task we86h0ttf, 8 agents) came back a **full NULL-COÛTEUX / fortress-null** — Intuition SC is picked clean (Diligence x2 + C4 + in-repo POST-MORTEM.md). Executed ledger:
- **AtomWarden/Factory/Wallet-validation** NULL: `claimOwnershipOverAddressAtom` gate is keccak-bound + address↔string bijective → can only claim the wallet of the atom encoding YOUR OWN address; CREATE2 no-collision; init-seize dead (owner set to getAtomWarden). (0 audit coverage but sound.)
- **MultiVault + MultiVaultCore** NULL: conservation V_in==V_out closed for create/deposit/redeem; rounding both dirs vault-favorable; `totalShares==0`/`totalAssets==0` unreachable; rollover personal-util sibling of #60 checked.
- **LinearCurve** NULL.
- **VotingEscrow-insolvency**: only candidate = `_totalSupply(t<point_history[0].ts)` Panic(0x11) (re-creates Nov-2025 brick class) → DROP on THREE legs: reachability-empty (no value path accepts attacker t; `point_history[0]` immutable after init, trigger window ~1.5M s in the past, epoch domain [0,21]); KNOWN-ISSUE (`POST-MORTEM.md` in the target's OWN repo, 2025-11-18, names this exact line + PR#126 — dup-fossil); DESIGN-INTENT codified in dev tests (`test_totalSupplyAt_revertsForBlockBeforeFirstCheckpoint` vm.expectRevert). Over-claim/insolvency family killed by executed conservation Σ==total (independently re-read: `totalBondedBalanceAtEpochEnd(20)`=22335721628403951066755018 exact).
- **Emissions** (SEC $960k / dispatcher / controllers): 3 candidates all DROP. Best = `claimRewards(recipient=SEC)` strands claimant's own reward (mechanism confirmed live) but NO HONEST VICTIM (self-grief 1:1, tokens were burn-scheduled anyway, creates surplus not deficit, upgrade-recoverable) = Hyperbridge-F-002 informative shape.

**Verdict: NULL-COÛTEUX, RE-SOURCE.** No $50 warranted. Program is smart_contract-only (OOS excludes frontend/API/off-chain) → no off-chain pivot within THIS program. **Latent re-arm:** VE Panic(0x11) re-arms IFF TrustBonding redeployed OR SEC `_START_TIMESTAMP` moved earlier than VE init ts (1761942156). Relates to [[feedback-a-known-issue-note-is-a-dup-fossil]], [[feedback-depth-is-an-edge-only-where-ore-remains]], [[protocol-fortress-null-hunt]], [[feedback-corpus-match-pull-the-discovery-how]].
