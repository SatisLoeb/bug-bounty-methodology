---
name: aztec-l1-sc-earned-fortress-null
description: "Aztec Network Cantina SC bounty — in-scope L1 Solidity scope is now EXECUTED fortress-null (was over-declared); SKIP, residual EV only circuit-side/off-chain"
metadata: 
  node_type: memory
  type: project
  originSessionId: 3099182a-dea7-4460-992c-f775e3ee365a
---

Aztec Network (Cantina SC bounty, Critical cap $50k = 10% funds-at-risk / $10k floor, High $5-10k). Worked 3x: 2026-05, 2026-06-24 (NO-GO but "fortress" over-declared — RewardBooster/FlushRewarder/bridge/slashing-vote were classified-not-executed), and **2026-07-04 missed-surface sweep that CLOSED that gap with executed artifacts**.

**Now genuinely null-with-artifact across all 12 previously-unexecuted in-scope surfaces** (workflow: 25 agents map→adversarial-refute→rank, ~2.3M tok). Do NOT re-sweep the L1 SC core a 4th time short of a >500 LOC new module or a fresh post-audit commit. Closed:
- RewardBooster/RewardLib: winner-takes-longest + activity-share by-design; `_toShares` floored ≥1 by ctor invariants; rewards funded externally (no conservation break).
- FlushRewarder: `sum(rewardsOf)==debt` by construction; `rewardsAvailable()` no underflow; reentry point is a callback-less ERC20 transfer.
- FeeJuicePortal/Inbox: amount bound into `contentHash` atomically 1:1; `FEE_JUICE_ADDRESS` identity gate unforgeable (`FEE_ASSET_PORTAL` is a ctor immutable); leaf-index uniqueness kills replay.
- RewardDistributor earmark lockstep; CoinIssuer mint `onlyOwner` (OOS); Rollup `burn≤fee` proven all branches + reward accounting inside the 125-invariant formal verification; slashing `vote()` padding-never-tallied + EIP-712 binds slot/chainId/addr.
- Sole workflow "survivor" EH-3 (EscapeHatch flag-before-guard) HAND-VERIFIED NULL: `$isHatchPrepared` early-returns (`setSize==0` @607, `block.timestamp>=nextFreezeTs` @617) are the exact negation of the designation-success path (@604/607/617 fall through to @621), and `setSize` is snapshot-fixed identical for all callers → no griefer early-`.set` can deprive an otherwise-possible honest designation. Refute-agent over-flagged; map-agent's original disconfirmer was right ([[feedback-workflow-agents-coverage-not-verdict]]).

**Previously KILLED+deep (do not re-hunt):** BaseHonkVerifier (KZG opening = last msg never absorbed, FS ordering correct); ignition ATP/staker conservation + #59 upgrade-drain fix incl V2; Outbox double-consume; TallySlashing retro-slash = Cantina M-3.1.1 known-issue OOS.

**EV verdict = SKIP.** Multi-audit (Cantina×2 + Veridise + Spearbit + ZKSecurity + Zellic) + 125-invariant FV + $50k cap on low rollup TVL + SC-only scope. Any future Aztec EV is circuit-side (Noir/barretenberg fee-equality — invfuzz, high-cost, and OOS for this L1-Solidity program) or off-chain/API/frontend (not in this scope). Prior notes: `aztec-fresh-intake-2026-06-24/` + `aztec-audit/SURFACE-INVENTORY.md`. Instance of [[feedback-target-diet-is-the-binding-constraint]] and [[apparatus-is-packaging-not-discovery]] (the sweep produced an honest null, not a finding).
