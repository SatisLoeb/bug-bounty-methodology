---
name: crypto-lib-vectors
description: Seam-hunting vector pack for crypto libraries, protocols, binary parsers, VMs, compilers, and serialization formats -- the gap between spec authors and implementers.
---

# Crypto-libs / Protocols / Low-level -- Vector Pack

## The seam

The two disciplines are **spec authors** (RFC / BIP / NIST FIPS / IACR paper / protocol designers) and **implementers** (the people who write the library, the bindings, the VM, the parser). The spec author writes "the verifier MUST reject the identity element" in prose buried in section 5.1.3 and assumes every implementer reads every MUST. The implementer reads the test vectors, makes them pass, and ships. The seam is the set of MUSTs that were never tested by a vector, the edge inputs nobody enumerated (identity element, all-zero scalar, max-length buffer, malformed length prefix, non-canonical encoding), and the behavioral divergence between two bindings of the same primitive that nobody diffed because each binding was reviewed alone. The bug lives in the seam: the primitive is provably secure, the test vectors all pass, both bindings are individually "audited," and yet a specific edge input on one binding reaches a skipped MUST and yields a forgery, a malleable signature, a timing leak, or a key-recovery oracle. The Serai `SchnorrAggregate::read()` using identity-accepting `Ciphersuite::read_G` instead of FROST's identity-rejecting `Curve::read_G` is exactly this. The SIWE parser validating 1 of 8 fields is exactly this.

**Candidate-target profile:** a signature scheme / KEM / hash / AEAD / threshold protocol / ZK proof system with (a) a published spec or paper that uses MUST/MAY/SHOULD language, (b) one or more independent implementations or language bindings, (c) a public test-vector set, and (d) a value-bearing consumer (a wallet, a bridge validator set, a consensus client, a TLS stack). Highest EV when two bindings of the same primitive are in production simultaneously (Rust core + WASM/JS binding + C FFI) and a money-bearing system trusts both.

**Shared blind spot:** spec authors assume implementers read every MUST. Implementers assume the test vectors cover the input space. Auditors review each binding in isolation against its own test vectors. **Nobody owns the edge inputs and nobody owns the cross-binding behavioral diff.** The primitive's security proof says nothing about what happens when you feed the deserializer the identity point, a non-canonical scalar, or a length field that overflows; the proof assumes well-formed inputs. That assumption is the seam.

---

## Variables used across kits

```bash
# ── Target identity ──────────────────────────────────────────────
export LIB_DIR="$HOME/audit/target-lib"          # cloned crypto library root
export LIB_LANG="rust"                            # rust|c|go|js|cpp
export PRIMITIVE="ed25519"                         # ed25519|frost|bls|secp256k1|sr25519|ml-dsa|...
export SPEC_FILE="$HOME/audit/specs/rfc8032.txt"   # downloaded RFC/BIP/NIST PDF-to-text
export SPEC_URL="https://www.rfc-editor.org/rfc/rfc8032.txt"

# ── Cross-binding pair (the differential surface) ───────────────
export BINDING_A_DIR="$LIB_DIR/core"               # e.g. Rust core crate
export BINDING_A_BIN="$HOME/audit/driver-a"        # compiled differential driver A
export BINDING_B_DIR="$LIB_DIR/wasm"               # e.g. JS/WASM binding
export BINDING_B_BIN="node $HOME/audit/driver-b.js"# differential driver B invocation

# ── Test vectors ─────────────────────────────────────────────────
export VECTORS_DIR="$LIB_DIR/tests/vectors"        # upstream test vectors
export EDGE_DIR="$HOME/audit/edge-vectors"         # generated edge-case vectors
mkdir -p "$EDGE_DIR"

# ── Fuzzing ──────────────────────────────────────────────────────
export FUZZ_DIR="$HOME/audit/fuzz"
export FUZZ_CORPUS="$FUZZ_DIR/corpus"
export FUZZ_TIME=900                                # seconds per target per run
mkdir -p "$FUZZ_CORPUS"

# ── Timing analysis ──────────────────────────────────────────────
export DUDECT_DIR="$HOME/audit/dudect"
export TIMING_SAMPLES=2000000

# ── Curve / field constants (fill per primitive) ────────────────
# ed25519 group order L, field prime p, identity-point encodings, etc.
export GROUP_ORDER_L="7237005577332262213973186563042994240857116359379907606001950938285454250989"
export FIELD_PRIME_P="57896044618658097711785492504343953926634992332820282019728792003956564819949"

# ── Convenience ──────────────────────────────────────────────────
export RG='rg --no-heading -n'                      # ripgrep with line numbers
[ -f "$SPEC_FILE" ] || curl -s "$SPEC_URL" -o "$SPEC_FILE"
```

The kits below are written against `ed25519`/`frost`/`bls` as running examples because they are the most common money-bearing primitives; substitute `$PRIMITIVE` constants for your target. Every kit is runnable as-is after the VARS block is sourced and the placeholder driver/vector paths are pointed at real files.

---

## V1 -- Spec MUST downgraded to MAY (skipped validation)

**What it is.** The spec contains a normative MUST (reject identity, reject non-canonical, check cofactor, validate length, bound the scalar) and the implementation either omits it or implements only a SHOULD-strength version. This is the single most recurrent class because MUSTs are prose and test vectors rarely include the rejection case. It lives in the seam because the spec author considered the requirement satisfied by writing it and the implementer considered the implementation correct because the (positive) vectors pass. No rejection vector, no failing test, no review flag.

**Detection kit.** Extract every normative keyword from the spec, then grep the implementation for the corresponding guard and diff the two lists.

```bash
# 1. Pull every MUST / MUST NOT / SHALL / REQUIRED clause from the spec, numbered.
grep -nE '\b(MUST NOT|MUST|SHALL NOT|SHALL|REQUIRED)\b' "$SPEC_FILE" \
  | sed -E 's/^([0-9]+):/[L\1] /' > "$EDGE_DIR/spec-musts.txt"
wc -l "$EDGE_DIR/spec-musts.txt"

# 2. Inventory validation guards actually present in the implementation.
$RG -i 'reject|invalid|return\s+Err|bail!|ensure!|assert|is_canonical|is_identity|is_zero|cofactor|in_range|< *L\b|>= *L\b|<= *0' \
  "$BINDING_A_DIR/src" > "$EDGE_DIR/impl-guards.txt"

# 3. For each high-risk MUST keyword, check whether a matching guard exists.
for kw in identity "non-canonical" canonical cofactor "small order" "low order" \
          "out of range" length "zero" "all-zero" "s < L" malleab; do
  hits=$($RG -c "$kw" "$BINDING_A_DIR/src" 2>/dev/null | awk -F: '{s+=$NF} END{print s+0}')
  spec=$(grep -ic "$kw" "$EDGE_DIR/spec-musts.txt")
  printf '%-16s spec-MUSTs=%-3s impl-mentions=%s\n' "$kw" "$spec" "${hits:-0}"
done

# 4. Zoom on deserialization entry points (where validation should sit).
$RG -n 'fn (from_bytes|deserialize|read|decode|parse|try_from)\b' "$BINDING_A_DIR/src"
```

**Observed-state / readback.** Build a *negative* test vector that the spec says MUST be rejected, feed it to the public API, and capture the return value. PROOF = the call returns `Ok(...)` / a valid object / a successful verification on an input the spec mandates rejecting. Patched = the same input returns `Err` / `false`. Wrap it as a failing test:

```bash
cat > "$EDGE_DIR/v1_must_test.rs" <<'EOF'
// Illustrative: feeds a spec-MUST-reject input and asserts acceptance (the bug).
#[test]
fn spec_must_reject_is_accepted() {
    let bad = hex::decode(std::env::var("V1_BAD_INPUT").unwrap()).unwrap();
    let r = target_lib::PublicKey::from_bytes(&bad); // entry point from step 4
    assert!(r.is_ok(), "BUG: spec MUST-reject input was ACCEPTED -> {:?}", r.map(|_|()));
}
EOF
echo "Place in $BINDING_A_DIR/tests/, set V1_BAD_INPUT, run: cargo test spec_must_reject"
```

**Instance example (illustrative).** A spec states "implementations MUST reject signatures where `s >= L`." A binding decodes `s` as a 32-byte little-endian scalar with no upper-bound check. Feeding `s' = s + L` (same point, scalar wrapped) verifies as a *second valid signature* over the same message = signature malleability admissible into a system that dedups by signature bytes. The observed delta: two distinct 64-byte blobs both `verify() == true` for one (msg, pubkey).

**Generalization.** Beyond identity/canonical, look for: cofactor checks skipped on Edwards/Montgomery curves; missing `s < L` bound (ed25519 malleability, the classic); KEM ciphertext re-encryption check (FO transform) skipped; AEAD tag-length not pinned; length-prefix not bounded; X.509/DER structure accepted with trailing bytes. The highest-value variant is a MUST that gates *authentication* (reject this and you forge / bypass), not merely a MUST that gates a format nicety.

---

## V2 -- Identity / zero-element acceptance in deserialization (the Serai `read_G` class)

**What it is.** A point/scalar deserializer accepts the group identity, a small-order point, or the zero scalar where the protocol's security assumes a generator-order element. This is V1's most weaponizable special case and gets its own vector because it has a named precedent (Serai: `Ciphersuite::read_G` accepts identity, `frost::Curve::read_G` rejects it; `SchnorrAggregate::read()` uses the permissive one). It lives in the seam because the *ciphersuite* layer and the *protocol* layer are different trait abstractions written by different mental models, and the rejection lives in only one.

**Detection kit.** Find every deserialization path and classify which layer's reader it calls; then test the identity encoding against each.

```bash
# 1. All point/scalar readers and which validation trait they route through.
$RG -n 'read_G|read_F|from_bytes|decompress|from_canonical|deserialize_element|G::read|read_point|read_scalar' \
  "$LIB_DIR" -g '*.rs' -g '*.go' -g '*.c' -g '*.cpp' -g '*.ts'

# 2. Which readers contain an identity/zero rejection, which do NOT.
echo "== readers WITH identity check ==";  $RG -ln 'is_identity|is_zero|ct_eq.*IDENTITY|== *G::identity|IDENTITY|ZERO' "$LIB_DIR" -g '*.rs'
echo "== readers (all) ==";                $RG -ln 'fn read_G|fn read_F|fn decompress|fn from_bytes' "$LIB_DIR" -g '*.rs'
# Set-difference the two lists by eye: any reader in the second NOT in the first is a candidate.

# 3. Cross-layer inconsistency: same primitive, two readers, different policy.
$RG -n 'trait (Ciphersuite|Curve|Group|PrimeGroup)\b' "$LIB_DIR" -g '*.rs'
$RG -n 'impl .*Ciphersuite for|impl .*Curve for' "$LIB_DIR" -g '*.rs'
```

Generate the identity / small-order encodings to feed in:

```bash
python3 - <<'PY' > "$EDGE_DIR/identity-encodings.txt"
# Illustrative encodings for ed25519-family. Verify against your curve's encoding.
enc = {
 "ed25519_identity":  "0100000000000000000000000000000000000000000000000000000000000000", # y=1,x=0 (sign bit clear)
 "ed25519_neg_ident": "0100000000000000000000000000000000000000000000000000000000000080", # y=1 with the x sign bit set (64 nibbles)
 "zero_scalar":       "0000000000000000000000000000000000000000000000000000000000000000",
}
for k,v in enc.items(): print(f"{k} {v}")
PY
cat "$EDGE_DIR/identity-encodings.txt"
```

**Observed-state / readback.** Feed the identity encoding to each reader found in step 1. PROOF = a reader returns a valid element for the identity/zero encoding AND that element is consumed by an aggregation/verification path (so the acceptance is reachable, not dead). The strongest readback chains it: identity public key accepted -> a "signature" verifies trivially (e.g. aggregate over identity points collapses the challenge) -> show `verify(forged) == true`. Patched = reader returns `Err`/`None` for identity.

**Instance example (illustrative; the Serai class is real, see CLAUDE.md).** An aggregate-signature `read()` uses the identity-accepting deserializer. An attacker submits an aggregate where one contributor's nonce commitment is the identity element. The Fiat-Shamir challenge becomes computable/controllable, and the aggregate verifies for a key the attacker never controlled = aggregate forgery. Observed delta: a crafted aggregate blob with `verify() == true` whose component the protocol assumed impossible.

**Generalization.** Any place where "is this a real group element of full order" is assumed but not enforced: BLS `G1`/`G2` subgroup checks (the classic rogue-key and small-subgroup attacks), Ristretto vs raw Edwards mismatch, secp256k1 point-at-infinity in ECDSA recovery, sr25519 ristretto identity. Also: HashMap/Vec lookups keyed on a deserialized index where `.unwrap()` assumes the index is valid (the Serai panic class). Cross-reference `~/arsenal/methodology/MPC-THRESHOLD-HUNT.md`.

---

## V3 -- Cross-binding differential behavior (lang-A vs lang-B on same input)

**What it is.** Two implementations of the same primitive (Rust core vs WASM vs C FFI vs Go reimplementation, or two independent libraries a system trusts interchangeably) diverge on a specific input: A accepts, B rejects; A returns point P, B returns P'; A is constant-time, B is not. The divergence is exploitable when a system uses one for signing and another for verifying, or when consensus requires bit-identical agreement (a validator running binding A and one running binding B fork or one accepts a block the other rejects). It lives in the seam because each binding was reviewed against the *same test vectors* and both pass, so no single review sees the divergence; only a differential harness does.

**Detection kit.** Drive both bindings with identical input and diff outputs. This is the core differential-fuzzing pattern; see `~/arsenal/methodology/DIFFERENTIAL-FUZZING-METHOD.md`.

```bash
# Driver contract: each binding reads hex stdin, prints "OK <hex-output>" or "ERR <reason>".
# Build A (Rust):
cat > "$HOME/audit/driver-a.rs" <<'EOF'
fn main(){ use std::io::Read; let mut s=String::new();
  std::io::stdin().read_to_string(&mut s).unwrap();
  let inp=hex::decode(s.trim()).unwrap_or_default();
  match target_lib::verify_or_decode(&inp){           // pick the op under test
    Ok(o)=>println!("OK {}",hex::encode(o)),
    Err(e)=>println!("ERR {e}"),
  }}
EOF
# Driver B (JS/WASM): node script printing the same contract.

# Differential loop over a shared corpus (upstream vectors + edge vectors + random).
diffs=0
for f in "$VECTORS_DIR"/* "$EDGE_DIR"/* ; do
  inp=$(xxd -p "$f" | tr -d '\n')
  a=$(printf '%s' "$inp" | $BINDING_A_BIN)
  b=$(printf '%s' "$inp" | $BINDING_B_BIN)
  if [ "$a" != "$b" ]; then
    diffs=$((diffs+1))
    printf 'DIVERGENCE on %s\n  A: %s\n  B: %s\n' "$f" "$a" "$b" \
      | tee -a "$EDGE_DIR/divergences.txt"
  fi
done
echo "total divergences: $diffs"

# Feed random + mutated inputs through the same diff loop (cheap brute differential):
for i in $(seq 1 100000); do
  inp=$(head -c 64 /dev/urandom | xxd -p | tr -d '\n')
  a=$(printf '%s' "$inp" | $BINDING_A_BIN); b=$(printf '%s' "$inp" | $BINDING_B_BIN)
  [ "$a" != "$b" ] && echo "RAND-DIVERGENCE $inp | A=$a B=$b" >> "$EDGE_DIR/divergences.txt"
done
```

**Observed-state / readback.** PROOF = a single input string for which `driver-a` and `driver-b` print different results, captured in `divergences.txt`, AND a named consumer that trusts both (a verifier pool, a multi-client network, a sign-on-A-verify-on-B flow). The state delta is the divergence record itself plus the consumer wiring. Patched = both bindings agree on every input in the corpus.

**Instance example (illustrative).** A Rust ed25519 lib enforces `s < L` (rejects malleable); a JS lib used by the same project's frontend does not. A bridge accepts a frontend-formed signature (JS-validated) that the on-chain/Rust verifier would reject, or vice versa: signatures valid on one side but not the other create an inclusion/exclusion asymmetry. Observed delta: input `X`, `driver-a == ERR`, `driver-b == OK`, both in production.

**Generalization.** Highest value where the divergence is *consensus-relevant* (two validator clients) or *trust-boundary-relevant* (sign here, verify there). Also covers: same library, two versions (post-upgrade drift); same algorithm, two curves with shared encoding; endianness divergence; hash-to-curve variant mismatch (RFC 9380 suite-ID confusion). Cross-reference `~/arsenal/methodology/MULTI-LANG-PATTERNS.md`.

---

## V4 -- Constant-time violation (secret-dependent branch / table / early-return)

**What it is.** The library claims constant-time (or the primitive requires it) but a code path branches, indexes a table, or returns early based on secret data (a key bit, a scalar limb, a comparison of a MAC/tag). Recurrent because constant-time is a property of compiled behavior, not source, and the spec's "implementations SHOULD be constant-time" is unverifiable by test vectors. Lives in the seam: the spec author assumed CT, the implementer wrote readable code, the compiler reintroduced a branch, and no functional test can see timing.

**Detection kit.** Source grep for the antipatterns, then measure with dudect / ctgrind. See `~/arsenal/methodology/MPC-THRESHOLD-HUNT.md` for the threshold-crypto angle.

```bash
# 1. Source-level CT antipatterns (fast triage, high false-positive -- confirm by measurement).
$RG -n 'if .*(secret|key|scalar|priv|nonce|d\b|sk\b)|memcmp|== *tag|!= *mac|return.*early|\[.*secret.*\]|match .*key_bit' \
  "$BINDING_A_DIR" -g '*.rs' -g '*.c' -g '*.cpp'
# Equality on secrets that should use ct_eq:
$RG -n '==|!=' "$BINDING_A_DIR/src" | $RG -i 'tag|mac|secret|key|hmac' 

# 2. dudect-style leakage test: feed two input classes (fixed-vs-random secret),
#    measure cycle distributions, t-test. Skeleton:
cat > "$DUDECT_DIR/leak_test.c" <<'EOF'
// Link against the target op (e.g. scalar_mul / verify / aead_decrypt).
// Class 0: fixed secret; Class 1: random secret. dudect does the Welch t-test.
#include "dudect.h"
uint8_t do_one_computation(uint8_t *data){ return target_op(data); }
void prepare_inputs(dudect_config_t*c,uint8_t*in,uint8_t*classes){
  for(size_t i=0;i<c->number_measurements;i++){
    classes[i]=randombit();
    if(classes[i]==0) memset(in+i*c->chunk_size,0x00,c->chunk_size);
    else randombytes(in+i*c->chunk_size,c->chunk_size);
  }}
EOF
echo "Build dudect harness, run: ./leak_test   (|t| > 10 over $TIMING_SAMPLES samples = leak)"

# 3. ctgrind / valgrind-memcheck-on-secrets: mark the secret poisoned, run under valgrind;
#    any branch/index on poisoned memory is reported.
#    (Rust: use `crabgrind` or compile with the secret in valgrind-poisoned region.)
echo "valgrind --tool=memcheck ./ct_target   # branch on poisoned secret -> 'Conditional jump depends on uninitialised value'"
```

**Observed-state / readback.** PROOF = a dudect run where `|t| > 10` (canonical dudect leakage threshold) separating the fixed-secret and random-secret classes over `$TIMING_SAMPLES` samples, OR a ctgrind/valgrind "conditional jump depends on poisoned secret" line. The state delta is the measured timing distribution divergence, reproducible. Patched = `|t| < 5` stable. Be honest: a t-test leak is necessary but a full key-recovery PoC (Lucky13-style, or a remote-timing extraction) is what makes it undismissable -- escalate the strongest hits to a recovery harness.

**Instance example (illustrative).** A library's `verify()` compares the recomputed tag with `==` (early-returns on first differing byte) instead of `ct_eq`. dudect shows `|t| ~ 40`. A network-reachable MAC-check oracle leaks the tag byte-by-byte (classic byte-at-a-time forgery). Observed delta: timing histograms by tag-prefix-length, monotonic.

**Generalization.** Highest value: secret-dependent scalar multiplication (key recovery), non-CT modular inversion in ECDSA nonce handling, table-based AES on a server, branch in RSA/CRT (recoverable via fault+timing). Also: variable-time `bignum` comparison, secret-length-dependent loops in AEAD. The recurrent Rust tell is using `==` / `PartialEq` on a `SecretKey` / tag type instead of `subtle::ConstantTimeEq`.

---

## V5 -- Serialization malleability / non-canonical encoding accepted

**What it is.** The same logical value has more than one valid byte encoding, and the deserializer accepts the non-canonical forms. This breaks any system that hashes, dedups, or signs over the *bytes* (replay via re-encoding, double-spend via two encodings of one tx, signature over a canonicalized form that differs from the verified form). Recurrent because canonicalization is a SHOULD/MUST the spec states once and the parser ignores (it just decodes whatever parses). Lives in the seam: the format author assumed canonical, the parser author was lenient ("be liberal in what you accept" -- Postel's law is the bug here).

**Detection kit.** Round-trip every value and check serialize(deserialize(x)) == x for all valid x, and that non-canonical x is rejected.

```bash
# 1. Find decoders that lack a canonicality re-check on the parsed bytes.
$RG -n 'fn (decode|deserialize|from_bytes|parse)\b' "$BINDING_A_DIR/src"
$RG -n 'reencode|re-serialize|canonical|== *input|original_bytes|round.?trip' "$BINDING_A_DIR/src" \
  && echo "has some canonicality plumbing" || echo "NO canonicality re-check found"

# 2. Round-trip differential on a corpus: decode then re-encode, flag mismatches.
for f in "$VECTORS_DIR"/* "$EDGE_DIR"/* ; do
  inp=$(xxd -p "$f" | tr -d '\n')
  out=$(printf '%s' "$inp" | $BINDING_A_BIN)        # driver does decode->reencode->hex
  [ "${out#OK }" != "$inp" ] && [ "${out%% *}" = "OK" ] \
    && echo "NON-CANONICAL ACCEPTED: in=$inp out=${out#OK }" >> "$EDGE_DIR/malleable.txt"
done

# 3. Generate known non-canonical variants per format:
python3 - <<'PY' >> "$EDGE_DIR/malleable-inputs.txt"
# Illustrative non-canonical generators -- adapt per format.
# DER: BER indefinite-length, leading-zero integers, non-minimal length octets.
# Protobuf: non-minimal varint (e.g. 0x80 0x00 for 0), repeated field reorder.
# ed25519: s+L (scalar above order), high-bit-set y, +/- x ambiguity.
# CBOR: indefinite-length strings, non-minimal int encoding, duplicate map keys.
print("der_nonminimal_len 30 81 03 02 01 00")
print("ed25519_high_s     <s_plus_L_64bytes>")
print("cbor_nonminimal_0  1900 00")
PY
```

**Observed-state / readback.** PROOF = a non-canonical byte string that decodes to the same logical value as a canonical one AND a consumer that distinguishes them by bytes (a nullifier set, a tx-hash dedup, a signed-over-bytes verification). Concretely: two distinct hex blobs, both `OK`, decoding to equal values, where the system keys on the blob. Patched = the parser rejects non-canonical forms (returns `Err`) or re-encodes and compares.

**Instance example (illustrative).** A bridge dedups processed messages by `keccak(message_bytes)`. The message format is CBOR with non-minimal integer encoding accepted. An attacker re-encodes a settled message with a non-minimal length, producing a different hash but the same decoded payload = replay past the dedup set. Observed delta: two CBOR blobs, different keccak, identical decode, both accepted by the relayer.

**Generalization.** Highest value: ECDSA `(r,s)` vs `(r,-s)` malleability feeding a bytes-keyed dedup (the Bitcoin/transaction-malleability class), DER signature non-minimal encoding, protobuf field-order/unknown-field tolerance in a signed-over-proto, JSON canonicalization (JCS) gaps in signed payloads, UTF-8 overlong encodings. Cross-reference the SIWE/parser leniency pattern in `~/Desktop/BUGS/WEB2-ON-SC-PROGRAMS-PLAYBOOK.md`.

---

## V6 -- Length / bounds confusion in parsers (binary format / TLV / length-prefix)

**What it is.** A parser trusts an attacker-supplied length field, computes an offset/size that overflows or underflows, reads out of bounds, allocates unboundedly, or desynchronizes a TLV stream so that one logical field is interpreted as another. Recurrent on every binary format (TLS records, DER/BER, protobuf, msgpack, multiaddr, RLP, custom wire protocols). Lives in the seam: the spec gives a grammar; the implementer writes a hand-rolled parser; the grammar's implicit bounds (length <= remaining buffer) are never written as code.

**Detection kit.** Grep the arithmetic-on-length antipatterns, then fuzz the parser with a structure-aware harness. This is prime cargo-fuzz / AFL++ territory.

```bash
# 1. Length-arithmetic antipatterns (Rust + C).
$RG -n 'as usize|len() *-|len() *\+|offset *\+|\+ *len|\.\.len|copy_from_slice|memcpy|\.get_unchecked|read_exact|with_capacity\(' \
  "$BINDING_A_DIR/src" | $RG -i 'len|size|offset|count|n_'
# Unchecked subtraction (Rust panics in debug, wraps in release) and raw indexing:
$RG -n '\[[^]]*\.\.[^]]*\]|\[.*idx.*\]|unwrap\(\)|expect\(' "$BINDING_A_DIR/src" | $RG -i 'len|off|idx|buf'

# 2. cargo-fuzz target for the parser (libFuzzer under the hood).
cargo install cargo-fuzz 2>/dev/null
cd "$BINDING_A_DIR" && cargo fuzz init 2>/dev/null
cat > fuzz/fuzz_targets/parse.rs <<'EOF'
#![no_main]
use libfuzzer_sys::fuzz_target;
fuzz_target!(|data:&[u8]|{ let _ = target_lib::parse_message(data); });  // no panic = pass
EOF
cargo fuzz run parse -- -max_total_time=$FUZZ_TIME -rss_limit_mb=2048

# 3. AFL++ alternative for non-Rust / FFI parsers:
#    afl-clang-fast -o parse_afl parse_harness.c -ltarget
#    afl-fuzz -i seeds/ -o out/ -- ./parse_afl @@
echo "AFL++: afl-fuzz -i $FUZZ_CORPUS -o $FUZZ_DIR/afl-out -- ./parse_afl @@"

# 4. Targeted overflow seeds: max length prefixes, length > buffer, zero length, nested depth bomb.
printf '\xff\xff\xff\xff' > "$EDGE_DIR/len-max.bin"        # length = 4G
printf '\x00\x00\x00\x00' > "$EDGE_DIR/len-zero.bin"
python3 -c 'import sys;sys.stdout.buffer.write(b"\x05"+b"\x00"*2)' > "$EDGE_DIR/len-gt-buf.bin"  # claims 5, gives 2
```

**Observed-state / readback.** PROOF = a fuzz crash artifact (`fuzz/artifacts/crash-*` or AFL `out/crashes/*`) reproducible via `cargo fuzz run parse <artifact>`, with the sanitizer backtrace (ASAN heap-buffer-overflow / Rust panic location). The state delta is the crash + minimized input. For a non-crash logic desync, PROOF = a TLV input that the parser interprets as field X but the format defines as field Y, shown by a unit test asserting the misparse. Patched = the artifact no longer crashes / the bound is enforced.

**Instance example (illustrative).** A custom wire protocol prefixes each frame with a `u32` length and does `buf[4..4+len]` without checking `4+len <= buf.len()`. cargo-fuzz finds a 6-byte input claiming `len = 0xFFFFFFFF`; ASAN reports a slice-index panic / OOB read. In a networked daemon this is a remote DoS, and if the OOB read is reflected, an info leak. Observed delta: `crash-deadbeef` reproduces a panic at `parser.rs:142`.

**Generalization.** Highest value: heap overflow reachable pre-auth over the network (RCE/DoS), integer overflow in `len * elem_size` allocation, recursion-depth bomb (stack exhaustion) in nested structures (ASN.1, nested CBOR/protobuf), `read_exact` mismatch desync in a length-delimited stream. Cross-reference `~/arsenal/methodology/DIFFERENTIAL-FUZZING-METHOD.md` and `~/arsenal/methodology/CONTAINER-LAYER-ATTACK-SPEC.md` for COSE/CWT/CBOR specifics.

---

## V7 -- Nonce / IV reuse or predictability

**What it is.** A signature/AEAD nonce or IV is reused, derived deterministically from attacker-influenceable input, generated from a weak source, or otherwise made predictable. For ECDSA/Schnorr, two signatures with the same nonce leak the private key algebraically. For AES-GCM/ChaCha20-Poly1305, IV reuse breaks confidentiality and authenticity. Recurrent because the spec says "the nonce MUST be unique/unpredictable" and the implementer either reuses a counter incorrectly, derives the nonce from the message in a flawed way, or seeds a PRNG poorly. Lives in the seam: the primitive is secure *given a good nonce*; the nonce-generation is "glue code" nobody treats as cryptographic.

**Detection kit.** Grep nonce/IV construction sites, check the entropy source and uniqueness invariant, and (for ECDSA) test for the reuse oracle.

```bash
# 1. Nonce/IV construction and RNG sourcing.
$RG -n 'nonce|iv\b|IV\b|k *=|gen_k|random_scalar|rand::|OsRng|thread_rng|from_entropy|counter|seq' \
  "$BINDING_A_DIR/src" -g '*.rs' -g '*.c' -g '*.go'
# Weak/deterministic RNG tells:
$RG -n 'SmallRng|StdRng::seed_from_u64|rand::rngs::mock|XorShift|time\(|timestamp|block.timestamp' "$BINDING_A_DIR"
# Deterministic-nonce (RFC6979) presence -- its ABSENCE on ECDSA is itself a flag:
$RG -ln 'rfc6979|deterministic|hmac.*k\b' "$BINDING_A_DIR" || echo "NO RFC6979 -> nonce gen is ad-hoc, inspect entropy"

# 2. For AEAD: is the IV a per-key counter that can wrap / reset on restart?
$RG -n 'fn (seal|encrypt|aead).*nonce|nonce.*\+= *1|nonce *= *0|reset.*nonce' "$BINDING_A_DIR/src"

# 3. ECDSA/Schnorr nonce-reuse oracle test (algebraic key recovery from two sigs sharing k):
python3 - <<'PY'
# Illustrative: if two signatures (r,s1),(r,s2) over m1,m2 share r (==> same k),
#   k = (m1-m2)/(s1-s2) mod n ; d = (s1*k - m1)/r mod n. Run against captured sigs.
print("Collect 2 sigs from target with identical r; this script recovers d.")
PY
```

**Observed-state / readback.** PROOF for nonce reuse = two real signatures from the target sharing the same `r` (capture them), plug into the recovery formula, and print the recovered private key, then verify it signs a fresh challenge = full key recovery. For AEAD IV reuse, PROOF = two ciphertexts under the same (key, IV) where XOR of plaintexts is recoverable (forge a third). The state delta is the recovered key / forged ciphertext, demonstrable. Patched = nonces provably unique (RFC6979 deterministic or counter with persistence + overflow guard).

**Instance example (illustrative).** A signing service uses `thread_rng()` seeded once at process start and, after a fork, both children produce the same nonce sequence (the classic fork-RNG bug). Two child signatures share `r`; the script recovers `d`. Observed delta: recovered private key bytes that re-sign a verifier-accepted message.

**Generalization.** Highest value: any ECDSA/EdDSA/Schnorr nonce derived from non-CSPRNG or reused across forks/VMs/snapshots; FROST/threshold nonce-commitment reuse across signing rounds (binding-value omission -- the original FROST "drew nonce" attack); AES-GCM IV counter reset on restart; deterministic ECDSA implemented with a flawed HMAC input (signing wrong bytes into `k`). Cross-reference `~/arsenal/methodology/MPC-THRESHOLD-HUNT.md` for the threshold-nonce specifics.

---

## V8 -- Missing domain separation / signature over the wrong bytes

**What it is.** A signature, hash, or MAC is computed over a message that is not unambiguously bound to its context: no domain-separation tag, a shared hash across protocols, a length-extension-able construction, or a signing routine that hashes a *different* serialization than the one the verifier reconstructs (sign-over-struct vs verify-over-bytes). Enables cross-protocol signature reuse (a signature meant for context A is valid in context B), type-confusion, and length-extension forgery. Recurrent because domain separation is a designer concern ("use a unique DST") that implementers treat as optional decoration. Lives in the seam: the paper assumes a random oracle with a context tag; the implementation hashes the bare message.

**Detection kit.** Enumerate every hash/sign input and check for a domain tag and for sign/verify serialization symmetry.

```bash
# 1. Hash/sign/mac call sites and what goes into them.
$RG -n 'sha256|sha512|keccak|blake2|blake3|hash_to_curve|H\(|challenge|fiat.?shamir|sign\(|mac\(|hmac' \
  "$BINDING_A_DIR/src"
# Domain-separation tags present? (their ABSENCE is the flag)
$RG -ni 'domain|DST|dst|separat|prefix|context|tag|"v1"|version' "$BINDING_A_DIR/src" \
  || echo "NO domain-separation tags found -> high risk of cross-protocol reuse"

# 2. Sign-vs-verify serialization symmetry: do both sides hash the SAME bytes?
$RG -n 'fn sign\b' "$BINDING_A_DIR/src"; $RG -n 'fn verify\b' "$BINDING_A_DIR/src"
# Manually diff the byte-construction inside sign() vs verify(). Mismatch = forgery seam.

# 3. Length-extension exposure (raw SHA-256/512 used as MAC = vulnerable):
$RG -n 'sha256\(.*key|sha512\(.*key|hash\(.*secret' "$BINDING_A_DIR/src" \
  && echo "POSSIBLE length-extension: secret||message under Merkle-Damgard hash"

# 4. EIP-712 / signed-struct vs raw-bytes confusion (if EVM-adjacent):
$RG -n 'eip712|domainSeparator|hashStruct|toTypedDataHash|personal_sign|\\x19' "$LIB_DIR"
```

**Observed-state / readback.** PROOF = a signature produced for context A (or protocol A) that `verify()` accepts in context B, demonstrated by a passing test that signs with one DST/struct and verifies under another. For length-extension, PROOF = a forged `MAC(secret || message || padding || suffix)` accepted without knowing `secret` (use `hashpump`/`hash_extender`). State delta = the cross-context valid signature / extended MAC accepted. Patched = distinct DSTs make the cross-context signature fail.

**Instance example (illustrative).** A protocol signs `H(msg)` for both "approve withdrawal" and "approve config change" with no type tag. A signature gathered for a benign config approval is replayed as a withdrawal approval. Observed delta: one 64-byte signature, `verify(WITHDRAW_CTX, sig) == true` and `verify(CONFIG_CTX, sig) == true`.

**Generalization.** Highest value: cross-chain / cross-protocol signature reuse (same key, no chain-ID/DST binding -- see Rule 23), hash-to-curve suite-ID confusion (RFC 9380), Merkle-tree second-preimage from missing leaf/internal-node domain separation (the Bitcoin CVE-2012-2459 class), EIP-712 domain-separator omission, transcript/Fiat-Shamir missing public-input absorption (overlaps V9). Cross-reference `~/arsenal/methodology/ZK-CIRCUIT-HUNT.md`.

---

## V9 -- Fiat-Shamir / challenge-derivation flaws (ZK / sigma protocols)

**What it is.** A non-interactive proof derives its challenge by hashing a transcript, and the transcript omits a public input, binds the wrong values, or is malleable. The "weak Fiat-Shamir" / "Frozen Heart" class: if the challenge does not commit to *all* public parameters and the statement, a prover can forge proofs for false statements or grind the challenge. Also covers in-circuit under-constraint where a witness is unconstrained. Lives in the seam: the paper specifies "challenge c = H(statement, commitments)"; the implementer hashes only the commitments, or forgets the public inputs, or uses a non-binding hash.

**Detection kit.** Reconstruct the transcript the code actually hashes and compare it to the paper's. See `~/arsenal/methodology/ZK-CIRCUIT-HUNT.md`.

```bash
# 1. Locate the challenge derivation and enumerate exactly what is absorbed.
$RG -n 'challenge|fiat.?shamir|transcript|absorb|append_message|squeeze|c *= *H|hash_to_field|RO\(' \
  "$LIB_DIR" -g '*.rs' -g '*.go' -g '*.sol'
# List every absorb/append call in transcript order:
$RG -n 'transcript\.(append|absorb|append_message|append_point|append_scalar)' "$BINDING_A_DIR/src"

# 2. Compare to paper: are ALL public inputs + the statement + every commitment absorbed
#    BEFORE the challenge is squeezed? Build the checklist from the paper, tick each.
grep -nE 'challenge|c *= *H|transcript|public input|statement' "$SPEC_FILE" | head -40

# 3. Under-constraint scan (for circuits): signals that are assigned but never constrained.
$RG -n 'witness|advice|assign_advice|unconstrained|<==|<--|=== ' "$LIB_DIR" -g '*.rs' -g '*.circom' -g '*.zok'
# circom: <-- (assignment without constraint) is the canonical under-constraint tell:
$RG -n '<--' "$LIB_DIR" -g '*.circom' && echo "REVIEW each <-- : assignment not constrained"

# 4. Forgery harness: try to verify a proof for a statement NOT proven, by grinding the
#    omitted input. If a public input is unabsorbed, you can vary it freely post-hoc.
echo "Build a verifier-driver; vary each public input and re-run verify(); if a varied input still verifies, it is unbound."
```

**Observed-state / readback.** PROOF = a verifying proof for a false statement, produced by exploiting the omitted absorption (e.g. swap a public input the transcript did not bind and show `verify() == true`). Or a circuit witness assignment that satisfies the constraints but encodes an invalid relation. State delta = the accepted false proof. Patched = the verifier rejects once the missing input is bound into the challenge. Be explicit: a forged proof is the only undismissable artifact here; a "the transcript looks incomplete" note is an argument, not proof.

**Instance example (illustrative; Frozen Heart is a real disclosed class across multiple libs).** A Schnorr-based proof of knowledge hashes only the commitment `R`, not the public key `A` or statement. A prover forges a valid proof for an `A` they do not control by choosing `R` after seeing the challenge. Observed delta: `verify(A_victim, forged_proof) == true` with no knowledge of the victim's secret.

**Generalization.** Highest value: omitted public-input absorption in a money-bearing proof system (the Frozen Heart family hit Bulletproofs, Plonk, and others), challenge truncation/bias, in-circuit under-constraint (missing range check enabling field-overflow, the next vector), non-binding commitment in the transcript, replayable proof (no nonce/context in transcript). Cross-reference `~/arsenal/methodology/ZK-CIRCUIT-HUNT.md` and the Aztec KZG opening-proof lesson in MEMORY (KZG opening-proof != commitment-to-absorb -- verify what is actually bound).

---

## V10 -- Integer / field overflow at boundaries

**What it is.** Arithmetic on field elements, scalars, lengths, or accumulators overflows or wraps at a boundary the spec assumes is unreachable: a scalar accepted at `>= L` (folds into the group), a field element `>= p` (non-canonical, see V5), a counter/accumulator that wraps, an in-circuit value that exceeds the field modulus and silently reduces, or a `len * size` multiplication that overflows allocation math (overlaps V6 but is specifically the arithmetic boundary). Recurrent because the spec works in the abstract field/group where these are impossible, and the implementer works in fixed-width machine integers where they are not. Lives in the seam: the math is correct in `Z_p`; the code is in `u64`/`i32`/`Fp` with implicit reduction.

**Detection kit.** Find the boundary arithmetic and test exactly at the modulus / max boundaries.

```bash
# 1. Field/scalar boundary arithmetic and reduction sites.
$RG -n 'mod |% *L|% *p|reduce|from_bytes_mod_order|wrapping_|overflowing_|checked_|saturating_|as u32|as u64|as i32' \
  "$BINDING_A_DIR/src"
# Multiplications feeding allocation/index (overflow -> small alloc, big copy):
$RG -n '\* *(len|size|count|n|num)|(len|size|count) *\*' "$BINDING_A_DIR/src"
# In-circuit: values used as array indices or compared without range constraint:
$RG -n 'range_check|num_bits|assert.*< *2\^|less_than|lt_gadget|bit_decompose' "$LIB_DIR"

# 2. Boundary test vectors: exactly L, L-1, L+1, p, p-1, p+1, 2^256-1, 0.
python3 - <<PY > "$EDGE_DIR/boundary-scalars.txt"
L=int("$GROUP_ORDER_L"); p=int("$FIELD_PRIME_P")
for name,v in [("L-1",L-1),("L",L),("L+1",L+1),("p-1",p-1),("p",p),("p+1",p+1),
               ("max256",2**256-1),("zero",0),("one",1)]:
    print(f"{name} {v.to_bytes(32,'little').hex()}")
PY
cat "$EDGE_DIR/boundary-scalars.txt"

# 3. Feed each boundary value to the scalar/field deserializer and to the op under test,
#    observe whether it is rejected or silently reduced (== a different logical value).
for line in $(cut -d' ' -f2 "$EDGE_DIR/boundary-scalars.txt"); do
  printf '%s' "$line" | $BINDING_A_BIN
done

# 4. Property test (proptest/quickcheck) for the invariant decode(x) in canonical range:
cat > "$BINDING_A_DIR/tests/boundary.rs" <<'EOF'
proptest!{ fn no_silent_reduction(b in proptest::array::uniform32(any::<u8>())) {
  if let Ok(s)=Scalar::from_bytes(&b){ prop_assert!(s.to_bytes()==b, "silent reduction: input != canonical"); }
}}
EOF
```

**Observed-state / readback.** PROOF = a boundary input (e.g. scalar `= L+k`) that the deserializer accepts and silently reduces to a *different* logical value than its bytes, demonstrated by `decode(x).to_bytes() != x` while `decode(x)` is `Ok`. Combined with V5 this is malleability; combined with V8/V1 it is forgery. For allocation overflow, PROOF = a fuzz/ASAN crash from `len*size` wrap. State delta = the failing property-test case or crash artifact. Patched = boundary inputs rejected, no silent reduction.

**Instance example (illustrative).** A scalar deserializer does `Scalar::from_bytes_mod_order(b)` (always succeeds, always reduces) where the protocol needs `Scalar::from_canonical_bytes(b)` (rejects `>= L`). Submitting `s = s0 + L` reduces to `s0`, producing a second encoding of an existing signature scalar = malleability into a bytes-keyed system. Observed delta: `from_bytes_mod_order(s0+L) == from_bytes_mod_order(s0)`, two distinct 32-byte inputs.

**Generalization.** Highest value: in-circuit field overflow with no range check (a witness `> p` wraps, satisfying constraints for a false statement -- direct ZK soundness break), `len*elem_size` allocation overflow (heap overflow), accumulator wrap in a Merkle/sum proof, `as u32` truncation of a length, signed/unsigned confusion in offset math. Cross-reference `~/arsenal/methodology/ZK-CIRCUIT-HUNT.md` (field overflow as soundness break) and `~/arsenal/methodology/COMPILER-BUG-HUNT.md` (codegen-level integer UB).

---

## Cross-vector amplifiers

The killshot on this surface is **a spec-MUST skipped on one binding (V1/V2) + an edge input that reaches it (V5/V6/V10) = forgery / auth-bypass / key-recovery.** A skipped check alone is a hardening note; a reachable edge input alone is noise; together they are an undismissable failing vector. Concretely:

- **V1 + V5 (skipped `s<L` bound + malleable re-encoding) = signature malleability into a bytes-keyed dedup.** The missing upper-bound check is dead unless someone can produce the second encoding; V5 produces it; a bytes-keyed nullifier/dedup consumer makes it a double-process. This is the cleanest two-line chain on the surface.

- **V2 + V9 (identity-element accepted + Fiat-Shamir omits a commitment) = aggregate/threshold forgery.** The Serai `read_G` identity acceptance becomes weaponizable precisely when the challenge derivation does not bind the contributor's commitment, so an identity contribution collapses the verification equation. Either alone is a note; together it is a forged aggregate signature.

- **V3 + V1 (cross-binding divergence where binding B skips a MUST binding A enforces) = sign-here/verify-there bypass.** A differential harness that finds "A rejects, B accepts" is most valuable when the rejected property is a security MUST and a system signs on B but verifies on A (or a multi-client network forks). The divergence record + the consumer wiring is the proof.

- **V7 + V4 (predictable nonce + a timing side-channel on the same scalar) = compounded key recovery.** Even a partial nonce bias (V7, a few leaked bits) plus a timing leak on the scalar multiplication (V4) feeds lattice-based key recovery (Minerva/LadderLeak class) that neither leak alone completes.

- **V6 + V10 (length-prefix trust + `len*size` arithmetic overflow) = heap overflow / RCE-class crash.** The parser trusts the length (V6); the allocation math wraps (V10) so a small buffer is allocated for a large declared size; the subsequent copy overflows. ASAN crash artifact is the proof.

- **V8 + V3 (missing domain separation + a second protocol/binding that reuses the same key) = cross-protocol signature reuse.** No DST (V8) is harmless until a second context exists that the same key signs for (V3 surfaces the second binding/protocol). The cross-context valid signature is the artifact.

---

## Expansion sub-pass hints (specialize HUNT-METHODOLOGY Pass 2)

- **2A authority-chain →** on this surface "authority" is *which layer owns validation*. Trace the trait/interface hierarchy (`Ciphersuite` → `Curve` → `Algorithm`; or `Group` → `Scheme` → `Protocol`) and locate, for each security property, the single layer that enforces it. The bug is the property that every layer assumes a *lower* layer enforces and none does (Serai: identity rejection assumed at ciphersuite, present only at curve). Map: property × layer matrix; any property with zero enforcing layers is a finding.

- **2B secret hygiene →** grep for secrets that touch non-constant-time code, leave the `Zeroize`/`SecretBox` wrapper, get logged, or get compared with `==` instead of `ct_eq`. Specialize: `$RG -n 'Debug.*SecretKey|format!.*key|println.*secret|\.clone\(\).*sk|impl.*Display.*Key'` and check that every `SecretKey`/`Scalar` carrying private material derives `Zeroize` and uses `subtle::ConstantTimeEq`. Missing `Zeroize` on a key that lives in a long-running process = residual-memory exposure.

- **2C privileged-actor-under-stress →** here the "privileged actor" is the signer/prover/verifier under adversarial input volume: fork-RNG (V7), nonce counter wrap on restart, signing-round state reuse in threshold protocols (two concurrent FROST rounds sharing a nonce commitment), proof-server grinding a Fiat-Shamir challenge under retries. Specialize: model the actor across process restart, fork, concurrent sessions, and snapshot/restore (VM/container) -- each is a nonce/state-reuse trigger.

- **2D shadow surface →** the deprecated curve, the legacy encoding still parsed for "compatibility," the v1 signature scheme accepted alongside v2, the test-only API exported in release. Specialize: `$RG -n 'legacy|deprecated|v1|compat|fallback|#\[cfg\(test\)\]|pub fn.*unsafe'` and verify whether a legacy verification path (e.g. accepting non-DST-tagged signatures for backward compat) is reachable in the deployed build. A legacy permissive path next to a strict new one is a downgrade attack.

- **2E error/telemetry leak →** distinct error variants for distinct failure causes leak an oracle (padding-oracle, invalid-curve-point oracle, MAC-vs-decrypt error distinction, "bad signature" vs "bad encoding"). Specialize: enumerate every `Err` variant a deserializer/verifier can return for one entry point; if the variant set distinguishes attacker-relevant causes (and is observable via API response or timing), it is an oracle. `$RG -n 'enum.*Error|return Err\(' "$BINDING_A_DIR/src"` then map variant → distinguishable cause.

---

## Mirror pairs (this surface)

Pass 3 audits these bidirectional pairs; for each, write the explicit `V_in vs V_out` line. The recurrent bug is asymmetry: the strict side and the lenient side disagree.

- **serialize ↔ deserialize.** Does `deserialize` accept strictly the set `serialize` can produce, or a superset? Superset = malleability/non-canonical (V5). Write: `V_in (accepted by parse) vs V_out (produced by encode)`; any input in `V_in \ V_out` is a finding.

- **sign ↔ verify.** Do both hash byte-identical transcripts? Sign-over-struct + verify-over-reserialized-bytes is the classic asymmetry (V8). Write: `bytes_signed vs bytes_verified`; mismatch = forgery seam.

- **encrypt ↔ decrypt.** Does `decrypt` enforce every invariant `encrypt` guarantees (AAD binding, tag length, nonce uniqueness)? A decrypt path that accepts a tag/nonce the encrypt path never produces is an oracle.

- **prove ↔ verify (ZK).** Does the verifier's transcript reconstruction bind exactly what the prover committed? Any public input the prover absorbs that the verifier does not re-absorb (or vice versa) = soundness gap (V9).

- **binding-A ↔ binding-B.** For two implementations of one op: `accepts_A vs accepts_B`. The symmetric-difference of the accepted sets is the V3 divergence surface; enumerate it with the differential driver.

- **commit ↔ open (commitments/Merkle).** Does `open` verify domain separation between leaves and internal nodes that `commit` used? Missing leaf/node tag = second-preimage (V8 Merkle class).

---

## Pointers to existing arsenal

Reference, do not duplicate:

- **`~/arsenal/methodology/MULTI-LANG-PATTERNS.md`** -- the cross-binding divergence playbook (V3); language-pair antipatterns for the differential driver.
- **`~/arsenal/methodology/DIFFERENTIAL-FUZZING-METHOD.md`** -- the harness construction for V3, V6, V10; corpus management, oracle definition, minimization.
- **`~/arsenal/methodology/ZK-CIRCUIT-HUNT.md`** -- Fiat-Shamir / under-constraint / field-overflow soundness breaks (V9, V10 in-circuit); the Frozen Heart and KZG-binding specifics.
- **`~/arsenal/methodology/MPC-THRESHOLD-HUNT.md`** -- threshold-nonce reuse, round-state reuse, identity-contribution attacks (V2, V7 in the FROST/threshold context).
- **`~/arsenal/methodology/COMPILER-BUG-HUNT.md`** -- codegen-level integer UB and CT-defeating optimizations (V4 compiler reintroduction of branches, V10 integer UB).
- **`~/arsenal/methodology/CONTAINER-LAYER-ATTACK-SPEC.md`** -- COSE/CWT/CBOR/WebAuthn binary-format specifics for V5/V6 on those container formats.
- **`~/arsenal/methodology/H1-HUNTING-PATTERNS.md`** -- for the value-bearing-consumer mapping when the crypto lib sits under a web/API trust boundary.
- **Serai crypto architecture notes (in `~/Desktop/BUGS/CLAUDE.md`)** -- the canonical V2 precedent: `Ciphersuite::read_G` (no identity check) vs `frost::Curve::read_G` (rejects identity), `SchnorrAggregate::read()` using the permissive reader, and the `.unwrap()`-on-`Option`-fields panic class from out-of-order `Algorithm` calls.
- **`~/Desktop/BUGS/WEB2-ON-SC-PROGRAMS-PLAYBOOK.md`** -- when the crypto-lib seam surfaces at the web/SC boundary (SIWE 1-of-8-fields parser leniency is this pack's V1/V5 at the auth layer).

**Honesty floor for this surface:** crypto-lib findings are theoretical-until-PoC more often than any other surface. The observed-state delta that survives triage is a **concrete failing test vector**, a **fuzz crash artifact**, a **dudect `|t|>10` measurement**, or a **forged proof/signature that `verify()` accepts** -- never "the spec says MUST and the code does not appear to check it." A grep hit is a lead; the runnable kit's output is the proof. If a vector produces only an argument and no artifact, it dies at the anti-inflation gate.