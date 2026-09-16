---
name: enzyme-onyx-immunefi-earned-null
description: "Enzyme Onyx (Immunefi $200K) closed as executed null 2026-07-31 — CCIP wallets + issuance/NAV core both survived fork harnesses; two latent items logged, neither submittable"
metadata: 
  node_type: memory
  type: project
  originSessionId: 8916322b-95a0-45a7-bced-61700d728f13
  modified: 2026-07-31T11:19:58.911Z
---

Enzyme Onyx (Immunefi, max $200K) — **NO-GO / NULL-COÛTEUX, no submission**, closed 2026-07-31.
Workspace `~/Desktop/BUGS/onyx-audit/`, ledger in `_negative-results.md`, PoCs in
`protocol-onyx/test/poc/` (CcipHunt*, CcipFee, LionRoundTrip, LionInvariant).

**Target:** `enzymefinance/protocol-onyx` @ `7b48d24`, 7,722 LOC / 73 files, 3 ChainSecurity audits —
the ACE audit landed 30 Jul 2026, *the day before* the pass (max dup risk on the freshest code).
Live: 51 Shares vaults on Ethereum (19 funded, $30.36M + 441 ETH + 76 BTC + €181K), 48 Arbitrum, 17 Base, Plume.

**Why it's null:** the trust model absorbs the surface — NAV, asset rates, fees, mint, burn and queue
execution are all `onlyAdminOrOwner`, and admin/owner are documented fully-trusted. Untrusted-reachable
surface is only: sync deposit, request/cancel deposit, request/cancel redeem, ERC20 transfer, CCIP inbound,
3 permissionless `deployProxy`, 2 permissionless `init()`.

**Executed artifacts (not inspection):**
- CCIP wallets, 11 fork probes vs the live Arbitrum WalletsManager. No source-chain/sender allowlist
  CONFIRMED absent — but neutralised because the wallet address binds (chainSelector, sender, initData)
  through CREATE2. Squatting, stray-balance sweep, victim-wallet drive, reentry all refuted.
- Issuance/NAV on a mainnet fork of Lion Yield Vault ($11.9M), config parity verified to 1 wei of the
  live price: round-trip over 10 sizes always returns ≤ input (exactly −1 wei); accounting identity
  `supply·price + feesOwed == tracked + untracked` holds to 1.09e7 wei on 1.3e25; stateful fuzz
  **7,200 calls** incl. duplicate-id batches — queue solvency, no-free-money, price-never-falls all hold.

**Two latent items (documented, NOT submitted — no impact PoC ⇒ would be closed):**
1. `AccountERC20Tracker.init` and `CreWorkflowConsumer.init` lack access control (hand-rolled
   `!__isInitialized()` instead of the OZ `initializer` + `_disableInitializers()` used everywhere else).
   86 live instances across 3 chains verified correctly initialized; `SharesDeployer` inits atomically.
   **Re-open if a component is ever deployed with empty initData.**
2. Async queues price against a stale NAV — the sibling `SyncDepositHandler` enforces
   `maxSharePriceStaleness`, the queues explicitly do not. Measured 45h and 139h stale executions on-chain
   with +0.36%/+0.11% subsequent drift. Real value transfer, but admin-only trigger ⇒ fails
   [[feedback-reachability-is-kill-gate-not-severity-modifier]].

**Harness bias caught mid-pass:** the first fork run used a stale `TOTAL0` from an old `ShareValueUpdated`
event and silently inflated the share price 0.8999 → 0.9635. Deriving total from *current* on-chain state
fixed parity. Reinforces [[feedback-scope-asset-dates-are-not-build-dates]] — anchor to live reads, not events.

Re-open only on: new deployed component with non-atomic init, a funded CCIP DepositorWallet population,
or an OpenAccessLimitedCallForwarder wired as a Shares admin (none deployed on mainnet as of this pass).
See [[feedback-depth-is-an-edge-only-where-ore-remains]] and [[feedback-target-diet-is-the-binding-constraint]].
