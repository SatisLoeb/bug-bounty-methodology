---
name: livepeer-l1migrator-fresh-scope-engagement
description: "Livepeer Immunefi ($40K, Primacy of Rules) — L1Migrator freshly scoped 2026-08-10; L1/migration/bridge surface = executed earned-null; fresher ore = 2023 governance layer"
metadata: 
  node_type: memory
  type: project
  originSessionId: 225aa0fd-f40f-4d49-be74-cdfdb3270750
  modified: 2026-08-10T22:57:33.037Z
---

**Target:** Livepeer bug bounty (Immunefi, engaged payer — paid a bounty for the migrator vuln below; refreshed scope 2026-08-10). **Primacy of Rules**, $40K Critical / $15K High / $2.5K Med / $1K Low. PoC + KYC required. **C4 2022-01-livepeer findings are excluded** (dup wall over the 2022 code).

**In-scope assets (23; authoritative from raw scope HTML, NOT WebFetch which truncates):** 5 mainnet (etherscan) = **L1Migrator `0x2a69191B…07759`, BridgeMinter `0x8dDD…B405`, L1LPTGateway `0x6142f1C8…0676`, L1Escrow `0x6A23F494…210A`** (+1). ~18 Arbitrum = Controller, Governor `0xD9dE…36a6`, LivepeerToken(L2) `0x289b…A839`, Minter `0xc20D…7252`, BondingManager `0x35Bc…3e40`, TicketBroker, RoundsManager, ServiceRegistry, SortedDoublyLL, PollCreator, MerkleSnapshot, DelegatorPool `0xfdb0…b567`, L2Migrator `0x148D5b…2085`, L2LPTGateway `0x6D24…D318`, **LivepeerGovernor, Treasury `0xf82C…E8C4`, BondingVotes**. NOTE: L1 LivepeerToken `0x58b6A8A3…` is NOT listed.

**Why the target is "fresh":** L1Migrator `0x2a69` was **redeployed 2026-05-26** (old `0x2114` = Feb 2022, now paused) to FIX a disclosed vuln — *"any L1 address could force a delegate change on an L2 delegator they don't own"* (griefing → set victim delegate to 0; concentration → redirect victim stake to attacker). Fix = `require(_l1Addr == _l2Addr, "L2_ADDR_MISMATCH")` in `requireValidMigration` + `require(len>0)`/`require(amount>0)` in getMigrateUnbondingLocksParams. Immunefi added it to scope 2026-08-10 (the date the operator handed me). Deployed logic = C4-audited 2022 code MINUS migrateETH/migrateLPT PLUS those guards.

**EXECUTED EARNED-NULL on the L1/migration/bridge surface (payable axes):**
- Replay: L1Migrator deliberately has NO replay guard ("L2Migrator rejects replays"). L2Migrator dedups: `migratedDelegators[l1Addr]`, `migratedSenders[l1Addr]`, `migratedUnbondingLocks[l1Addr][id]` — all set-then-require. finalize* are `onlyL1Counterpart(l1MigratorAddr=0x2a69)`. Simple replay DEAD.
- Duplicate lock-IDs (`[5,5,5]` → L1 `total=3×`): DEAD — L2 `finalizeMigrateUnbondingLocks` sets `migrated[l1Addr][5]=true` on 1st, 2nd reverts BEFORE `bondFor(total)`.
- Force-delegate-change: fix present on all 3 paths, delegate read from L1 (not caller). Complete.
- Over-claim: `DelegatorPool.claim` caps `require(_stake<=remaining)`, proportional payout. No inflation.
- LPT issuance on L1 (BridgeMinter owns L1 LPT mint authority, `LPT.owner()==BridgeMinter`, NOT pause-gated): reachable but bridge is symmetric — L2 `burnFrom(from,_amount)` then L1 releases-escrow-or-mints same `_amount`; both sides canonical Outbox-gated. No mint>burn.

**Reachability facts:** L1 BondingManager `0x511Bc4…` still accepts `bondWithHint` (last Feb 2025); holds ~36 LPT. L1 Controller PAUSED (does NOT gate bridgeMint). L2Migrator holds 6.7 ETH, `claimStakeEnabled=true`. Escrow holds 5.2M LPT w/ infinite allowance to gateway (withdrawals < 5.2M release, don't mint).

**Un-exhausted / residual (low priority, low reachability):** (1) `claimedDelegatedStake` vs pool reward-accrual mismatch → possible temporary-freeze of last delegators of an un-migrated orchestrator w/ a live pool (High IF reachable, but big orchestrators migrated 2022 → thin). (2) L2Migrator ETH-pool drain starving fee/sender migrations (griefing, self-inflicted, low-sev).

**L2 inflation core — ALSO executed earned-null (operator-directed 2nd pass):** `getGlobalTotalSupply() = L2.totalSupply() + max(0, l1TotalSupply − l2SupplyFromL1)`. Live: L2 supply 36.17M, l1TotalSupply 24.92M, l2SupplyFromL1 5.145M → base 55.95M; inflation 538500/1e9 → mintable ~30,111 LPT/round. Over-mint killed: (1) bridge inc/dec symmetric — deposit `mint(_amount)`+`increaseL2SupplyFromL1(_amount)`, withdraw `burnFrom(_amount)`+`decreaseL2SupplyFromL1(_amount)` → global invariant across a transition; (2) `decreaseL2SupplyFromL1` floor UNDER-counts (Δglobal=F−W<0 on mass withdrawal); (3) l1TotalSupply canonical (`onlyL1Counterpart` pushes real L1 `totalSupply()`); (4) `RoundsManager.initializeRound` `require(lastInitializedRound<currRound)` → `setCurrentRewardTokens` once/round, `createReward` capped `currentMintedTokens<=currentMintableTokens`; (5) L2 LPT `mint` `onlyRole(MINTER_ROLE)`, holders = ONLY Minter `0xc20D` + L2LPTGateway `0x6D24` (canonical). Residual (NOT attacker-reachable): escrow-vs-l2SupplyFromL1 desync → +X global only if a single withdrawal exceeds the 5.2M-LPT escrow, or escrow<counter (the 2-step cross-chain flow keeps escrow≥counter).

**2023 governance — ALSO executed earned-null (operator-directed 3rd pass, solo trace + 8-agent adversarial workflow, all converged empty).** Contracts: LivepeerGovernor impl `0xd2Ce37BC…` (proxy `0xcFE4E2…6aa0`) = OZ GovernorUpgradeable + GovernorCountingOverridable (custom delegator-overrides-transcoder counting) + Treasury(TimelockController, minDelay=0) + BondingVotes impl `0x68AF8037…` (proxy `0x0B9C…68169A`). Treasury holds ~589,610 LPT. The ENTIRE override-counting security reduces to ONE invariant (GovernorCountingOverridable ~L228): `votes(T) >= Σ votes(delegators)` at every snapshot. Proven to HOLD:
- Checkpoint completeness: every BondingManager write to delegatedAmount(`increaseTotalStake`@1416/`decreaseTotalStake`@1460)/bondedAmount/lastClaimRound/lastRewardRound is paired with a same-tx `_checkpointBondingState` of BOTH transcoder and delegator (bond@643/654, unbond@823+autoCheckpoint, rebond@1656+autoCheckpoint, reward autoCheckpoint@926, claim autoCheckpoint@482, transferBond=unbond+processRebond both checkpoint). `slashTranscoder` is `onlyVerifier` (null role, OOS).
- Timing-lock: `BondingVotes.delegatorVotesAtRoundStart` reads RF_end from the SAME transcoder checkpoint that supplies `votes(T)=delegatedAmount` → cannot desync. `checkpointBondingState` requires `startRound==clock()+1` (no past-round forgery; historical snapshots immutable).
- LIP-36 math floors everywhere (`PreciseMathUtils.percOf` truncates) → `Σ floor(delegator_i) <= delegatedAmount`, with STRICT margin (transcoder commission siphoned to `t.cumulativeRewards`, excluded from the factor). So `_handleVoteOverrides` checked-subtraction (@192,214-219) cannot underflow → no vote-grief AND no inflation.
- transferBond/DelegatorPool.claim conserve votes across the migration boundary (no double-count round).
- Treasury timelock correctly role-gated (only Governor is PROPOSER/EXECUTOR/CANCELLER; no open executor); minDelay=0 = no cancel window but no standalone bug.
- Protocol Governor `0xD9dE` (Controller owner) sound: `transferOwnership`=`onlyThis` (stage/execute-only), `stage`/`cancel`=`onlyOwner` (multisig `0x04F5…`), `execute` public but runs only committed owner-staged updates, `delete` before calls (no replay).
- Treasury-drain requires inflating votes past real staked LPT (quorum=33.33% of ~29.75M active LPT ≈ 9.9M LPT, not marshalable without breaking the invariant). Invariant holds → path dead.
Scope note: `0x1d24838b` (a listed asset) has NO CODE on-chain.

**VERDICT: Livepeer SC in-scope surface = comprehensive executed earned-null** across (1) L1Migrator migration/bridge, (2) L2 inflation core, (3) 2023 governance. Fresh surfaces (2026 migrator fix + 2023 governance) are complete/clean; the rest is C4-2022-saturated. RE-SOURCE. Re-open ONLY on new arbitrum-lpt-bridge / protocol commit, or a listed asset's fresh deployment.

**Re-open triggers:** new commit to arbitrum-lpt-bridge; a live un-migrated orchestrator+pool appears; DataCache/Minter inflation-base finding.

Links [[feedback-webfetch-summarizer-truncates-immunefi-scope]] [[feedback-verify-the-recommended-fix-against-real-usage]] [[feedback-audited-target-hunt-invariant-not-class]] [[depth-is-an-edge-only-where-ore-remains]].
