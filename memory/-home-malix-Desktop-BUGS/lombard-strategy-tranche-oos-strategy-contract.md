---
name: lombard-strategy-tranche-oos-strategy-contract
description: "Lombard Immunefi BTCoc strategy — CORRECTION 2026-08-12: program is Primacy of IMPACT for SC Critical/High, so the unlisted strategy 0xf14F678d IS in scope for those tiers (prior 'Primacy of Rules → OOS' premise was WRONG). Re-executed full pass: listed adapters + PoI-opened core all null; only residual = mid-epoch PPS-reconciliation composition"
metadata: 
  node_type: memory
  type: project
  originSessionId: bdadc85d-aa49-46b3-98d7-115c736ad457
  modified: 2026-08-12T16:03:20.253Z
---

Lombard Finance, Immunefi, worked 2026-08-01. **NO-GO on the strategy tranche.** Workspace
`~/Desktop/BUGS/lombard-audit/` (evm repo + `poc/` foundry project, 8 PoC tests all green).

**The scope trap.** The July-2026 "strategy" tranche lists only peripherals as assets: Shard
`0xDde9898A9f80aF2d9fbBb48B92FB2677a3b62dFD`, BlocklistOracle `0xc94B1E74aa3B5695D25b323cd0333fc2dBaada16`,
MerkleAllowlistValidator `0x5D84449068792B56663e4796A5AC117D90D06602`, DirectConverter
`0x6647Bf1C4214096B97145E0B23CF41C54A46CDd3`, ChainlinkConverter `0xecc0282C71bA63d58c0dD2282125566045A8F777`.
The **strategy itself** `0xf14F678d9c05798ba61652a950a05D74aD2E0A6C` ("Bitcoin Onchain Credit
Strategy", BTCoc, ~180.97 BTC reported) is **NOT listed**. ⚠️ **CORRECTION 2026-08-12: the "Primacy
of Rules" claim was WRONG** — the live Information tab states **Primacy of Impact for SC Critical + High**,
so the unlisted strategy IS in scope for those two tiers (Medium/Low stay Primacy of Rules). See the
2026-08-12 re-run at the bottom. All the interesting behaviour lives on the strategy contract, which is
now in-scope-for-Crit/High.

**Dead by program rules, not technique** (see [[feedback-audit-acknowledgment-is-a-liability-not-an-asset]]):
zero-fee deposit captures unclaimed yield during the frozen-PPS window. PoC was strong (fork replay of
their real post tx `0x015c27f2…` from the real setter, value conserved to 62 sats, disconfirmer showing
their own promised 6bps fee kills it, entry-timing test killing the mempool objection). Killed because
it IS OZ M-05, acknowledged-not-resolved, and `docs/audit/OZ_strategies_06_26.pdf` sits at the exact URL
the program cites for "any unfixed vulnerabilities mentioned in these reports are not eligible".
Program charges a **non-refundable fee at all severities**.

**Executed nulls (do not re-hunt):**
- `ShardBaseUpgradeable.exec(to,value,data,validatorArgs)` has **no `onlyRole`** — permissionless, the
  Merkle validator is the whole authz boundary. Recovered the live-shaped ruleset from deleted git
  history (`634d9dc`, path `scripts/strategy/ruleset/0x00..01/<validator>.yaml`). **L-11 bypass PROVEN**
  against real deployed bytecode (constraints are independent 32-byte windows, no ABI head/tail binding;
  redirect the unpinned head pointer, pinned windows stay satisfied). But NULL: every rule pins
  `sender = 0x653d5c6CEf72822e7C409ecB5c46C5c2858E5F2A`, a 2-of-5 Safe that **already holds
  `SHARD_TRANSFER_ROLE`**, an un-policed path that bypasses the validator entirely. Zero escalation.
  Live root `0x7d26468c…` ≠ recovered-ruleset root `0xc7a9cd7f…` (domain separator DID match on-chain,
  so the pipeline was right and the mismatch real) — live ruleset is a later private revision.
- Rate limiter is widened on demand before each post (`maxBps` 110 → 4000 → 110 → 600) so it is not a
  standing bound, BUT separation of duties **holds**: `setPricePerShareRateLimit` is `MANAGER_ROLE`
  (admin Safe `0x251a604E…`), price setter `0x33De6a85…` does not hold it. Admin-trust, OOS.
- No `cancel`/`refund` in `AsyncRedemptionUpgradeable`: shares burn at `requestRedeem`, claim frozen,
  payment discretionary (`PAY_REDEMPTIONS_ROLE`), strategy custodies 0 BTC.b on-chain. Real asymmetry
  but on the unlisted contract.

**Only in-scope surface left un-swept:** BlocklistOracle (+112 lines post-audit, plus commit `d6a1552`
"remove redundant blocklist checks") and the two converters. Everything else on this tranche is closed.

---

## 2026-08-12 re-run (fresh clone `~/Desktop/BUGS/lombard-2026-08/`, scope updated same day; TVL now ~432 BTC/~$41M)

**THE PREMISE CORRECTION:** Information tab → *"Lombard adheres to Primacy of Impact for Smart contract Critical
[and] High … impact prioritized rather than a specific asset, even if the affected assets are not in scope."*
So the unlisted strategy `0xf14F678d` (impl `MAWARS-0.0.1` = `MAWARStrategyMigrated`) **IS in scope for Crit/High.**
Medium/Low remain Primacy of Rules (listed assets only). Non-refundable fee at all tiers still applies; known-issues
clause kills anything in OZ_strategies_06_26 + Veridise_strategies_06_26 (dual audit) + the README's many
"accepted tradeoff" notes + prior reports.

**Executed nulls THIS run (do not re-hunt without a NEW angle):**
- **d6a1552 blocklist removal = genuinely REDUNDANT** (not a bug). `StrategyBaseUpgradeable._update` (the strategy
  IS the ERC20; `ShareToken.sol` is a *different* token) gates `_requireBlocklistAllows(from)`+`(to)` on every
  mint/burn/transfer. requestRedeem `_burn(owner)` re-checks owner; deposit `_mint(receiver)` re-checks receiver.
  `fulfillRedeemRequests` pays underlying only (no share move) so not even a freeze vector. Dead.
- **Converters null on-chain (D8b readback @ block 25.74M):** ChainlinkConverter_StakedLBTC 0xecc0 inverted=false,
  baseDec=8, scaleNum=1e18 (⟹tokenDec=8 ✓), feed=StakedLBTCOracle 0x1De9 (18-dec ratio 1.00482). `toBaseUnits`
  math matches live ratio. heartbeat=1123200s (~13d) but StakedLBTC ratio is monotone-up ⇒ stale = protocol-favorable.
  DirectConverter 1:1, base asset = NativeLBTC 0xB0F7. No production misconfig (OOS-rule-#1 exception doesn't fire).
- **Redemption overpay (theft/insolvency) = CLOSED by `e085bf6`:** fulfill now pays `min(pendingAssets, shares×currentPPS)`
  — protocol-favorable both PPS directions. Pre-fix it paid full `pendingAssets` (overpay on PPS drop); that's the fix.
- **PPS reconciliation:** M-19 rounding (`16cb6ac`, single-Floor fused) + `0e90cac` underflow-safeguard both landed;
  attacker can't reach the removal branch (`requestRedeem` leaves `_effectiveShareSupply` unchanged: burn−pending cancel;
  only operator-sequenced `fulfill` decreases it). Not attacker-triggerable.
- **Fees:** mgmt/perf mint to trusted treasury; dust-spam fee-avoidance & sub-share discards are DOCUMENTED accepted.
- **MerkleValidator fresh fix `1486646`** closes truncated-payload match; prior L-11 head-redirect still null (Safe holds
  SHARD_TRANSFER_ROLE). **MAWAR `migrate()`** = DEFAULT_ADMIN only (OOS). RemoteShard not deployed for BTCoc.
- **My prior M-05 (understated-window yield capture)** = DOCUMENTED "accepted tradeoff" in README + spec 003 + OZ-audited
  ⇒ known-issues clause. Bounded to yield (not principal) ⇒ no Critical escalation.

**Only genuinely-unexhausted thread:** the mid-epoch reconciliation *composition* (`postPricePerShare` × interleaved
user deposit/requestRedeem × fee mints) — most complex math, but it's exactly the OZ/Veridise+spec+M-19-fix focus, so
p(novel Crit) is low. Un-read behavior commits: `9c62f17`, `91df523`, `619ce17`, `984d69a` (all reconciliation/pause
hardening, same family already concluded protocol-favorable/operator-gated).

**Verdict:** GO-status corrected (core is in-scope via PoI) but **EV still poor** — saturated dual-audit core, brutal
known-issues clause, non-refundable fee. Recommend RE-SOURCE unless a bounded reconciliation-delta dig is wanted.
Instascope deployed-core harness built & green at `~/Downloads/foundry-v2-lombard-finance-9dee88d64a5f3aa3/`.
