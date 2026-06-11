# LRT-SLASHING-HUNT — Liquid Restaking Token slashing verification

Puffer, Renzo, Kelp, Ether.fi, Mantle mETH, Bedrock, Swell, Eigenpie, KelpDAO, Origin ETH, Bedrock, Kinetix.
Each wraps EigenLayer / Symbiotic with custom `handleSlashing` logic.
Oracle-heavy, permissionned, fund-theft class.
$15B+ TVL across the space, bounties $50K-$500K.

## Bug classes

| ID | Class | Detection signal |
|---|---|---|
| LRT-001 | Slashing report delay — slash on-chain at block X, LRT reports at X+N, user withdraws at old rate in [X, X+N] | `grep -rn "reportSlashing\|_handleSlashing"` — check if reporting is atomic with on-chain slash event |
| LRT-002 | Slashing oracle manipulation — who can trigger reportSlashing? Multisig with low threshold / permissionless → false slash to tank price | `grep -rn "onlyOracle\|onlySlashingReporter"` — count signers required |
| LRT-003 | Operator set override — admin can add adversarial operator, affects LRT trust | `grep -rn "addOperator\|whitelistOperator"` — check admin controls |
| LRT-004 | Withdrawal queue ordering — FIFO claimed but actually permissioned | `grep -rn "completeWithdrawal\|claimQueued"` — check queue iteration |
| LRT-005 | Cross-chain LRT redemption — redeem chain A, double-redeem chain B via bridge message race | `grep -rn "redeem\|requestWithdrawal" + bridge sends` |
| LRT-006 | Reward claim race with slashing — claim pre-slash-timestamp rewards AFTER slash | `grep -rn "claimReward\|accrueRewards"` — check rewardTimestamp comparison |
| LRT-007 | Slashable collateral double-counting — LRT wraps EigenLayer operator that's ALSO in Symbiotic | cross-check operator registrations across restaking protocols |
| LRT-008 | Delegation switch — delegation changes, earned rewards attributed to wrong operator | `grep -rn "delegateTo\|switchOperator"` — check reward accounting |
| LRT-009 | Checkpoint proof staleness — Merkle root of validator state N used when current is M | `grep -rn "checkpoint\|verifyWithdrawalCredentials"` — check root freshness |
| LRT-010 | Undelegation timer bypass — avoid slashing by undelegate after slashable event but before slash block | `grep -rn "undelegate\|startWithdrawal"` — check timestamp vs slashable-event window |
| LRT-011 | Validator exit griefing — attacker triggers validator exits via LRT, extractable MEV | check `initiateValidatorExit` permissions |
| LRT-012 | Oracle TWAP window — rate-derivation oracle uses window too short, flash-loan manipulable | `grep -rn "rateOracle\|oracleWindow"` |

## Targets with live bounties

| LRT | TVL | Bounty | Platform |
|---|---|---|---|
| Ether.fi (eETH / weETH) | $6.5B | $100K | HackenProof |
| Puffer (pufETH) | $500M | $100K | Cantina |
| Renzo (ezETH) | $1.5B | $250K | HackerOne |
| Kelp DAO (rsETH) | $1.8B | $150K | HackerOne |
| Mantle mETH | $1.2B | Mantle $200K | HackenProof |
| Bedrock (uniBTC / uniETH) | $700M | $50K | Direct |
| Swell (swETH / rswETH) | $500M | $100K | Direct |
| Eigenpie (mLRT) | $300M | $25K | Direct |
| EigenLayer | OOS | Immunefi $1M OOS | skip Immunefi |
| Symbiotic | $200M | direct security | |
| Karak | TVL growing | Karak $100K direct | |

## Grep arsenal

```bash
# Slashing entry points
grep -rn "reportSlashing\|handleSlashing\|_processSlashing\|slashOperator" --include="*.sol"

# Rate oracle
grep -rn "getRate\|ratePerShare\|exchangeRate\|pricePerShare" --include="*.sol"

# Operator management
grep -rn "addOperator\|removeOperator\|delegateTo\|undelegate" --include="*.sol"

# Withdrawal queue
grep -rn "queueWithdrawal\|completeWithdrawal\|finalizeWithdrawal" --include="*.sol"

# Checkpoint / state sync
grep -rn "verifyCheckpoint\|updateStateRoot\|verifyWithdrawalCredentials" --include="*.sol"

# Cross-chain
grep -rn "ccipReceive\|lzReceive\|nonblockingLzReceive" --include="*.sol"
```

## Methodology (per LRT, 30-60h)

1. **Map the stack** — what underlying (EigenLayer? Symbiotic? Karak?). What's the rate oracle? Who reports slashing?
2. **Enumerate slashing triggers** — who can call `reportSlashing`? Multisig? Oracle? Governance? Count required sigs.
3. **Trace rate impact** — when slashing is reported, how does rate drop? Immediate? Delayed? Delay window = arbitrage window.
4. **Withdrawal queue audit** — can attacker front-run the queue? Is ordering permissioned? Can slash-pending withdrawals escape?
5. **Cross-chain redemption** — LRT on 3+ chains. Each bridge message should carry slash-state. Check race conditions.
6. **Operator rotation** — admin adds new operator. Does it affect existing LRT holders' claim? Forced delegation?
7. **Rewards vs slashing** — rewards accrued pre-slash but claimed post-slash. Accounting bug?

## PoC pattern

```solidity
// test/LRTSlashingDelay.t.sol
contract LRTSlashingDelay is Test {
    function setUp() public {
        vm.createSelectFork("mainnet", BLOCK_BEFORE_SLASH);
    }

    function test_withdrawAtOldRateAfterSlash() public {
        // 1. Snapshot LRT rate at BLOCK_BEFORE_SLASH (e.g., 1.05 ETH/sLRT)
        uint256 rateBeforeSlash = LRT.getRate();

        // 2. Trigger slashing event on-chain (via EigenLayer slash or mock)
        // 3. LRT contract doesn't know yet — reportSlashing hasn't been called
        uint256 rateAfterSlashBeforeReport = LRT.getRate();
        assertEq(rateBeforeSlash, rateAfterSlashBeforeReport); // still old rate

        // 4. Attacker withdraws at old rate
        uint256 amountOut = LRT.redeem(1e18, attacker);

        // 5. reportSlashing finally called
        LRT.reportSlashing(slashEventData);

        // 6. Later redeemers get new (lower) rate
        // Arbitrage profit = (oldRate - newRate) × attacker's share of extraction
        assertGt(amountOut, 1e18 * newRate);
    }
}
```

## Integration with lifecycle

```bash
TARGET_HINTS="lrt restaking eigenlayer" \
  ~/arsenal/audit-lifecycle/bin/init-target.sh renzo-audit
```

## Tool requirements

- `lrt-operator-scanner.sh` — for a given operator address, query all LRTs that delegate to it
- `lrt-rate-watcher.py` — monitor rate oracle across LRTs; flag when underlying slash event doesn't propagate within N blocks
- `lrt-withdrawal-queue-inspector.sh` — enumerate queued withdrawals, flag ordering anomalies

## Known patterns (ghost-finding candidates)

- Puffer 2024: withdrawal queue ordering bug (Medium, patched)
- Renzo 2024: oracle depeg during restaking rate miscalc (temporary depeg)
- Eigenpie: operator delegation timing window
