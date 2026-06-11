# Zero-Day Hunting Methodology — Systematic Component-Level Vulnerability Research

Methodology for systematically discovering zero-day vulnerabilities in shared infrastructure components. This is a fundamentally different posture from target-level bug bounty: instead of finding bugs in one application, you find bugs in components used by hundreds of applications.

**The economic model:**
- One zero-day in a shared lib = 1 CVE + N bug bounty reports (one per affected target)
- pac4j CVE-2026-29000: 1 vuln → every Java app using pac4j JWT is affected
- Cetus overflow: 1 vuln in liquidity math → $223M drained
- Solidity SOL-2026-1: 1 compiler bug → every contract compiled with 0.8.28-0.8.33 + `--via-ir` affected

**Pipeline integration:** This document feeds INTO the existing pipeline. Zero-days discovered here are validated against live targets using CRITICAL-HUNT-CHECKLIST, DEFI-FULLSTACK-CHECKLIST, and the submission pipeline (Kill Gate → Pre-Flight → /disclose).

**Relationship to other specs:**
- JWT-ARSENAL-SPEC.md → covers auth layer zero-days (JWT/OAuth2/SAML libs)
- PIPELINE-EXPANSION-SPEC.md → covers integration-level vulns (supply chain, proxy chains, messaging)
- THIS DOCUMENT → covers component-level zero-days across TWO tracks:
  - Track A (Domains 1-5): Crypto/DeFi infrastructure — parsers, crypto libs, compilers, bundlers, bridge clients
  - Track B (Domains 6-12): General infrastructure — HTTP servers, runtimes, databases, serialization, TLS/PKI, containers, DNS

---

## Architecture: The Zero-Day Research Loop

```
1. SELECT component class (parsers, crypto, compilers, bundlers, bridge clients,
                            HTTP servers, runtimes, databases, serialization, TLS, containers, DNS)
     ↓
2. ENUMERATE instances (specific libs, specific versions)
     ↓
3. MAP attack surface (entry points, trust boundaries, type conversions)
     ↓
4. BUILD harness (fuzzer, differential tester, formal checker)
     ↓
5. RUN (continuous — background process generating leads)
     ↓
6. TRIAGE leads → confirm zero-day → build PoC
     ↓
7. WEAPONIZE for bounty: identify affected targets → Kill Gate → submit
     ↓
8. DISCLOSE: CVE + responsible disclosure to lib maintainer
     ↓
Loop back to 5 (harness keeps running) or 1 (next component class)
```

**Critical difference from target hunting:** Steps 1-4 are upfront investment (days to weeks). Step 5 runs continuously in the background. Steps 6-8 are the payout. The ROI curve is inverted — high upfront cost, then each lead from step 5 converts to a finding with minimal marginal effort.

---

## Domain 1: Binary/Complex Format Parsers

### 1.0 Rationale

Parsers are the #1 historical source of zero-days across all software domains. In DeFi, parsers handle untrusted input at critical trust boundaries: transaction decoding, ABI decoding, proof deserialization, calldata parsing. A parser bug in a shared lib affects every application that decodes untrusted data through it.

### 1.1 Target Map

#### EVM Ecosystem

| Parser | Library | Language | Usage | Weekly Downloads | Priority |
|--------|---------|----------|-------|-----------------|----------|
| ABI decoder | `ethers.js` (defaultAbiCoder) | JS/TS | Transaction/event decoding | 3M+ | P1 |
| ABI decoder | `viem` (decodeAbiParameters) | JS/TS | Transaction/event decoding | 1.5M+ | P1 |
| ABI decoder | `alloy` (sol-types) | Rust | Foundry, Reth | High | P1 |
| ABI decoder | `web3.py` (ABICodec) | Python | Backend decoding | 500K+ | P2 |
| RLP decoder | `@ethereumjs/rlp` | JS/TS | Transaction parsing | 2M+ | P1 |
| RLP decoder | `rlp` (Python) | Python | Transaction parsing | 300K+ | P2 |
| Calldata decoder | ERC-4337 bundler validation | JS/Rust | UserOp parsing | Varies | P1 |
| SSZ decoder | Lodestar/Prysm/Lighthouse | JS/Go/Rust | Beacon chain consensus | Critical | P2 |
| Solidity ABI encoder (compiler) | `solc` | C++ | ABI encoding in contracts | Universal | P1 |

#### Solana/SVM Ecosystem

| Parser | Library | Language | Usage | Priority |
|--------|---------|----------|-------|----------|
| Borsh decoder | `borsh-js`, `borsh-rs` | JS/Rust | Account data deserialization | P1 |
| BCS decoder | `@mysten/bcs` | JS/TS | Sui transaction parsing | P2 |
| Anchor IDL decoder | `@coral-xyz/anchor` | JS/TS | Instruction parsing | P1 |
| SPL token parser | `@solana/spl-token` | JS/TS | Token account parsing | P1 |

#### ZK Ecosystem

| Parser | Library | Language | Usage | Priority |
|--------|---------|----------|-------|----------|
| Groth16 proof deserializer | `snarkjs` | JS | Client-side proof verification | P1 |
| PLONK proof deserializer | `snarkjs`, custom | JS/Rust | Proof parsing | P1 |
| Circom witness parser | `circom_runtime` | JS/WASM | Witness generation | P2 |
| R1CS parser | `snarkjs`, `bellman` | JS/Rust | Constraint system loading | P2 |
| Noir ACIR parser | `@noir-lang/acvm` | JS/WASM | Circuit intermediate repr | P2 |

### 1.2 Bug Pattern Taxonomy

Every parser bug falls into one of these categories:

| Pattern ID | Name | Mechanism | Impact | Detection Method |
|-----------|------|-----------|--------|-----------------|
| PARSE-001 | Length confusion | Length field parsed as signed → negative length → buffer underread/overread | Memory corruption, info leak | Fuzzing with extreme length values |
| PARSE-002 | Type confusion | Type tag mismatched with actual data → wrong decoder applied | Logic error, bypass | Differential testing: encode with type A, decode claiming type B |
| PARSE-003 | Truncation | Input truncated mid-field → partial parse accepted as valid | State corruption | Fuzzing with truncated inputs |
| PARSE-004 | Integer overflow in offset | Offset computation overflows → wraps around → reads wrong data | Info leak, corruption | Fuzzing with large offset values near MAX_INT |
| PARSE-005 | Nested depth bomb | Deeply nested structures → stack overflow or quadratic parsing | DoS | Recursive nesting fuzzing |
| PARSE-006 | Encoding confusion | UTF-8 vs Latin-1 vs raw bytes → different parse results | Logic bypass | Cross-encoding differential |
| PARSE-007 | Null/zero handling | Null bytes or zero-length fields → unexpected parser behavior | Various | Fuzzing with \x00 insertion |
| PARSE-008 | Duplicate key ambiguity | Duplicate keys in map/struct → first-wins vs last-wins | Logic bypass | Duplicate key injection |
| PARSE-009 | Canonical form bypass | Non-canonical encoding accepted → hash/signature mismatch | Signature bypass | Generate non-canonical encodings |
| PARSE-010 | Implicit type coercion | String "0" vs integer 0 vs boolean false → treated differently | Logic bypass | Type permutation testing |

### 1.3 Fuzzing Harness Architecture

```
                    ┌─────────────────┐
                    │  Corpus Manager  │
                    │  (valid samples  │
                    │   + mutations)   │
                    └────────┬────────┘
                             │
                    ┌────────▼────────┐
                    │  Mutator Engine  │
                    │  - bit flips     │
                    │  - length mods   │
                    │  - type swaps    │
                    │  - truncation    │
                    │  - overflow vals  │
                    │  - null injection │
                    │  - nesting depth  │
                    │  - dup keys       │
                    └────────┬────────┘
                             │
              ┌──────────────┼──────────────┐
              ▼              ▼              ▼
     ┌────────────┐ ┌────────────┐ ┌────────────┐
     │  Parser A   │ │  Parser B   │ │  Parser C   │
     │  (ethers)   │ │  (viem)     │ │  (alloy)    │
     └──────┬─────┘ └──────┬─────┘ └──────┬─────┘
            │              │              │
            ▼              ▼              ▼
     ┌─────────────────────────────────────────┐
     │         Differential Oracle              │
     │  Compare: result_A vs result_B vs result_C│
     │  Flag: any divergence in:                │
     │    - accept/reject decision              │
     │    - decoded values                       │
     │    - error type/location                  │
     │    - memory usage (OOM signals)           │
     └────────────────────┬────────────────────┘
                          │
                          ▼
                   ┌──────────────┐
                   │  Triage Queue │
                   │  (divergences │
                   │   to analyze)  │
                   └──────────────┘
```

**Initial corpus sources:**
- Real mainnet transactions (etherscan API → raw tx data)
- Real Solana instructions (Solscan → raw instruction data)
- Protocol-specific test vectors from lib test suites
- Manually crafted edge cases per PARSE-001 through PARSE-010

**Mutator strategies (priority order):**

| Strategy | Target Bug Pattern | Implementation |
|----------|-------------------|----------------|
| Length field mutation | PARSE-001, PARSE-004 | Replace length bytes with 0, MAX, MAX-1, negative equivalents |
| Type tag swapping | PARSE-002, PARSE-010 | For ABI: swap uint256↔int256, bytes↔string, fixed↔dynamic |
| Truncation | PARSE-003 | Cut input at every byte offset from 1 to len-1 |
| Offset overflow | PARSE-004 | Set offset fields to values near 2^32-1 and 2^256-1 |
| Depth bombing | PARSE-005 | Nest arrays/tuples 100, 1000, 10000 deep |
| Null injection | PARSE-007 | Insert \x00 at every position |
| Duplicate fields | PARSE-008 | For ABI tuple: duplicate field with different value |
| Non-canonical encoding | PARSE-009 | RLP: use long form for short values; ABI: non-zero padding |

**Implementation:**
- Fuzzer: custom Python orchestrator + `atheris` (Python), `jazzer` (Java), `cargo-fuzz` (Rust), `jsfuzz` (JS)
- Differential oracle: compare N parsers on same input
- Crash detection: ASAN/MSAN for native code, exception catching for managed code
- Output: `{input_hex, parser_results[], divergence_type, crash_info}`

**Effort estimate:** 5-7 days for ABI decoder differential fuzzer (ethers vs viem vs alloy). Each additional parser family = 2-3 days.

### 1.4 Integration with Bug Bounty Pipeline

```
Zero-day found in ethers.js ABI decoder
  ↓
1. CVE request to ethers.js maintainers (responsible disclosure)
  ↓
2. Identify affected targets:
   - Search bounty programs for ethers.js usage
   - `grep -rn "ethers\|@ethersproject" package.json` in each target
   - Each target using affected version = separate bounty report
  ↓
3. Per target: Kill Gate → is this reachable in THEIR code path?
   - Does their contract/frontend decode untrusted ABI data using ethers?
   - Can an attacker supply the malformed input?
  ↓
4. PoC per target: craft input that triggers the bug in THEIR specific context
  ↓
5. Submit per target: /disclose with CVE reference + target-specific impact
```

---

## Domain 2: Crypto Implementations in WASM/JS

### 2.0 Rationale

Browser-side cryptography is a growing attack surface in DeFi. Wallets, ZK provers, and signature verifiers run in the browser via WASM or pure JS. These implementations face threat models that traditional crypto audits don't cover: timing side-channels that survive compilation to WASM, integer type mismatches at the JS↔WASM boundary, and memory safety issues in WASM's flat linear memory.

### 2.1 Target Map

| Library | Language | Compiles to | Usage | Weekly Downloads | Priority |
|---------|----------|-------------|-------|-----------------|----------|
| `@noble/curves` | JS/TS | Native JS | secp256k1, ed25519 in ethers/viem | 5M+ | P1 |
| `@noble/hashes` | JS/TS | Native JS | SHA, Keccak in ethers/viem | 5M+ | P1 |
| `@noble/ciphers` | JS/TS | Native JS | AES, ChaCha | 500K+ | P2 |
| `snarkjs` | JS | Native JS + WASM | Groth16/PLONK proving/verifying | 100K+ | P1 |
| `circomlibjs` | JS | Native JS | Pedersen, Poseidon, EdDSA for circuits | 50K+ | P1 |
| `libsodium.js` | C → WASM | WASM | NaCl crypto in browsers | 300K+ | P2 |
| `tweetnacl` | JS | Native JS | Ed25519, x25519 | 3M+ | P2 |
| `@solana/web3.js` (crypto parts) | JS/TS | Native JS | Ed25519 signing for Solana | 1M+ | P1 |
| `@polkadot/wasm-crypto` | Rust → WASM | WASM | Sr25519, Ed25519 for Polkadot | 200K+ | P2 |
| `@mysten/sui.js` (crypto) | JS/TS | Native JS | Signing for Sui | 100K+ | P2 |
| `@aztec/bb.js` | C++ → WASM | WASM | Barretenberg prover | Growing | P2 |

### 2.2 Bug Pattern Taxonomy

| Pattern ID | Name | Mechanism | Impact | Detection |
|-----------|------|-----------|--------|-----------|
| CRYPTO-001 | Timing side-channel | Branch on secret data → timing variation observable via `performance.now()` | Key extraction | Timing measurement harness |
| CRYPTO-002 | JS↔WASM type mismatch | JS BigInt truncated to WASM i64, or JS number loses precision at 2^53 | Incorrect computation → invalid signatures or proofs | Differential: JS vs native implementation |
| CRYPTO-003 | WASM linear memory exposure | No ASLR in WASM; heap is predictable ArrayBuffer; secrets adjacent to public data | Secret extraction via speculative execution or side-channel | Memory layout analysis |
| CRYPTO-004 | Nonce reuse/bias | PRNG seeded from `Math.random()` or `Date.now()` instead of `crypto.getRandomValues()` | Nonce bias → key recovery (ECDSA) | PRNG source analysis + statistical testing |
| CRYPTO-005 | Field element reduction error | Reduction mod p incorrect for edge cases (p-1, p, p+1, 2p-1) | Incorrect curve arithmetic → signature forgery | Boundary value testing |
| CRYPTO-006 | Scalar multiplication edge case | Multiplication by 0, 1, n-1, n (group order) not handled | Identity point accepted, wrong result | Edge case test suite |
| CRYPTO-007 | Encoding/decoding asymmetry | Point compression/decompression doesn't round-trip | Signature on different point than intended | Encode → decode → re-encode differential |
| CRYPTO-008 | Cofactor handling | Small-subgroup attack possible if cofactor not cleared | Malleable signatures, key recovery | Test with points of small order |
| CRYPTO-009 | Hash domain separation | Missing or inconsistent domain separators | Cross-protocol replay, collision | Compare domain tags between operations |
| CRYPTO-010 | Constant-time violation | Non-constant-time comparison or branching in WASM | Timing oracle for secret recovery | dudect statistical timing test |

### 2.3 Testing Methodology

#### 2.3.1 Differential Testing (CRYPTO-002, CRYPTO-005, CRYPTO-006, CRYPTO-007)

```
Reference implementation: libsodium (C), or known-correct test vectors from NIST/RFC

For each operation (sign, verify, derive, hash):
  1. Generate N random inputs (including edge cases: 0, 1, p-1, p, n-1, n, 2^53, 2^53+1)
  2. Execute in target lib (JS/WASM)
  3. Execute in reference implementation
  4. Compare results byte-for-byte
  5. Any divergence → investigate

Edge case corpus for elliptic curve operations:
  - Scalar: 0, 1, 2, n-1, n, n+1, 2^128, 2^256-1, random
  - Point: identity, generator, generator*2, point at infinity, random valid, invalid (not on curve)
  - Field element: 0, 1, p-1, p, p+1, 2p-1, random
  - For WASM: values near 2^32, 2^53, 2^64 (boundary of JS number / WASM types)
```

**Implementation:** Test harness per lib that exercises all public API functions with the edge case corpus. Output: `{operation, input, expected_output, actual_output, match: bool}`.

#### 2.3.2 Timing Analysis (CRYPTO-001, CRYPTO-010)

```
Methodology: dudect (constant-time verification)

1. Prepare two input classes:
   - Class A: fixed secret, random message
   - Class B: random secret, random message

2. Measure execution time for N=10000+ iterations per class

3. Apply Welch's t-test:
   - |t| < 4.5 → no detectable timing leak
   - |t| > 4.5 → timing leak present → investigate

4. For WASM specifically:
   - Measure with performance.now() (microsecond resolution in browsers)
   - Measure with SharedArrayBuffer + Atomics (nanosecond resolution if available)
   - Test in V8 (Chrome), SpiderMonkey (Firefox), JavaScriptCore (Safari)
     → Different engines optimize differently → leak may be engine-specific

5. Isolate the leaking operation:
   - Binary search: measure sub-operations individually
   - Common sources: table lookups, conditional branches, variable-time multiplication
```

**Tool:** Custom JS harness using `performance.now()` + statistical analysis. Portable to browser and Node.js.

#### 2.3.3 PRNG Quality Analysis (CRYPTO-004)

```bash
# For each target lib, identify the randomness source:
grep -rn "Math\.random\|Date\.now\|crypto\.getRandomValues\|randomBytes\|getRandomValues" \
  --include="*.js" --include="*.ts" node_modules/<target_lib>/

# If Math.random() or Date.now() is used ANYWHERE in a cryptographic context:
# → CRITICAL: predictable nonces → ECDSA key recovery

# Check for nonce generation in signing:
grep -rn "nonce\|k_value\|random.*sign\|sign.*random" \
  --include="*.js" --include="*.ts" node_modules/<target_lib>/

# Check for RFC 6979 deterministic nonce (safe):
grep -rn "rfc6979\|hmac.*drbg\|deterministic.*nonce\|hmacDrbg" \
  --include="*.js" --include="*.ts" node_modules/<target_lib>/
```

- If lib uses `Math.random()` for any crypto operation → CRITICAL zero-day
- If lib uses `crypto.getRandomValues()` → safe (OS entropy)
- If lib uses RFC 6979 deterministic nonces → safe (no randomness needed)
- If lib rolls custom PRNG → investigate thoroughly

#### 2.3.4 Small Subgroup / Invalid Curve Attacks (CRYPTO-008)

```
For each curve implementation:

1. Generate points of small order (for curves with cofactor > 1):
   - Ed25519: cofactor 8, small-subgroup points of order 2, 4, 8
   - secp256k1: cofactor 1, but check identity point handling

2. Submit small-order points as public keys:
   - Does key validation reject them?
   - If accepted, what happens during ECDH/signing?

3. For ECDH specifically:
   - Result should be multiplied by cofactor (or point validated)
   - If not → attacker can force shared secret to be identity → key recovery

4. For signature verification:
   - Submit signature with R = small-order point
   - Does verification reject? Or does it accept malleable signatures?
```

### 2.4 Effort & Roadmap

| Phase | Effort | Deliverable |
|-------|--------|-------------|
| Edge case corpus + test harness framework | 3 days | Reusable across all crypto libs |
| `@noble/curves` full audit (differential + timing + edge cases) | 5 days | First zero-day hunt pass |
| `snarkjs` proof deserializer + verifier audit | 4 days | ZK-specific focus |
| `circomlibjs` (Poseidon, Pedersen, EdDSA) | 3 days | ZK primitive audit |
| Timing analysis tooling (dudect for JS/WASM) | 2 days | Reusable timing harness |
| Remaining P1 libs | 2-3 days each | Incremental coverage |

---

## Domain 3: ERC-4337 Account Abstraction Bundlers & Paymasters

### 3.0 Rationale

Account Abstraction is the newest and least audited infrastructure layer in EVM. Bundlers and paymasters handle untrusted UserOperations and make financial decisions (gas sponsorship) based on validation logic that's often trivially bypassable. The attack surface is large: every bundler has its own implementation of the validation rules, and the simulation-execution gap is a well-documented but poorly defended vulnerability class.

### 3.1 Target Map

| Component | Implementation | Language | Deployment | Priority |
|-----------|---------------|----------|------------|----------|
| Bundler | Infinitism (eth-infinitism/bundler) | TS | Reference implementation | P1 |
| Bundler | Biconomy | Go | Major AA provider | P1 |
| Bundler | Pimlico (Alto) | TS | Major AA provider | P1 |
| Bundler | Alchemy (Rundler) | Rust | Major AA provider | P1 |
| Bundler | Stackup | Go | Open-source bundler | P2 |
| Bundler | Voltaire | Python | EF-funded reference | P2 |
| EntryPoint | eth-infinitism/account-abstraction | Solidity | v0.6, v0.7 deployed | P1 |
| Paymaster | Biconomy Paymaster | Solidity | Token/sponsored paymasters | P1 |
| Paymaster | Pimlico Paymaster | Solidity | Verifying paymaster | P1 |
| Paymaster | Stackup Paymaster | Solidity | Simple paymaster | P2 |
| Smart Account | Safe{Core} (4337 module) | Solidity | Safe AA module | P1 |
| Smart Account | Biconomy Smart Account v2 | Solidity | Modular account | P1 |
| Smart Account | Kernel (ZeroDev) | Solidity | Modular account | P2 |
| Smart Account | Coinbase Smart Wallet | Solidity | Consumer wallet | P1 |

### 3.2 Bug Pattern Taxonomy

| Pattern ID | Name | Mechanism | Impact | Severity |
|-----------|------|-----------|--------|----------|
| AA-001 | Simulation-execution gap | Bundler simulates UserOp → passes. On-chain execution → different result due to state change between simulation and execution | Bundler gas drain, failed bundles | HIGH |
| AA-002 | Paymaster signature replay | Paymaster validates signature but doesn't bind it to specific UserOp hash → same signature reused for different operations | Drain paymaster deposit | CRITICAL |
| AA-003 | Paymaster validation bypass | Paymaster `validatePaymasterUserOp()` has logic errors: wrong hash computed, wrong signer checked, missing expiry validation | Unauthorized gas sponsorship → drain | CRITICAL |
| AA-004 | UserOp hash collision | Two different UserOps produce same hash → bundler treats as duplicate when they're not, or accepts replay | Transaction replay, censorship | HIGH |
| AA-005 | Gas estimation manipulation | Attacker submits UserOp that costs X gas in simulation but Y >> X on-chain → bundler pays the difference | Bundler financial loss | HIGH |
| AA-006 | Storage access violation | UserOp accesses storage slots that should be banned during validation (ERC-7562 rules) but bundler doesn't catch it | Simulation-execution gap exploitable | HIGH |
| AA-007 | Bundler mempool griefing | Flood bundler mempool with valid-looking UserOps that will all revert on-chain → bundler wastes gas | Bundler DoS + financial drain | MEDIUM |
| AA-008 | Factory validation bypass | Factory creates account at deterministic address → attacker front-runs with different factory → account controlled by attacker | Account takeover | CRITICAL |
| AA-009 | Module installation abuse | Modular accounts (Kernel, Biconomy v2) allow installing modules → malicious module approved by user unknowingly | Account takeover | CRITICAL |
| AA-010 | Paymaster postOp manipulation | `postOp()` callback can be manipulated by the UserOp execution → paymaster accounting corrupted | Paymaster drain | HIGH |

### 3.3 Testing Methodology

#### 3.3.1 Bundler Validation Differential

```
Same principle as JWT Tool 7 (cross-lib differential):

1. Craft a corpus of UserOperations:
   - Valid standard UserOps (baseline)
   - UserOps with banned opcodes in initCode/callData
   - UserOps with storage access violations (ERC-7562)
   - UserOps with factory + paymaster combinations
   - UserOps with maximum gas values (near block gas limit)
   - UserOps with zero gas values
   - UserOps referencing non-existent accounts
   - UserOps with mismatched nonces

2. Submit each UserOp to multiple bundlers:
   - eth_sendUserOperation to each bundler's RPC
   - Record: accepted/rejected, error message, simulation result

3. Divergence analysis:
   - UserOp accepted by bundler A but rejected by bundler B → investigate
   - UserOp accepted by bundler but reverts on-chain → AA-001 (simulation gap)
   - UserOp rejected by bundler but would succeed on-chain → false negative (censorship)
```

#### 3.3.2 Paymaster Signature Analysis

```bash
# For each paymaster contract:

# 1. Identify what's signed
grep -rn "getHash\|_packUserOp\|userOpHash\|ECDSA.recover\|SignatureChecker" --include="*.sol"
# What fields are included in the hash? What's missing?
# Missing nonce → replay. Missing sender → cross-account. Missing chainId → cross-chain replay.

# 2. Check signature binding
# Does the signed hash include ALL of: sender, nonce, callData, chainId, paymaster address?
# If callData is NOT signed → attacker can change the operation while keeping the same sponsorship

# 3. Check expiry
grep -rn "validUntil\|validAfter\|block\.timestamp.*paymaster\|expiry.*paymaster" --include="*.sol"
# No expiry → signature valid forever → replay indefinitely

# 4. Check re-entrancy in postOp
grep -rn "postOp\|_postOp\|PostOpMode" --include="*.sol"
# Can the UserOp execution manipulate state that postOp reads?
# If yes → AA-010 (postOp manipulation)
```

#### 3.3.3 Storage Access Rule Verification

```
ERC-7562 defines which storage slots a UserOp can access during validation.
Each bundler must enforce these rules. Test compliance:

1. Craft UserOps that access banned storage during validation:
   - Other accounts' storage
   - Unrelated contracts' storage
   - Block-dependent values (block.timestamp, block.number, block.basefee)

2. Submit to each bundler:
   - If accepted → bundler violates ERC-7562 → simulation-execution gap exploitable
   - If rejected → compliant

3. Craft UserOps that access storage that's borderline-allowed:
   - Sender's own storage (allowed)
   - Factory's storage during first deployment (allowed)
   - Paymaster's storage (allowed but constrained)
   - Associated storage of staked entities (allowed under staking rules)

4. Edge cases:
   - DELEGATECALL to a contract that accesses banned storage
   - CREATE2 during validation that deploys a contract accessing banned storage
   - Transient storage (EIP-1153) — are TLOAD/TSTORE covered by the rules?
```

### 3.4 Grep Patterns

```bash
### Account Abstraction (ERC-4337)

# EntryPoint and UserOp handling
grep -rn "IEntryPoint\|handleOps\|UserOperation\|PackedUserOperation" --include="*.sol"
grep -rn "validateUserOp\|_validateSignature\|missingAccountFunds" --include="*.sol"

# Paymaster patterns
grep -rn "IPaymaster\|validatePaymasterUserOp\|postOp\|PaymasterAndData" --include="*.sol"
grep -rn "getHash.*paymaster\|_packPaymasterData\|verifyingSigner" --include="*.sol"

# Modular accounts
grep -rn "installModule\|IModule\|IValidator\|IExecutor\|IHook\|IFallback" --include="*.sol"
grep -rn "execute\|executeBatch\|executeUserOp\|delegateExecute" --include="*.sol"

# Factory patterns
grep -rn "createAccount\|CREATE2\|deployCounterFactual\|getAddress" --include="*.sol"
grep -rn "initCode\|factory\|accountFactory" --include="*.sol"

# Nonce management
grep -rn "getNonce\|nonceKey\|nonceSequence\|nonce.*2d" --include="*.sol"
```

### 3.5 Effort & Roadmap

| Phase | Effort | Deliverable |
|-------|--------|-------------|
| UserOp corpus generation (50+ adversarial operations) | 2 days | Reusable test suite |
| Bundler differential testing (3 bundlers) | 3 days | Divergence report |
| Paymaster contract audit framework | 3 days | Reusable analysis per paymaster |
| ERC-7562 compliance checker | 2 days | Automated storage rule verification |
| Each additional bundler | 1 day | Incremental coverage |

---

## Domain 4: Compiler/Transpiler Bugs in Smart Contract Languages

### 4.0 Rationale

A compiler bug is the ultimate zero-day: it affects EVERY contract compiled with the vulnerable version. Solidity SOL-2026-1 (§6b.3 in existing pipeline) demonstrated this. The bug was in the IR optimizer — `delete` on a transient storage variable with a persistent storage variable of the same type caused the wrong opcode to be emitted (`sstore` instead of `tstore`). This class of bug is detectable by differential fuzzing and has historically been underhunted.

### 4.1 Target Map

| Compiler | Language | Deployed TVL | Bug History | Priority |
|----------|----------|-------------|-------------|----------|
| `solc` | Solidity | $100B+ | SOL-2024-* series, SOL-2026-1 | P1 |
| `vyper` | Vyper | $5B+ | Curve reentrancy bug 2023, multiple 2024 | P1 |
| `cairo` | Cairo (StarkNet) | $1B+ | Young compiler, under-audited | P2 |
| `move` | Move (Sui/Aptos) | $3B+ | Bytecode verifier bugs | P2 |
| `nargo` (Noir) | Noir | Growing | Very young, rapid development | P2 |
| `circom` | Circom | Growing | Under-constrained circuits documented | P2 |
| `solang` | Solidity (alternative) | Minimal | Alternative Solidity compiler | P3 |

### 4.2 Differential Fuzzing Methodology

#### 4.2.1 Same-Language Differential (solc versions)

```
Method: Compile the same Solidity source with different compiler versions
(or same version with/without optimizer, with/without --via-ir)
and compare the resulting bytecode behavior.

1. Source generation:
   - Mutate existing test contracts from the Solidity test suite
   - Focus on optimizer-relevant patterns:
     - Dead code elimination
     - Constant folding
     - Storage layout packing
     - ABI encoding/decoding
     - Memory management (free memory pointer)
     - Transient storage operations (EIP-1153)
     - EIP-7702 related patterns

2. Compilation matrix:
   - Version A: solc 0.8.28 (pre-bug)
   - Version B: solc 0.8.33 (post-bug)
   - Optimizer: off vs on (200 runs) vs on (10000 runs)
   - Pipeline: legacy vs --via-ir
   → 2 versions × 3 optimizer settings × 2 pipelines = 12 variants

3. Behavioral comparison:
   - Deploy all 12 variants on a local anvil fork
   - Execute identical calldata on each
   - Compare: return values, state changes, gas usage, revert behavior

4. Divergence classification:
   - Gas-only difference: informational (optimizer working as intended)
   - Return value difference: CRITICAL (semantic bug)
   - Revert vs success difference: CRITICAL (correctness bug)
   - State change difference: CRITICAL (storage bug)
```

#### 4.2.2 Cross-Language Differential (Solidity vs Vyper)

```
For contracts with equivalent logic in both languages:

1. Write equivalent implementations of:
   - ERC-20 token
   - ERC-4626 vault
   - AMM swap function
   - Reentrancy guard
   - Timelocked admin

2. Compile both with their respective compilers

3. Execute identical calldata sequences on both

4. Compare results:
   - If Solidity and Vyper produce different results for the same logic
     → at least one has a bug
   - Cross-reference with language spec to determine which is correct
```

#### 4.2.3 Optimizer-Specific Fuzzing

```
The optimizer is the most bug-prone component of any compiler.
Target specific optimizer passes:

Solidity (solc):
- Yul optimizer: SSA transform, common subexpression elimination,
  dead code elimination, loop optimization
- IR pipeline (--via-ir): Yul → optimized Yul → EVM bytecode
- ABI encoder v2 (abicoder v2): complex type encoding

Vyper:
- Vyper IR optimizer: newer, less tested than solc
- ABI encoding: different implementation than solc
- Storage layout: different packing strategy

Fuzzing strategy:
1. Generate random Yul/Vyper IR programs
2. Optimize with compiler
3. Execute both optimized and unoptimized versions
4. Compare results
5. Divergence → optimizer bug
```

### 4.3 Grep Patterns for Deployed Contract Vulnerability

When a compiler bug is found, identify affected deployed contracts:

```bash
# Check compiler version of deployed contracts
# Etherscan API: get compiler version from verified source
curl -s "https://api.etherscan.io/api?module=contract&action=getsourcecode&address=${CONTRACT}&apikey=${ETHERSCAN_KEY}" | \
  jq -r '.result[0].CompilerVersion'

# For a known buggy version range (e.g., 0.8.28-0.8.33):
# Search DeFiLlama/DeBank for high-TVL contracts compiled with those versions

# Check if specific buggy pattern exists in bytecode:
# SOL-2026-1: TSTORE where SSTORE should be (or vice versa)
cast code ${CONTRACT} --rpc-url ${RPC} | grep -c "5d"  # TSTORE opcode
cast code ${CONTRACT} --rpc-url ${RPC} | grep -c "55"  # SSTORE opcode
# Presence of TSTORE in a contract compiled with 0.8.28-0.8.33 + --via-ir → potentially affected
```

### 4.4 Effort & Roadmap

| Phase | Effort | Deliverable |
|-------|--------|-------------|
| Solidity differential fuzzer (version × optimizer matrix) | 5 days | Automated fuzzer + divergence detector |
| Vyper differential fuzzer | 3 days | Same framework adapted for Vyper |
| Solidity-Vyper cross-language differential | 3 days | Equivalent contracts + comparison harness |
| Optimizer-specific Yul fuzzer | 5 days | Random Yul program generator + executor |
| Deployed contract scanner (for known bugs) | 2 days | `affected-contracts.sh` — identifies deployed contracts with buggy compiler version |

---

## Domain 5: Bridge Relayer/Validator Client Implementations

### 5.0 Rationale

Bridge smart contracts get audited. The relayer/validator client software — the off-chain component that observes the source chain, generates attestations, and submits them to the destination — is audited far less. These clients parse block headers, verify merkle proofs, handle reorgs, and manage consensus. Each of these operations is a parser problem (Domain 1) combined with consensus logic.

### 5.1 Target Map

| Bridge | Client Software | Language | TVL Secured | Priority |
|--------|----------------|----------|-------------|----------|
| Wormhole | Guardian Node | Go | $3B+ | P1 |
| LayerZero | DVN client implementations | Various | $5B+ | P1 |
| Axelar | Validator node | Go | $1B+ | P2 |
| Hyperlane | Agent (relayer, validator) | Rust | $500M+ | P2 |
| CCIP | DON (Chainlink) | Go | $2B+ | P2 |
| Across | Relayer | TS | $500M+ | P2 |
| Stargate | Relayer (LayerZero-based) | TS | $500M+ | P2 |
| Polyhedra (zkBridge) | Prover/Verifier | Rust | $1B+ | P2 |
| deBridge | Validator | Go | $500M+ | P2 |

### 5.2 Bug Pattern Taxonomy

| Pattern ID | Name | Mechanism | Impact | Severity |
|-----------|------|-----------|--------|----------|
| BRIDGE-001 | Block header parsing error | Malformed header accepted as valid by client → false attestation | False bridge attestation → mint without burn | CRITICAL |
| BRIDGE-002 | Merkle proof bypass | Proof verification accepts crafted proof → non-existent event attested | Unauthorized minting on destination | CRITICAL |
| BRIDGE-003 | Reorg handling failure | Client attests block that gets reorged → attestation no longer valid but already processed | Double-spend across chains | CRITICAL |
| BRIDGE-004 | Finality assumption error | Client considers block final before actual finality → attestation on non-final block | Same as BRIDGE-003 | HIGH |
| BRIDGE-005 | Consensus split | Disagreement between validators on which block is canonical → split attestations | Bridge halt or double-spend | HIGH |
| BRIDGE-006 | Rate limiting bypass | Client doesn't enforce rate limits on attestation requests → spam valid attestations | DoS on destination chain | MEDIUM |
| BRIDGE-007 | Signature aggregation error | BLS/multisig aggregation logic has edge case → invalid aggregate accepted | False attestation with insufficient signers | CRITICAL |
| BRIDGE-008 | Chain ID confusion | Client confuses source chains (e.g., Ethereum vs Ethereum Classic) | Cross-chain replay | CRITICAL |
| BRIDGE-009 | Event log parsing error | Client misparses event data → wrong amount/recipient in attestation | Incorrect bridging amount | CRITICAL |
| BRIDGE-010 | RPC response manipulation | Client trusts RPC response without independent verification → attacker controls RPC → false data | Arbitrary attestation generation | CRITICAL |

### 5.3 Testing Methodology

#### 5.3.1 Block Header Fuzzing

```
For each bridge client:

1. Collect valid block headers from the source chain (100+ headers)

2. Mutate:
   - Modify stateRoot (should invalidate receipts proof)
   - Modify parentHash (should break chain continuity)
   - Modify blockNumber (non-sequential)
   - Modify timestamp (out of bounds)
   - Modify gasLimit/gasUsed (exceed limits)
   - Modify difficulty/baseFee (invalid values)
   - Truncate header
   - Add extra fields

3. Submit mutated headers to client's verification logic

4. Expected: ALL mutations rejected
   Finding: ANY mutation accepted → BRIDGE-001
```

#### 5.3.2 Merkle Proof Manipulation

```
For each bridge client's proof verification:

1. Generate valid proofs for real events

2. Manipulate proofs:
   - Swap sibling hashes in proof path
   - Truncate proof (remove last N levels)
   - Empty proof for non-existent event
   - Proof with extra nodes (longer than necessary)
   - Proof with duplicate nodes
   - Proof for event on wrong block

3. Submit manipulated proofs to verification logic

4. Expected: ALL manipulations rejected
   Finding: ANY manipulation accepted → BRIDGE-002
```

#### 5.3.3 Reorg Simulation

```
1. Set up local fork with the bridge client

2. Simulate sequence:
   a. Block N published with bridge event
   b. Client observes and generates attestation
   c. Block N reorged (replaced by block N' without the event)
   d. Check: does client retract attestation?
   e. Check: does client prevent submission of retracted attestation?

3. Edge cases:
   - Reorg depth 1 (single block)
   - Reorg depth > client's confirmation requirement
   - Reorg that changes event data (same event, different amount)
   - Reorg on L2 rollup (different finality model)
```

#### 5.3.4 RPC Trust Verification

```bash
# For each bridge client, identify how it connects to source chain:

# 1. Does it run its own full node or use external RPC?
grep -rn "rpc_url\|endpoint\|provider\|JsonRpcProvider\|EthClient" --include="*.go" --include="*.rs" --include="*.ts"

# 2. Does it verify RPC responses independently?
grep -rn "verifyHeader\|verifyProof\|validateBlock\|lightClient\|stateRoot.*verify" --include="*.go" --include="*.rs" --include="*.ts"

# 3. Does it use multiple RPC sources for consensus?
grep -rn "quorum\|consensus\|multipleProviders\|fallbackProvider" --include="*.go" --include="*.rs" --include="*.ts"

# If single RPC without independent verification → BRIDGE-010
# Attacker who controls the RPC can feed arbitrary data to the client
```

### 5.4 Effort & Roadmap

| Phase | Effort | Deliverable |
|-------|--------|-------------|
| Block header fuzzer (EVM) | 3 days | Reusable across all EVM bridge clients |
| Merkle proof manipulator | 2 days | Reusable proof mutation framework |
| Wormhole Guardian analysis | 5 days | First full client audit |
| Reorg simulation framework | 3 days | Local fork + reorg injection |
| Each additional bridge client | 3-5 days | Incremental coverage |

---

## TRACK B: GENERAL INFRASTRUCTURE ZERO-DAYS (Domains 6-12)

Track A (Domains 1-5) targets crypto/DeFi-specific infrastructure. Track B targets the general infrastructure that EVERYTHING runs on — including every DeFi protocol. A zero-day in Nginx affects more targets than a zero-day in ethers.js. The blast radius is orders of magnitude larger, the bounty programs are broader (HackerOne, Bugcrowd, vendor programs, not just Immunefi), and the CVE value is higher.

**The strategic link between Track A and Track B:** Every DeFi target you scan in Track A runs on Track B infrastructure. An HTTP request smuggling zero-day in the proxy sitting in front of a $300M DeFi protocol is a critical finding on that protocol's bounty program. A container escape in the Kubernetes cluster running the protocol's keepers is a fund theft chain. Track B zero-days are weapons that multiply the value of your Track A target hunting.

---

## Domain 6: HTTP Servers & Reverse Proxies

### 6.0 Rationale

Every HTTP request in the internet passes through at least one proxy or web server. The HTTP specification (RFC 9110/9112) is intentionally ambiguous in places, and different implementations resolve ambiguities differently. When a proxy and a backend server disagree on where one request ends and the next begins, request smuggling occurs — and request smuggling is consistently one of the highest-severity vulnerability classes because it bypasses ALL application-layer security (auth, WAF, rate limiting).

### 6.1 Target Map

| Component | Type | Language | Deployment Scale | Bug Bounty | Priority |
|-----------|------|----------|-----------------|-----------|----------|
| Nginx | Reverse proxy / web server | C | 34%+ of web | HackerOne (managed) | P1 |
| Apache httpd | Web server | C | 30%+ of web | ASF program | P2 |
| HAProxy | Load balancer / proxy | C | Major CDNs, cloud | HackerOne | P1 |
| Envoy | Service mesh proxy | C++ | Kubernetes default, Istio | HackerOne | P1 |
| Traefik | Cloud-native proxy | Go | Kubernetes, Docker | GitHub Security | P2 |
| Caddy | Web server | Go | Growing adoption | GitHub Security | P2 |
| Cloudflare CDN | CDN / WAF / proxy | (proprietary) | 20%+ of web | HackerOne ($3K-$15K) | P1 |
| AWS ALB/CloudFront | Load balancer / CDN | (proprietary) | AWS ecosystem | AWS bounty | P1 |
| Varnish | Caching proxy | C | CDN caching layer | HackerOne | P2 |
| Express.js | Node.js web framework | JS | Ubiquitous in Node | HackerOne (via Node) | P2 |
| Go net/http | Go HTTP server | Go | Go services, DeFi backends | Go security | P1 |
| Hyper / Actix | Rust HTTP servers | Rust | Rust backends | GitHub Security | P2 |

### 6.2 Bug Pattern Taxonomy

| Pattern ID | Name | Mechanism | Impact | CVSS Range |
|-----------|------|-----------|--------|------------|
| HTTP-001 | CL.TE smuggling | Proxy uses Content-Length, backend uses Transfer-Encoding → request boundary mismatch | Auth bypass, cache poison, request hijack | 9.1-9.8 |
| HTTP-002 | TE.CL smuggling | Proxy uses Transfer-Encoding, backend uses Content-Length → same impact | Same as HTTP-001 | 9.1-9.8 |
| HTTP-003 | H2.CL desync | HTTP/2 request downgraded to HTTP/1.1 with conflicting Content-Length | Request smuggling via H2 | 9.1-9.8 |
| HTTP-004 | H2.TE desync | HTTP/2 with injected Transfer-Encoding header (should be stripped per RFC) | Request smuggling via H2 | 9.1-9.8 |
| HTTP-005 | Chunk extension parsing | Proxy and backend parse chunk extensions differently → size miscalculation | Request smuggling | 8.0-9.0 |
| HTTP-006 | Header folding | Obsolete line folding (RFC 7230 §3.2.4) handled inconsistently | Header injection | 7.0-8.5 |
| HTTP-007 | Host header confusion | Multiple Host headers or Host vs :authority (H2) disagreement | Cache poisoning, routing bypass | 7.0-9.0 |
| HTTP-008 | 0-day in Transfer-Encoding variants | `Transfer-Encoding: xchunked`, `Transfer-Encoding : chunked`, extra whitespace/capitalization | Smuggling via TE normalization differences | 9.0+ |
| HTTP-009 | Trailer header abuse | Trailers in chunked encoding parsed as regular headers → header injection post-body | Auth bypass, cache poison | 7.5-8.5 |
| HTTP-010 | Request line parsing | Absolute URI vs relative URI, path normalization (%2f vs /, double slash) | Path traversal, routing bypass | 6.5-8.0 |
| HTTP-011 | Connection state desync | Keep-alive vs close, pipelining, H2 stream reset → connection reuse confusion | Cross-user request leakage | 8.0-9.5 |
| HTTP-012 | WebSocket upgrade confusion | Proxy handles Upgrade differently than backend → request smuggling via WS upgrade | Same as HTTP-001 | 8.0-9.0 |

### 6.3 Differential Testing Methodology

#### 6.3.1 Request Smuggling Scanner

```
Architecture:

           ┌──────────────┐     ┌──────────────┐
           │   Proxy A     │────▶│   Backend X   │
           │  (Nginx)      │     │  (Express)    │
           └──────────────┘     └──────────────┘
                │
  Raw socket───┘  (bypass HTTP client normalization)
                │
           ┌──────────────┐     ┌──────────────┐
           │   Proxy B     │────▶│   Backend X   │
           │  (HAProxy)    │     │  (Express)    │
           └──────────────┘     └──────────────┘

For EACH (proxy, backend) pair:
  1. Send request with ambiguous body delimiter
  2. Observe: does the backend see one request or two?
  3. If proxy sees 1 and backend sees 2 → smuggling confirmed
```

**Test corpus — ambiguous requests:**

```
# CL.TE basic
POST / HTTP/1.1\r\n
Host: target\r\n
Content-Length: 6\r\n
Transfer-Encoding: chunked\r\n
\r\n
0\r\n
\r\n
G

# TE.CL basic
POST / HTTP/1.1\r\n
Host: target\r\n
Content-Length: 3\r\n
Transfer-Encoding: chunked\r\n
\r\n
8\r\n
SMUGGLED\r\n
0\r\n
\r\n

# TE obfuscation variants (test each)
Transfer-Encoding: xchunked
Transfer-Encoding : chunked
Transfer-Encoding: chunked
Transfer-Encoding: x
Transfer-Encoding:[tab]chunked
Transfer-Encoding: chunKed
X: x\r\nTransfer-Encoding: chunked
Transfer-Encoding\r\n : chunked
Transfer-Encoding: ,chunked

# H2 desync
:method: POST
:path: /
:authority: target
content-length: 0
transfer-encoding: chunked  # Should be stripped in H2→H1 downgrade

# Chunk extension abuse
POST / HTTP/1.1\r\n
Transfer-Encoding: chunked\r\n
\r\n
5;ext=val\r\n
HELLO\r\n
0\r\n
\r\n

# Null byte in header
GET / HTTP/1.1\r\n
Host: target\r\n
X-Injected: value\x00\r\nX-Hidden: smuggled\r\n
\r\n
```

**Implementation:**
- Raw socket connections (NOT http libraries — they normalize requests)
- Python `socket` module or custom Rust tool
- Local Docker environment: proxy container → backend container
- Detection: backend logs request count vs expected count
- For timing-based detection: delayed second request, measure if it arrives early

**Key principle:** NEVER use an HTTP client library for smuggling tests. Libraries normalize the request, removing the exact ambiguities you're testing. Always use raw sockets.

#### 6.3.2 Pairwise Testing Matrix

```
Proxies:  [Nginx, HAProxy, Envoy, Traefik, Caddy, Cloudflare, AWS ALB, Varnish]
Backends: [Express, Go net/http, Gunicorn, Uvicorn, Tomcat, Apache, Hyper]

For each (proxy P, backend B):
  For each ambiguous request R in corpus:
    1. Send R through P → B
    2. Record: P's interpretation (1 request or 2), B's interpretation
    3. If P != B → SMUGGLING CANDIDATE
    4. Verify with timing/response-based confirmation

Matrix size: 8 × 7 × 50+ request variants = 2800+ test cases
Automated: 100% — run overnight
```

### 6.4 Effort & Roadmap

| Phase | Effort | Deliverable |
|-------|--------|-------------|
| Raw socket test framework + basic corpus | 3 days | Reusable smuggling tester |
| Docker environment (8 proxies × 7 backends) | 2 days | Local test lab |
| Full pairwise matrix run | 1 day (automated) | Divergence report |
| H2 desync testing harness | 2 days | HTTP/2 specific tests |
| Each new proxy/backend version | 30 min | Regression test |

### 6.5 Bounty Integration

```
Zero-day in Nginx request parsing
  ↓
1. CVE to Nginx security team
  ↓ in parallel
2. Every DeFi target behind Nginx:
   - Verify with §F3.2 (WAF/CDN detection): is target behind Nginx?
   - Craft target-specific smuggling PoC (bypass their auth)
   - Submit to their bounty program with CVE reference
  ↓
3. HackerOne managed programs for Nginx itself
```

---

## Domain 7: JavaScript Runtimes & VM Engines

### 7.0 Rationale

V8 (Chrome, Node.js, Deno, Bun, Cloudflare Workers), SpiderMonkey (Firefox), JavaScriptCore (Safari, Bun). These runtimes execute untrusted code at planetary scale. The JIT compiler, garbage collector, and built-in objects are each massive attack surfaces. For DeFi specifically: Cloudflare Workers and Vercel Edge Functions run DeFi protocol logic in V8 isolates — an isolate escape is a direct path to protocol infrastructure compromise.

### 7.1 Target Map

| Runtime | Engine | Language | Bug Bounty | Reward Range | Priority |
|---------|--------|----------|-----------|-------------|----------|
| Chrome/V8 | V8 | C++ | Chrome VRP | $1K-$250K+ | P1 |
| Node.js | V8 | C++/JS | HackerOne | $250-$15K | P1 |
| Deno | V8 | Rust/TS | GitHub Security | Varies | P2 |
| Bun | JSC | Zig/C++ | GitHub Security | Varies | P2 |
| Cloudflare Workers | V8 isolates | C++ | HackerOne | $200-$10K+ | P1 |
| Firefox/SpiderMonkey | SpiderMonkey | C++/Rust | Mozilla bounty | $500-$15K | P2 |
| Safari/JSC | JavaScriptCore | C++ | Apple bounty | $5K-$100K+ | P2 |

### 7.2 Bug Pattern Taxonomy

| Pattern ID | Name | Mechanism | Impact | Typical CVSS |
|-----------|------|-----------|--------|-------------|
| RT-001 | JIT type confusion | JIT compiler assumes type A, actual value is type B → incorrect machine code | RCE via arbitrary read/write | 9.0-10.0 |
| RT-002 | Bounds check elimination | JIT removes bounds check it believes is redundant, but isn't → OOB access | RCE | 8.5-9.5 |
| RT-003 | GC use-after-free | Object collected while still referenced due to GC root tracking error | RCE | 8.0-9.0 |
| RT-004 | Prototype pollution (engine level) | Built-in prototype modification causes unexpected behavior in engine internals | Info leak, DoS, potential RCE | 6.0-8.0 |
| RT-005 | TypedArray boundary error | SharedArrayBuffer / TypedArray offset/length calculation overflow | OOB read/write | 8.0-9.5 |
| RT-006 | RegExp ReDoS (engine) | RegExp engine pathological backtracking not bounded → CPU exhaustion | DoS | 5.0-7.5 |
| RT-007 | Isolate escape | V8 isolate boundary bypassed → cross-tenant data access in Workers | Data theft across tenants | 9.5-10.0 |
| RT-008 | WASM sandbox escape | WASM execution escapes linear memory sandbox → native memory access | RCE | 9.0-10.0 |
| RT-009 | Async/Promise state confusion | Race condition in microtask queue / event loop → use-after-free | RCE | 7.5-9.0 |
| RT-010 | Proxy/Reflect handler abuse | Exotic Proxy traps cause engine to enter unexpected state | Various | 6.0-8.5 |

### 7.3 Fuzzing Methodology

#### 7.3.1 JavaScript Program Fuzzing

```
Method: Grammar-aware JS program generation + differential execution

Fuzzers (established, leverage don't rebuild):
- Fuzzilli (Google) — coverage-guided JS fuzzer, targets V8/JSC/SM
- Domato (Google) — grammar-based generative fuzzer
- DIE — aspect-preserving mutation fuzzer
- Custom: type confusion-focused generator (see below)

Type confusion generator (custom, highest ROI):
  1. Generate function with typed hot loop (triggers JIT compilation)
  2. Call function N times with consistent types (JIT compiles optimized path)
  3. Call function once with different type (triggers deoptimization)
  4. Check: does deoptimization handle the type transition correctly?

  Example template:
  function trigger(x) {
    let arr = [1.1, 2.2, 3.3];
    return arr[x];           // JIT assumes x is SMI (small integer)
  }
  for (let i = 0; i < 100000; i++) trigger(0);  // Train JIT
  trigger({valueOf() { return 0; }});            // Deopt trigger — type confusion?
  // If JIT doesn't deopt correctly → OOB read/write possible

Differential execution:
  - V8 (Node.js) vs SpiderMonkey (js78 shell) vs JSC (jsc binary)
  - Same program, compare: output, exceptions, crash/no-crash
  - Divergence in output → potential correctness bug
  - Crash in one engine → definite bug in that engine
```

#### 7.3.2 WASM Boundary Fuzzing

```
Focus: JS↔WASM interface, WASM memory operations

1. Generate WASM modules with:
   - Memory operations at boundary (offset 0, offset MAX-1, offset MAX)
   - Table operations (funcref at boundary indices)
   - Import/export combinations
   - Multi-memory proposals (if supported)
   - Bulk memory operations (memory.copy, memory.fill with overlapping ranges)

2. Call WASM from JS with:
   - TypedArray views of WASM memory (SharedArrayBuffer if available)
   - Concurrent access from multiple Workers
   - Growing memory during access
   - Passing BigInt, Symbol, Proxy to WASM imports

3. Detect:
   - WASM accessing memory outside its linear memory → RT-008
   - JS seeing values that should be inside WASM sandbox
   - Crashes (ASAN/MSAN build of V8)
```

#### 7.3.3 Isolate Escape Testing (Cloudflare Workers)

```
This requires working within the Cloudflare Workers environment:

1. Deploy two Workers on same runtime:
   - Worker A: writes canary value to various storage
   - Worker B: attempts to read Worker A's canary

2. Vectors to test:
   - SharedArrayBuffer timing side-channel (Spectre variant)
   - V8 snapshot manipulation
   - Module cache pollution
   - Error object cross-isolate leakage
   - Performance.now() timing oracle

3. If Worker B reads Worker A's canary → isolate escape confirmed

Note: Cloudflare has mitigations. The goal is to find gaps in mitigations.
```

### 7.4 Effort & Roadmap

| Phase | Effort | Deliverable |
|-------|--------|-------------|
| Set up Fuzzilli for V8 + ASAN build | 2 days | Continuous fuzzing pipeline |
| Custom type confusion generator | 3 days | Targeted JIT fuzzer |
| WASM boundary test harness | 2 days | JS↔WASM fuzzer |
| Differential engine testing (V8 vs SM vs JSC) | 3 days | Cross-engine comparison |
| Cloudflare Workers isolate testing | 2 days | Isolate escape attempts |

---

## Domain 8: Database Engines

### 8.0 Rationale

Every DeFi backend talks to a database. PostgreSQL, MySQL, MongoDB, Redis — each has its own query parser, authentication protocol, and privilege model. Bugs in these components are not application-level SQL injection — they are engine-level vulnerabilities that affect every application using the database, regardless of how well the application sanitizes input.

### 8.1 Target Map

| Database | Language | Deployment | Bug Bounty | Priority |
|----------|----------|-----------|-----------|----------|
| PostgreSQL | C | Ubiquitous backend DB | HackerOne + PG security | P1 |
| MySQL/MariaDB | C/C++ | Legacy web, managed services | Oracle/MariaDB programs | P2 |
| MongoDB | C++ | DeFi analytics, indexing services | HackerOne | P2 |
| Redis / Valkey | C | Caching, session store, pub/sub | HackerOne (Redis) | P1 |
| SQLite | C | Embedded everywhere, mobile wallets | No bounty (submit to devs) | P2 |
| ClickHouse | C++ | DeFi analytics, on-chain data | GitHub Security | P3 |
| CockroachDB | Go | Distributed SQL, cloud-native | HackerOne | P3 |

### 8.2 Bug Pattern Taxonomy

| Pattern ID | Name | Mechanism | Impact | Typical CVSS |
|-----------|------|-----------|--------|-------------|
| DB-001 | Auth protocol bypass | Authentication handshake has logic error → auth without valid credentials | Full database access | 9.8 |
| DB-002 | Privilege escalation | Unprivileged user reaches admin functions via query/extension abuse | Data theft, RCE | 8.8-9.8 |
| DB-003 | Query parser confusion | Parser interprets query differently than expected → unintended operations | Data leak, manipulation | 7.0-9.0 |
| DB-004 | Extension/module RCE | Loaded extension has buffer overflow or arbitrary code execution | RCE on DB server | 9.0-9.8 |
| DB-005 | Replication injection | Crafted replication stream causes slave to execute unintended operations | Data corruption, RCE | 8.0-9.5 |
| DB-006 | Wire protocol parsing | Malformed client→server packets cause crash or memory corruption | DoS, potential RCE | 6.5-9.0 |
| DB-007 | Prepared statement confusion | Prepared statement type metadata mismatches actual data → type confusion | Data leak, manipulation | 7.0-8.5 |
| DB-008 | View/function security definer | SECURITY DEFINER function executes with elevated privileges, exploitable by caller | Privilege escalation | 7.5-8.8 |
| DB-009 | Collation/charset confusion | Different collations produce different sort/comparison results → logic bypass | Auth bypass, data leak | 6.0-8.0 |
| DB-010 | Lua/JS sandbox escape (Redis/Mongo) | Scripting engine sandbox bypassed → OS command execution | RCE | 9.0-10.0 |

### 8.3 Testing Methodology

#### 8.3.1 Wire Protocol Fuzzing

```
For each database, fuzz the client→server wire protocol:

1. Capture valid protocol exchanges (login, query, prepare, execute)

2. Mutate at the protocol level (NOT SQL level):
   - Message type bytes (change query to prepare, auth to data)
   - Length fields (underflow, overflow, zero, MAX)
   - Sequence numbers (out of order, duplicate, skip)
   - Truncation at every byte offset
   - Null injection in string fields
   - Invalid encoding in character fields

3. Tools:
   - PostgreSQL: pgsql wire protocol fuzzer (custom, ~300 lines Python)
   - MySQL: mysql protocol fuzzer (similar structure)
   - Redis: RESP protocol is simple enough for direct fuzzing
   - MongoDB: wire protocol fuzzer targeting OP_MSG

4. Monitor: ASAN-instrumented database build for crashes
```

#### 8.3.2 Auth Protocol Testing

```bash
# PostgreSQL auth handshake abuse:
# 1. MD5 auth: can you predict the salt? Replay a captured hash?
# 2. SCRAM-SHA-256: is channel binding enforced? Can you downgrade to MD5?
# 3. Trust auth: is pg_hba.conf allowing trust from unexpected sources?
# 4. Certificate auth: are cert CNs validated correctly?

# Redis AUTH testing:
# - Default: no auth (CRITICAL if exposed)
# - ACL bypass: can you access commands after partial auth?
# - AUTH command timing: constant-time comparison?

# MongoDB auth testing:
# - SCRAM-SHA-1 vs SCRAM-SHA-256 downgrade
# - X.509 cert validation
# - LDAP proxy auth bypass
```

#### 8.3.3 Scripting Sandbox Escape (Redis Lua, MongoDB JS)

```bash
# Redis Lua sandbox:
# The Lua sandbox restricts module loading, file access, OS commands.
# Test escape vectors:

# 1. Module loading
redis-cli EVAL "require('os')" 0  # Should fail
redis-cli EVAL "loadfile('/etc/passwd')()" 0  # Should fail

# 2. Debug library (historically problematic)
redis-cli EVAL "debug.getinfo(1)" 0
redis-cli EVAL "debug.getregistry()" 0  # Registry may contain references to blocked functions

# 3. String library abuse
redis-cli EVAL "return string.dump(function() end)" 0  # Bytecode dump → analyze sandbox

# 4. Coroutine manipulation
redis-cli EVAL "coroutine.wrap(function() coroutine.yield(os) end)()" 0

# 5. Metatable manipulation
redis-cli EVAL "return getmetatable('').__index" 0  # Access string metatable

# MongoDB JS sandbox:
# Similar approach — test module loading, file access, child_process
```

### 8.4 Effort & Roadmap

| Phase | Effort | Deliverable |
|-------|--------|-------------|
| PostgreSQL wire protocol fuzzer | 3 days | Custom fuzzer + ASAN-instrumented PG build |
| Redis Lua sandbox escape testing | 2 days | Escape vector test suite |
| Redis RESP protocol fuzzer | 2 days | Protocol-level fuzzer |
| MongoDB wire protocol + JS sandbox | 3 days | Dual fuzzer |
| Auth protocol differential (PG MD5 vs SCRAM) | 1 day | Auth downgrade tester |

---

## Domain 9: Serialization Frameworks

### 9.0 Rationale

Domain 1 covers crypto-specific parsers (ABI, RLP, Borsh). This domain covers the general-purpose serialization frameworks that backend infrastructure uses for inter-service communication. gRPC (protobuf) is in every microservice architecture. MessagePack is in every high-performance API. CBOR is in every COSE/WebAuthn implementation. These parsers handle untrusted input at service boundaries, and a bug in protobuf-go or protobuf-js affects every gRPC service in the world.

### 9.1 Target Map

| Framework | Library | Language | Usage | Priority |
|-----------|---------|----------|-------|----------|
| Protocol Buffers | protobuf-go | Go | gRPC servers (K8s, DeFi backends) | P1 |
| Protocol Buffers | protobuf-js / protobufjs | JS | gRPC-web, browser clients | P1 |
| Protocol Buffers | prost | Rust | Rust gRPC services | P2 |
| Protocol Buffers | protobuf-java | Java | Enterprise gRPC | P2 |
| MessagePack | msgpack-js / @msgpack/msgpack | JS | High-perf APIs, WebSocket payloads | P1 |
| MessagePack | msgpack-python / msgpack | Python | FastAPI internal comm | P2 |
| CBOR | cbor-x / cbor2 | JS/Python | WebAuthn, COSE, IoT | P2 |
| FlatBuffers | flatbuffers | C++/JS/Go | Game engines, high-perf systems | P3 |
| Avro | avro-js | JS | Kafka message serialization | P3 |
| BSON | bson (MongoDB driver) | JS/Python | MongoDB wire protocol | P2 |

### 9.2 Bug Pattern Taxonomy

| Pattern ID | Name | Mechanism | Impact | Detection |
|-----------|------|-----------|--------|-----------|
| SER-001 | Length prefix overflow | Length field × element size overflows → small allocation, large write | Heap overflow → RCE | Fuzz with large length values |
| SER-002 | Unknown field handling | Unknown field type accepted and parsed with wrong decoder | Type confusion | Inject unknown field type tags |
| SER-003 | Varint overflow | Variable-length integer encoding overflows target type (32-bit vs 64-bit) | Integer overflow → logic error | Fuzz with maximum-length varints |
| SER-004 | Nested message bomb | Deeply nested messages → stack overflow or quadratic parsing | DoS | Depth bombing |
| SER-005 | Map key collision | Duplicate keys in map type → first-wins vs last-wins | Logic bypass | Duplicate key injection |
| SER-006 | Oneof confusion | Multiple fields set in oneof group → undefined behavior | Type confusion | Set all oneof fields simultaneously |
| SER-007 | Default value confusion | Missing field → default value (0, "", false) → treated as explicitly set | Logic bypass | Omit fields that shouldn't be default |
| SER-008 | Extension/any type abuse | protobuf Any type → arbitrary message deserialized without schema | Type confusion, injection | Craft Any with unexpected types |
| SER-009 | Cross-language differential | Same protobuf message parsed differently by Go vs JS vs Python | Logic divergence | Differential testing |
| SER-010 | String encoding confusion | String field contains invalid UTF-8 → different handling per language | Parser confusion | Invalid UTF-8 injection |

### 9.3 Testing Methodology

```
Same architecture as Domain 1 parser fuzzing, adapted for serialization:

1. Corpus: valid serialized messages from real services (capture from gRPC calls)

2. Mutators (serialization-specific):
   - Varint: encode same value with different varint lengths (1-10 bytes)
   - Wire type: change wire type tag without changing data
   - Field number: use field numbers outside schema
   - Nested depth: embed message N levels deep (N = 100, 1000, 10000)
   - Map: duplicate keys, empty keys, keys with null bytes
   - Oneof: set multiple fields, set no fields
   - Any: embed unexpected message types
   - String: invalid UTF-8, overlong encodings, null terminators
   - Bytes: length 0, length MAX, length -1 (signed interpretation)

3. Differential oracle:
   - protobuf-go vs protobuf-js vs prost vs protobuf-java
   - Same bytes → decoded message → compare field values
   - Divergence → investigate

4. Crash detection:
   - ASAN/MSAN for native implementations
   - Exception monitoring for managed implementations
   - Memory usage monitoring (decompression/nested bombs)
```

### 9.4 Effort & Roadmap

| Phase | Effort | Deliverable |
|-------|--------|-------------|
| Protobuf differential fuzzer (Go vs JS vs Rust) | 4 days | Cross-language divergence detector |
| MessagePack fuzzer | 2 days | Simpler format, faster to build |
| CBOR fuzzer (WebAuthn focus) | 2 days | COSE/WebAuthn attack surface |
| Each additional framework | 1-2 days | Incremental coverage |

---

## Domain 10: TLS / PKI Implementations

### 10.0 Rationale

Every HTTPS connection depends on TLS implementations and X.509 certificate parsing. CVE-2022-21449 (Java "Psychic Signatures" — blank ECDSA signature accepted) is already in our references. The X.509 certificate parser is arguably the most complex parser in widespread use — ASN.1/DER encoding with recursive structures, optional fields, extensions with arbitrary data, name constraints, policy trees. Each parsing difference between implementations is a potential MitM or auth bypass.

### 10.1 Target Map

| Library | Language | Usage | Bug Bounty | Priority |
|---------|----------|-------|-----------|----------|
| OpenSSL | C | Default TLS for most Linux services | OpenSSL bounty ($500-$20K) | P1 |
| BoringSSL | C | Chrome, Go (via cgo), Android | Chrome VRP | P1 |
| rustls | Rust | Growing Rust ecosystem, Cloudflare | GitHub Security | P1 |
| Go crypto/tls | Go | All Go services, DeFi backends | Go security | P1 |
| mbed TLS | C | IoT, embedded, hardware wallets | ARM bounty | P2 |
| LibreSSL | C | OpenBSD, macOS (older) | OpenBSD security | P3 |
| GnuTLS | C | GNOME ecosystem, some Linux distros | Red Hat/SUSE | P3 |
| wolfSSL | C | Embedded, automotive, IoT | wolfSSL bounty | P2 |
| Node.js TLS (OpenSSL binding) | C/JS | Node.js servers | HackerOne (Node) | P1 |

### 10.2 Bug Pattern Taxonomy

| Pattern ID | Name | Mechanism | Impact | Typical CVSS |
|-----------|------|-----------|--------|-------------|
| TLS-001 | Certificate chain validation bypass | Intermediate cert not validated, or root trust store mishandled | MitM | 9.1 |
| TLS-002 | Signature verification error | ECDSA/RSA signature validation has edge case → invalid sig accepted | Auth bypass, MitM | 9.8 (CVE-2022-21449) |
| TLS-003 | Name constraint bypass | X.509 nameConstraints extension not enforced → wrong cert accepted for domain | MitM | 8.0-9.0 |
| TLS-004 | Alternative name confusion | SAN parsing differs between implementations → cert valid for wrong domain | MitM | 8.0-9.0 |
| TLS-005 | ASN.1 parsing error | Malformed ASN.1 causes crash or incorrect decoding | DoS, potential bypass | 5.0-9.0 |
| TLS-006 | Renegotiation attack | TLS renegotiation used to inject prefix in application data | Injection | 7.5-8.5 |
| TLS-007 | Downgrade attack | POODLE-style: force downgrade to weaker cipher/protocol | Decryption | 7.5-8.5 |
| TLS-008 | Session resumption confusion | Session ticket from server A accepted by server B | Cross-server auth bypass | 7.0-8.5 |
| TLS-009 | CT/OCSP stapling bypass | Certificate Transparency or OCSP checks bypassable → revoked cert accepted | MitM with revoked cert | 6.5-8.0 |
| TLS-010 | Private key extraction via side-channel | Timing/cache side-channel during RSA/ECDSA operations | Key recovery | 7.5-9.0 |

### 10.3 Testing Methodology

#### 10.3.1 Certificate Differential Testing

```
Method: Generate certificates with edge-case properties,
test acceptance across multiple TLS implementations.

Certificate corpus (craft each):
  1. Self-signed cert with valid SAN → baseline
  2. Cert with nameConstraints excluding target domain
  3. Cert with SAN containing null byte: "target.com\x00.evil.com"
  4. Cert with wildcard in unexpected position: "*.*.target.com"
  5. Cert with IP SAN vs DNS SAN for same host
  6. Cert chain with missing intermediate
  7. Cert chain with expired intermediate, valid leaf
  8. Cert with critical unknown extension
  9. Cert with non-DER encoding (BER-valid but not DER-valid)
  10. Cert with maximal path length constraint violated
  11. Cert with duplicate extensions
  12. Cert with overlong UTF-8 in CN/SAN
  13. Cert with empty SAN
  14. Cert with SAN containing only space characters
  15. Cert signed with SHA-1 (should be rejected by modern libs)

For each cert:
  - OpenSSL s_client → accept/reject
  - Go crypto/tls → accept/reject
  - rustls → accept/reject
  - BoringSSL → accept/reject
  - curl (OpenSSL/NSS/SecureTransport) → accept/reject

Divergence = potential zero-day in the accepting implementation.
```

#### 10.3.2 Signature Verification Edge Cases

```
Target: the same patterns as CVE-2022-21449 (Psychic Signatures)

For ECDSA:
  - r = 0, s = 0 (blank signature)
  - r = n (group order), s = anything
  - r = 1, s = 1 (minimal values)
  - r and s with leading zeros (DER encoding variations)
  - Signature with wrong curve parameters
  - Signature with point at infinity

For RSA:
  - Signature = 0
  - Signature = n-1 (modulus - 1)
  - Signature with wrong padding (PKCS1 vs PSS confusion)
  - Bleichenbacher-style padding oracle (timing)
  - Signature over wrong hash algorithm

For Ed25519:
  - All-zero signature
  - Signature with non-canonical S (S >= L)
  - Signature with small-order R component
  - Mixed-up signature components (swap R and S)

Submit each to verification functions in each TLS library.
Any acceptance of an invalid signature → CRITICAL zero-day.
```

### 10.4 Effort & Roadmap

| Phase | Effort | Deliverable |
|-------|--------|-------------|
| Edge-case certificate generator | 3 days | 15+ cert templates |
| Differential cert acceptance testing (4 libs) | 2 days | Divergence matrix |
| Signature verification edge case suite | 2 days | Comprehensive invalid sig corpus |
| ASN.1 parser fuzzer | 3 days | Grammar-aware ASN.1 fuzzer |
| Each additional TLS lib | 1 day | Incremental coverage |

---

## Domain 11: Container Runtimes & Orchestration

### 11.0 Rationale

Every DeFi protocol runs in containers. The container runtime (runc, crun, containerd) and orchestrator (Kubernetes, Docker Compose, ECS) are the isolation boundary between the protocol and the host. A container escape = access to the host = access to keys, secrets, and other containers. runc CVE-2024-21626 ("Leaky Vessels") demonstrated that these escapes are still being found and are extremely high-impact.

### 11.1 Target Map

| Component | Type | Language | Bug Bounty | Priority |
|-----------|------|----------|-----------|----------|
| runc | Container runtime | Go | HackerOne (Docker) + Linux distros | P1 |
| containerd | Container daemon | Go | HackerOne (Docker) | P1 |
| Docker Engine | Container platform | Go | HackerOne ($100-$10K) | P1 |
| CRI-O | Container runtime (K8s) | Go | Red Hat bounty | P2 |
| Kubernetes API Server | Orchestrator | Go | HackerOne ($100-$10K) | P1 |
| kubelet | Node agent | Go | K8s bounty (via HackerOne) | P1 |
| etcd | K8s state store | Go | K8s bounty | P2 |
| CoreDNS | K8s DNS | Go | K8s bounty | P2 |
| Envoy (sidecar) | Service mesh | C++ | HackerOne (Envoy) | P1 |
| Istio | Service mesh control plane | Go | HackerOne | P2 |

### 11.2 Bug Pattern Taxonomy

| Pattern ID | Name | Mechanism | Impact | Typical CVSS |
|-----------|------|-----------|--------|-------------|
| CTR-001 | Container escape via proc/fd | /proc/self/fd or /proc/self/exe manipulation → access to host filesystem | Full host access | 8.6-9.8 |
| CTR-002 | Symlink race in container setup | TOCTOU race during rootfs setup → symlink to host path | Host filesystem access | 7.0-8.5 |
| CTR-003 | Namespace confusion | User namespace or PID namespace not properly isolated | Privilege escalation | 7.5-8.8 |
| CTR-004 | Capability leak | Container inherits capabilities it shouldn't have (CAP_SYS_ADMIN, CAP_NET_RAW) | Privilege escalation | 7.0-8.5 |
| CTR-005 | Volume mount escape | Crafted volume mount escapes container boundary → host filesystem access | Data theft, RCE | 8.0-9.0 |
| CTR-006 | K8s RBAC bypass | RBAC policy allows unintended actions via verb/resource/subresource combinations | Cluster compromise | 8.0-9.5 |
| CTR-007 | Service account token abuse | Default service account token mounted → lateral movement within cluster | Lateral movement | 7.5-8.5 |
| CTR-008 | etcd direct access | etcd accessible without auth → read/write all K8s state including secrets | Full cluster compromise | 9.8 |
| CTR-009 | Kubelet API exposure | Kubelet API (10250) exposed without auth → pod exec, logs, container management | Container exec, data theft | 8.5-9.5 |
| CTR-010 | Admission controller bypass | Webhook admission controller has logic error → malicious pod admitted | Arbitrary workload deployment | 7.5-9.0 |

### 11.3 Testing Methodology

#### 11.3.1 Container Escape Techniques

```bash
# === Run from INSIDE a container (your test container) ===

# 1. /proc/self exploration
ls -la /proc/self/fd/
ls -la /proc/self/ns/
cat /proc/self/cgroup  # Identify container runtime
cat /proc/self/mountinfo  # Mount namespace leaks

# 2. Capabilities check
cat /proc/self/status | grep Cap
# Decode: capsh --decode=<hex_value>
# If CAP_SYS_ADMIN → likely escapable

# 3. Docker socket mount
ls -la /var/run/docker.sock
# If accessible → create privileged container → escape
# curl --unix-socket /var/run/docker.sock http://localhost/containers/json

# 4. Service account token (Kubernetes)
cat /var/run/secrets/kubernetes.io/serviceaccount/token
# If present → test access:
# curl -k -H "Authorization: Bearer $(cat token)" https://kubernetes.default.svc/api/v1/namespaces

# 5. Metadata service (cloud)
curl -s http://169.254.169.254/latest/meta-data/
curl -s -H "Metadata-Flavor: Google" http://metadata.google.internal/computeMetadata/v1/
# If accessible → cloud credential theft

# 6. Host PID namespace leak
ls /proc/ | grep -E '^[0-9]+' | wc -l
# If seeing host processes → PID namespace not isolated

# 7. CVE-2024-21626 check (Leaky Vessels)
# Working directory set to /proc/self/fd/X → possible fd leak to host
ls -la /proc/self/cwd
```

#### 11.3.2 Kubernetes Audit (External)

```bash
# === From outside the cluster, test for exposure ===

K8S_TARGET="https://target-k8s-api:6443"

# 1. API server exposure
curl -sk "${K8S_TARGET}/api/v1/namespaces"
curl -sk "${K8S_TARGET}/version"
curl -sk "${K8S_TARGET}/healthz"

# 2. Kubelet exposure (per node)
KUBELET="https://node-ip:10250"
curl -sk "${KUBELET}/pods"
curl -sk "${KUBELET}/runningpods"
# If 200 → unauthenticated kubelet access = CRITICAL

# 3. etcd exposure
ETCD="https://etcd-ip:2379"
curl -sk "${ETCD}/v2/keys/"
# If 200 → unauthenticated etcd access = CRITICAL

# 4. CoreDNS exposure
dig @coredns-ip version.bind chaos txt
dig @coredns-ip kubernetes.default.svc.cluster.local
# If resolves internal names from outside → DNS exfiltration possible

# 5. Dashboard exposure
curl -sk "https://target:443/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/"
```

### 11.4 Effort & Roadmap

| Phase | Effort | Deliverable |
|-------|--------|-------------|
| Container escape test suite (10 techniques) | 2 days | Automated escape checker |
| runc fuzzing harness (namespace/mount operations) | 4 days | Coverage-guided fuzzer |
| Kubernetes external audit checklist | 1 day | Automated K8s exposure scanner |
| K8s RBAC analysis tool | 3 days | RBAC policy analyzer |
| Each new runtime version | 1 day | Regression testing |

---

## Domain 12: DNS Resolvers & Implementations

### 12.0 Rationale

DNS is the foundation of internet routing. CoreDNS runs in every Kubernetes cluster. BIND and Unbound serve the majority of recursive DNS. A DNS cache poisoning zero-day affects every client behind the resolver. For DeFi specifically: DNS hijacking has already caused $4M+ in losses (Curve $3.5M, Aerodrome $700K). A zero-day in a DNS resolver makes hijacking possible even WITH DNSSEC configured, if the resolver's DNSSEC validation has a bug.

### 12.1 Target Map

| Resolver | Language | Usage | Bug Bounty | Priority |
|----------|----------|-------|-----------|----------|
| CoreDNS | Go | Every Kubernetes cluster | K8s bounty (HackerOne) | P1 |
| BIND 9 | C | 35%+ of authoritative DNS | ISC bounty | P1 |
| Unbound | C | Major recursive resolver | NLnet Labs security | P2 |
| PowerDNS | C++ | Authoritative + recursive | Open-Xchange bounty | P2 |
| dnsmasq | C | Consumer routers, Docker | Distro programs | P2 |
| systemd-resolved | C | Default on modern Linux (Ubuntu, Fedora) | Systemd security | P2 |
| Knot Resolver | C | CZ.NIC resolver | CZ.NIC security | P3 |
| trust-dns (Hickory) | Rust | Growing Rust DNS ecosystem | GitHub Security | P3 |

### 12.2 Bug Pattern Taxonomy

| Pattern ID | Name | Mechanism | Impact | Typical CVSS |
|-----------|------|-----------|--------|-------------|
| DNS-001 | Cache poisoning (Kaminsky variant) | Predict TXID + source port → inject forged response → poisoned cache | Domain hijack for ALL clients | 8.1-9.8 |
| DNS-002 | DNSSEC validation bypass | DNSSEC signature verification has edge case → invalid signature accepted | MitM despite DNSSEC | 9.0-9.8 |
| DNS-003 | Zone transfer leak | AXFR/IXFR allowed without auth → full zone data exposed | Complete DNS enumeration | 5.3-7.5 |
| DNS-004 | NXDomain injection | NSEC/NSEC3 processing error → attacker proves non-existence of valid domain | DoS, domain takeover | 7.0-8.5 |
| DNS-005 | DNS rebinding | Resolver caches short-TTL response → allows internal network scanning | SSRF, internal access | 6.5-8.0 |
| DNS-006 | Compression pointer loop | DNS name compression creates infinite loop → CPU exhaustion | DoS | 7.5 |
| DNS-007 | Label length overflow | DNS label >63 bytes or name >255 bytes → buffer overflow | DoS, potential RCE | 7.5-9.0 |
| DNS-008 | EDNS0 OPT abuse | Extended DNS options parsed incorrectly → buffer overread/overwrite | DoS, potential RCE | 6.5-8.5 |
| DNS-009 | DNS-over-HTTPS/TLS parsing | DoH/DoT specific parsing errors in HTTP/TLS layer | DoS, potential bypass | 5.0-8.0 |
| DNS-010 | Wildcard synthesis error | Wildcard record matching logic has edge case → wrong resolution | Domain confusion | 5.0-7.5 |

### 12.3 Testing Methodology

#### 12.3.1 DNS Response Fuzzing

```
Architecture:

  ┌────────────┐         ┌─────────────────┐         ┌──────────────┐
  │ Test Client │────────▶│  Resolver Under  │────────▶│ Fake Auth NS  │
  │             │         │  Test (CoreDNS/  │         │ (controlled)  │
  │             │◀────────│  BIND/Unbound)   │◀────────│              │
  └────────────┘         └─────────────────┘         └──────────────┘

1. Fake authoritative NS returns crafted responses:
   - Valid response (baseline)
   - Response with compression pointer loop (DNS-006)
   - Response with label > 63 bytes (DNS-007)
   - Response with duplicate records
   - Response with EDNS0 OPT with unknown options (DNS-008)
   - Response with RRSIG but invalid signature (DNS-002)
   - Response with NSEC3 covering unexpected range (DNS-004)
   - Response with wildcard synthesis edge cases (DNS-010)
   - Response with null bytes in labels
   - Response with maximal CNAME chain (20+ hops)

2. Observe resolver behavior:
   - Does it crash? (ASAN-instrumented build)
   - Does it cache the response? (query again, check if cached)
   - Does it validate DNSSEC correctly? (query with +dnssec)
   - Does it follow CNAME chains to the end?

3. Differential:
   - Same crafted response → CoreDNS vs BIND vs Unbound
   - Divergence in cache behavior → potential poisoning vector
```

#### 12.3.2 DNSSEC Validation Edge Cases

```
Craft DNSSEC-signed responses with edge-case properties:

1. Valid signature over wrong RRset → should reject
2. Expired signature (1 second past expiry) → should reject (check tolerance)
3. Future signature (not yet valid) → should reject
4. Signature with unknown algorithm → should treat as insecure (not validated)
5. NSEC3 with opt-out flag → covers delegation, should allow insecure children
6. DNSKEY rollover: old key still in cache, response signed with new key
7. Trust anchor mismatch: DS in parent doesn't match DNSKEY in child
8. Algorithm rollback: zone signed with strong algo, attacker replays weak algo response
9. Key tag collision: two different keys with same tag
10. Wildcard with DNSSEC: synthesized record RRSIG validation

For each: test against CoreDNS, BIND, Unbound.
Any acceptance of invalid DNSSEC → CRITICAL zero-day (bypasses DNSSEC protection).
```

#### 12.3.3 CoreDNS Plugin Fuzzing (Kubernetes-Specific)

```
CoreDNS in Kubernetes uses plugins: kubernetes, forward, cache, etc.

Target the kubernetes plugin specifically:
1. Craft DNS queries for:
   - Non-existent services
   - Services in non-existent namespaces
   - Headless services with many endpoints
   - External names pointing to internal services
   - SRV records with extreme port numbers

2. Test plugin interactions:
   - cache + kubernetes: can a cached response from external
     override an internal service name?
   - forward + kubernetes: does forwarding break zone boundaries?

3. Check for information leakage:
   - Can external DNS queries enumerate internal services?
   - Does the resolver leak internal hostnames in error responses?
```

### 12.4 Effort & Roadmap

| Phase | Effort | Deliverable |
|-------|--------|-------------|
| Fake authoritative NS + response fuzzer | 3 days | Controlled DNS test environment |
| DNSSEC edge case certificate set | 2 days | 10+ edge-case signed zones |
| CoreDNS kubernetes plugin testing | 2 days | K8s-specific DNS test suite |
| Differential resolver testing (3 resolvers) | 2 days | Cross-resolver divergence report |
| Cache poisoning timing analysis | 2 days | TXID/port predictability assessment |

---

## Domain 13: Container Layer Formats (Track A extension)

**Full spec:** `CONTAINER-LAYER-ATTACK-SPEC.md`

**What:** Signature containers, attestation formats, identity tokens — the L2 layer wrapping L1 parsers with crypto semantics. Serialization divergence = security divergence.

**The 4-Layer Model:**
```
L1 — Primitive Parsing    (CBOR, JSON, ASN.1, protobuf, msgpack)     OPERATIONAL
L2 — Container Formats    (COSE, JWS/JWE, X.509, CMS/PKCS#7)       THIS DOMAIN
L3 — Crypto Validation    (sig verify, MAC, cert chain)              JWT Arsenal partial
L4 — Application Tokens   (CWT, JWT, WebAuthn, SAML, PASETO)        JWT Arsenal + WebAuthn
```

**Key insight:** A single L1 parser bug (e.g., C-003 non-canonical boolean) propagates upward through L2 (COSE header confusion) -> L3 (signature validation flip) -> L4 (CWT token bypass) -> downstream apps.

### Tier 1 Targets (Immediate)

| Target | Format | Attack Classes | Key Lib | CBOR Backend | Priority |
|--------|--------|---------------|---------|-------------|----------|
| COSE | RFC 9052 | COSE-001 to COSE-004 (header merge, alg confusion, crit bypass, protected header divergence) | pycose | cbor2 (C-003/4/5 confirmed) | P1 |
| CWT | RFC 8392 | CWT-001 to CWT-003 (claim type confusion, duplicate claim keys, numeric coercion on exp) | python-cwt | cbor2 via pycose | P1 |
| WebAuthn | W3C | WEBAUTHN-001 to WEBAUTHN-003 (fmt confusion, authData parsing, COSE_Key alg confusion) | py_webauthn, @simplewebauthn | cbor2 (C-005 design dep), cbor-x (C-006 heap OOB) | P1 |

### Tier 2 Targets

| Target | Format | Attack Classes | Notes |
|--------|--------|---------------|-------|
| X.509/ASN.1 | ITU-T X.690 | X509-001 to X509-003 (BER/DER, dup extensions, SAN divergence) | Focus on lesser-known parsers + eIDAS for PSD2 |

### Tier 3 Targets

| Target | Attack Classes |
|--------|---------------|
| PASETO | Version confusion, footer misinterpretation |
| Biscuit | Datalog rule injection, signature chain confusion |
| Macaroons | Caveat bypass via encoding, HMAC chain order confusion |

### The Meta-Attack: Cross-Implementation Verification Mismatch

Issuer (Lib A) signs token. Gateway (Lib B) verifies. If Lib A and Lib B parse differently -> token semantically different at each end. This is the highest-impact class the differential pipeline can produce.

### Pattern Taxonomy

```
COSE-001    Header merge confusion (protected vs unprotected overwrite)
COSE-002    Algorithm confusion via CBOR type (int vs bignum vs float vs string)
COSE-003    Critical parameter bypass (crit label via C-003/C-004 patterns)
COSE-004    Protected header CBOR parsing divergence (trailing data in bstr)
CWT-001     Claim type confusion (exp as float/bignum/string/boolean)
CWT-002     Duplicate claim keys (first-write vs last-write on exp)
CWT-003     Numeric coercion on expiration (float64 precision loss)
WEBAUTHN-001  Attestation format confusion (non-canonical fmt string)
WEBAUTHN-002  authData parsing divergence (CBOR round-trip offset error)
WEBAUTHN-003  Credential public key algorithm confusion (C-004 key collision)
X509-001    BER vs DER confusion (indefinite length acceptance)
X509-002    Duplicate extension confusion (first-write vs last-write on BasicConstraints)
X509-003    SAN parsing divergence (null byte, wildcard, IDN handling)
```

---

## Updated Master Roadmap — All 13 Domains

### Months 1-3: Track A (Crypto/DeFi) — Status

| Domain | Component | Tooling Status | Results |
|--------|-----------|---------------|---------|
| D1 | ABI parser differential | OPERATIONAL | 35K+ tests, strictness divergences only |
| D1 | RLP parser differential | OPERATIONAL | 540K+ tests, strictness only |
| D1 | Nested ABI | OPERATIONAL | 15K tests, 0 divergences |
| D1 | Calldata + selectors | OPERATIONAL | 29K tests, 0 divergences |
| D1 | Cross-language ABI (JS vs Python) | OPERATIONAL | 34K tests, 0 divergences |
| D1 | Borsh differential | SKELETON | Package only, no runner |
| D2 | Crypto curves differential | SKELETON | Package only, no runner |
| D3 | AA bundler differential | BUILT | Runner exists, 0 results |
| D4 | Solidity compiler differential | SKELETON | Package only, no runner |
| D5 | Bridge (Wormhole VAA + LZ) | OPERATIONAL | 39K+ tests, 0 divergences |

### Month 4: Track B Foundation

| Week | Domain | Task | Deliverable |
|------|--------|------|-------------|
| 13 | HTTP (D6) | Raw socket smuggling framework + Docker test lab | 56-pair proxy×backend matrix |
| 13 | HTTP (D6) | Full pairwise smuggling matrix run | Divergence report |
| 14 | Serialization (D9) | Protobuf differential fuzzer (Go vs JS vs Rust) | Cross-language divergence detector |
| 14 | DNS (D12) | Fake auth NS + response fuzzer | Controlled DNS test environment |
| 15 | Runtime (D7) | Fuzzilli setup + custom type confusion generator | V8 JIT fuzzer running |
| 15 | TLS (D10) | Edge-case certificate generator + differential testing | Cert acceptance divergence report |
| 16 | Database (D8) | PostgreSQL wire protocol fuzzer + ASAN build | Protocol-level fuzzer |
| 16 | Containers (D11) | Container escape test suite + K8s audit checklist | Automated escape checker |

### Month 5: Track B Exploitation

| Week | Domain | Task | Deliverable |
|------|--------|------|-------------|
| 17-18 | HTTP (D6) | H2 desync testing + WebSocket upgrade confusion | Extended smuggling coverage |
| 17-18 | DNS (D12) | DNSSEC validation edge cases + CoreDNS plugin fuzzing | DNSSEC bypass hunt |
| 19 | Runtime (D7) | WASM boundary fuzzing + isolate escape testing | Runtime escape attempts |
| 19 | Database (D8) | Redis Lua sandbox escape + MongoDB JS sandbox | Scripting escape hunt |
| 20 | All Track B | Triage leads from Month 4 fuzzing | Confirmed zero-days |

### Month 6: Track B Expansion + Weaponization

| Week | Domain | Task | Deliverable |
|------|--------|------|-------------|
| 21 | All | Build PoCs for confirmed zero-days | CVE-ready reports |
| 22 | All | Identify affected bounty targets + submit | Bug bounty reports |
| 23 | TLS (D10) | ASN.1 parser fuzzer + signature verification edge cases | Deep TLS audit |
| 24 | Containers (D11) | runc namespace/mount fuzzing | Container runtime fuzzer |

### Continuous (After Month 6)

All Track A + Track B fuzzers running 24/7. Two leads pipelines:
- Track A leads → DeFi bounty programs (direct disclosure)
- Track B leads → general bounty programs (HackerOne, Bugcrowd, vendor programs)
- Cross-track: Track B zero-day weaponized against Track A targets (e.g., Nginx smuggling → auth bypass on DeFi protocol)

---

## Updated Infrastructure Requirements

| Component | Purpose | Cost |
|-----------|---------|------|
| Fuzzing server (existing) | Track A fuzzers (Domains 1-5) | $50-100/month |
| Fuzzing server #2 | Track B fuzzers (Domains 6-12) | $50-100/month |
| Docker lab | HTTP proxy×backend matrix (56 pairs) | Existing server |
| DNS test lab | Fake auth NS + resolver instances | Existing server |
| K8s test cluster | Container escape + K8s audit | Minikube on existing server |
| ASAN builds storage | Instrumented binaries for crash detection | 100GB local disk |
| V8/SM/JSC builds | JS engine ASAN builds for fuzzing | Built on fuzzing server |

**Total ongoing cost:** $100-200/month for two fuzzing servers.
One Nginx request smuggling zero-day on HackerOne = $5K-$25K+.
One V8 type confusion on Chrome VRP = $10K-$100K+.
ROI is measured in orders of magnitude.

---

## Updated Integration with Existing Pipeline

### Kill Gate Extensions (Track B additions)

**For zero-day findings in general infrastructure:**

- Q5 (Trigger Feasibility): Can the malformed input reach the vulnerable component from the internet? (HTTP: always yes. DNS: depends on resolver exposure. Container: requires initial access.)
- Q11 (Blast Radius): How many servers/clients are affected? Use Shodan/Censys for internet-facing component counts.
- New Q12: **Bounty Program Mapping** — which bounty programs accept this finding? Map: component → vendor program + all downstream programs where the component is deployed.

### OUTCOMES.jsonl Extensions (updated)

```json
{
  "finding_type": "zero_day",
  "domain": "parser | crypto_wasm | aa_bundler | compiler | bridge_client | http_server | runtime | database | serialization | tls_pki | container | dns | container_layer",
  "component": "ethers.js@6.x | nginx@1.25.x | v8@12.x | postgresql@16.x | coredns@1.11.x",
  "detection_method": "differential_fuzz | timing_analysis | edge_case_test | reorg_simulation | request_smuggling | wire_protocol_fuzz | cert_differential | container_escape | dns_response_fuzz",
  "blast_radius": "estimated_affected_servers_or_downloads",
  "cve_id": "CVE-YYYY-XXXXX",
  "bounty_programs": ["hackerone:nginx", "target_bounty:defi_target_behind_nginx"],
  "downstream_bounties": ["target1:$X", "target2:$Y"],
  "track": "A | B | cross_track"
}
```

### Cross-Track Weaponization Workflow

```
Track B zero-day found (e.g., Nginx request smuggling)
  ↓
1. CVE: responsible disclosure to Nginx security team
  ↓ in parallel
2. Track A integration:
   For each DeFi target in your active pipeline:
     a. Check §F3.2: is target behind Nginx?
     b. If yes → craft target-specific smuggling PoC
     c. Demonstrate: smuggled request bypasses auth → access admin API → fund theft path
     d. Kill Gate → Pre-Flight → /disclose to target's bounty program
  ↓
3. HackerOne/Bugcrowd:
   For each managed program using Nginx:
     a. Submit with CVE reference
     b. Demonstrate target-specific impact
  ↓
4. One zero-day → N bounty reports across both tracks
```

---

## Coverage Matrix — Complete Arsenal

```
RESEARCH DOMAIN          COMPONENT CLASS              TOOLING STATUS
──────────────────────────────────────────────────────────────────────
TARGET-LEVEL HUNTING
                         Smart contracts (EVM)         CRITICAL-HUNT
                         Smart contracts (Solana)       SOLANA-HUNT
                         Smart contracts (ZK)           CRITICAL-HUNT §4
                         Full-stack DeFi               DEFI-FULLSTACK
                         Next.js/RSC                   NEXTJS-HUNT
                         Auth flows (JWT+)             JWT-ARSENAL
                         Supply chain                  PIPELINE-EXPANSION
                         Proxy chains                  PIPELINE-EXPANSION
                         Cross-chain messaging         PIPELINE-EXPANSION
                         MEV structural                PIPELINE-EXPANSION
                         Off-chain infra               PIPELINE-EXPANSION

ZERO-DAY RESEARCH — TRACK A (Crypto/DeFi)
  Domain 1               Format parsers (ABI/RLP)      OPERATIONAL (abi-fuzzer, rlp-fuzzer, crosslang-abi-fuzzer)
  Domain 1               Borsh differential            OPERATIONAL (borsh-fuzzer) — 4 findings in borsh-js
  Domain 2               Crypto in WASM/JS             OPERATIONAL (crypto-curves-fuzzer, crypto-timing-harness)
  Domain 3               AA bundlers/paymasters        BUILT (aa-bundler-fuzzer) — needs execution
  Domain 4               Compiler/transpiler bugs      OPERATIONAL (solc-abi-fuzzer)
  Domain 5               Bridge relayer clients         OPERATIONAL (bridge-fuzzer)

ZERO-DAY RESEARCH — TRACK B (General Infrastructure)
  Domain 6               HTTP servers / reverse proxies OPERATIONAL (http-smuggling-lab)
  Domain 7               JS runtimes / VM engines       NOT BUILT (needs Fuzzilli setup)
  Domain 8               Database engines               NOT BUILT (needs ASAN builds)
  Domain 9               Serialization frameworks       OPERATIONAL (serialization-fuzzer) — 6962 divergences
  Domain 10              TLS / PKI implementations      OPERATIONAL (tls-cert-fuzzer)
  Domain 11              Container runtimes / K8s       OPERATIONAL (container-escape-scanner)
  Domain 12              DNS resolvers                  OPERATIONAL (dns-response-fuzzer)
  Domain 13              Container layer formats         SPEC READY (COSE, CWT, WebAuthn, X.509, PASETO, Biscuit, Macaroons)
```

Four operational layers:
1. **Target hunting** — reactive, per-bounty-program, using checklists
2. **Track A zero-day research** — proactive, crypto/DeFi components, fuzzers running
3. **Track B zero-day research** — proactive, general infrastructure, expanding
4. **Container layer research (D13)** — L1 parser bugs propagated through L2 signed containers into L3/L4 auth bypass

Each Track B zero-day multiplies through Track A targets.
Each Track A zero-day multiplies through all applications using the component.
D13 container layer vulns multiply through ALL downstream apps using the container format.
The compound effect is multiplicative, not additive.
