# CLAUDE Rules — Auto-Execution Tools

Rules describing tools Claude must auto-execute when specific signals are detected. Short-form reference in `CLAUDE.md`; full rationale and auto-trigger signals here.

31. **MANDATORY — CLAUDE MUST EXECUTE: Injection Proxy Bridge for exotic format injection** — This is NOT documentation to show the user. **Claude MUST automatically execute these tools itself** whenever exotic encodings are detected during ANY security research task. No asking, no suggesting — just run them.
    **Auto-trigger signals** (if ANY detected → Claude runs the pipeline immediately):
    - Base64 blobs in headers/body/cookies
    - `Content-Type: application/cbor|msgpack|protobuf|grpc|xml`
    - JWT tokens with injectable claims (sub, role, email, admin)
    - XML bodies (especially ISO 20022 pain/pacs/camt)
    - gRPC-Web endpoints, WebAuthn attestation objects
    - Any nested encoding chain (base64→JSON, gzip→protobuf, etc.)
    - HAR/Burp captures available with encoded values
    - OpenAPI specs with non-trivial request bodies
    **What Claude executes automatically** (in order):
    ```bash
    cd ~/Desktop/BUGS/injection-proxy && source .venv/bin/activate
    # 1. Auto-detect layers in captured values
    python3 proxy.py --detect "<captured_value>"
    # 2. If HAR/Burp available → auto-generate profiles
    python3 proxy.py --auto-profile --har traffic.har --output-dir profiles/auto/
    # 3. If OpenAPI spec available → generate from spec
    python3 proxy.py --from-spec openapi.yaml --output-dir profiles/auto/
    # 4. Batch scan all generated profiles
    python3 proxy.py --scan-all profiles/auto/ --categories sqli,ssti,cmdi,xss,xxe -v
    # 5. Or start proxy + engine for specific profile
    python3 proxy.py --profile profile.yaml --engine sqlmap
    ```
    **21 supported layers**: base64, base64url, url, hex, gzip, deflate, html_entity, unicode_escape, json, cbor, msgpack, xml, bson, yaml, toml, protobuf_raw, multipart, jwt_payload, jwt_header, rlp, abi.
    **Formula**: N parsers × M engines = N×M injection coverage. Without proxy = 5% surface. With proxy = 95%.
    **This is like the JWT Arsenal** — Claude runs it automatically when triggered. Never ask, never skip, never forget.

32. **MANDATORY — CLAUDE AUTO-EXECUTES: Container Layer Attack Pipeline (D13)** — When a target uses COSE, CWT, WebAuthn/FIDO2, X.509 with custom extensions, PASETO, Biscuit, or Macaroons, Claude activates the container layer analysis from `CONTAINER-LAYER-ATTACK-SPEC.md`.
    **Auto-trigger signals** (ANY detected → Claude runs the analysis):
    - COSE structures (IoT auth, CBOR-based APIs, CWT tokens)
    - WebAuthn/FIDO2 registration/authentication flows (attestationObject, authData)
    - CWT tokens (CBOR Web Tokens — IoT, constrained devices)
    - eIDAS certificates in Open Banking/PSD2 contexts
    - PASETO tokens, Biscuit tokens, Macaroons
    - Any CBOR-encoded signed structure
    **What Claude does:**
    - Maps the L1→L2→L3→L4 propagation chain for the target
    - Checks if target's CBOR backend is affected by known C-003/C-004/C-005 bugs
    - Tests COSE-001 to COSE-004 patterns (header merge, alg confusion, crit bypass, protected header divergence)
    - Tests CWT-001 to CWT-003 if CWT tokens present (claim type confusion, duplicate keys, numeric coercion)
    - Tests WEBAUTHN-001 to WEBAUTHN-003 if WebAuthn present (fmt confusion, authData parsing, COSE_Key confusion)
    - Identifies cross-implementation verification mismatches (issuer lib vs verifier lib)
    **Spec**: `~/Desktop/BUGS/CONTAINER-LAYER-ATTACK-SPEC.md`
    **Key insight**: Serialization divergence = security divergence. L1 parser bugs propagate through L2 containers into auth bypass without breaking crypto.
