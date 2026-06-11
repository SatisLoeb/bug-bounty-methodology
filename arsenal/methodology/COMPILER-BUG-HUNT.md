# COMPILER-BUG-HUNT — Smart contract compiler and toolchain bugs

solc, vyper, Rust/LLVM crypto optimizations, Cairo compiler, Move verifier, Noir→bb, Halo2 circuit builder.
Payout: Curve/Vyper 2023 = $70M drained via reentrancy guard miscompile.
Cycle: weeks of fuzzing per bug. Filter: compiler internals expertise.
Low base rate, massive payout when hit.

## Bug classes

| ID | Class | Detection signal |
|---|---|---|
| CBG-001 | solc optimizer reordering — IR pass moves stateful op across memory barrier | diff bytecode across `--optimize-runs` levels; fork-test diverges |
| CBG-002 | solc via-IR inline assembly corruption — Yul optimizer rewrites assembly incorrectly | test contract with inline assembly, compile with and without via-IR |
| CBG-003 | Vyper reentrancy guard miscompile (Curve 2023) — `@nonreentrant("lock")` key collision across functions | Vyper 0.2.15 / 0.2.16 / 0.3.0 — all affected |
| CBG-004 | Rust LLVM timing attack — constant-time crypto code made variable by `-O3` optimizer | dudect / t-test on release build |
| CBG-005 | Rust `as` silent truncation — already codified as R-011 in MULTI-LANG-PATTERNS | `grep -rn "as u8\|as u16\|as u32\|as u64"` in Rust crypto/financial code |
| CBG-006 | Solidity `unchecked` scope bleed — `unchecked {}` leaks into modifier code via IR optimization | diff behavior of modifier-applied unchecked vs explicit |
| CBG-007 | Inline assembly immediates off-by-one — solc generates wrong immediate value | test inline assembly arithmetic |
| CBG-008 | Move bytecode verifier reference tracking — verifier accepts refs that should be rejected | fuzz Move verifier with hand-crafted bytecode |
| CBG-009 | Cairo felt252 wrap at prime — arithmetic wraps at 2^251+17·2^192+1, often invariant-breaking | test Cairo arithmetic near PRIME |
| CBG-010 | Yul dispatch table collision — function selectors collide in Yul dispatch | test contracts with selector-colliding functions |
| CBG-011 | Noir→barretenberg circuit builder drop — `constrain` dropped in optimization | diff compiled constraint count to source constraint count |
| CBG-012 | zk circuit compiler elides constraint — halo2 / plonky2 circuit optimizer removes constraints deemed "redundant" | diff circuit advice columns pre/post optimization |
| CBG-013 | solc storage layout change across versions — upgradeable contracts' storage shifts silently | diff `storageLayout` output across solc versions |
| CBG-014 | Lambda hoisting — Solidity optimizer hoists state read out of loop, stale value used | test loop-body state reads |
| CBG-015 | Out-of-gas at prologue — function prologue gas changes across versions, OOG on some compilations | test gas-constrained entry points |

## Target landscape

| Compiler / toolchain | Bug path | Notes |
|---|---|---|
| solc (Solidity) | security@ethereum.org direct | active bug bounty, silent fixes common |
| vyper (Vyper) | security@vyperlang.org | post-Curve, more responsive |
| Rust / LLVM | llvm.org security | massive but cycle is long |
| Cairo (StarkNet) | StarkWare direct | relatively new |
| Move (Aptos/Sui) | Aptos / MystenLabs bounty | |
| Noir → barretenberg | Aztec direct $100K | new compiler |
| circom → snarkjs | CVE path | reference implementation |
| halo2 / plonky2 | Zcash / Mir Protocol / academic | |
| Foundry (tooling) | Paradigm / Foundry bounty | test framework bugs affect audits |
| Hardhat (tooling) | Nomic Foundation | |
| Remix (tooling) | Ethereum Foundation | |

## Grep arsenal (finding compiler-dependent code in target protocols)

```bash
# Protocols using old solc (possible unpatched bugs)
grep -rn "pragma solidity" --include="*.sol" | awk '{print $NF}' | sort -u

# Use of inline assembly (CBG-002, CBG-007 surface)
grep -rn "assembly\s*{" --include="*.sol"

# Use of unchecked (CBG-006 surface)
grep -rn "unchecked\s*{" --include="*.sol"

# Vyper version pin (CBG-003 relevance)
grep -rn "@version" --include="*.vy"

# Rust `as` casts in financial/crypto code (CBG-005 canonical)
grep -rn "as u8\|as u16\|as u32\|as u64\|as i8\|as i16\|as i32\|as i64" --include="*.rs" | grep -vi test

# Rust release profile (CBG-004)
cat Cargo.toml | grep -A 10 "\[profile.release\]"
# Check for opt-level, overflow-checks, lto — weak settings amplify bugs

# Move specific
grep -rn "bytecode" --include="*.move"

# Cairo felt arithmetic (CBG-009)
grep -rn "felt252\|Felt252" --include="*.cairo"
```

## Methodology (per compiler, weeks)

1. **Pick a compiler + version range** — e.g., solc 0.8.20-0.8.28.
2. **Diff compiler test suite failures across versions** — look for "fixed" entries. Each fix = pattern that was broken.
3. **Write a differential test harness:**
   ```
   for each compiler version:
       compile target contract
       deploy to fork or bytecode-compare
       run test corpus
   diff outputs — any divergence is a candidate
   ```
4. **Fuzz with `afl` / `cargo-fuzz` / `medusa`** — compiler as input, check for panic/crash/miscompile
5. **Known CVE replay** — for each CVE in compiler's bug tracker, check if live protocols deploy affected version
6. **Read compiler's own "miscompilation" label issues** — open issues = already-identified attack patterns that aren't fixed yet

## PoC pattern (miscompile across versions)

```python
# compiler-diff.py
import subprocess, json

def compile_and_run(src_path, solc_version):
    # 1. docker run ethereum/solc:<version> — compile
    # 2. Write bytecode to foundry project
    # 3. Run forge test with fork of same block
    # 4. Return test output state

versions = ["0.8.20", "0.8.23", "0.8.26", "0.8.30"]
for v1, v2 in combinations(versions, 2):
    state1 = compile_and_run("target.sol", v1)
    state2 = compile_and_run("target.sol", v2)
    if state1 != state2:
        print(f"DIVERGENCE between {v1} and {v2}: {diff(state1, state2)}")
```

## Cross-compiler attack (differential across vyper/solc)

If a protocol has a solc contract calling a vyper contract, and the compilers disagree on ABI encoding edge cases (dynamic bytes, struct packing):
- Call with input that both compilers accept but parse differently
- solc decodes as type A, vyper decodes as type B
- Invariant violation

```bash
# Find mixed-compiler protocols
find . -name "*.sol" -o -name "*.vy" | xargs grep -l "interface\|import"
```

## Foundry-specific bug hunt (tooling)

Tooling bugs that cause AUDITORS to miss bugs:
- `vm.expectRevert` swallowing wrong revert
- `vm.mockCall` stale / not cleared between tests
- Fuzzer corpus retention bugs
- Fork state corruption across tests

Submit to `github.com/foundry-rs/foundry/issues` with proof of missed finding.

## Integration with lifecycle

```bash
TARGET_HINTS="compiler solc vyper" \
  ~/arsenal/audit-lifecycle/bin/init-target.sh solc-miscompile-hunt
```

## Tool requirements

- `compiler-diff.py` — run target source across N compiler versions, diff bytecode + runtime behavior on fork
- `vyper-reentrancy-lint.sh` — scan for `@nonreentrant` keys that might collide (Curve pattern)
- `rust-cast-truncation-scanner.sh` — already needed for R-011 (MULTI-LANG pattern), extend here
- `solc-storage-layout-diff.py` — diff storage layout across upgrades

## Known recent patterns (replay-able)

- **Curve Vyper 2023** — `@nonreentrant("lock")` key reuse across functions allowed cross-function reentrancy, $70M drained
- **solc 0.8.13 via-IR** — inline assembly corruption
- **LLVM constant-folding in ring (Rust)** — non-constant-time comparison optimized
- **Cairo 0.x felt252 arithmetic** — overflow at prime, various protocol bugs
- **Move verifier 2023** — reference tracking bug, allowed unsafe borrow

## Long-cycle strategy

- **Pipeline:** dedicate ~10h/week background to compiler fuzzing with `medusa` or `cargo-fuzz`
- **Read** `secbit.github.io/kmszhang/solc-bugs/` and `github.com/ethereum/solidity/issues?q=label:miscompilation`
- **Subscribe** vyperlang blog and Aztec Noir compiler GitHub
- **Targets worth the cycle:** protocols using `assembly`, `unchecked`, Vyper, cross-compiler boundaries
- Cycle 4-8 weeks per bug target, but hit = $100K+ typically

## Disclosure notes

- **Compiler bugs themselves:** always to compiler security team first (solc, Vyper, LLVM). PGP-encrypt.
- **Protocol using vulnerable compiler version:** 90-day coordinated with both compiler team AND protocol team.
- **CVE-driven hunt:** if new CVE drops, immediate scan of live protocols using the affected compiler version — first-mover advantage.
