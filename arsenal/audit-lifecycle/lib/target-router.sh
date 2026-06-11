#!/usr/bin/env bash
# INVOCATION CONDITION: called from init-target.sh. Emits ROUTING.md content to stdout.
# Classifies target and outputs mandatory/recommended checklists + blind spot warnings.
#
# Usage: target-router.sh <target-name>
# Classification hints: set TARGET_HINTS env var with keywords like
#   "solana anchor" / "smart.contract solidity" / "blockchain.node p2p" / "web api rest"
#   / "mobile android" / "defi fintech openbanking"
set -euo pipefail

TARGET="${1:?Usage: target-router.sh <target-name>}"
HINTS="${TARGET_HINTS:-}"

cat <<EOF
# Routing — $TARGET

Generated: $(date -u +%Y-%m-%dT%H:%M:%SZ)
Target: $TARGET
Hints: ${HINTS:-<none — populate via TARGET_HINTS env var and re-run init-target.sh>}

## Mandatory gate stack (universal)

Applies to every finding regardless of target class:

- **Kill Gate Q1-Q10** (30 min max per finding) → /home/malix/Desktop/BUGS/KILL-GATE-TEMPLATE.md
- **SEVERITY-COMMIT** (pre-gate, artifact-required) → findings/{id}-severity-commit.md
- **CHAIN-PROOF-GATE (D7)** (auth-class findings) → findings/{id}-chain-proof.md
- **WEIGHT-CARD (D8a + D8b)** (severity ≥ Low with dollar impact) → findings/{id}-weight-card.md
- **Preflight mechanical** (4 deterministic gates, hard block) → audit-lifecycle/bin/preflight-mechanical.sh
- **OUTCOMES.jsonl entry** (submit or hold) → workspace-local OUTCOMES.jsonl

## Feedback memory indexes to load

**Always load** (applies to every target):
- \`~/.claude/projects/-home-malix-Desktop-BUGS/memory/INDEX-strategic.md\` — gate mechanics, ROI, triager dynamics, process

**Conditional load** (based on target class detected below):
- Web/API target → \`~/.claude/projects/-home-malix-Desktop-BUGS/memory/INDEX-web.md\`
- Smart contract target → \`~/.claude/projects/-home-malix-Desktop-BUGS/memory/INDEX-sc.md\`

At session start, read these INDEX files to discover relevant feedback_*.md memory entries. Each INDEX maps domain-specific rules → file paths.

## Target-class checklists

EOF

classified=false
hints_lower=$(echo "$HINTS" | tr '[:upper:]' '[:lower:]')

if echo "$hints_lower" | grep -qE 'solana|anchor'; then
  classified=true
  cat <<EOF
### Detected: Solana / Anchor

MANDATORY:
- /home/malix/Desktop/BUGS/SOLANA-HUNT-CHECKLIST.md (all sections)
- /home/malix/arsenal/methodology/MULTI-LANG-PATTERNS.md (R-001 to R-012)
  Priority: R-011 silent type truncation (\`as u32\` on price = GMTrade #31 \$200K pattern)
- CLAUDE.md rule #35 (5 fund theft checks — silent truncation, cross-market payout,
  partial state commit, branch asymmetry, assert on peer data)

If IDL is closed-source: read feedback_solana_closed_source.md — IDL misses runtime require!().

EOF
fi

if echo "$hints_lower" | grep -qE 'smart.contract|evm|solidity|foundry|erc|eip'; then
  classified=true
  cat <<EOF
### Detected: Smart Contract (EVM / Solidity)

MANDATORY:
- /home/malix/Desktop/BUGS/CRITICAL-HUNT-CHECKLIST.md (all sections)
- /home/malix/arsenal/methodology/C4-HUNTING-PATTERNS.md (128 patterns)
- CLAUDE.md rule #35 (5 fund theft checks — run BEFORE check matrix)

FORK-TEST MANDATORY:
- Use \`vm.createSelectFork()\`, \`deal()\` for tokens, \`vm.prank(realAdmin)\`
- Free RPC: https://ethereum-rpc.publicnode.com
- PoC without fork = mock-based = likely dismissed

IF FORK OF PARENT PROTOCOL:
- Run ~/arsenal/tools/fork-diff.sh <local> <parent-repo-url>
- Focus on [SECURITY] tagged changes
- Search parent's C4/Cantina/Sherlock audits (CLAUDE.md rule "C4 reports as bounty pipeline")

IF CONTRACT IS PROXY:
- Resolve EIP-1967 slots via \`cast storage\`
- Trace FULL governance chain (EOA → Safe → Timelock → ProxyAdmin → Proxy → Impl)

EOF
fi

if echo "$hints_lower" | grep -qE 'blockchain.node|l1|l2.node|p2p|validator'; then
  classified=true
  cat <<EOF
### Detected: Blockchain node (L1/L2 P2P layer)

MANDATORY:
- /home/malix/Desktop/BUGS/CRITICAL-HUNT-CHECKLIST.md §6c (lock contention cross-subsystem)
- /home/malix/arsenal/methodology/MULTI-LANG-PATTERNS.md (per node language)
- CLAUDE.md rule #33 (4-phase lock contention methodology — TRON \$100K pattern)

METHODOLOGY (4 phases from rule #33):
1. Internal consistency map: all P2P message types × protections (rate limit, size, count, auth)
2. GitHub issues recon: search repo for "rate limit", "DoS", "performance" in issues/PRs
3. Algorithmic complexity trace: per-element function calls inside loops = O(N²) candidate
4. Lock contention cross-subsystem trace: \`grep -rn "synchronized|Mutex|RwLock|\\.lock()" <service_classes>\`

HUNT PATTERNS:
- Java: \`grep -rn "private.*synchronized.*void|synchronized.*this" --include="*.java"\`
- Go: \`grep -rn "sync.Mutex|sync.RWMutex|\\.Lock()|\\.RLock()" --include="*.go"\`
- Rust: \`grep -rn "Mutex::new|RwLock::new|\\.lock()\\.|\\.write()\\." --include="*.rs"\`

EXCEPTION: 8h time-box does NOT apply — blockchain nodes require 24-48h+ deep analysis.
(feedback_trust_user_intuition.md lesson — TRON \$100K found after 24h mark)

EOF
fi

if echo "$hints_lower" | grep -qE 'web|api|rest|graphql|websocket|frontend'; then
  classified=true
  cat <<EOF
### Detected: Web / API surface

MANDATORY:
- /home/malix/Desktop/BUGS/DEFI-FULLSTACK-CHECKLIST.md (F1-F6)
- /home/malix/arsenal/methodology/H1-HUNTING-PATTERNS.md (detection priority matrix, 60+ patterns)
- CLAUDE.md rule #26 (RPC namespace hunt — 5 min on every DeFi web target)
- CLAUDE.md rule #29 (authenticated session testing — WAF 403 = requires auth, not blocked)
- CLAUDE.md rule #30 (authorization consistency matrix — MFA vs baseline ops)
- CLAUDE.md rule #34 (H1 hacktivity pattern scan)

AUTO-TRIGGERS (if detected, execute playbook):
- JWT tokens → /home/malix/.claude/skills/gravedigger/JWT-ARSENAL-PLAYBOOK.md
- OAuth2 / OIDC → /home/malix/.claude/skills/gravedigger/OAUTH2-OIDC-PLAYBOOK.md
- Next.js (_next/, __NEXT_DATA__) → /home/malix/Desktop/BUGS/NEXTJS-HUNT-CHECKLIST.md
- COSE / CWT / WebAuthn → /home/malix/Desktop/BUGS/CONTAINER-LAYER-ATTACK-SPEC.md + rule #32
- Exotic encodings (base64/CBOR/msgpack/protobuf/XML/gRPC) → Injection Proxy Bridge + rule #31

MANDATORY FIRST STEPS:
1. Create test account, capture Bearer token (rule #29)
2. Extract ALL routes from JS bundles (grep -oE '/api/[a-zA-Z0-9_/-]+')
3. Test EVERY route WITH Bearer token (103-route blindspot — Request Finance lesson)

EOF
fi

if echo "$hints_lower" | grep -qE 'mobile|android|ios|apk'; then
  classified=true
  cat <<EOF
### Detected: Mobile app

MANDATORY:
- /home/malix/Desktop/BUGS/MOBILE-API-HUNT-CHECKLIST.md (Phase 1-3)

WORKFLOW:
1. Frida SSL unpinning: \`frida -U -l ssl-unpin.js\`
2. mitmproxy with system cert installed (Android 7+ requires /system/etc/security/cacerts/)
3. mitmproxy2swagger conversion for API enumeration
4. API version enumeration (v0/v1/v2/v3/v4/v5 for legacy)
5. APK decompile: \`grep -rn "sk_live|sk_test|firebase|amazonaws"\` for hardcoded keys
6. Deep link exploitation: \`adb shell am start -a android.intent.action.VIEW -d "app://..."\`

FINTECH PRIORITY TARGETS: Revolut (500+ endpoints), Wise (300+), Cash App (300+).

EOF
fi

if echo "$hints_lower" | grep -qE 'aa-smart-account|aa-4337|erc-4337|erc-7579|bundler|paymaster'; then
  classified=true
  cat <<EOF
### Detected: Account Abstraction (ERC-4337 / ERC-7579) ecosystem

MANDATORY:
- /home/malix/arsenal/methodology/AA-ECOSYSTEM-HUNT.md (12 bug classes AA-001 to AA-012)
- Targets: Pimlico, Alchemy, Biconomy, Candide, Stackup, Kernel, Soul Wallet

KEY GREP:
- validateUserOp / _validateSignature / validatePaymasterUserOp
- installModule / executeFromExecutor
- getNonce / sessionKey

FORK-TEST with EntryPoint v0.7: 0x0000000071727De22E5E9d8BAf0edAc6f37da032

EOF
fi

if echo "$hints_lower" | grep -qE 'da-layer|celestia|eigenda|avail|blobstream|data.availability'; then
  classified=true
  cat <<EOF
### Detected: Data Availability layer + light client bridge

MANDATORY:
- /home/malix/arsenal/methodology/DA-LAYER-HUNT.md (12 bug classes DA-001 to DA-012)
- Targets: Celestia Blobstream, EigenDA, Avail, Near DA, Polygon AvailDA

KEY GREP:
- verifyCommitment / verifyBlob / kzgVerify
- verifyAttestation / validateQuorum
- Namespace / namespace_id
- challengePeriod / fraudProofWindow

CROSS-CHECK bridge contracts consuming DA attestations on Ethereum side.

EOF
fi

if echo "$hints_lower" | grep -qE 'lrt|restaking|eigenlayer|symbiotic|karak|puffer|renzo|kelp'; then
  classified=true
  cat <<EOF
### Detected: Liquid Restaking Token (LRT) ecosystem

MANDATORY:
- /home/malix/arsenal/methodology/LRT-SLASHING-HUNT.md (12 bug classes LRT-001 to LRT-012)
- Targets: Ether.fi, Puffer, Renzo, Kelp, Mantle mETH, Bedrock, Swell, Eigenpie

KEY GREP:
- reportSlashing / handleSlashing / _processSlashing
- getRate / exchangeRate / pricePerShare
- delegateTo / undelegate
- queueWithdrawal / completeWithdrawal

RATE ORACLE TIMING is the most profitable class (LRT-001 slashing delay).

EOF
fi

if echo "$hints_lower" | grep -qE 'indexer|subgraph|thegraph|goldsky|envio|ponder'; then
  classified=true
  cat <<EOF
### Detected: Indexer / subgraph drift

MANDATORY:
- /home/malix/arsenal/methodology/INDEXER-DRIFT-HUNT.md (12 bug classes IDX-001 to IDX-012)

KEY GREP:
- subgraph.yaml / schema.graphql (repo scan)
- BigInt math in mapping.ts
- useSubgraph / useQuery in frontend

MUST: diff subgraph output vs contract state on N random users.
If frontend calculates withdrawable from indexer → high-impact class.

EOF
fi

if echo "$hints_lower" | grep -qE 'zk-circuit|circom|halo2|plonky|noir|arkworks|cairo.prover|zkvm|risc.zero|sp1'; then
  classified=true
  cat <<EOF
### Detected: Zero-Knowledge circuit / proving system

MANDATORY:
- /home/malix/arsenal/methodology/ZK-CIRCUIT-HUNT.md (15 bug classes ZK-001 to ZK-015)
- Targets: Aztec (Noir), zkSync Era, StarkNet (Cairo), Scroll/Linea/Polygon zkEVM,
  Risc Zero / SP1 (zkVM), Penumbra / Aleo / Railway

KEY GREP (per system):
- circom: signal input/output, <==, ===, template
- halo2: meta.advice_column, create_gate
- Noir: constrain, assert_eq, pub fn
- Fiat-Shamir: squeeze_challenge, absorb, transcript

UNDER-CONSTRAINED SIGNAL (ZK-001) is most common class.
NULLIFIER FORGERY (ZK-009) is canonical privacy pool bug.

EOF
fi

if echo "$hints_lower" | grep -qE 'mpc|threshold|frost|dkg|mpc.wallet'; then
  classified=true
  cat <<EOF
### Detected: MPC / threshold signature / DKG

MANDATORY:
- /home/malix/arsenal/methodology/MPC-THRESHOLD-HUNT.md (15 bug classes MPC-001 to MPC-015)
- Targets: Fireblocks, Qredo, Copper, Web3Auth, Lit Protocol
- Libraries: frost-core, schnorr-fun, Serai, tss-lib, cggmp21, multi-party-ecdsa

KEY GREP:
- SigningNonces, SigningCommitments
- is_identity, from_bytes, read_G (identity point acceptance — MPC-002)
- threshold comparison (>= t vs > t off-by-one — MPC-009)
- lagrange, polynomial_evaluate (MPC-007)

IDENTITY POINT ACCEPTANCE (MPC-002) is canonical — Serai pattern.

EOF
fi

if echo "$hints_lower" | grep -qE 'compiler|solc|vyper|cairo.compiler|move.verifier|llvm'; then
  classified=true
  cat <<EOF
### Detected: Smart contract compiler / toolchain

MANDATORY:
- /home/malix/arsenal/methodology/COMPILER-BUG-HUNT.md (15 bug classes CBG-001 to CBG-015)
- Targets: solc, vyper, Rust/LLVM crypto, Cairo, Move, Noir->bb

KEY GREP (in target protocols):
- pragma solidity (find old solc usage)
- assembly { (inline assembly = CBG-002, CBG-007 risk)
- unchecked { (CBG-006)
- @version (Vyper — CBG-003 Curve pattern)
- as u8/u16/u32/u64 in Rust (CBG-005 silent truncation, also R-011)

LONG CYCLE (weeks per hit) but massive payout when found.

EOF
fi

if echo "$hints_lower" | grep -qE 'post-audit-drift|fix-regression'; then
  classified=true
  cat <<EOF
### Detected: Post-audit drift monitoring

MANDATORY:
- /home/malix/arsenal/methodology/POST-AUDIT-DRIFT-PIPELINE.md

WATCH protocols that:
- Had C4/Cantina/Sherlock/Spearbit/TrailofBits audit in last 90 days
- Have live bounty program
- Show continuous commit activity on main branch

TOOL: ~/arsenal/tools/post-audit-drift-monitor.sh (extension of github-monitor.py)

TRIAGE score per commit (0-10): security-sensitive diff signals, non-main authors.

EOF
fi

if echo "$hints_lower" | grep -qE 'differential-fuzzing|cross.impl'; then
  classified=true
  cat <<EOF
### Detected: Differential fuzzing across implementations

METHODOLOGY:
- /home/malix/arsenal/methodology/DIFFERENTIAL-FUZZING-METHOD.md

TOOL: ~/arsenal/tools/differential-fuzzer.py

Multi-impl targets: EVM clients (Geth/Reth/Nethermind), bridge relayers (LZ DVN, Axelar,
Wormhole), Uniswap V3 cross-chain, FROST reference libs, ZK verifier implementations.

EOF
fi

if echo "$hints_lower" | grep -qE 'ghost-finding|cross.protocol.transfer'; then
  classified=true
  cat <<EOF
### Detected: Ghost-finding transfer across forks

METHODOLOGY:
- /home/malix/arsenal/methodology/GHOST-FINDING-TRANSFER.md

TOOL: ~/arsenal/tools/ghost-finding-scanner.sh

INGEST: C4/Cantina/Sherlock public reports → finding DB indexed by class + function
MATCH: for each fork of audited protocol, check if cognate code has the fix
UPGRADE: reassess severity per fork's specific TVL/composition/live state

EOF
fi

if echo "$hints_lower" | grep -qE 'academic.paper|eprint|iacr|new.attack'; then
  classified=true
  cat <<EOF
### Detected: Academic paper → live protocol hunt

METHODOLOGY:
- /home/malix/arsenal/methodology/ACADEMIC-PAPER-HUNT.md

TOOL: ~/arsenal/tools/eprint-rss-monitor.sh

SOURCES: eprint.iacr.org RSS, ACM CCS/IEEE S&P/USENIX/NDSS proceedings,
ethresear.ch, zkresear.ch.

FILTER: score each new paper for crypto/DeFi relevance (>= 6/10 → read).

MATCH: paper's abstract attack → grep live deployments for matching primitive.

EOF
fi

if echo "$hints_lower" | grep -qE 'defi|fintech|payment|openbanking|psd2|bank'; then
  classified=true
  cat <<EOF
### Detected: Fintech / Open Banking / Payment infrastructure

MANDATORY:
- /home/malix/Desktop/BUGS/FINANCIAL-SYSTEMS-HUNT.md (§FIN + §OB + §Payment)
- /home/malix/Desktop/BUGS/OPEN-BANKING-HUNT-CHECKLIST.md (if PSD2 scope)
- /home/malix/Desktop/BUGS/DEFI-FULLSTACK-CHECKLIST.md (if DeFi + web)

REGULATORY FRAMING (non-dismissable):
- PSD2 Article 67 (consent), Article 97 (SCA), RTS Article 5 (dynamic linking)
- PCI-DSS Req 6.5 (secure coding), Req 8.3 (MFA)
- SOX, GLBA, CCPA, GDPR, SHIELD, HIPAA — cite specific article, never generic

PAYOUT EXPECTATION: 3-10x DeFi for equivalent severity. Lower competition.

EOF
fi

# ==============================================================================
# Unexplored-surface playbooks (NEW 2026-04-24) — ADDITIVE to classifiers above.
# These three don't gate `classified`: they layer onto any SC/Web/crypto target
# where the specific surface condition matches. Triggered independently so that
# a single target can fire multiple playbooks.
# Rationale: feedback_unexplored_sc_surface_2026_04_24.md — shift away from
# saturated SC fund-theft hunting toward zones where <5% of hunters compete.
# ==============================================================================

# Trigger 1 — WEB2-ON-SC-PROGRAMS-PLAYBOOK
# Fires when target is on a SC bounty platform AND has a web surface attached.
# Platform detected from hints OR from .target-repo / SCOPE.md residue.
if echo "$hints_lower" | grep -qE 'cantina|code4rena|c4|sherlock|hackenproof|bounty' \
   || echo "$hints_lower" | grep -qE '(smart.contract|evm|solidity|solana|anchor).*(web|api|dashboard|app|frontend|webapp|dapp|admin|nextjs)' \
   || echo "$hints_lower" | grep -qE '(web|api|dashboard|app|frontend|webapp|dapp|admin|nextjs).*(smart.contract|evm|solidity|solana|anchor)' \
   || echo "$hints_lower" | grep -qE '\b(dashboard|webapp|dapp|admin|ui|frontend)\b'; then
  cat <<EOF
### Additive: Web2-on-SC program (Polymarket #197 template)

The SC program you're auditing likely has a dashboard/API. Web2-class findings there
are eligible via pooled Web2 tier or Primacy of Impact, hunted by <5% of the population.

MANDATORY BEFORE CONTRACT DEEP-DIVE (2-4h recon):
- /home/malix/Desktop/BUGS/WEB2-ON-SC-PROGRAMS-PLAYBOOK.md (all sections)

WORKFLOW:
1. §0 — Confirm Web2 pool eligibility (explicit pool | implicit via fund-at-risk UI)
2. §1 — Enumerate every sub-surface (app/api/admin/docs/status/cdn/dev/indexer/relayer)
3. §2 — Auth surface (JWT null-gate/DER-confusion/JWK-auto-trust/OAuth-scope/SIWE-replay)
4. §3 — Authorization matrix (IDOR/vertical/mass-assignment/GraphQL mutations)
5. §4-§7 — API, fund-at-risk actions, RPC namespace (rule #26), infra misconfig
6. §8 — Classify pool (Web2 explicit / Primacy of Impact / platform-specific) BEFORE writing

TEMPLATE FINDING: Polymarket #197 — Critical→Medium mitigation-speed, Web2 pool, \$10K,
In Review + triager comment in 8 min. See feedback_killshot_report_standard.md.

DECISION RULE: if \$0 found in Web2 after 8h → return to SC but log surface map for next cycle.

EOF
fi

# Trigger 2 — CRYPTO-LIB-HUNT-PLAYBOOK
# Fires when target uses crypto libraries (threshold sigs, FROST, DKG, JWT libs,
# curve implementations) — one bug = N-way payout across every consumer.
if echo "$hints_lower" | grep -qE 'crypto.lib|ed25519|secp256k1|bls|frost|dkg|threshold|mpc|jwt.lib|authlib|noble|libsodium|blst|arkworks|circom|halo2'; then
  cat <<EOF
### Additive: Cryptographic library hunt (N-way amplifier)

If the target depends on a crypto library (direct or transitive), one bug applies to
every consumer. Arc Ed25519 \$9-15K per consumer. Authlib silent-patched across SaaS.

MANDATORY:
- /home/malix/Desktop/BUGS/CRYPTO-LIB-HUNT-PLAYBOOK.md (all sections)

PRIORITY LIBS (higher consumer density = higher amplifier):
- ed25519_consensus / ed25519-dalek (consensus nodes)
- frost-core / frost-ed25519 / frost-secp256k1 (MPC custodians)
- @noble/curves, @noble/hashes (every modern EVM dApp)
- libsecp256k1, k256 (Bitcoin + EVM signing)
- blst (Eth2 consensus, Filecoin)
- authlib, pyjwt, jsonwebtoken (JWT CVE density)
- ark-* (arkworks) ZK
- tss-lib, multi-party-ecdsa (MPC custody — \$100K-\$5M bounties)

WORKFLOW:
1. §0 — Select library + enumerate consumers (crates.io reverse deps, npm, pkg.go.dev)
2. §1 — Static analysis: trait/interface layering inconsistencies (Serai pattern),
        validation-absence checklist per primitive type (point/scalar/sig/FROST/JWT)
3. §2 — Differential fuzzing vs upstream (24h min), Wycheproof vectors, RFC compliance
4. §3 — Panic/DoS reachability (Arc Ed25519 pattern — consensus halt)
5. §5 — N-way coordinated disclosure: library maintainer + top-1 day 0, top-2/3 day 3,
        rest day 7, public day 90. Cite CVE in every consumer report.

DO NOT BLAST-DISCLOSE — maintainer patches silently, late consumers dismiss as dup.

EOF
fi

# Trigger 3 — INFRA-ADJACENT-TO-SC-PLAYBOOK
# Fires when target has relayer/bridge/oracle/sequencer/indexer/keeper/MPC surface.
# "Shadow audit" concept: protocol spends \$5M auditing contracts, \$50K on ops.
if echo "$hints_lower" | grep -qE 'relayer|bridge|oracle|sequencer|indexer|subgraph|keeper|gelato|automation|mpc|fireblocks|meta.?tx|gasless|layerzero|axelar|wormhole|ccip|hyperlane|connext|chainlink|pyth|api3|redstone|thegraph|goldsky'; then
  cat <<EOF
### Additive: Infra-adjacent-to-SC (shadow audit surface)

Every SC audit has a shadow: the off-chain infrastructure that signs/relays/indexes/
triggers contracts. Protocol audits contracts for \$5M, operations for \$50K. 100x ROI.

MANDATORY:
- /home/malix/Desktop/BUGS/INFRA-ADJACENT-TO-SC-PLAYBOOK.md (apply relevant sections)

SURFACE SELECTION (run sections matching detected infra):
- §1 Relayer / gasless meta-tx (Polymarket ClobAuth pattern — signature-scheme bugs)
- §2 Cross-chain bridges (Rule #23: source + sender validation; LayerZero/Axelar/Wormhole/CCIP)
- §3 Oracles (pull-oracle freshness, signer-set drift, operator key OPSEC)
- §4 Sequencers / L2 RPCs (Rule #26 namespace scan — 5 min mandatory)
- §5 Indexers / subgraphs (dashboard drift exploit)
- §6 Keepers / liquidation bots (Rule #28 keeper wallet audit)
- §7 MPC / custody (Safe{Core}, Fireblocks, Fordefi — Bybit \$1.5B class)

CROSS-REFERENCE RULES: #23 (cross-chain source+sender), #26 (RPC namespace),
#28 (keeper/bot wallet). Already in universal rules list below — this playbook
operationalizes them into end-to-end hunt workflows.

TEMPLATE FINDINGS: Polymarket #232 ClobAuth (In Review High + Web2 tag), 1inch F01
RPC namespace (\$50K HackenProof submitted), KelpDAO/LayerZero \$292M RPC poisoning.

FUND-FLOW TRACEBACK (per component): what keys held? what funds at risk if compromised?
what operations authorized? what revocation path? — Prioritize components where key
compromise = direct fund loss with no governance delay.

EOF
fi

if [ "$classified" = false ]; then
  cat <<EOF
### Target class: UNKNOWN

Set TARGET_HINTS env var with classifier keywords before re-running init-target.sh:

    TARGET_HINTS="solana anchor"           → Solana/Anchor program
    TARGET_HINTS="smart.contract solidity" → EVM Solidity
    TARGET_HINTS="blockchain.node p2p"     → L1/L2 node P2P layer
    TARGET_HINTS="web api rest"            → Web/API surface
    TARGET_HINTS="mobile android ios"      → Mobile app
    TARGET_HINTS="defi fintech payment"    → Fintech / Open Banking / Payment
    TARGET_HINTS="solana web"              → Mixed (multiple classifiers)

ADDITIVE layers (fire on top of base class, multi-select via space-separated hints):
    TARGET_HINTS="solidity cantina"        → SC + Web2-on-SC playbook
    TARGET_HINTS="evm frost threshold"     → EVM + crypto-lib playbook
    TARGET_HINTS="solidity relayer bridge" → SC + infra-adjacent playbook
    TARGET_HINTS="cantina dashboard relayer oracle"
                                           → SC + Web2-on-SC + infra-adjacent
                                             (all three fire simultaneously)

FALLBACK (while classifier missing):
- /home/malix/Desktop/BUGS/CRITICAL-HUNT-CHECKLIST.md kill gate
- Universal CLAUDE.md rules (see below)

EOF
fi

cat <<EOF

## Blind spots (no deep playbook yet — proceed with caution)

If target touches any of these, flag limitation explicitly in findings:

- **ZK circuits** (circom / halo2 / arkworks) — under-constrained, trusted setup, Fiat-Shamir
  flaws, field element boundary (0, 1, p-1, p, p+1). No dedicated playbook.
- **MPC / threshold / FROST / DKG** — identity point acceptance, nonce reuse, state machine
  ordering, signer set validation. Serai findings dismissed, class never codified.
- **Rollup / L2 specifics** — sequencer censorship, forced inclusion window, fraud/validity
  proof verification, state root posting, bridge withdrawal finalization. No dedicated playbook.
- **AI / LLM deep methodology** — prompt injection chains, function-call data exfil, jailbreak
  → tool abuse, training data leak. Only H1 patterns P-H1-100/101 available.
- **Cross-chain messaging deep playbook** — Rule #23 covers source+sender validation as
  principle; LayerZero/Axelar/Wormhole/Hyperlane/CCIP specifics not codified.

## Universal rules (CLAUDE.md) — apply to ALL targets

- Rule #26 — RPC namespace probe (5 min, any DeFi web target)
- Rule #29 — authenticated session testing (web/API, 103-route lesson)
- Rule #30 — authorization consistency matrix (MFA vs baseline)
- Rule #31 — Injection Proxy Bridge (auto-exec if exotic encodings)
- Rule #32 — Container Layer Attack (auto-exec if COSE/CWT/WebAuthn)
- Rule #33 — Lock contention cross-subsystem (blockchain nodes)
- Rule #34 — H1 hacktivity pattern scan (web/API)
- Rule #35 — 5 fund theft checks (SC targets, 30 min, before check matrix)
- Rule #36 — Chain Proof Gate D7 (auth-class findings)
- Rule #37 — Weight Card D8a + D8b (severity ≥ Low with dollar impact)
- **Rule #38 (NEW)** — Lifecycle init mandatory first action
- **Rule #39 (NEW)** — SEVERITY-COMMIT artifact-required before draft

## Boycotted platforms (NEVER submit)

- **Immunefi** — PERMANENT boycott (user_immunefi_boycott.md). Silent-patched \$120K ENS finding.
  If target is Immunefi-only, it is OUT OF SCOPE for this workspace.

EOF
