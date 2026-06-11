# Solana / Anchor Security Hunt Checklist

Systematic checklist for auditing Solana programs (Anchor and native). Derived from Zealynx 45-point checklist, Neodyme Solana security research, Sec3 patterns, and Jupiter Lend audit lessons.

**Prerequisite:** Complete the Kill Gate (KILL-GATE-TEMPLATE.md) for each finding before writing any report.

---

## 0. RECON (5 min)

- [ ] Program ID(s) on mainnet/devnet — verify deployed version matches audit scope
- [ ] Anchor version — check for known framework bugs at that version
- [ ] TVL / SOL locked in PDAs — `solana balance <PDA>` or Solscan
- [ ] Prior audits — read conclusions, note what's covered
- [ ] Number of instructions — larger surface = more opportunity
- [ ] Upgrade authority — is the program upgradeable? Who holds the authority?
- [ ] Dependencies — which CPIs does the program make? (Token Program, System Program, custom programs)

---

## 1. ACCOUNT VALIDATION & ACCESS CONTROL

### 1.1 Missing Account Validation (Most Common Solana Bug Class)

- [ ] **Missing `has_one` / `constraint`** — Does every account in the instruction context have adequate constraints? Can an attacker pass a fake account?
- [ ] **Missing signer check** — Is `Signer<'info>` used for all accounts that should authorize the transaction?
- [ ] **Missing owner check** — Does the program verify `account.owner == expected_program_id`? Anchor's `Account<'info, T>` does this automatically, but `AccountInfo` does NOT.
- [ ] **Missing `is_initialized` check** — Can an uninitialized account be used where an initialized one is expected?
- [ ] **PDA seed collisions** — Are PDA seeds unique enough? Can different logical entities map to the same PDA?
- [ ] **Bump seed canonicalization** — Does the program use `bump = <field>` (canonical) or allow arbitrary bumps? Non-canonical bumps → multiple valid PDAs.

```rust
// VULNERABLE: No owner check on raw AccountInfo
pub fn process(ctx: Context<MyCtx>) -> Result<()> {
    let data = ctx.accounts.user_data.try_borrow_data()?;  // could be ANY account
}

// SAFE: Anchor Account<> type checks owner automatically
#[account]
pub struct UserData { ... }
```

- [ ] **Ref exploit:** Wormhole bridge ($320M) — missing signer verification on guardian set

### 1.2 Privilege Escalation

- [ ] **Authority transfer without 2-step** — Can admin authority be transferred to a wrong address with no recovery?
- [ ] **Missing multi-sig on critical operations** — Are high-value operations single-signer?
- [ ] **Upgrade authority check** — If upgradeable, can an attacker somehow get upgrade authority?

---

## 2. CPI (Cross-Program Invocation) SECURITY

### 2.1 Arbitrary CPI

- [ ] **CPI to unchecked program** — Does the CPI target a program whose ID is passed as an account (user-controlled)? If so, attacker can substitute a malicious program.
- [ ] **Missing program ID check** — `invoke_signed(&ix, accounts, seeds)` doesn't verify the target program. Verify `program_id == expected` BEFORE CPI.
- [ ] **CPI privilege escalation** — Can CPI invoke a privileged instruction on the target program using the calling program's PDA signer seeds?

```rust
// VULNERABLE: Program ID from user input
invoke(&instruction, &[account_infos], &[&signer_seeds])?;

// SAFE: Hardcode expected program ID
assert_eq!(target_program.key(), &spl_token::ID);
invoke(&instruction, &[account_infos], &[&signer_seeds])?;
```

### 2.2 Re-entrancy via CPI

- [ ] **CPI callback** — Does any CPI'd program have a callback that re-enters this program?
- [ ] **State mutation after CPI** — Is program state modified AFTER a CPI call? (CEI violation)
- [ ] **Ref exploit:** Mango Markets ($114M) — price manipulation via CPI to oracle

---

## 3. ARITHMETIC & OVERFLOW

### 3.1 Integer Overflow/Underflow

- [ ] **`checked_*` operations** — Are all arithmetic operations using `checked_add`, `checked_mul`, `checked_div`, `checked_sub`? In Anchor, default is checked, but `unchecked_math` feature or explicit `unchecked {}` bypasses this.
- [ ] **`as` casts** — Every `as u64`, `as u128`, `as i64` is a potential truncation or sign flip. List all casts and verify range.
- [ ] **`try_from().unwrap()`** — This panics on overflow. Use `try_from().map_err(...)` instead.
- [ ] **Multiplication before division** — `a * b / c` can overflow even if result fits. Use `u128` intermediaries or `checked_mul` then `checked_div`.

### 3.2 Precision Loss

- [ ] **Rounding direction** — Deposits should round DOWN (protocol keeps dust). Withdrawals should round DOWN (protocol keeps dust). If reversed → user extraction possible.
- [ ] **Fixed-point math** — Are decimal representations consistent? (e.g., 6 decimals for USDC, 9 for SOL, custom for protocol tokens)
- [ ] **Zero-amount edge cases** — What happens when amount = 0? Can zero-value transactions bypass checks?
- [ ] **Ref exploit:** Cetus Protocol ($223M, Sui) — overflow in liquidity calculation, same pattern applies to Solana AMMs

### 3.3 Jupiter Lend Specific Patterns

- [ ] **Exchange rate monotonicity** — If a vault tracks share→asset exchange rate, can the rate ever DECREASE? If decrease is possible → value extraction.
- [ ] **Rate magnification** — Small rounding errors in rate calculation that compound over time. Check: is the rate stored with sufficient precision?
- [ ] **`saturating_sub` masking** — If code uses `saturating_sub`, does it mask a state where underflow SHOULD be an error? (Jupiter #3 lesson)

---

## 4. TOKEN HANDLING

### 4.1 SPL Token Edge Cases

- [ ] **Token account ownership** — Is the token account owned by the expected program/PDA?
- [ ] **Mint authority check** — Can someone mint additional tokens to inflate supply?
- [ ] **Close account dust** — When closing a token account, is the remaining dust (< rent-exempt minimum) handled correctly?
- [ ] **Token-2022 extensions** — Transfer hooks, confidential transfers, permanent delegate, non-transferable — does the program handle these?
- [ ] **Token-2022 transfer fees** — If the token has a transfer fee, does `amount_received = amount_sent - fee`? Does the program account for this?

### 4.2 SOL Handling

- [ ] **Lamport accounting** — Does `account.lamports()` match expected balance tracking?
- [ ] **Rent-exempt minimum** — Can draining an account below rent-exempt cause it to be purged?
- [ ] **System program transfer vs direct lamport manipulation** — Is SOL moved via `system_program::transfer` or direct `**account.lamports.borrow_mut()` manipulation?

---

## 5. STATE MANAGEMENT

### 5.1 Account Lifecycle

- [ ] **Account initialization** — Can an account be initialized twice? (Double-init → state corruption)
- [ ] **Account closure** — When closing accounts, is the discriminator cleared? Can a closed account be revived?
- [ ] **Account reallocation** — If account size changes (`realloc`), is additional rent paid? Is old data zeroed?

### 5.2 State Consistency

- [ ] **Atomic state updates** — Are related state changes in the same instruction? Or can a partial update leave inconsistent state?
- [ ] **Clock/slot dependence** — Does the program use `Clock::get()` for timing? Can validators manipulate slots?
- [ ] **Stale state** — Can a transaction use stale account data if another transaction modifies it in the same slot?
- [ ] **Oracle staleness** — If using Pyth/Switchboard, is `last_update_slot` checked? How old is "too old"?

### 5.3 Jupiter Lend Specific: Lending Protocol State

- [ ] **Liquidation threshold vs borrow factor consistency** — Are the same safety margins applied uniformly across all collateral types?
- [ ] **Reserve staleness** — Can an operation use a stale reserve state to get favorable rates?
- [ ] **Interest rate model** — Can extreme utilization cause overflow in rate calculation?

---

## 6. ORACLE SECURITY (Solana-Specific)

### 6.1 Pyth Network

- [ ] **Price confidence interval** — Is `price.conf` checked? High confidence = price uncertainty → manipulation risk
- [ ] **Price staleness** — Is `price.publish_time` or `last_update_slot` verified?
- [ ] **TWAP vs spot** — Is the program using EMA price or spot? Spot is more manipulable.
- [ ] **Negative price** — Can `price.price` be negative? (Yes, for some assets). Does the program handle this?

### 6.2 Switchboard

- [ ] **Aggregator staleness** — `aggregator.latest_confirmed_round.round_open_timestamp` checked?
- [ ] **Min/max response check** — Does the program verify the oracle response is within sane bounds?

### 6.3 LP Token / Pool Price

- [ ] **Pool reserves as oracle** — Never use `reserves / total_supply` as price. Manipulable via flash loan.
- [ ] **Virtual reserves** — If using a CLMM (concentrated liquidity), active tick range affects "price." Is this handled?

---

## 7. ANCHOR-SPECIFIC PATTERNS

### 7.1 Common Anchor Pitfalls

- [ ] **`init` without `payer` check** — Who pays rent? Can an attacker force someone else to pay?
- [ ] **`mut` on accounts that shouldn't be mutable** — Can a read-only account be passed as mutable?
- [ ] **`close` without zeroing** — Anchor's `close` should zero the account. Verify in older versions.
- [ ] **`#[account(seeds, bump)]` without `has_one`** — PDA exists but might belong to a different entity.
- [ ] **Error swallowing** — `if let Ok(...) = dangerous_operation { }` silently ignores failures.

### 7.2 IDL / Type Confusion

- [ ] **Discriminator collisions** — Different account types with the same first 8 bytes. Rare but possible with short names.
- [ ] **Enum variants** — Can passing an unexpected enum variant cause unintended behavior?
- [ ] **Remaining accounts** — If `ctx.remaining_accounts` is used, is each account validated?

---

## 8. GREP PATTERNS FOR SURFACE SCAN

```bash
# Unsafe arithmetic
grep -rn "as u64\|as u128\|as i64\|as u32\|as i128" --include="*.rs"
grep -rn "unwrap()" --include="*.rs"
grep -rn "unchecked" --include="*.rs"
grep -rn "saturating_sub\|saturating_add\|saturating_mul" --include="*.rs"

# CPI without program check
grep -rn "invoke\|invoke_signed" --include="*.rs"
grep -rn "CpiContext::new\b" --include="*.rs"

# Account validation gaps
grep -rn "AccountInfo" --include="*.rs"  # Raw accounts lack auto-validation
grep -rn "remaining_accounts" --include="*.rs"
grep -rn "to_account_info" --include="*.rs"

# Signer checks
grep -rn "Signer" --include="*.rs"
grep -rn "is_signer" --include="*.rs"

# State management
grep -rn "close\|realloc\|init" --include="*.rs"
grep -rn "lamports()" --include="*.rs"

# Oracle usage
grep -rn "get_price\|load_price\|price_feed" --include="*.rs"
grep -rn "publish_time\|last_update\|staleness" --include="*.rs"

# Token operations
grep -rn "transfer\|mint_to\|burn\|approve" --include="*.rs"
grep -rn "token_2022\|token_extensions\|transfer_hook" --include="*.rs"

# Error handling gaps
grep -rn "if let Ok\|if let Some" --include="*.rs"  # Potential error swallowing
grep -rn "expect(" --include="*.rs"  # Panics in production
```

---

## 9. WORKFLOW

```
For each Solana target:

1. RECON (5 min)           → Section 0
2. SURFACE SCAN (15 min)   → Section 8 (grep patterns)
3. ENTRY POINTS (30 min)   → List all instruction handlers
                              Classify: touches funds? modifies state? CPI?
4. KILL GATE (30 min/finding) → KILL-GATE-TEMPLATE.md
5. DEEP DIVE (2-4h)        → Sections 1-7 based on protocol type:
                              - Lending/Borrowing → Sections 1, 3, 5, 6
                              - AMM/DEX          → Sections 3, 4, 6
                              - NFT/Gaming       → Sections 1, 2, 5
                              - Bridge           → Sections 1, 2, 5
                              - Governance       → Sections 1, 2, 5
6. POC (1-2h)              → anchor test / solana-test-validator
7. PREFLIGHT (15 min)      → PREFLIGHT-CHECK.md (min 22/24)
8. WRITE-UP (1h)           → /disclose
```

---

## 10. TOOLING

| Tool | Usage | Command |
|------|-------|---------|
| `anchor test` | PoC tests in native framework | `anchor test -- --test-threads=1` |
| `solana-test-validator` | Local fork for realistic tests | `solana-test-validator --clone <program_id>` |
| `trdelnik` (Ackee) | Fuzz testing Anchor programs | `trdelnik fuzz` |
| `sec3 X-Ray` | Static analysis | [x-ray.sec3.dev](https://x-ray.sec3.dev) (web-based) |
| `solana logs` | Monitor program logs | `solana logs <program_id> --url devnet` |
| `anchor idl fetch` | Get program IDL from on-chain | `anchor idl fetch <program_id> --provider.cluster mainnet` |
| `solana account` | Inspect account data | `solana account <address> --output json` |

---

## 11. REFERENCE EXPLOITS (Solana-Specific)

| Date | Protocol | Amount | Vector | Category |
|------|----------|--------|--------|----------|
| 2022 | Wormhole | $320M | Missing signer verification | Account Validation |
| 2022 | Mango Markets | $114M | Oracle manipulation via CPI | Oracle + CPI |
| 2022 | Cashio | $48M | Infinite mint from unchecked account | Account Validation |
| 2023 | Marinade | $0 (caught) | PDA seed collision | Account Validation |
| 2024 | Solend/Save | $0 (caught) | Oracle staleness in liquidation | Oracle |
| 2025 | Various Anchor | Multiple | Token-2022 transfer hook reentrancy | CPI + Reentrancy |

---

## 12. JUPITER LEND LESSONS INTEGRATED

| Lesson | Finding | Gate That Catches It |
|--------|---------|---------------------|
| Disjoint sets don't interact | #2 (Branch Recycling) — recycled vs liquidated branches = DISJOINT | Kill Gate Q3 |
| `saturating_sub` masks real errors | #3 (Bank-run scenario) — saturating_sub prevented the claimed underflow | Kill Gate → Dismissal Matrix (B7) |
| Rate precision requires honest math | #4 (Magnifier) — 1-year extrapolation was unrealistic | Preflight A2 |
| Internal consistency wins arguments | #1 (Oracle) — StakePool staleness check present, MsolPool absent | Kill Gate Q4 → Dismissal Matrix |
| #4 survived via monotonicity argument | Vault rate should only increase, it can decrease = invariant violation | Sections 3.3, 5.2 |
