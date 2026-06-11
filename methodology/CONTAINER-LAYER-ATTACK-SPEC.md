# Container Layer Attack Specification — Signature Containers, Attestation Formats, Identity Tokens

Systematic targeting of the Layer 2 (container) attack surface — the structures that wrap parsers (L1) with cryptographic semantics. This is where parser bugs transform into auth bypass, signature forgery, and identity spoofing.

**Origin:** External researcher analysis + internal pipeline mapping. Integrates into ZERO-DAY-HUNTING-SPEC as Domain 13 (Track A extension).

**Key insight:** Serialization divergence = security divergence. If two implementations parse a signed container differently, the signature verification on one may accept what the other would reject. This is the highest-impact bug class the differential fuzzing pipeline can produce.

---

## The 4-Layer Model

```
Layer 1 — Primitive Parsing          (CBOR, JSON, ASN.1, protobuf, msgpack)
    OPERATIONAL — C-001 to C-006 confirmed
                |
Layer 2 — Container Formats          (COSE, JWS/JWE, X.509, CMS/PKCS#7)
    THIS DOCUMENT
                |
Layer 3 — Cryptographic Validation   (sig verify, MAC check, cert chain)
    Partially covered by JWT Arsenal
                |
Layer 4 — Application Tokens         (CWT, JWT, WebAuthn, SAML, PASETO)
    JWT Arsenal + WebAuthn (via cbor-x/cbor2 work)
```

**The multiplication path:** A single L1 parser bug (e.g., C-003 non-canonical boolean) propagates upward through L2 (COSE header confusion) -> L3 (signature validation logic flip) -> L4 (CWT token bypass) -> downstream applications (IoT auth, Passkey registration, Cardano transactions).

---

## Target 1: COSE (RFC 9052) — Priority: TIER 1

### 1.1 Why COSE is the Natural Next Target

COSE = CBOR container + signature metadata + key identification + algorithm negotiation.

Every CBOR parser bug found in C-003 to C-006 potentially propagates through COSE. The COSE libraries (pycose, cose-js, go-cose, COSE-RUST) use cbor2/cbor-x as their serialization layer. A bug in the serialization layer that affects the semantics of a COSE structure = signature bypass without breaking the crypto.

### 1.2 COSE Structure

```
COSE_Sign1 = [
    protected   : bstr,    # CBOR-encoded protected header (signed)
    unprotected : map,     # Unprotected header (NOT signed, attacker-modifiable)
    payload     : bstr,    # The signed content
    signature   : bstr     # The cryptographic signature
]
```

**Critical detail:** The protected header is CBOR-encoded inside a bstr. To access header parameters, the verifier must:
1. Decode the outer COSE array (CBOR)
2. Extract the protected header bstr
3. Decode the protected header bstr AS CBOR AGAIN (nested decoding)

This double-decode is where L1 parser bugs enter L2 container semantics.

### 1.3 Attack Classes

#### COSE-001: Header Merge Confusion

```
protected:   { 1: -7 }     # alg = ES256
unprotected: { 1: -37 }    # alg = PS256 (RSA-PSS)

Question: which algorithm does the verifier use?
```

Many implementations merge protected + unprotected headers:
```python
headers = {}
headers.update(decode_cbor(protected))
headers.update(unprotected)  # Unprotected OVERWRITES protected
```

If unprotected overwrites protected -> attacker controls algorithm via unprotected header (which is NOT signed).

**Detection:** Differential testing. Craft COSE structure with conflicting alg in protected vs unprotected. Compare behavior across pycose, cose-js, go-cose.

**Fuzzing template:**
```
For each header parameter (alg, kid, crit, content_type, iv, partial_iv, counter_signature):
  1. Set conflicting values in protected vs unprotected
  2. Sign with protected algorithm
  3. Verify across implementations
  4. Divergence = vulnerability
```

#### COSE-002: Algorithm Confusion via CBOR Type

```
COSE algorithm identifiers are CBOR integers:
  -7  = ES256
  -37 = PS256
  -8  = EdDSA

What if the algorithm is encoded as:
  - CBOR integer -7 (canonical)
  - CBOR bignum -7 (tagged, non-canonical)
  - CBOR text string "-7" (wrong type)
  - CBOR float -7.0 (type confusion)
```

**Direct application of C-003/C-004 patterns:** If the CBOR parser decodes a non-canonical integer representation differently, the algorithm selection may diverge between signer and verifier.

**Fuzzing template:**
```
For each algorithm identifier:
  Encode as: canonical int, bignum, float, string, tagged int
  For each encoding:
    Build valid COSE_Sign1 structure
    Sign with actual algorithm
    Present to each implementation
    Record: which algorithm each impl thinks was specified
    Divergence = algorithm confusion
```

#### COSE-003: Critical Parameter Bypass

COSE has a `crit` (label 2) parameter listing header parameters that MUST be understood by the verifier. If a verifier doesn't understand a critical parameter, it MUST reject.

```
protected: {
    1: -7,              # alg = ES256
    2: [99],            # crit = [99] -- label 99 must be understood
    99: "custom_value"  # custom parameter
}
```

**Attack:** If C-003 (non-canonical boolean) affects the `crit` parameter:
```
crit encoded as f814 (non-canonical false)
-> CBORSimpleValue(20) -> truthy in Python
-> verifier thinks crit is present and truthy
-> but doesn't iterate it properly
-> critical parameters not enforced
```

Or: duplicate `crit` key with different values (C-004 pattern):
```
protected: {
    2: [99],            # crit requires understanding label 99
    2: []               # duplicate key: crit is empty (last-write-wins)
}
```

#### COSE-004: Protected Header CBOR Parsing Divergence

The protected header is a bstr containing CBOR. The verifier must:
1. Decode the bstr to get raw bytes
2. Decode those bytes as CBOR to get the header map

**Attack:** What if the protected header bstr contains valid CBOR followed by trailing data (C-005 pattern)?

```
protected_header_bytes = CBOR({1: -7}) + b"TRAILING_GARBAGE"
protected = bstr(protected_header_bytes)
```

- Verifier A: decodes first CBOR item, ignores trailing -> alg = ES256
- Verifier B: rejects trailing data -> invalid COSE

If the SIGNER uses verifier A behavior (ignores trailing) and the VERIFIER also uses A behavior -> the trailing data is part of the signed protected header but never interpreted. An attacker who can modify the trailing data changes the signed bytes without changing the parsed semantics -> signature collision potential.

### 1.4 COSE Implementation Map

| Library | Language | CBOR Backend | Downloads | Priority |
|---------|----------|-------------|-----------|----------|
| pycose | Python | cbor2 (C-003/4/5 TARGET) | 50K/wk | P1 |
| cose-js | JS | cbor (npm) / cbor-x | 10K/wk | P1 |
| go-cose | Go | fxamacker/cbor | 5K/wk | P2 |
| COSE-RUST | Rust | ciborium / coset | Growing | P2 |
| cn-cbor | C | Custom CBOR | Used in constrained devices | P2 |
| COSE-C | C | nanocbor / tinycbor | IoT/embedded | P3 |

**Key leverage:** pycose uses cbor2. C-003/C-004/C-005 bugs in cbor2 propagate DIRECTLY into pycose. pycose confirmed vulnerable to C-004 (algorithm substitution via from_id(True)). The COSE layer amplifies the parser bug into a signature bypass.

---

## Target 2: CWT (RFC 8392) — Priority: TIER 1

### 2.1 Structure

```
CWT = COSE_Sign1 where payload = CBOR map of claims

Claims (integer keys):
  1 = iss (issuer)
  2 = sub (subject)
  3 = aud (audience)
  4 = exp (expiration)
  5 = nbf (not before)
  6 = iat (issued at)
  7 = cti (CWT ID)
```

### 2.2 Attack Classes

#### CWT-001: Claim Type Confusion

CWT claims use integer keys. The `exp` claim (key 4) should be a CBOR integer (epoch timestamp).

```
What if exp is encoded as:
  - Integer 1700000000 (canonical)
  - Float 1700000000.0 (type confusion)
  - Bignum 1700000000 (tagged)
  - Text string "1700000000" (wrong type)
  - Boolean true (C-003 pattern: truthy = "not expired"?)
```

**Detection:** Differential testing across python-cwt, cose-js, go implementations. Same CWT with non-canonical claim types.

#### CWT-002: Duplicate Claim Keys

CBOR maps allow duplicate keys (C-004 pattern). In a CWT:

```
payload = {
    4: 0,              # exp = epoch 0 (expired in 1970)
    4: 9999999999      # exp = far future (last-write-wins)
}
```

- Verifier A: first-write-wins -> token expired -> reject
- Verifier B: last-write-wins -> token valid -> accept

If issuer uses lib A (first-write, sets exp=future first, then exp=0 as "backup") and verifier uses lib B (last-write) -> token accepted with wrong expiration.

#### CWT-003: Numeric Coercion on Expiration

CBOR supports multiple numeric representations:
- Positive integer (major type 0)
- Negative integer (major type 1)
- Bignum (tag 2/3)
- Float16, Float32, Float64 (major type 7)

```
exp encoded as float64 -> loses precision for large timestamps
exp encoded as bignum -> some libs may not handle
exp encoded as negative integer -> epoch before 1970 -> underflow?
```

**Precision loss attack:**
```python
import struct
# Float64 can't represent all int64 values precisely
# Timestamps near 2^53 lose precision
timestamp = 2**53 + 1  # 9007199254740993
float_repr = float(timestamp)  # 9007199254740992.0 (lost the +1)
# If verifier compares as float: different value than intended
```

### 2.3 CWT Implementation Map

| Library | Language | CBOR Backend | COSE Backend | Priority |
|---------|----------|-------------|-------------|----------|
| python-cwt | Python | cbor2 | pycose | P1 (confirmed C-004 downstream) |
| cose-js (CWT mode) | JS | cbor / cbor-x | cose-js | P1 |
| go-cwt | Go | fxamacker/cbor | go-cose | P2 |

---

## Target 3: WebAuthn / FIDO2 — Priority: TIER 1

### 3.1 Structure

```
Registration flow:
  Client -> Server:
    attestationObject = CBOR({
        fmt: "packed" | "tpm" | "android-key" | ...,
        attStmt: { alg, sig, x5c },
        authData: bytes
    })

authData = concatenated binary:
    [rpIdHash 32B][flags 1B][signCount 4B][attestedCredData][extensions]

attestedCredData:
    [aaguid 16B][credentialIdLength 2B][credentialId][credentialPublicKey CBOR]
```

### 3.2 Attack Classes

#### WEBAUTHN-001: Attestation Format Confusion

```
fmt = "packed"  -> specific verification flow
fmt = "none"    -> no attestation verification

What if fmt is encoded non-canonically?
  - CBOR text "packed" (canonical)
  - CBOR text with UTF-8 BOM prefix
  - CBOR text with trailing null
  - Non-canonical length encoding of "packed"
```

If the server's CBOR parser normalizes the string differently -> wrong attestation format selected -> "none" verification applied to a "packed" attestation -> attestation bypass.

#### WEBAUTHN-002: authData Parsing Divergence

authData is raw bytes concatenated without length prefixes (except credentialIdLength). The parser must:
1. Read 32 bytes (rpIdHash)
2. Read 1 byte (flags)
3. Read 4 bytes (signCount)
4. If flags.AT set: read attestedCredData
5. If flags.ED set: read extensions (CBOR)

**The C-005 pattern applies directly:** When parsing the CBOR credential public key inside attestedCredData, if the CBOR parser accepts trailing data, the parser can't determine where the credential public key ends and the extensions begin -> extensions misinterpreted -> security flags wrong.

This is EXACTLY what py_webauthn does (C-005 design dependency):
```python
cose_key = cbor2.loads(buffer[pointer:])
re_encoded = cbor2.dumps(cose_key)
pointer += len(re_encoded)  # Advance past CBOR key to reach extensions
```

If `cbor2.dumps(cbor2.loads(data))` doesn't round-trip perfectly (canonical form differs from original encoding), `pointer` advances by wrong amount -> extensions parsed from wrong offset -> flags/data corruption.

#### WEBAUTHN-003: Credential Public Key Algorithm Confusion

The credential public key is a COSE_Key structure (CBOR map):
```
{
    1: 2,      # kty = EC2
    3: -7,     # alg = ES256
    -1: 1,     # crv = P-256
    -2: x,     # x coordinate
    -3: y      # y coordinate
}
```

C-004 (key collision) applies: if boolean `True` collides with integer `1`:
```
{
    1: 2,      # kty = EC2
    true: 3    # boolean true == integer 1 in Python -> overwrites kty
}
# Result: kty = 3 (Symmetric) instead of 2 (EC2)
# -> wrong key type -> verification with wrong algorithm
```

This is CONFIRMED in pycose (C-004 downstream finding).

### 3.3 WebAuthn Implementation Map

| Library | Language | CBOR Backend | Findings | Priority |
|---------|----------|-------------|----------|----------|
| py_webauthn | Python | cbor2 | C-005 design dependency | P1 |
| @simplewebauthn/server | JS | cbor-x | C-006 heap overflow | P1 |
| python-fido2 | Python | Custom CBOR | Independent (not affected by cbor2) | P2 |
| fido2-rs | Rust | ciborium | Not yet tested | P2 |
| java-webauthn-server (Yubico) | Java | cbor-java | Not yet tested | P2 |

---

## Target 4: X.509 / ASN.1 — Priority: TIER 2

### 4.1 Why Tier 2 (Not Tier 1)

X.509 is the highest-impact target (TLS, code signing, eIDAS) but also the most heavily researched. Google, Mozilla, and Apple fuzz X.509 parsers continuously. The probability of finding NEW bugs is lower, but the impact of each bug is catastrophic.

**Strategic approach:** Focus on LESSER-KNOWN X.509 parsers, not OpenSSL/BoringSSL/Go crypto. Target the eIDAS certificate parsing in Open Banking TPP registration (FINANCIAL-SYSTEMS-HUNTING OB-5), and the PKI libs used in IoT/embedded.

### 4.2 Attack Classes

#### X509-001: BER vs DER Confusion

X.509 certificates MUST be DER-encoded (a strict subset of BER). But many parsers accept BER.

```
DER: definite length, canonical
BER: indefinite length, non-canonical, constructed strings

Same certificate, different encoding:
  DER: 30 82 01 4A (definite length 330)
  BER: 30 80 ... 00 00 (indefinite length)
```

Same class as C-002 (RLP trailing data) and C-005 (CBOR trailing data) applied to ASN.1.

#### X509-002: Duplicate Extension Confusion

X.509 certificates contain extensions (BasicConstraints, KeyUsage, SubjectAlternativeName). Each extension should appear at most once.

```
Extensions:
  BasicConstraints: CA=false        # Not a CA
  BasicConstraints: CA=true         # IS a CA (duplicate!)
```

First-write-wins vs last-write-wins -> one parser thinks it's a CA cert, another doesn't.
This is C-004 (CBOR duplicate key confusion) applied to X.509 extensions.

#### X509-003: SAN Parsing Divergence

Subject Alternative Name (SAN) determines which domains a certificate is valid for.

```
SAN:
  DNS: example.com
  DNS: *.example.com
  DNS: example.com\x00.evil.com  # Null byte injection
```

Classic null-byte attack applied to certificate validation.

### 4.3 eIDAS-Specific Attacks (Open Banking)

PSD2 requires TPPs to present eIDAS QWAC/QSeal certificates containing:
- Organization identifier (PSD2 roles: AISP, PISP, ASPSP)
- NCA (National Competent Authority) identifier
- TPP authorization number

If the ASN.1 parser for the eIDAS extension (OID 0.4.0.19495.2) has a bug:
- Role misparse -> AISP cert accepted as PISP -> unauthorized payment initiation
- NCA mismatch -> cert from unauthorized country accepted
- Authorization number confusion -> revoked TPP cert accepted

**Feeds directly into FINANCIAL-SYSTEMS-HUNTING OB-5 (certificate validation).**

---

## Target 5: PASETO — Priority: TIER 3

### 5.1 Structure

```
PASETO token format:
  v4.public.{base64_payload}.{optional_footer}

Payload = JSON (not CBOR)
Footer = optional JSON or arbitrary bytes
```

### 5.2 Attack Classes

#### PASETO-001: Version Confusion

```
v2.public -> Ed25519 signing
v4.public -> Ed25519 signing (different construction)
v2.local  -> XChaCha20-Poly1305 encryption
v4.local  -> XChaCha20-Poly1305 encryption (different KDF)
```

Can a v2 token be presented as v4 (or vice versa)? If the version prefix is not cryptographically bound to the construction -> downgrade.

#### PASETO-002: Footer Misinterpretation

The footer is optional and not encrypted (in public mode). If the footer contains JSON that influences verification (e.g., key identifier), and the footer is parsed differently across implementations -> key confusion.

### 5.3 PASETO Implementation Map

| Library | Language | Priority |
|---------|----------|----------|
| paseto (paragonie) | PHP | P3 |
| rusty_paseto | Rust | P3 |
| go-paseto | Go | P3 |
| paseto.js | JS | P3 |
| pyseto | Python | P3 |

---

## Target 6: Biscuit — Priority: TIER 3

### 6.1 Structure

```
Biscuit = protobuf-encoded token with:
  - Authority block (root of trust)
  - Attenuation blocks (capability restrictions)
  - Datalog rules (logic language)
  - Signatures (chained)
```

### 6.2 Attack Classes

#### BISCUIT-001: Datalog Rule Injection

Biscuit uses a Datalog-based logic language. If the Datalog parser has edge cases:
```
rule: right($resource, "read") <- user($user), owner($user, $resource)
```

What if `$resource` contains Datalog metacharacters? -> Rule injection -> capability escalation.

#### BISCUIT-002: Signature Chain Confusion

Biscuit uses chained signatures. Each block is signed with a new keypair, and the public key is embedded in the previous block.

If the protobuf parsing of the signature chain has duplicate-field or trailing-data issues (D9 patterns) -> block insertion or removal without detection.

### 6.3 Implementation Map

| Library | Language | Priority |
|---------|----------|----------|
| biscuit-rust | Rust | P3 |
| biscuit-java | Java | P3 |
| biscuit-go | Go | P3 |
| biscuit-python | Python | P3 |

---

## Target 7: Macaroons — Priority: TIER 3

### 7.1 Structure

```
Macaroon:
  identifier: bytes
  location: string
  signature: HMAC chain
  caveats: [
    { cid: "time < 2026-12-31", vid: null },        # First-party caveat
    { cid: "...", vid: encrypted_key, cl: "url" }    # Third-party caveat
  ]
```

### 7.2 Attack Classes

#### MACAROON-001: Caveat Bypass via Encoding

Caveat identifiers are byte strings. If the caveat verifier and the caveat encoder use different string encodings:
```
Caveat: "time < 2026-12-31"
Encoded as UTF-8: valid
Encoded as Latin-1: different bytes -> HMAC chain breaks differently
```

#### MACAROON-002: Signature Chain Order Confusion

HMAC chaining: `sig_n = HMAC(sig_{n-1}, caveat_n)`. If caveats are processed in different order by different implementations -> HMAC mismatch -> but what if the verifier doesn't check the HMAC and relies on caveat parsing only?

### 7.3 Implementation Map

| Library | Language | Priority |
|---------|----------|----------|
| pymacaroons | Python | P3 |
| macaroon (js) | JS | P3 |
| go-macaroon (gopkg.in) | Go | P3 |
| libmacaroons | C | P3 |

---

## Cross-Implementation Verification Mismatch — The Meta-Attack

**Highest-impact attack class the pipeline can produce.**

```
Architecture:
  Issuer Service (signs tokens with Lib A)
      | token
  API Gateway (verifies tokens with Lib B)
      | verified request
  Backend Service
```

If Lib A and Lib B disagree on token semantics -> token valid at gateway despite being semantically different from what issuer intended.

**Detection with existing pipeline:**

```
1. Tool 7 (cross-library differential) generates the divergence matrix
2. For each divergence where Lib A accepts and Lib B accepts
   but parsed values differ:
   -> This is a cross-implementation verification mismatch
3. Identify real-world deployments where:
   - Issuer uses Lib A (check: what lib signs the tokens?)
   - Verifier uses Lib B (check: what lib the API gateway uses?)
4. Craft token that exploits the specific divergence
5. Submit as target-specific bounty
```

**Extension to Tool 8 (Config-to-Vuln Mapper):**

```yaml
# Add to vuln database:
cross_impl_mismatches:
  cbor2_vs_cbor_x:
    divergences:
      - C-003: non-canonical boolean (cbor2 truthy, cbor-x ?)
      - C-005: trailing data (cbor2 accepts, cbor-x rejects for some cases)
    affected_stacks:
      - issuer: pycose (uses cbor2) + verifier: @simplewebauthn (uses cbor-x)
      - issuer: python-cwt (uses cbor2) + verifier: cose-js (uses cbor)

  pyjwt_vs_jsonwebtoken:
    divergences:
      - alg:none handling
      - HS256 key type validation
    affected_stacks:
      - issuer: Python backend (PyJWT) + verifier: Node gateway (jsonwebtoken)
```

---

## The Four Critical Vulnerability Classes

Framework for systematic detection of container-layer vulnerabilities. Each class maps to existing findings and pipeline capabilities.

### Class 1: Cross-Implementation Verification Mismatch

```
Same token -> Lib A: VALID -> Lib B: INVALID (or vice versa)

Root cause: parsing divergence between implementations
Detection: Tool 7 cross-library differential
Existing findings: all C-001 to C-006 generate mismatches
```

**When this becomes exploitable:**
```
Issuer uses Lib A (permissive parser)
Verifier uses Lib B (also permissive, but DIFFERENTLY permissive)

Attacker crafts token that:
  - Lib A would reject (so issuer never legitimately creates it)
  - Lib B accepts (so verifier lets it through)

The token is FORGED -- never issued by the legitimate issuer,
but accepted by the verifier because of parsing difference.
```

**Specific detection pattern:**
```
For each (Lib_i, Lib_j) pair where i != j:
  For each mutated token T:
    result_i = verify(Lib_i, T)
    result_j = verify(Lib_j, T)
    IF result_i != result_j:
      -> CLASS 1 CANDIDATE
      Assess: which is the issuer, which is the verifier in real deployments?
```

### Class 2: Semantic Canonicalization Bypass

```
Two different byte sequences represent the same logical structure:
  bytes_A != bytes_B
  semantic(bytes_A) == semantic(bytes_B)

But the signature covers BYTES, not SEMANTICS.
```

**When this becomes exploitable:**
```
Signer signs bytes_A (canonical form)
Attacker produces bytes_B (non-canonical, same semantics)

Verifier that does: decode -> normalize -> verify-against-normalized
  -> signature FAILS (signed bytes_A, verifying bytes_B)

Verifier that does: verify-raw-bytes -> decode
  -> signature FAILS (bytes don't match)

Verifier that does: decode -> re-encode-canonical -> verify
  -> if re-encoded matches bytes_A: PASSES
  -> if re-encoded differs: FAILS

The vulnerability is when the verifier NORMALIZES before verification
and the normalization produces different bytes than what was signed.
```

**Existing findings in this class:**
- C-003: `f814` (non-canonical false) -> `CBORSimpleValue(20)` -> if normalized to `f4` (canonical false) -> different bytes -> signature mismatch
- C-005: trailing data accepted -> if stripped during normalization -> signed bytes != verified bytes
- C-002: RLP trailing data -> same pattern

**Specific formats where this applies:**
```
CBOR: non-canonical integers, non-canonical simple values, non-canonical lengths,
      indefinite vs definite encoding, map key ordering
ASN.1: BER vs DER encoding, indefinite lengths, constructed vs primitive strings
Protobuf: varint length variations, field ordering, default value presence
JSON: key ordering, whitespace, Unicode escapes, number representation
```

### Class 3: Duplicate / Shadow Field Attacks

```
Container has duplicate fields with conflicting values:
  { "exp": 0, "exp": 9999999999 }

Lib A: first-write-wins -> exp = 0 -> expired
Lib B: last-write-wins -> exp = 9999999999 -> valid
Lib C: error -> rejects token
```

**When this becomes exploitable:**
```
Scenario 1: Issuer-Verifier Mismatch
  Issuer (Lib A, first-write): sets exp = 9999999999 (first), exp = 0 (second)
  Issuer thinks: token expires far future
  Verifier (Lib B, last-write): reads exp = 0
  Verifier thinks: token expired -> REJECTS
  -> DoS on legitimate tokens

Scenario 2: Security Bypass
  Attacker crafts: { "exp": 0, "exp": 9999999999 }
  Signature covers: full bytes including both fields
  Verifier (last-write-wins): exp = 9999999999 -> token valid forever
  -> Expiration bypass

Scenario 3: Claim Confusion
  Attacker crafts: { "role": "user", "role": "admin" }
  If auth service reads last-write -> admin
  -> Privilege escalation
```

**Existing findings in this class:**
- C-004: CBOR map key collision (True==1, False==0) -> silent entry loss in Python dicts
- Confirmed downstream: PyCardano (transaction output overwrite), pycose (algorithm substitution), python-cwt (key type dispatch confusion)

**Fields to target for maximum impact:**
```
Auth tokens: exp, nbf, aud, iss, sub, scope, role, permissions
COSE: alg (1), kid (4), crit (2)
CWT: exp (4), nbf (5), aud (3), iss (1)
X.509: BasicConstraints, KeyUsage, SAN (as duplicate extensions)
```

### Class 4: Signature Scope Confusion

```
Parts of the token that INFLUENCE security decisions
but are NOT COVERED by the signature.

The attacker modifies unsigned fields to change the
verifier's behavior without invalidating the signature.
```

**This is the rarest and most dangerous class.** It requires understanding exactly which bytes are signed and which aren't in each container format.

**Per-format analysis:**

#### COSE Signature Scope

```
COSE_Sign1 signature covers:
  Sig_structure = [
    "Signature1",           # context string
    protected_header,       # SIGNED -- attacker cannot modify
    external_aad,           # SIGNED (if provided)
    payload                 # SIGNED -- attacker cannot modify
  ]

NOT signed:
  unprotected_header        # ATTACKER CAN MODIFY
```

**Attack vector:** If the verifier reads algorithm, kid, or other security-relevant parameters from the unprotected header instead of the protected header -> attacker modifies them freely.

```
Real-world pattern (pycose):
  headers = protected.copy()
  headers.update(unprotected)  # Unprotected OVERWRITES protected

If attacker sets:
  unprotected: { 1: 5 }  # alg = A128GCM (symmetric)

And protected has:
  protected: { 1: -7 }   # alg = ES256 (asymmetric)

After merge:
  headers[1] = 5          # Symmetric algorithm selected
  -> attacker uses known symmetric key to forge signature
```

#### JWT Signature Scope

```
JWS signature covers:
  BASE64URL(header) + "." + BASE64URL(payload)

Header IS signed (part of the input to the signature).
BUT: the header determines HOW the signature is verified.

If the verifier trusts the header to select the algorithm/key:
  alg: none -> no signature needed -> forgery
  alg: HS256 + use RSA public key as HMAC secret -> forgery

This is the classic JWT alg confusion -- a Class 4 vulnerability.
The algorithm field is "signed" but the signature can't protect
against the algorithm being used to DEFEAT the signature check.
```

**JWT Arsenal Tool 1 (null-gate scanner) and Tool 5 (state machine fuzzer) already target this class for JWT. The extension is to apply the same analysis to COSE, CWT, and WebAuthn.**

#### WebAuthn Signature Scope

```
WebAuthn assertion signature covers:
  authenticatorData + hash(clientDataJSON)

clientDataJSON is NOT directly signed -- only its hash is included.
authenticatorData IS directly signed.

Attack surface:
  1. clientDataJSON hash collision (extremely hard, SHA-256)
  2. authenticatorData parsing confusion (Class 2 applies):
     - If authData bytes are re-encoded during verification
     - And re-encoding changes the bytes
     -> signed authData != verified authData
  3. Extensions in authData:
     - Extensions are AFTER the credential public key
     - Boundary determined by CBOR parsing (C-005 pattern)
     - If boundary is wrong -> extensions parsed from wrong data
     - Extensions are signed but misinterpreted
```

**The C-005 design dependency in py_webauthn is a Class 4 candidate:**
```
cbor2.loads() determines where the COSE key ends
cbor2.dumps() re-encodes to measure consumed bytes
If loads->dumps doesn't preserve length -> pointer error
-> extensions parsed from wrong offset
-> signed extensions interpreted as different data
= Signature scope confusion: the signature covers the extensions,
  but the verifier reads different data than what was signed
```

#### X.509 Signature Scope

```
X.509 certificate signature covers:
  tbsCertificate (To Be Signed Certificate)

tbsCertificate includes:
  version, serialNumber, signature algorithm, issuer, validity,
  subject, subjectPublicKeyInfo, extensions

The OUTER signatureAlgorithm field is NOT part of tbsCertificate.
It is OUTSIDE the signed structure.

Attack:
  tbsCertificate.signatureAlgorithm: SHA-256 with RSA (strong)
  outer.signatureAlgorithm: SHA-1 with RSA (weak)

If verifier uses OUTER algorithm for verification:
  -> downgrade to weak hash -> collision attack feasible

This is CVE-2014-1491 (NSS) and similar bugs.
```

### Class 4 Detection Strategy

```
For each container format:
  1. IDENTIFY the signed scope:
     - Which bytes/fields are input to the signature function?
     - Document precisely.

  2. IDENTIFY the unsigned fields:
     - Which fields exist OUTSIDE the signed scope?
     - Which of these influence security decisions?

  3. For each unsigned-but-security-relevant field:
     - MODIFY the field in a valid signed container
     - VERIFY: does the signature still pass?
     - ASSESS: does the modified field change the verifier's security decision?

  4. For each signed field:
     - DETERMINE: can the field be re-interpreted after signature verification?
     - If the verifier normalizes/re-encodes the signed data:
       does normalization preserve semantics?
     - If not -> Class 2 + Class 4 combination (most dangerous)

  5. OUTPUT: signature scope map per format
     {
       "format": "COSE_Sign1",
       "signed": ["protected_header", "payload", "external_aad"],
       "unsigned_security_relevant": [
         {"field": "unprotected.alg", "risk": "algorithm downgrade"},
         {"field": "unprotected.kid", "risk": "key selection manipulation"}
       ],
       "class4_candidates": [...]
     }
```

---

## Five Cryptographic Invariants — Automated Assertion Framework

Five properties that MUST hold in any correct token/signature system. Every fuzzing run automatically checks all five. A violation of any invariant is a finding candidate.

These invariants formalize the detection logic behind all four vulnerability classes. Instead of testing for specific bugs, we test for invariant violations — which catches both known and unknown bug patterns.

### The Invariants

```
INV-1  CANONICAL UNIQUENESS
       "A signed object has exactly one valid binary representation"

       Test: encode(decode(token)) == token
       Violation: round-trip produces different bytes
       -> Class 2 (Semantic Canonicalization Bypass)
       -> Existing findings: C-003, C-005, C-002

INV-2  UNIVERSAL INTERPRETATION
       "The same token is interpreted identically by all implementations"

       Test: decode_A(token) == decode_B(token) for all (A, B) pairs
       Violation: parsed structures differ
       -> Class 1 (Cross-Implementation Verification Mismatch)
       -> Class 3 (Duplicate/Shadow Field)
       -> Existing findings: C-001, C-004, all Tool 7 divergences

INV-3  SIGNATURE COMPLETENESS
       "The signature covers exactly what the verifier uses for decisions"

       Test: signed_bytes >= security_relevant_bytes
       Violation: unsigned field influences verification or policy
       -> Class 4 (Signature Scope Confusion)
       -> Existing analysis: COSE unprotected header, JWT alg, X.509 outer sigAlg

INV-4  CRITICAL PARAMETER ENFORCEMENT
       "Unknown critical parameters cause rejection"

       Test: token with crit=["unknown_param"] -> must reject
       Violation: unknown critical parameter accepted/ignored
       -> COSE-003, JWT crit bypass
       -> JWT Arsenal Tool 5 tests this for JWT, extend to COSE/CWT

INV-5  VERIFICATION ORDERING
       "Cryptographic verification completes before any claim/policy logic"

       Test: verify_signature() called BEFORE parse_claims()/apply_policy()
       Violation: claims parsed or acted upon before signature verified
       -> JWT Arsenal Tool 2 (Pipeline Tracer) detects this
       -> Extend to COSE/CWT verification pipelines
```

### Automated Assertion Implementation

```python
class InvariantChecker:
    """
    Run after every differential fuzzing iteration.
    Each method returns (passed: bool, details: dict).
    """

    def check_inv1_canonical(self, token_bytes, lib):
        """INV-1: encode(decode(token)) == token"""
        decoded = lib.decode(token_bytes)
        re_encoded = lib.encode(decoded)
        passed = (re_encoded == token_bytes)
        return passed, {
            "invariant": "INV-1",
            "original_len": len(token_bytes),
            "roundtrip_len": len(re_encoded),
            "diff_offset": self._first_diff(token_bytes, re_encoded),
            "class": "Class 2 — Semantic Canonicalization Bypass"
        }

    def check_inv2_universal(self, token_bytes, libs):
        """INV-2: all libs decode to same structure"""
        results = {}
        for name, lib in libs.items():
            try:
                results[name] = lib.decode(token_bytes)
            except Exception as e:
                results[name] = f"ERROR: {e}"

        # Compare all pairs
        divergences = []
        names = list(results.keys())
        for i in range(len(names)):
            for j in range(i + 1, len(names)):
                if results[names[i]] != results[names[j]]:
                    divergences.append({
                        "lib_a": names[i],
                        "lib_b": names[j],
                        "value_a": str(results[names[i]])[:200],
                        "value_b": str(results[names[j]])[:200]
                    })

        passed = len(divergences) == 0
        return passed, {
            "invariant": "INV-2",
            "libs_tested": len(libs),
            "divergences": divergences,
            "class": "Class 1/3 — Verification Mismatch / Shadow Field"
        }

    def check_inv3_scope(self, container, lib):
        """INV-3: modifying unsigned fields doesn't change verification"""
        # Modify each unsigned field
        violations = []
        for field in container.unsigned_fields:
            modified = container.modify_unsigned(field, "INJECTED")
            still_valid = lib.verify(modified)
            if still_valid:
                # Unsigned field modified, signature still valid — expected
                # But does the modified value influence security decisions?
                decision_before = lib.get_security_decision(container.original)
                decision_after = lib.get_security_decision(modified)
                if decision_before != decision_after:
                    violations.append({
                        "field": field,
                        "decision_change": f"{decision_before} -> {decision_after}"
                    })

        passed = len(violations) == 0
        return passed, {
            "invariant": "INV-3",
            "unsigned_fields_tested": len(container.unsigned_fields),
            "violations": violations,
            "class": "Class 4 — Signature Scope Confusion"
        }

    def check_inv4_crit(self, lib):
        """INV-4: unknown critical parameters cause rejection"""
        # Build token with unknown critical parameter
        token = build_token_with_crit(
            crit=["x-unknown-param-12345"],
            extra_headers={"x-unknown-param-12345": "value"}
        )

        try:
            result = lib.verify(token)
            passed = not result  # Should reject
        except Exception:
            passed = True  # Exception = rejection = correct

        return passed, {
            "invariant": "INV-4",
            "unknown_param": "x-unknown-param-12345",
            "result": "rejected" if passed else "ACCEPTED (VIOLATION)",
            "class": "COSE-003 / JWT crit bypass"
        }

    def check_inv5_ordering(self, lib, token):
        """INV-5: signature verified before claims parsed"""
        # This is a static analysis check, not a runtime check.
        # Use Tool 2 (Pipeline Tracer) or manual code review.
        # For runtime approximation: provide token with invalid signature
        # but valid claims — does the lib return claim data before rejecting?

        invalid_sig_token = corrupt_signature(token)
        try:
            result = lib.decode_and_verify(invalid_sig_token)
            # If we get claim data back despite invalid sig -> INV-5 violation
            passed = result.claims is None
        except SignatureError:
            passed = True  # Correctly rejected before exposing claims
        except ClaimError:
            passed = False  # Claims were parsed before signature check

        return passed, {
            "invariant": "INV-5",
            "class": "Verification ordering violation"
        }
```

### Integration into Fuzzing Harness

```
EXISTING FUZZING LOOP:
  For each mutated token:
    Submit to N implementations
    Record results
    Flag divergences

ENHANCED FUZZING LOOP (with invariant assertions):
  For each mutated token:
    +-- INV-1: canonical round-trip per lib
    |  Flag: any lib where encode(decode(token)) != token
    |
    +-- INV-2: cross-implementation decode
    |  Flag: any pair where decoded structures differ
    |
    +-- INV-3: signature scope (for signed containers)
    |  Flag: unsigned field modification changes security decision
    |
    +-- INV-4: critical parameter enforcement
    |  Flag: unknown crit param accepted
    |
    +-- INV-5: verification ordering (static + runtime)
       Flag: claims accessible before signature verification

  Output per token:
    {
      "token_hex": "...",
      "mutations_applied": ["non-canonical-int", "duplicate-key"],
      "invariant_results": {
        "INV-1": {"lib_A": PASS, "lib_B": FAIL, ...},
        "INV-2": {"divergences": [...]},
        "INV-3": {"violations": [...]},
        "INV-4": {"lib_A": PASS, "lib_B": FAIL, ...},
        "INV-5": {"lib_A": PASS, "lib_B": PASS, ...}
      },
      "finding_candidates": ["INV-1 fail on lib_B", "INV-2 divergence A<->C"]
    }
```

### Cross-Layer Desynchronization Detection

The most dangerous pattern: parser, crypto, and application layers each interpret the same token differently.

```
Detection:

For each token T and each implementation:
  L1_result = parser.decode(T)                    # What the parser sees
  L2_result = crypto.verify(T)                    # What the crypto layer verifies
  L3_result = application.extract_claims(T)       # What the app acts on

If L1_result != L3_result:
  -> The app acts on data that wasn't what was parsed
  -> Cross-layer desync between parser and application

If L2_result.signed_content != L3_result.used_content:
  -> The app acts on data that wasn't what was signed
  -> Cross-layer desync between crypto and application (INV-3 + INV-5 combined)

If L1_result differs across implementations AND L2_result is PASS:
  -> Different parsers extract different data from a validly-signed token
  -> Cross-layer desync between implementations (INV-2 + INV-3 combined)

This is the rarest vulnerability class but produces:
  - Signature forgery
  - Authenticator spoofing
  - Credential impersonation

The invariant assertions detect the preconditions automatically.
When INV-1 AND INV-2 fail on the same token -> cross-layer desync candidate.
When INV-3 AND INV-5 fail on the same token -> crypto-application desync candidate.
```

---

## Fuzzing Template — Container Layer

### Universal Differential Harness

```
For each container format (COSE, CWT, X.509, PASETO, Biscuit, Macaroons):

INPUT GENERATION:
  1. Generate valid container with reference implementation
  2. Mutate at L1 (serialization) level using existing parser fuzzers:
     - Non-canonical encodings (C-003 pattern)
     - Duplicate keys (C-004 pattern)
     - Trailing data (C-005 pattern)
     - Truncation
     - Type confusion (int<->float<->string<->bool)
  3. Mutate at L2 (container) level:
     - Conflicting protected/unprotected headers
     - Missing required fields
     - Extra unknown fields
     - Duplicate container-level fields
  4. Mutate at L3 (crypto) level:
     - Wrong algorithm identifier
     - Stripped signature
     - Wrong key type
     - Invalid curve point

DIFFERENTIAL ORACLE:
  For each mutated container:
    Submit to N implementations
    Record: { parsed_headers, parsed_claims, verification_result, error }
    Flag: any divergence in verification_result or parsed_values

OUTPUT:
  Divergence report with:
    - Input (hex + human-readable)
    - Per-implementation results
    - Divergence classification (accept/reject, value mismatch, crash)
    - Exploitability assessment
    - Downstream impact (which applications use this lib combination)
```

---

## Implementation Roadmap

### Immediate (This Week)

| Task | Effort | Deliverable |
|------|--------|-------------|
| COSE differential harness (pycose vs cose-js vs go-cose) | 2 days | Extend D9 CBOR fuzzer to COSE |
| CWT claim fuzzing (duplicate keys, type confusion) | 1 day | CWT-specific mutation corpus |
| WebAuthn attestation format confusion testing | 1 day | WEBAUTHN-001 through WEBAUTHN-003 |

### Short-Term (This Month)

| Task | Effort | Deliverable |
|------|--------|-------------|
| Cross-implementation mismatch detector | 2 days | Tool 7 extension for L2 containers |
| Tool 8 extension: lib_signer x lib_verifier matrix | 1 day | Cross-impl vuln database |
| X.509 eIDAS extension fuzzer (for Open Banking) | 3 days | PSD2-specific cert testing |

### Medium-Term

| Task | Effort | Deliverable |
|------|--------|-------------|
| PASETO differential (5 implementations) | 2 days | PASETO divergence report |
| Biscuit Datalog rule injection fuzzer | 3 days | Logic language fuzzer |
| Macaroon HMAC chain differential | 2 days | Macaroon divergence report |

---

## Integration Points

- **ZERO-DAY-METHODOLOGY**: Domain 13 (Track A). Builds on D9 serialization infrastructure.
- **JWT-ARSENAL**: COSE/CWT extend JWT tooling to CBOR-based tokens. Cross-impl mismatch feeds Tool 8.
- **FINANCIAL-SYSTEMS-HUNTING**: X.509/eIDAS feeds OB-5. CWT feeds IoT/device auth.
- **INJECTION-PROXY**: COSE/CWT layers added to encoding chain. Inject through signed containers.
- **CRITICAL-HUNT-CHECKLIST**: Container layer patterns added as section 6b.14.
- **CLAUDE.md**: Rule #32 (auto-trigger on COSE/CWT/WebAuthn container formats).
