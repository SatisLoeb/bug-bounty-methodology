# LayerZero x Stellar Endpoint -- Cantina $101K Contest Preparation Guide

**Contest:** ~$101K on Cantina (likely $92-96K H/M + $4K QA + $3K judge)
**Code drop:** ~30 hours from now
**Language:** Rust (Soroban smart contracts compiled to WASM)
**Prior art:** LayerZero Sui (Move, C4 $103K, Sep 2025) + Starknet (Cairo, C4 $100K, Oct 2025)

---

## PART 1: LayerZero V2 Architecture (What We're Auditing)

### Core Protocol Components

LayerZero is an omnichain messaging protocol. It does NOT move tokens directly -- it sends verified messages between chains. Tokens (OFT) are an application built on top.

**Four pillars:**
1. **Endpoint** -- Immutable, non-upgradeable smart contract on each chain. Entry point for `send()`, exit point for `lzReceive()`. Manages messaging channels, nonces, library registration.
2. **MessageLib (ULN302)** -- Append-only verification modules. The Ultra Light Node is the default. Handles encoding/decoding packets, fee calculation, and DVN threshold checks.
3. **DVN (Decentralized Verifier Network)** -- Independent entities that verify payloadHash on destination chain. Configurable X-of-Y-of-N quorum (up to 254 DVNs via two-tier system: required + optional).
4. **Executor** -- Permissionless off-chain worker that calls `lzReceive()` on destination. Separated from verification for security isolation.

### Message Flow (Critical Path to Audit)

```
SOURCE CHAIN:
1. OApp calls endpoint.send(dstEid, receiver, message, options)
2. Endpoint assigns nonce (sequential per channel)
3. Endpoint routes to configured SendLib (ULN302)
4. SendLib encodes Packet, emits event with payloadHash
5. DVNs + Executor pick up the event off-chain

DESTINATION CHAIN:
6. DVNs independently verify payloadHash, call ReceiveLib
7. ReceiveLib checks: all required DVNs signed + threshold of optional DVNs met
8. Once threshold satisfied: packet marked VERIFIED
9. Anyone calls commitVerification() -> nonce committed to Endpoint
10. Executor (or anyone) calls lzReceive() -> payload delivered to OApp
```

### Packet Structure

```
Packet {
    nonce: u64,          // Sequential per channel, prevents replay
    srcEid: u32,         // Source endpoint ID (NOT chain ID)
    sender: bytes32,     // Sender address (padded to 32 bytes)
    dstEid: u32,         // Destination endpoint ID
    receiver: bytes32,   // Receiver address
    guid: bytes32,       // Globally Unique ID = hash(nonce + path)
    message: bytes       // Application payload
}
```

**Payload encoding:** `encodePacked(guid, message)`
**Full packet:** `encodePacked(header, payload)` where header = `version + nonce + srcEid + sender + dstEid + receiver`

### Nonce Management (Lazy Inbound Nonce)

- **Outbound nonce:** Strictly sequential, incremented on send
- **Inbound nonce (lazy):** Tracks highest DELIVERED nonce. Packets can execute out-of-order, but all prior nonces must be VERIFIED before execution
- **Key invariant:** Messages can only be cleared in-order (censorship resistance)
- **Skip mechanism:** OApp can mark nonces as "skipped" to unblock channel

### Compose Messages (lzCompose)

- After `lzReceive()`, if options specify composition, additional calls happen
- `lzCompose` lacks built-in sender/endpoint checks -- manual validation required
- Failure in compose does NOT revert the primary `lzReceive`
- Must verify: `_oApp == expectedOApp` AND `msg.sender == endpoint`

### Security Stack Configuration

- Each OApp configures DVNs PER PATHWAY (srcEid <-> dstEid)
- Send library and receive library configured independently
- `allowInitializePath()` controls which origins can initialize channels
- `setPeer()` sets trusted remote OApp address -- CRITICAL: if misconfigured, messages go to wrong address or attacker contract

### Key Invariants (From Prior Contests)

1. LayerZero endpoint owner CANNOT censor messages
2. Endpoint contracts are immutable
3. Only delegates/OApps can configure OApp settings
4. ULN is immutable -- message delivery guaranteed once verified
5. DVN signatures cannot be replayed
6. Admin-only arbitrary payload execution via signed payloads
7. No DOS possible even with non-default configurations

---

## PART 1B: Non-EVM Architecture Pattern (From Sui Spec -- CRITICAL)

The Sui specification document reveals the exact architecture that will be replicated for Stellar. Key differences from EVM that create audit surface:

### The Dynamic Dispatch Problem

EVM has dynamic dispatch (call contracts by address at runtime). Non-EVM chains (Move, Cairo, Soroban) do NOT -- all contract references must be known at compile time. LayerZero solves this with a **Call<Param, Result> object pattern** (Sui) or equivalent indirection.

On Soroban, this will likely use `contractimport!` + client patterns or a registry-based dispatch mechanism. **The translation of this dispatch pattern is the #1 source of critical bugs.**

### Three-Layer Architecture (Expect Same for Stellar)

```
Layer 1: Protocol (On-Chain, IMMUTABLE)
  - Endpoint, Message Libraries, Workers
  - Trust-critical, cannot be upgraded
  - Defines WHAT must happen

Layer 2: PTB Construction / Transaction Builders (On-Chain, Append-Only)
  - Read-only view contracts for metadata
  - NOT in trust boundary
  - Helps off-chain tools build transactions

Layer 3: SDK (Off-Chain)
  - Stateless, deterministic
  - Translates Call objects into executable transactions
  - No logic enforcement
```

**Audit implication:** Layer 1 is the only trust-critical code. Layers 2-3 are likely out of scope but bugs in Layer 1 that ASSUME correct Layer 2/3 behavior are in scope.

### Identity and Capability Model (Sui -> Soroban Translation)

Sui uses CallCap objects for identity (no msg.sender equivalent). **Soroban has `require_auth()` instead.** The translation between these models is where auth bugs hide.

**Two identity types on Sui:**
1. **Package Capability** -- Identity derived from original package address (survives upgrades via one-time witness)
2. **Individual Capability** -- Unique per instance, for delegates/non-contracts

**On Soroban, expect:** Contract addresses + `require_auth()` for the same purpose. Check if the Stellar implementation properly maps both identity types.

### Send Flow (10-Step Process)

```
1. OApp creates root Call<Param, Result> targeting Endpoint.send()
2. Endpoint derives Call B -> Message Library (ULN302) send()
3. ULN302 derives Calls C1...Cn -> Each DVN assign_job()
4. ULN302 derives Call D -> Executor assign_job()
5-6. Workers process assignments, return results via confirm_send()
7-8. ULN302 calls endpoint.confirm_send() to finalize + collect fees
9-10. Endpoint handles refund (auto or manual via OApp)
```

**Audit targets in Send:**
- Step 2: Can a malicious OApp influence which message library is called?
- Steps 3-4: Are DVN/Executor assignments correctly derived? Can jobs be skipped?
- Steps 7-8: Fee collection -- are fees correctly aggregated? Can they be manipulated?
- Steps 9-10: Refund logic -- can excess fees be stolen?

### Receive Flow (5-Step Process)

```
1. Each DVN verifies off-chain, calls uln.verify() on-chain (static calls)
2. Executor triggers uln.commit_verification() (aggregates DVN results)
3. ULN302 calls endpoint.verify() to commit message hash
4. Executor calls endpoint.lz_receive() to begin delivery
5. Endpoint creates dynamic Call<Param, Result> to OApp.lz_receive()
```

**Audit targets in Receive:**
- Step 1: Can DVN verification be spoofed? Replayed? Can a non-DVN call verify()?
- Step 2: Aggregation logic -- is quorum correctly checked? Can threshold be bypassed?
- Step 3: Is the payloadHash commitment atomic? Race conditions?
- Step 4-5: Can lz_receive be called before verification? Can it be called twice?

### LzReceive Discovery (Soroban-Specific Challenge)

On Sui, OApps register `lz_receive_info` metadata blob (versioned binary: 2-byte version + BCS-encoded MoveCall list) so executors know how to construct the receive transaction.

**On Soroban:** This metadata registration mechanism will have a Soroban-specific implementation. Check:
- Can the metadata be set to a malicious payload?
- Can it be updated by unauthorized callers?
- Does version parsing have edge cases?

### SDK Validation Checks (What Off-Chain Tools Enforce)

The Sui spec defines SDK-level safety checks:
- **Send flow:** No unauthorized mutations of signer-owned resources; all targets whitelisted
- **Receive flow:** PTB must not contain/access executor-owned objects

**Audit insight:** If these checks ONLY exist in the off-chain SDK and not on-chain, a malicious actor building their own transaction can bypass them. Look for on-chain enforcement gaps.

---

## PART 2: Stellar/Soroban (Target Platform)

### What is Soroban?

Stellar's smart contract platform. Contracts written in **Rust**, compiled to **WebAssembly (WASM)**, executed in Stellar's host environment.

### Key Differences from EVM/Move/Cairo

| Feature | EVM | Soroban |
|---------|-----|---------|
| Language | Solidity | Rust |
| Execution | EVM bytecode | WASM |
| Reentrancy | Possible (guard needed) | **Disallowed by design** |
| Storage | Persistent slots | 3 types: Instance, Persistent, Temporary |
| Auth model | msg.sender | `require_auth()` framework |
| Contract size | ~24KB | **64KB max** |
| Overflow | Unchecked (Solidity <0.8) | **Wraps in release mode** (no panic) |
| Address format | 20 bytes | Public key / contract ID |

### Soroban Storage Types (Audit-Critical)

1. **Instance Storage** -- Loaded with every call. ~100KB limit. For config/admin data. TTL tied to contract instance.
2. **Persistent Storage** -- Expensive but survives independently. For user balances, state. Archivable/recoverable.
3. **Temporary Storage** -- Auto-deleted after TTL expires. For ephemeral data.

**CRITICAL SECURITY ISSUE:** TTL extension has NO access control. Anyone can extend any entry's TTL. Never rely on TTL expiration for security enforcement. Time bounds must be in the data itself.

### Soroban Authorization Model

- `require_auth(address)` -- Verifies the address authorized this specific function call
- `require_auth_for_args(address, args)` -- Same but with custom args
- Authorization entries form a TREE structure (SorobanAuthorizedInvocation)
- Sub-invocations in cross-contract calls must be pre-authorized
- Built-in replay prevention
- **Key audit pattern:** Missing `require_auth` on state-changing functions

### Soroban-Specific Vulnerability Classes

1. **Host-boundary type safety** -- `Vec<T>` / `Map<K,V>` elements converted to `Val` at host boundary. No guarantee of safe conversion back. Can halt execution.
2. **Unbounded data in Instance Storage** -- DoS via growing data that loads on every call
3. **Integer overflow in release mode** -- Rust wraps (doesn't panic) in release builds with `overflow-checks = false`. The Soroban SDK itself had bugs here (Vec::slice, Bytes::slice, Prng::gen_range)
4. **Stale contract dependencies** -- `contractimport!` doesn't enforce dependency versions
5. **TTL misuse** -- Relying on expiration for security (anyone can extend)
6. **Panic vs panic_with_error!** -- `panic!()` causes false positives in fuzz testing
7. **Cross-contract call authorization** -- Missing auth checks on sub-invocations

### Development Setup (Install Before Contest)

```bash
# Install Stellar CLI
curl -fsSL https://github.com/stellar/stellar-cli/raw/main/install.sh | sh -s -- --install-deps

# Or via cargo
cargo install --locked stellar-cli

# Add WASM target
rustup target add wasm32-unknown-unknown

# Verify
stellar --version
```

### Building/Testing Soroban Contracts

```bash
# Build
stellar contract build

# Run tests
cargo test

# Deploy to testnet
stellar contract deploy --wasm target/wasm32-unknown-unknown/release/contract.wasm --network testnet
```

---

## PART 3: What the Contest Code Will Look Like

### Expected Repository Structure (Based on Sui + Starknet Patterns)

```
contracts/
  endpoint/           # EndpointV2 -- main entry/exit point
    src/
      endpoint_v2.rs        # Core send/receive/compose logic
      messaging_channel.rs  # Nonce management, channel state
      messaging_composer.rs # lzCompose handling
      message_lib_manager.rs # Library registration/configuration

  message-libs/
    uln-302/          # Ultra Light Node 302
      src/
        uln302.rs           # DVN threshold verification
        send_uln.rs         # Send-side encoding
        receive_uln.rs      # Receive-side verification
    blocked-message-lib/    # Blocks all messages (safety)
    message-lib-common/     # Shared types/utils
    treasury/               # Fee collection

  workers/
    dvn/              # DVN contract
      src/
        dvn.rs              # DVN verification logic
        fee_lib.rs          # DVN fee calculation
    executor/               # Executor contract (likely OOS)

  oapps/              # OApp/OFT standards (may be OOS)
    oapp/
    oft/

  libs/
    multisig/         # Multi-signature verification
    utils/            # Encoding, hashing, type conversion
```

### Soroban-Specific Dispatch Pattern (KEY AUDIT AREA)

Unlike Sui (Move's "Hot Potato" Call objects) or Starknet (Cairo dispatcher interfaces), Soroban handles cross-contract calls through:

1. **`contractimport!` macro** -- Imports contract interface, generates Client type
2. **Client-based invocation** -- `ContractClient::new(&env, &contract_id).function(args)`
3. **Address-based dispatch** -- `env.invoke_contract(&contract_id, &symbol, &args)`

The challenge: LayerZero needs runtime-configurable message library dispatch (OApp chooses its library). Soroban's `contractimport!` is compile-time. So expect one of:
- A **registry pattern** with `env.invoke_contract()` for dynamic dispatch
- A **trait-based pattern** where libraries implement a common interface
- A **wrapper contract** that dispatches based on stored config

**Where bugs hide in this translation:**
- Type confusion in `env.invoke_contract()` args (no compile-time checking)
- Missing validation of return values from dynamic calls
- Incorrect error propagation from sub-contract panics
- Authorization context not properly propagated across dynamic calls

### Expected In-Scope (Based on Sui $103K and Starknet $100K)

**IN SCOPE:**
- Endpoint V2 (send, receive, compose, channel management)
- ULN-302 message library (DVN verification, threshold logic)
- DVN contracts (verification, fee calculation)
- Supporting libraries (multisig, utils)

**LIKELY OUT OF SCOPE:**
- Executors
- OApp/OFT application layer
- External dependencies (Soroban SDK, Stellar core)

### Critical Audit Focus Areas (From Prior Contest Descriptions)

1. **Message Sequencing & Finality** -- Prevent out-of-order execution and replay
2. **Fee Integrity** -- Validate fee calculations match cross-implementation
3. **Channel Isolation** -- Malicious OApps cannot interfere with others
4. **Error State Handling** -- Failed messages stored for retry/clearing
5. **Censorship Resistance** -- No entity can block message delivery
6. **DVN Replay Prevention** -- Signatures cannot be reused
7. **Immutability Enforcement** -- Configuration cannot be overridden by admin

---

## PART 4: Prior LayerZero Findings & Attack Patterns

### Historical Vulnerabilities Found

**1. Nonce Path Breaking (Medium)**
- Attack: Call `setConfig()` from malicious UA in same tx as legitimate UA's `send()`
- Impact: Relayer blocks legitimate message, breaking nonce sequence permanently
- Fix: Relayer checks WHICH UA called setConfig
- **Pattern for Soroban:** Check if config changes are properly scoped to the calling OApp

**2. Fee Manipulation**
- Attack: UA temporarily sets custom Oracle/Relayer returning zero fees
- Impact: Free cross-chain messages, draining fee pool
- **Pattern for Soroban:** Verify fee calculation cannot be bypassed via config changes

**3. setPeer Unauthorized Modification ($GAIN Exploit, $3M lost)**
- Attack: Insider/compromised admin calls `setPeer()` to point to attacker contract
- Impact: Attacker mints unlimited tokens via fake cross-chain messages
- Root cause: No timelock or multisig on setPeer
- **Pattern for Soroban:** Check access control on peer configuration

**4. Stargate Token Desynchronization (Zellic)**
- Attack: Business logic bug causing cross-chain token balance mismatch
- Impact: Broken Instant Finality Guarantee, permanently locked funds
- **Pattern for Soroban:** Verify atomic consistency of cross-chain state transitions

**5. Blocking via lzReceive Revert (OtterSec, Aptos)**
- Attack: If receiver aborts, unprocessable packet blocks the channel
- Impact: DoS on message channel
- **Pattern for Soroban:** Check error handling in lzReceive path

**6. Trust Security -- 3 High Severity (V1)**
- Repeatable fund freezing in NonBlockingLzApp
- Missed by multiple auditors
- **Pattern:** The NonBlocking wrapper creates additional attack surface

### Known Out-of-Scope from Prior Contests

- Malformed byte array keccak hash collision (Starknet-specific)
- Alexandria library / Starknet core library bugs
- Executor bugs (typically out of scope)

---

## PART 5: Hunting Patterns to Apply

### Bridge-Specific Patterns (CLAUDE.md #23 + Hunt Checklist)

| Pattern | Description | How to Apply |
|---------|-------------|-------------|
| P-BRIDGE-001 | Duplicate signature acceptance in quorum | Check DVN verification: can same DVN sign twice? Is dedup enforced? |
| P-BRIDGE-002 | Message type filtering excludes value-carrying messages | Check if certain message types bypass verification |
| P-BRIDGE-003 | Hash mismatch between message storage and receipt lookup | Compare payloadHash encoding on send vs verify side |
| P-BRIDGE-004 | Wrong fund source in withdrawal | Check fee withdrawal sources and destinations |
| P-BRIDGE-005 | Reentrancy during state transition | Soroban disallows reentrancy BUT check cross-contract calls |
| P-BRIDGE-006 | Arbitrary external call via user-controlled bridge data | Check if message payload influences contract calls |
| P-BRIDGE-007 | Cross-layer message size amplification | Check message size validation and gas estimation |
| P-BRIDGE-008 | Permissionless registration drains gateway | Check OApp/library registration access control |

### Soroban-Specific Attack Vectors

1. **Integer overflow in WASM release builds**
   - Rust wraps on overflow in release mode (no panic)
   - Check all arithmetic in nonce handling, fee calculation, threshold computation
   - Look for `checked_add`, `checked_sub`, `checked_mul` usage (or lack thereof)

2. **Storage type misuse**
   - Instance Storage with unbounded data -> DoS
   - Temporary Storage for security-critical data -> data loss after TTL
   - TTL extension by anyone -> time-based assumptions broken

3. **Authorization gaps**
   - Missing `require_auth()` on admin functions
   - Cross-contract call auth context not propagated
   - Delegate permission escalation

4. **Host-boundary type confusion**
   - Vec/Map elements losing type info at host boundary
   - Deserialization failures halting contract execution
   - Incorrect type casting in packet decode

5. **WASM-specific**
   - Contract size approaching 64KB limit (functionality cut corners?)
   - Resource metering bypass (100M instruction limit)
   - Memory bounds (50MB limit)

### Cross-Chain Translation Bugs (HIGHEST VALUE)

When porting from EVM/Move/Cairo to Soroban, translation errors are the #1 source of critical bugs:

1. **Address encoding mismatch**
   - EVM: 20 bytes padded to bytes32
   - Soroban: Stellar addresses are different format
   - Check: Does bytes32 conversion preserve/validate correctly?

2. **Nonce handling differences**
   - EVM: uint256 nonce
   - Soroban: u64 max = 18,446,744,073,709,551,615
   - Check: Overflow possible? Consistent with other chains?

3. **Hash function differences**
   - EVM: keccak256
   - Soroban: Likely sha256 (Stellar native) or keccak256 via SDK
   - Check: Hash must match cross-chain for verification

4. **Error handling semantics**
   - EVM: revert rolls back everything
   - Soroban: panic traps the WASM module, different rollback semantics
   - Check: Failed lzReceive cleanup correctness

5. **Storage model translation**
   - EVM: Everything persistent by default
   - Soroban: Must choose Instance/Persistent/Temporary
   - Check: Critical state in wrong storage type

6. **Access control translation**
   - EVM: modifier-based (onlyOwner, msg.sender checks)
   - Soroban: require_auth() framework
   - Check: Every EVM modifier has Soroban equivalent

7. **Byte order / encoding**
   - EVM: big-endian packed encoding
   - Soroban: Check endianness of packet encoding
   - Mismatch = messages fail or worse, verify against wrong data

---

## PART 6: Speed Strategy for Contest Launch

### Hour 0-2: Triage & Architecture Map

```bash
# 1. Clone repo immediately when available
git clone <contest-repo>

# 2. Get LOC count
find . -name "*.rs" | xargs wc -l | sort -n

# 3. Map all public functions
grep -rn "pub fn" --include="*.rs" | grep -v test | grep -v "mod tests"

# 4. Identify entry points
grep -rn "fn send\|fn lz_receive\|fn verify\|fn commit\|fn compose" --include="*.rs"

# 5. Check for unsafe blocks
grep -rn "unsafe" --include="*.rs"

# 6. Check for raw arithmetic (no checked_*)
grep -rn "\.wrapping_\|as u64\|as u32\|as u128" --include="*.rs"
```

### Hour 2-6: Deep Dive Priority Order

1. **Endpoint send/receive** -- The core message path. Every bug here is High/Critical.
2. **ULN302 verification** -- DVN threshold logic. Quorum bypass = Critical.
3. **Nonce management** -- Lazy inbound nonce. Replay/skip bugs = High.
4. **DVN contract** -- Signature verification, replay prevention.
5. **Multisig library** -- If custom implementation, high value target.
6. **Fee calculation** -- Consistency with other chain implementations.

### Hour 6-12: Pattern Application

Apply each hunting pattern from Part 5 systematically against the code.

### Specific Grep Patterns for Launch

```bash
# Authorization checks
grep -rn "require_auth" --include="*.rs" | wc -l
grep -rn "pub fn" --include="*.rs" | grep -v "require_auth" | grep -v test

# Arithmetic safety
grep -rn "checked_add\|checked_sub\|checked_mul\|checked_div" --include="*.rs"
grep -rn "\+ \|\ - \|\* \|/ " --include="*.rs" | grep -v "//" | grep -v test

# Storage usage
grep -rn "instance\(\)\|persistent\(\)\|temporary\(\)" --include="*.rs"

# Error handling
grep -rn "unwrap()\|expect(" --include="*.rs" | grep -v test

# Cross-chain encoding
grep -rn "to_bytes\|from_bytes\|encode\|decode\|serialize\|deserialize" --include="*.rs"

# Hash functions
grep -rn "keccak\|sha256\|hash" --include="*.rs"

# Access control
grep -rn "owner\|admin\|delegate\|authority" --include="*.rs"
```

---

## PART 7: Tooling Checklist

### Required (Install Now)

- [x] Rust toolchain (`rustup`)
- [ ] Stellar CLI (`cargo install --locked stellar-cli`)
- [ ] WASM target (`rustup target add wasm32-unknown-unknown`)
- [x] cargo (for building/testing)
- [ ] `cargo-expand` (for macro expansion: `cargo install cargo-expand`)

### Recommended

- [ ] Scout Soroban (static analysis: `cargo install scout-audit`)
- [ ] cargo-fuzz (fuzzing: `cargo install cargo-fuzz`)
- [ ] Soroban SDK docs bookmarked: https://docs.rs/soroban-sdk/latest/soroban_sdk/

### Reference Materials to Have Open

- LayerZero V2 EVM EndpointV2.sol: https://github.com/LayerZero-Labs/LayerZero-v2/blob/main/packages/layerzero-v2/evm/protocol/contracts/EndpointV2.sol
- LayerZero V2 Sui Endpoint: https://github.com/code-423n4/2025-09-layerzero (reference for non-EVM patterns)
- LayerZero V2 Starknet Endpoint: https://github.com/code-423n4/2025-10-layerzero (most recent non-EVM audit)
- Soroban Authorization: https://developers.stellar.org/docs/build/smart-contracts/example-contracts/auth
- Soroban Storage: https://developers.stellar.org/docs/learn/fundamentals/contract-development/storage/persisting-data
- LayerZero Integration Checklist: https://docs.layerzero.network/v2/tools/integration-checklist
- LayerZero Whitepaper V2.1.1: https://layerzero.network/publications/LayerZero_Whitepaper_V2.1.1.pdf

---

## PART 8: High-Value Finding Categories

### Critical ($10K+)

1. **Packet forgery** -- Craft a message that passes DVN verification without actual cross-chain send
2. **Nonce replay** -- Execute same message twice
3. **DVN quorum bypass** -- Satisfy threshold with fewer signatures than required
4. **Arbitrary message injection** -- Send message as if from different OApp
5. **Channel hijacking** -- Intercept/redirect messages meant for another OApp

### High ($3-10K)

1. **Nonce desync** -- Break channel by creating gap in nonce sequence
2. **DoS on message delivery** -- Block specific messages from being executed
3. **Fee drain** -- Extract fees without providing service, or bypass fees
4. **Storage corruption** -- Write to wrong storage slot/type causing state corruption
5. **Auth bypass on config** -- Change OApp configuration without authorization

### Medium ($1-3K)

1. **Incorrect fee calculation** -- Overcharge/undercharge compared to other chains
2. **Edge case in lazy nonce** -- Specific sequence causes stuck channel
3. **Missing validation** -- Accept malformed packets that should be rejected
4. **Inconsistent behavior** -- Different outcome than EVM/Sui/Starknet for same input
5. **Storage TTL misuse** -- Critical data in Temporary storage

---

## PART 9: Critical Observations from Reference Code (Starknet)

Studied the Starknet endpoint implementation (702 LOC) and ULN302 (~900 LOC). Key findings for Soroban translation:

### Verification Logic Pattern (ULN302._check_verifiable)

```
1. For each required DVN: check hash_lookup[headerHash][payloadHash][dvn].submitted == true AND confirmations >= required
2. If ALL required DVNs pass AND no optional DVNs exist -> return true (early exit)
3. For optional DVNs: count verified, decrement threshold counter
4. Return true only if remaining_threshold reaches 0
```

**Audit focus:** The early exit on line 811-814 (if all required pass and no optionals) -- does the Soroban version handle this edge case identically? Missing this early return = always requiring optional DVN threshold even when none configured.

### verify() is PERMISSIONLESS

The `verify()` function on ULN302 (line 185-209) takes `get_caller_address()` as the DVN -- **anyone can call this**. The security comes from `_check_verifiable` checking that the caller's address matches a configured DVN in the OApp's UlnConfig. If the config resolution has bugs, a non-DVN could submit valid-looking verifications.

### commit() Does NOT Check Caller

The `commit()` function (line 211-238) is permissionless -- anyone can trigger it once DVN threshold is met. It:
1. Validates packet header against local EID
2. Gets receive config for the receiver
3. Calls `_verify_and_reclaim_storage` (which asserts verifiable AND clears DVN storage)
4. Calls `endpoint.commit(origin, receiver, payload_hash)`

**Audit target:** The storage reclamation in step 3. After commit, DVN verifications are cleared (set to EMPTY_VERIFICATION). This prevents re-commit of same nonce but also means a failed commit could leave inconsistent state.

### _committable() Logic (Endpoint)

```cairo
origin.nonce > lazy_inbound_nonce
    || self.messaging_channel._has_payload_hash(receiver, src_eid, sender, nonce)
```

A nonce is committable if it's NEW (> lazy nonce) OR if it already has a payload hash stored. This means a committed-but-not-executed nonce CAN be re-committed (overwritten). **Check if Soroban version preserves this intentional behavior.**

### Fee Payment Pattern

The Starknet implementation uses ERC20 allowance-based fee payment:
1. OApp gives allowance to Endpoint
2. Endpoint calculates total fees by summing payee amounts (does NOT trust MessageLib's total)
3. Endpoint transfers from sender to each payee
4. Refunds remainder to refund_address

**Audit target in Soroban:** Stellar uses different token standards (SEP-41/Stellar Asset Contract). The fee payment logic must correctly handle Soroban's token authorization model.

### Authorization Model

```cairo
fn _assert_authorized(oapp) {
    caller == delegates[oapp] || caller == oapp
}
```

Either the OApp itself or its configured delegate can modify settings. **Check Soroban version:** Is the delegate check consistent across all config functions?

### lzReceive Execution Order

```
1. Create payload = guid + message
2. Clear payload hash FIRST (prevents reentrancy)
3. Check executor allowance for value transfer
4. Transfer value from executor to receiver
5. Call receiver.lz_receive(origin, guid, message, executor, value, extra_data)
6. Emit PacketDelivered
```

**Critical:** Step 2 clears BEFORE execution. In Soroban, since reentrancy is disallowed by design, is the clear-first pattern still implemented? If not, could there be a state inconsistency if the receiver call panics?

---

## Key References

### LayerZero Documentation
- [Protocol Overview](https://docs.layerzero.network/v2/concepts/protocol/protocol-overview)
- [Message, Packet, and Payload](https://docs.layerzero.network/v2/concepts/protocol/packet)
- [Message Library](https://docs.layerzero.network/v2/concepts/protocol/message-library)
- [DVN Overview](https://docs.layerzero.network/v2/workers/off-chain/dvn-overview)
- [Integration Checklist](https://docs.layerzero.network/v2/tools/integration-checklist)
- [V2 Deep Dive (Medium)](https://medium.com/layerzero-official/layerzero-v2-deep-dive-869f93e09850)
- [DVN Explained (Medium)](https://medium.com/layerzero-official/layerzero-v2-explaining-dvns-02e08cce4e80)

### Prior LayerZero Audits
- [LayerZero Audits Repo](https://github.com/LayerZero-Labs/Audits)
- [C4 Sui Endpoint ($103K)](https://code4rena.com/audits/2025-09-layerzero-endpoint-v2-sui)
- [C4 Starknet Endpoint ($100K)](https://code4rena.com/audits/2025-10-layerzero-starknet-endpoint)
- [Zellic OApp/OFT Report](https://reports.zellic.io/publications/layerzero-oapp--oft)
- [ChainSecurity OFT/OApp](https://www.chainsecurity.com/security-audit/layerzero-oft-oapp)
- [Paladin V2 Audit (Dec 2023)](https://paladinsec.co/projects/layerzero/)

### Historical Vulnerabilities
- [Cross-Chain Messaging Vulnerability (Medium)](https://medium.com/@Heuss/layerzeros-cross-chain-messaging-vulnerability-e5ef48c5ccec)
- [$GAIN Exploit -- setPeer Attack](https://www.bitget.com/news/detail/12560604986269)
- [LayerZero Cross-Chain Security (Cantina Blog)](https://cantina.xyz/blog/cross-chain-security-with-layerzero-labs)

### Soroban/Stellar Security
- [Veridise Soroban Security Checklist](https://veridise.com/blog/audit-insights/building-on-stellar-soroban-grab-this-security-checklist-to-avoid-vulnerabilities/)
- [CoinFabrik Scout for Soroban](https://www.coinfabrik.com/blog/scouting-for-vulnerabilities-in-stellar-smart-contracts/)
- [Soroban Authorization](https://developers.stellar.org/docs/build/smart-contracts/example-contracts/auth)
- [Soroban Storage Types](https://developers.stellar.org/docs/learn/fundamentals/contract-development/storage/persisting-data)
- [Stellar CLI](https://developers.stellar.org/docs/tools/cli)
