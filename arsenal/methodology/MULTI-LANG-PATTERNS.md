# Multi-Language Vulnerability Patterns

Complements C4-HUNTING-PATTERNS.md (Solidity) with language-specific patterns.

---

## RUST (Soroban, Solana, NEAR, Spark)

### R-001: unwrap()/expect() Panic in Production
- **Severity:** MEDIUM (DoS via panic)
- **Detection:** `grep -rn "\.unwrap()\|\.expect(" --include="*.rs" | grep -v test | grep -v "#\[test\]"`
- **FP:** Safe if in test code or if the Option/Result is provably Some/Ok by construction
- **Impact:** Process panic = node/service crash

### R-002: Integer Overflow in Release Mode
- **Severity:** HIGH (silent wrap)
- **Detection:** `grep -rn "overflow-checks\s*=\s*false\|wrapping_add\|wrapping_sub\|wrapping_mul" --include="*.rs" --include="*.toml"`
- **FP:** Safe if `overflow-checks = true` in Cargo.toml release profile
- **Impact:** Rust debug panics on overflow, release WRAPS SILENTLY. Check Cargo.toml.

### R-003: unsafe Block Without Justification
- **Severity:** MEDIUM-HIGH
- **Detection:** `grep -rn "unsafe\s*{" --include="*.rs" | grep -v test`
- **FP:** Safe if unsafe is well-documented with safety invariant comments
- **Impact:** Memory corruption, undefined behavior

### R-004: Missing Zeroization of Secret Keys
- **Severity:** LOW-MEDIUM
- **Detection:** `grep -rn "private_key\|secret_key\|seed\|mnemonic" --include="*.rs" | grep -v "zeroize\|Zeroize\|Drop"`
- **FP:** Safe if type implements Zeroize on Drop
- **Impact:** Key material persists in memory after deallocation

### R-005: Unchecked Arithmetic in Checked Context
- **Severity:** MEDIUM
- **Detection:** `grep -rn "unchecked_add\|unchecked_sub\|unchecked_mul\|as u64\|as u128\|as usize" --include="*.rs"`
- **FP:** Safe if bounds proven by preceding checks
- **Impact:** Overflow/truncation in type casts

### R-006: Race Condition in Shared Mutable State
- **Severity:** HIGH
- **Detection:** `grep -rn "Arc<Mutex\|RwLock\|AtomicU\|static mut\|lazy_static" --include="*.rs"`
- **FP:** Safe if all access paths properly synchronized
- **Impact:** Data corruption, double-spend in concurrent processing

### R-007: Soroban-Specific — TTL Extension Permissionless
- **Severity:** MEDIUM
- **Detection:** `grep -rn "extend_ttl\|bump\|instance().extend_ttl" --include="*.rs"`
- **FP:** By design in Soroban — but attacker extending enemy's TTL prevents cleanup
- **Impact:** Storage griefing, preventing state expiry

### R-008: Soroban-Specific — Missing require_auth
- **Severity:** HIGH
- **Detection:** `grep -rn "pub fn\|fn.*env" --include="*.rs"` then verify each public function calls `require_auth`
- **FP:** Safe if function is read-only or intended to be permissionless
- **Impact:** Unauthorized state modification

### R-009: Solana-Specific — Missing Signer Check
- **Severity:** HIGH
- **Detection:** `grep -rn "AccountInfo\|next_account_info" --include="*.rs"` then verify `is_signer` checked
- **FP:** Safe if account is PDA (no signer needed) or if Anchor `Signer<>` type used
- **Impact:** Unauthorized instruction execution

### R-010: Solana-Specific — PDA Seed Collision
- **Severity:** CRITICAL
- **Detection:** `grep -rn "find_program_address\|create_program_address" --include="*.rs"` — verify seeds are unique per entity
- **FP:** Safe if seeds include unique identifiers (user pubkey, mint, index)
- **Impact:** Two entities sharing PDA = data corruption or unauthorized access

### R-011: Silent Type Truncation in Casts (GMTrade #31 — $200K bounty)
- **Severity:** CRITICAL (direct fund theft)
- **Detection:** `grep -rn "as u8\|as u16\|as u32\|as u64\|as i8\|as i16\|as i32\|as i64" --include="*.rs" | grep -v test`
- **FP:** Safe if value is provably bounded before cast (preceding require/assert/if check). NOT safe if the input comes from oracle prices, user amounts, or timestamp calculations.
- **Impact:** Silent truncation wraps large values. Price $60K with precision 8 = 6 trillion, doesn't fit u32 (max 4.3B). Effective price drops to ~$17K. Attacker withdraws at wrong price = pool drain.
- **Hunt:** For every `as uN` cast, ask: can the source value exceed `uN::MAX`? Trace the source. If it comes from multiplication (amount * price * 10^precision), the product can easily overflow the target type.
- **Reference:** GMTrade ZESTPSC-31, `value as u32` in `Decimal::try_from_price`. One of 2 accepted findings out of ~25 submissions.
- **Kill signal:** Rust compiler does NOT warn on `as` casts. Unlike checked arithmetic, `as` is always silent. This is the #1 Rust-specific fund theft pattern.

### R-012: Cross-Market Accounting Mismatch in Shared Vaults (GMTrade #45 — $200K bounty)
- **Severity:** CRITICAL (direct fund theft via double payout)
- **Detection:** `grep -rn "record_transferred_out\|record_transferred_in\|transfer_out\|shared.*vault\|pool.*balance" --include="*.rs"`
- **FP:** Safe if the market that receives the credit is the same market that gets debited during payout.
- **Impact:** When routing through multiple markets in a shared-vault system, the swap credits Market A but the payout debits Market B. Market A retains a phantom balance. The attacker withdraws LP from Market A and extracts the phantom credit from the shared vault a second time.
- **Hunt:** Trace the full lifecycle: swap routing -> balance credit -> payout debit -> LP withdrawal. At each step, verify the SAME market entity is referenced. If swap routing uses `SwapDirection::Into(market_A)` but payout resolves `final_output_market` from the last swap path entry (market_B), the accounting is split.
- **Pattern:** Any DEX/perp with shared vaults + multi-market routing. The swap engine and the payout engine resolve the "responsible market" differently. One uses the order's current market, the other uses the swap path's last market.
- **Reference:** GMTrade #45, `swap_market.rs:383-393` credits into current market, `execute_order.rs:535-548` debits from last swap path market. Full Anchor PoC with deposit -> swap -> withdraw chain demonstrating double extraction.

### R-013: assert!/panic! on Peer-Controlled Data in Main Executor (TRON-C01 pattern, Monad #167)
- **Severity:** HIGH-CRITICAL (persistent crash loop)
- **Detection:** `grep -rn "assert!\|panic!\|unwrap()\|expect(" --include="*.rs" | grep -v test | grep -v "#\[cfg(test)]"`
- **FP:** Safe if the assert is on internally-derived state, NOT on data received from a network peer or external input. If the error message names the external actor ("server sent", "peer returned"), it's a peer-data assert = vulnerable.
- **Impact:** Process terminates. If in the main executor (not a spawned task), the entire node dies. On restart, same peer can trigger same crash = persistent crash loop.
- **Hunt:** For each assert!/panic!, trace the data source. If it originates from a network message, RPC call, or peer response, it must be a graceful error (return Err), not a panic. Internal consistency check on same function's other error paths: if 3 error cases return gracefully and 1 panics, the panic is an oversight.
- **Reference:** TRON AdvService `assert!(replaced.is_none())` on peer-sent duplicate response_index. Monad `assert!` on duplicate state sync response_index. Both in main executor path, both persistent crash loops.

---

## GO (Blockchain Nodes, Cosmos SDK, Spark SO)

### G-001: Goroutine Race Condition
- **Severity:** HIGH
- **Detection:** `grep -rn "go func\|go .*(" --include="*.go"` then check for shared state access
- **FP:** Safe if all shared state accessed via channels or sync.Mutex
- **Impact:** Data corruption, double-processing
- **Tool:** `go test -race ./...`

### G-002: Mutex Lock Contention Cross-Subsystem
- **Severity:** CRITICAL (TRON $100K pattern)
- **Detection:** `grep -rn "sync.Mutex\|sync.RWMutex\|\.Lock()\|\.RLock()" --include="*.go"`
- **FP:** Safe if untrusted input and consensus-critical paths use separate locks
- **Impact:** Consensus stall, block production halt

### G-003: Defer Ordering Bug
- **Severity:** MEDIUM
- **Detection:** `grep -rn "defer.*Unlock\|defer.*Close\|defer.*mu\." --include="*.go"`
- **FP:** Safe if defers are in correct LIFO order relative to operations
- **Impact:** Unlock before operation completes, resource leak

### G-004: Interface Nil Panic
- **Severity:** MEDIUM (DoS)
- **Detection:** `grep -rn "\.(\|type assertion" --include="*.go"` — check for `val, ok := x.(Type)` pattern
- **FP:** Safe if two-value assertion (val, ok) used instead of single (val only)
- **Impact:** Panic on nil interface or wrong type

### G-005: Unbounded Slice/Map from External Input
- **Severity:** HIGH (DoS)
- **Detection:** `grep -rn "make\(.*len\|append\(.*req\.\|range.*req\." --include="*.go"`
- **FP:** Safe if input size bounded before allocation
- **Impact:** OOM crash via malicious large input

### G-006: Error Swallowing (err != nil ignored)
- **Severity:** MEDIUM
- **Detection:** `grep -rn "if err != nil" --include="*.go"` — check that ALL error paths either return or handle
- **FP:** Deliberate ignore with `_ = err` is explicit
- **Impact:** Silent failure, inconsistent state

### G-007: SQL Injection in Raw Queries
- **Severity:** CRITICAL
- **Detection:** `grep -rn "fmt.Sprintf.*SELECT\|fmt.Sprintf.*INSERT\|fmt.Sprintf.*UPDATE\|Exec.*+.*req" --include="*.go"`
- **FP:** Safe if parameterized queries used (`db.Query("SELECT * WHERE id = ?", id)`)
- **Impact:** Full database compromise

### G-008: X-Forwarded-For Trust Without Validation
- **Severity:** HIGH
- **Detection:** `grep -rn "X-Forwarded-For\|x-forwarded-for\|RemoteAddr\|ClientIP" --include="*.go"`
- **FP:** Safe if XFF position configured and load balancer strips untrusted headers
- **Impact:** IP-based auth bypass (TRON/Spark pattern)

---

## CAIRO (Starknet)

### C-001: felt252 Overflow
- **Severity:** HIGH
- **Detection:** `grep -rn "felt252\|felt_add\|felt_mul" --include="*.cairo"`
- **FP:** Safe if arithmetic uses bounded types (u256, u128) instead of felt252
- **Impact:** Silent wrap at PRIME (2^251 + 17*2^192 + 1), wrong calculation

### C-002: Storage Collision (No Storage Offset)
- **Severity:** HIGH
- **Detection:** `grep -rn "storage_address\|storage_read\|storage_write" --include="*.cairo"`
- **FP:** Safe if using component-based storage with unique prefixes
- **Impact:** Two state variables sharing same storage slot = data corruption

### C-003: L1↔L2 Message Reentrancy
- **Severity:** HIGH
- **Detection:** `grep -rn "send_message_to_l1\|l1_handler\|from_address" --include="*.cairo"`
- **FP:** Safe if state finalized before L1 message sent
- **Impact:** Reentrancy via L1→L2 message callback during L2→L1 send

### C-004: Missing Access Control on l1_handler
- **Severity:** CRITICAL
- **Detection:** `grep -rn "#\[l1_handler\]" --include="*.cairo"` — verify each handler checks `from_address`
- **FP:** Safe if handler validates L1 sender address
- **Impact:** Anyone can trigger L1 handler with arbitrary data

### C-005: No Reentrancy Guard in Cairo
- **Severity:** MEDIUM
- **Detection:** Cairo contracts can be re-entered via `call_contract_syscall`. Check for state changes after external calls.
- **FP:** Safe if CEI pattern strictly followed
- **Impact:** State manipulation via reentrancy

---

## MOVE (Sui, Aptos)

### M-001: Missing Object Ownership Check
- **Severity:** HIGH
- **Detection:** `grep -rn "transfer::public_transfer\|transfer::transfer" --include="*.move"` — verify object ownership
- **FP:** Safe if Sui's ownership model enforced by type system (owned vs shared)
- **Impact:** Transfer of objects the caller doesn't own

### M-002: Shared Object Race Condition
- **Severity:** HIGH
- **Detection:** `grep -rn "shared_object\|public.*mut.*shared" --include="*.move"`
- **FP:** Safe if consensus-ordered access (Sui guarantees this for shared objects)
- **Impact:** State inconsistency in concurrent access

### M-003: Abort in Critical Path (DoS)
- **Severity:** MEDIUM
- **Detection:** `grep -rn "abort\|assert!" --include="*.move"`
- **FP:** Safe if abort conditions cannot be triggered by external input
- **Impact:** Transaction revert = channel blocking in bridge context
