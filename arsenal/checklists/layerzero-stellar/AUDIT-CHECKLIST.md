# LayerZero x Stellar Integration — Audit Checklist

## When code drops, apply in order:

### 0. Instant Triage (10 min)

```bash
# clone + LOC
git clone <repo> && cd <repo>
find . -name "*.rs" -not -path "*/test*" | xargs wc -l | sort -n | tail -20

# Cargo.toml — check overflow behavior FIRST
grep -rn "overflow-checks" Cargo.toml */Cargo.toml

# all public entry points
grep -rn "pub fn" --include="*.rs" | grep -v test | grep -v "mod tests" | wc -l

# diff against prior non-EVM endpoint if available
# git diff <starknet-or-sui-ref> -- contracts/
```

### 1. Architecture Map (30 min)
- [ ] Count LOC per file
- [ ] Map the message flow: Stellar → Endpoint → DVN → Destination chain
- [ ] Identify: which contracts are new? Which are forked from Sui/Starknet endpoint?
- [ ] git diff against Starknet endpoint — the CHANGES are where bugs live

---

### 2. Address Encoding (HIGH PRIORITY — 2h)
- [ ] How are Stellar Ed25519 addresses encoded to 32-byte LZ format?
- [ ] Can an attacker craft an address that decodes differently on Stellar vs EVM?
- [ ] Is there padding? Left-pad or right-pad? Zero-extension safe?
- [ ] Does `sender` field in packet match the actual Stellar transaction sender?

**P-BRIDGE-003: Hash mismatch between storage and lookup**
```bash
# find all hash/encode operations — compare send side vs receive side
grep -rn "sha256\|keccak\|hash\|digest" --include="*.rs" | grep -v test
grep -rn "to_bytes\|from_bytes\|encode\|decode" --include="*.rs" | grep -v test
# compare: is payloadHash computed identically on send and verify paths?
```

**META-005: Cross-layer semantic mismatch**
```bash
# Stellar address = 56-char base32 (G... or C...) vs EVM = 20 bytes
# check all address conversion points
grep -rn "Address\|AccountId\|bytes32\|to_array\|from_array" --include="*.rs" | grep -v test
```

---

### 3. Nonce / Ordering (1h)
- [ ] Is nonce sequential per (src_eid, sender, dst_eid, receiver) tuple?
- [ ] Can nonces be replayed across chains?
- [ ] Can a message with nonce N+1 be delivered before nonce N?
- [ ] What happens on nonce gap? DoS on the channel?

**META-009: Global counter must match sum of per-entity counters**
```bash
# find all nonce increments — verify no double-increment or skip
grep -rn "nonce\|next_nonce\|inbound_nonce\|outbound_nonce" --include="*.rs" | grep -v test
# check: is lazy_inbound_nonce updated atomically with message delivery?
```

---

### 4. DVN Verification (HIGH PRIORITY — 3h)
- [ ] How do DVNs verify Stellar transactions? On-chain verification or off-chain attestation?
- [ ] Is the quorum threshold correctly enforced?
- [ ] Is the verification payload correctly derived from the Stellar transaction?

**P-BRIDGE-001: Duplicate signature acceptance in quorum**
```bash
# find DVN verification/submit functions
grep -rn "fn verify\|fn submit\|fn confirm\|fn attest" --include="*.rs" | grep -v test
# check: is there dedup on DVN address? can same DVN call verify() twice?
grep -rn "has_verified\|already_verified\|submitted\|set\|insert" --include="*.rs" | grep -v test
```

**META-004: Inconsistent validation between entry points**
```bash
# compare: verify() vs commit_verification() vs lz_receive() — do they validate same fields?
grep -rn "fn verify\|fn commit\|fn lz_receive\|fn receive" --include="*.rs" | grep -v test
# each should check: src_eid, sender, nonce, payload_hash
```

---

### 5. Message Receive Flow (2h)
- [ ] What validates that a received message actually originated on Stellar?
- [ ] Rule #23: Source chain AND sender address validated?
- [ ] Can an attacker forge a message that appears to come from Stellar?
- [ ] Is the payload_hash verified before execution?

**P-BRIDGE-002: Message type filtering excludes value-carrying messages**
```bash
# are there different message types? does any type skip verification?
grep -rn "msg_type\|message_type\|MSG_TYPE\|MessageType" --include="*.rs" | grep -v test
```

**P-BRIDGE-006: Arbitrary external call via user-controlled bridge data**
```bash
# does the message payload influence which contract is called?
grep -rn "invoke_contract\|call_contract\|env\.invoke" --include="*.rs" | grep -v test
# trace: can a user-crafted message.payload reach env.invoke_contract?
```

---

### 6. Send Flow (1h)
- [ ] What happens when a user sends a message FROM Stellar?
- [ ] Is the fee calculation correct? Can fees be manipulated?
- [ ] Is there a gas estimation mechanism? Can it be gamed?

**P-BRIDGE-007: Cross-layer message size amplification**
```bash
# is there a max message size? can oversized messages cause OOG on destination?
grep -rn "max_message\|MAX_PAYLOAD\|message_size\|len()\|size" --include="*.rs" | grep -v test
```

**P-BRIDGE-004: Wrong fund source in withdrawal**
```bash
# trace fee collection: who pays? where do fees go? can they be stolen?
grep -rn "transfer\|pay\|fee\|treasury\|collect\|withdraw" --include="*.rs" | grep -v test
```

**META-010: Chain-specific constants**
```bash
# check hardcoded values — are EIDs, gas limits, decimals correct for Stellar?
grep -rn "const \|static \|EID\|CHAIN_ID\|GAS\|DECIMAL" --include="*.rs" | grep -v test
```

---

### 7. OApp Integration (1h)
- [ ] How do Stellar OApps (applications) register with the endpoint?
- [ ] Can a malicious OApp steal messages intended for another OApp?
- [ ] Compose/callback flow — reentrancy in compose?

**P-BRIDGE-008: Permissionless registration drains gateway**
```bash
# who can register OApps/libraries? is there access control?
grep -rn "register\|set_peer\|set_config\|set_library\|initialize" --include="*.rs" | grep -v test
```

---

### 8. Soroban-Specific Patterns (2h)

**R-001: unwrap()/expect() panic in production (DoS)**
```bash
grep -rn "\.unwrap()\|\.expect(" --include="*.rs" | grep -v test | grep -v "#\[test\]"
# every hit = potential DoS if attacker can trigger the None/Err path
```

**R-002: Integer overflow in release mode (CRITICAL if overflow-checks=false)**
```bash
grep -rn "overflow-checks" Cargo.toml */Cargo.toml
# if false or absent: ALL arithmetic is silent wrap in release
grep -rn "checked_add\|checked_sub\|checked_mul\|checked_div" --include="*.rs" | grep -v test
# compare to total arithmetic operations:
grep -rn " + \| - \| \* \| / " --include="*.rs" | grep -v test | grep -v "//" | wc -l
```

**R-003: unsafe blocks**
```bash
grep -rn "unsafe\s*{" --include="*.rs" | grep -v test
```

**R-005: Unchecked type casts (truncation)**
```bash
grep -rn "as u64\|as u32\|as u128\|as usize\|as i64\|as i128" --include="*.rs" | grep -v test
# each cast = potential truncation if source > target range
```

**R-007: TTL extension permissionless (storage griefing)**
```bash
grep -rn "extend_ttl\|bump\|instance().extend_ttl\|persistent().extend_ttl" --include="*.rs" | grep -v test
# anyone can call extend_ttl — never rely on expiry for security
```

**R-008: Missing require_auth on mutating functions (auth bypass)**
```bash
# list ALL pub fn, then check which ones call require_auth
grep -rn "pub fn" --include="*.rs" | grep -v test > /tmp/all_pub_fns.txt
grep -rn "require_auth" --include="*.rs" | grep -v test > /tmp/auth_calls.txt
# diff: any pub fn that mutates state but does NOT require_auth = finding
```

**Soroban storage type audit**
```bash
# critical state in wrong storage type?
grep -rn "instance()\|persistent()\|temporary()" --include="*.rs" | grep -v test
# verify: nonces in persistent (not temporary!), config in instance, ephemeral data in temporary
```

**Panic paths (DoS surface)**
```bash
grep -rn "panic!\|panic_with_error!\|assert!\|assert_eq!\|assert_ne!" --include="*.rs" | grep -v test
# each assert/panic reachable by external input = DoS vector
```

---

### 9. Cross-Chain Invariants (1h)
- [ ] META-005: Cross-layer semantic mismatch (Stellar vs EVM concepts)
- [ ] Are token decimals handled consistently? (Stellar=7, EVM=18)
- [ ] Is the eid (endpoint ID) for Stellar unique and correctly validated?
- [ ] Can a message loop back to Stellar from itself?

**META-007: Decimal consistency across token layers**
```bash
# if OFT in scope: check decimal conversion between Stellar (7) and EVM (18)
grep -rn "decimal\|DECIMAL\|shared_decimal\|local_decimal\|ld2sd\|sd2ld" --include="*.rs" | grep -v test
# rounding in conversion = loss of funds
```

**Byte order / encoding consistency**
```bash
# EVM = big-endian packed, Soroban = ?
grep -rn "to_be_bytes\|to_le_bytes\|from_be_bytes\|from_le_bytes\|BigEndian\|LittleEndian" --include="*.rs" | grep -v test
# mismatch = messages decode wrong on destination chain
```

---

### 10. Upgrade / Admin (30 min)
- [ ] Is the endpoint upgradeable? By whom?
- [ ] Can message libraries be swapped? Time-lock?
- [ ] Is there a kill switch / pause mechanism?

```bash
# find all admin/owner functions
grep -rn "owner\|admin\|set_admin\|transfer_ownership\|upgrade\|migrate" --include="*.rs" | grep -v test
# check: do admin functions have proper auth?
```

---

## Pattern Application Matrix

### Bridge Patterns (C4 database)

| Pattern | Grep | Applied? | Result |
|---|---|---|---|
| P-BRIDGE-001: Duplicate sig in quorum | `verify.*dvn\|submitted\|has_verified` | [ ] | |
| P-BRIDGE-002: Message type filtering | `msg_type\|message_type` | [ ] | |
| P-BRIDGE-003: Hash mismatch storage/lookup | `sha256\|keccak\|hash.*payload` | [ ] | |
| P-BRIDGE-004: Wrong fund source | `transfer\|pay\|fee\|treasury` | [ ] | |
| P-BRIDGE-005: Reentrancy during state transition | N/A (Soroban disallows reentrancy) | [ ] | |
| P-BRIDGE-006: Arbitrary call via user data | `invoke_contract\|env\.invoke` | [ ] | |
| P-BRIDGE-007: Cross-layer size amplification | `max_message\|MAX_PAYLOAD\|len()` | [ ] | |
| P-BRIDGE-008: Permissionless registration | `register\|set_peer\|initialize` | [ ] | |

### Meta Patterns

| Pattern | Grep | Applied? | Result |
|---|---|---|---|
| META-004: Inconsistent validation | compare verify vs commit vs receive | [ ] | |
| META-005: Cross-layer semantic mismatch | address/nonce/hash encoding | [ ] | |
| META-007: Decimal consistency | `decimal\|ld2sd\|sd2ld` | [ ] | |
| META-009: Global ≠ sum of per-entity | `nonce\|total_fee\|counter` | [ ] | |
| META-010: Chain-specific constants | `const.*EID\|CHAIN_ID\|GAS` | [ ] | |

### Rust/Soroban Patterns

| Pattern | Grep | Applied? | Result |
|---|---|---|---|
| R-001: unwrap/expect panic | `.unwrap()\|.expect(` | [ ] | |
| R-002: Overflow in release | `overflow-checks` in Cargo.toml | [ ] | |
| R-003: unsafe blocks | `unsafe {` | [ ] | |
| R-005: Unchecked casts | `as u64\|as u32\|as u128` | [ ] | |
| R-007: TTL extension permissionless | `extend_ttl\|bump` | [ ] | |
| R-008: Missing require_auth | pub fn without require_auth | [ ] | |

---

## Time Budget: 13 days

| Phase | Days | Focus | Patterns |
|-------|------|-------|----------|
| Triage + Architecture | 1 | LOC, flow map, diff against ref | — |
| Address + Nonce | 1-2 | Encoding, cross-chain identity | P-BRIDGE-003, META-005, META-010 |
| DVN + Receive (HIGHEST VALUE) | 3-5 | Verification, quorum, delivery | P-BRIDGE-001, P-BRIDGE-002, META-004 |
| Send + OApp | 6-7 | Fees, registration, compose | P-BRIDGE-004, P-BRIDGE-007, P-BRIDGE-008 |
| Soroban-Specific | 8-9 | Auth, overflow, storage, panic | R-001 to R-008 |
| Cross-Chain Invariants | 10 | Decimals, encoding, loopback | META-007, META-009 |
| PoC + Reports | 11-13 | Foundry/cargo test PoCs, writeup | — |

## Priority Stack (if time is short)

1. **R-002** overflow-checks in Cargo.toml → if false, audit ALL arithmetic (10 min check, massive payoff)
2. **R-008** require_auth coverage → pub fn without auth = instant HIGH (30 min scan)
3. **P-BRIDGE-001** DVN duplicate verification → quorum bypass = CRITICAL
4. **P-BRIDGE-003** hash mismatch send vs verify → packet forgery = CRITICAL
5. **META-005** address encoding mismatch → cross-chain identity confusion = HIGH
6. **R-001** unwrap/expect → DoS surface mapping (15 min scan)
7. **P-BRIDGE-006** user data → contract call → arbitrary execution = CRITICAL
