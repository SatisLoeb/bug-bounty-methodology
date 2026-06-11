---
name: hunt-methodology
description: The 4-pass sequential hunt discipline that took Upshift from 12 findings (typical hunter ceiling) to 48 findings (final count). Each pass has explicit completion criteria. Pass 1 = primary 10-vector scan in parallel. Pass 2 = expansion (NEW-01-05 class). Pass 3 = mirror invariant audit (CLAUDE.md rule #41). Pass 4 = chain construction (combine 2+ findings into amplified attack like F1+W34=$308M).
---

# Hunt methodology -- the 4-pass discipline

## Why 4 passes (not 1)

A single pass through SURFACE-ATTACK-PATTERNS.md surfaces ~10-15 findings on an Upshift-class target. That is the ceiling of what a normal hunter produces in 8 hours. Stopping there is what 90% of the bug bounty market does.

The Upshift engagement produced 48 findings because it ran **4 sequential passes**, each with a different lens:

| Pass | Lens | Findings produced (Upshift) | Trigger to start |
|---|---|---|---|
| Pass 1 | 10-vector parallel scan | W1, W2, W3, W4, W6, W7, W17, W19, W26, W30, W34, F1, F3 (~14 base findings) | Day 1, immediately after recon |
| Pass 2 | Expansion: missed-pattern sweep | NEW-01 through NEW-05 + W23 + W27 + W28 + W29 + W31 + W32 + W33 + W35 + W36-W40 (~16 expansion findings) | Day 2-3, after Pass 1 inventory done |
| Pass 3 | Mirror invariant audit | W5 + W8 + W9 + W10 + W11 + W12 + W13 + W14 + W15 + W16 + W21 + W22 + W24 + W25 (~14 asymmetry findings) | Day 3-4, after Pass 2 |
| Pass 4 | Chain construction | F1+W34 = $308M chain (combined Critical) + 2 other amplified chains | Day 4-5, after all primitives mapped |

48 findings = 14 (Pass 1) + 16 (Pass 2) + 14 (Pass 3) + amplification framing from Pass 4. Without Pass 2-3-4, the engagement would have stopped at ~14 findings and missed the $308M chain entirely.

This file encodes the discipline so you can reproduce it on any target of the same class.

## Pass 1 -- Primary scan (10 vectors in parallel)

**Lens:** "Is the obvious thing broken?"

**Method:** Apply the 10 vectors from SURFACE-ATTACK-PATTERNS.md in parallel. Each vector is a self-contained detection kit (grep / curl / on-chain read).

**Parallelism:** All 10 vectors can be scanned simultaneously. There are zero dependencies between them. On Upshift this took 3 hours of wall-clock time across 10 parallel terminals (or 10 parallel Bash tool calls in one assistant message).

**Suggested batching when running solo (you, with the tools):**
- Batch A (passive web reads): V1 bundle harvest + V2 unauth API sweep + V5 staging recon + V6 Lambda + V8 webhook leak + V9 Sentry correlation + V10 proxy governance chain. All read-only HTTP/grep work. Run in one parallel batch.
- Batch B (interactive): V7 SIWE state machine. Requires multiple sequential auth requests with controlled inputs.
- Batch C (on-chain): V3 operator wallet audit + V4 off-chain → on-chain trigger trace. Requires eth_call + log analysis.

**Per-finding output:** For each vector that returns a hit, write a finding stub at `findings/W##/SUMMARY.md` with: vector ID, raw evidence, primitive name, severity guess. **Do not** write the full report yet -- that comes after Pass 4. The goal in Pass 1 is to inventory primitives, not to write reports.

**Completion criteria for Pass 1:**
- All 10 vectors run end-to-end
- Each hit has a stub finding file
- An inventory table exists at `recon/INVENTORY-PASS-1.md` listing every primitive found

**Anti-stop signal in Pass 1:** "I found a Critical, let me write it up first." → **NO.** Continue Pass 1 to completion. Writing up stops the scanning rhythm and starves Pass 2-4.

**Time budget:** 4-8 hours on an Upshift-class target. Do not exceed 8h on Pass 1 alone -- if you are still scanning after 8h, you are deep-diving prematurely. Move to Pass 2 even if Pass 1 feels incomplete.

## Pass 2 -- Expansion (NEW-01-05 class)

**Lens:** "What patterns did Pass 1 systematically miss?"

The 10 vectors are tuned to common patterns. Pass 2 catches the architectural patterns that vectors don't directly target but that emerge from inspecting what Pass 1 surfaced.

**Five expansion sub-passes** (each ~1-2h):

### Sub-pass 2A -- Proxy governance chain (NEW-01 class)

For every proxy contract identified in Pass 1 (V3 + V4 + V10 hits), trace the FULL governance chain:

```
Implementation → ProxyAdmin → ProxyAdminOwner → (Safe? Timelock? EOA?)
              ↓                                     ↓
         What addresses can upgrade?         Are these addresses multisig or EOA?
                                                    ↓
                                          What is the threshold? Is the timelock 0?
```

For each step in the chain, run on-chain reads:

```bash
PROXY_ADDR="0x..."
RPC="https://ethereum-rpc.publicnode.com"

# EIP-1967 implementation slot
IMPL=$(cast storage $PROXY_ADDR 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc --rpc-url $RPC)

# EIP-1967 admin slot
ADMIN=$(cast storage $PROXY_ADDR 0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103 --rpc-url $RPC)

# If admin is a ProxyAdmin contract, get its owner
ADMIN_OWNER=$(cast call $ADMIN "owner()(address)" --rpc-url $RPC)

# If owner is a Safe, get threshold + signers
THRESHOLD=$(cast call $ADMIN_OWNER "getThreshold()(uint256)" --rpc-url $RPC)
SIGNERS=$(cast call $ADMIN_OWNER "getOwners()(address[])" --rpc-url $RPC)

# If owner is a Timelock, get min delay
DELAY=$(cast call $ADMIN_OWNER "getMinDelay()(uint256)" --rpc-url $RPC 2>/dev/null)
```

**What you are looking for:**
- Proxy admin'd by a single EOA (NEW-04 class on Upshift)
- ProxyAdmin owned by a Safe with threshold 1 (effectively single-signer)
- Timelock with 0 second delay (effectively no timelock)
- Naming deception: contract called "Timelock" or "Multisig" but is actually an EOA (NEW-05 class)

**Upshift hits:** NEW-01 (proxy governance no timelock), W35 (EOA proxy admin), W39 (proxy upgrade chain audit), NEW-05 (naming deception).

### Sub-pass 2B -- RPC key + multi-RPC sweep (NEW-02-03 class)

For every RPC URL referenced in the JS bundle (Pass 1 V1 hits), check:
- Is it a public RPC or a paid RPC with embedded API key?
- If paid: is the key reusable for arbitrary RPC calls (eth_call, eth_sendRawTransaction)?
- Is there a fallback RPC list, and does the fallback have weaker auth?

```bash
# Pull all RPC URLs from the bundle
curl -s https://app.target.io/assets/index-XXX.js | grep -oE 'https://[a-z0-9-]+\.(infura|alchemy|quicknode|publicnode|llamarpc|ankr|chainstack|helius|getblock|drpc|rpc\.[a-z]+)\.[a-z/?=&_-]+' | sort -u

# For each, test whether the key works
curl -s https://leaked-rpc-key.example.com/ABCD1234 \
  -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}'
```

**Upshift hits:** NEW-02 (Helius RPC key), NEW-03 (multi-RPC fallback config exposed).

### Sub-pass 2C -- Operator wallet behavior under stress (NEW-04 class)

Pass 1 V3 identified the operator/executor wallet. Pass 2C asks the deeper questions:

- What happens if the operator wallet runs out of gas? Does the protocol stall? Can users brick state by spamming transactions that drain the operator?
- What happens if the operator wallet is compromised? Is there a recovery mechanism? An emergency pause? A multisig override?
- Has the operator wallet ever been rotated? (Check tx history.) If it has been the same EOA for 12+ months, the private key has had a long exposure window.
- Is the operator wallet's private key derived from a hardware wallet, a backend env var, or an HSM?

```bash
OPERATOR="0x..."
RPC="https://ethereum-rpc.publicnode.com"

# How much gas does it currently hold?
BALANCE=$(cast balance $OPERATOR --rpc-url $RPC)

# When did it first transact?
FIRST_TX=$(cast etherscan-source --etherscan-api-key $KEY --chain mainnet $OPERATOR | head -1)

# How many txs has it sent in the last 30 days? (Activity = fresh attack surface)
TX_COUNT=$(cast nonce $OPERATOR --rpc-url $RPC)
```

**Upshift hits:** NEW-04 (operator wallet single-key, no rotation, no recovery).

### Sub-pass 2D -- Staging/dev backend + Lambda secondary surface

Pass 1 V5 + V6 found primary staging surfaces. Pass 2D digs deeper:

- For each staging subdomain found, enumerate its routes (does staging expose an admin panel that prod hides?)
- For each Lambda found, check whether it has weaker auth than the primary API (Lambda envs are often misconfigured)
- Are there staging-only endpoints that accept production data? (e.g., `staging.api.target.com/v1/users` with prod DB read access)
- Do staging/Lambda use different secret names than prod, suggesting separate env files? (Higher chance of one being leaked.)

```bash
# Enumerate staging routes
ffuf -u https://staging.target.com/FUZZ -w /usr/share/wordlists/api-routes.txt -mc 200,401,422 -fs 0

# For each Lambda found in V6, test arg validation
curl -X POST https://abcd1234.execute-api.us-east-1.amazonaws.com/prod/endpoint \
  -H 'Content-Type: application/json' \
  -d '{}' -i

# Compare staging route inventory vs prod route inventory
diff <(curl -s https://api.target.com/openapi.json | jq -r '.paths | keys[]' | sort) \
     <(curl -s https://staging.api.target.com/openapi.json | jq -r '.paths | keys[]' | sort)
```

**Upshift hits:** W28 (dev/QA backends), W29 (Lambda body validator gap), W31 (staging admin route exposed), W32 (staging replica with prod-adjacent data).

### Sub-pass 2E -- Secret hygiene sweep (W26-W27 class)

Beyond the primary V1 grep, run a forensic pass:

- Search the bundle for any 32+ char hex string that is not an obvious commit SHA
- Search for base64-encoded JWTs (look for `eyJ` prefix)
- Search for AWS access key prefixes (`AKIA`, `ASIA`)
- Search for Slack webhook URLs (`hooks.slack.com/services/`)
- Search for Sentry DSN URLs (`*@*.ingest.sentry.io`)
- Search for any URL containing `apikey=`, `token=`, `key=` query params
- Check the source maps if exposed (`.js.map` files often leak development env vars stripped from the prod bundle)

```bash
BUNDLE_URL="https://app.target.io/assets/index-XXX.js"

curl -s $BUNDLE_URL | grep -oE '\b[a-f0-9]{40,128}\b' | sort -u  # hex strings
curl -s $BUNDLE_URL | grep -oE 'eyJ[a-zA-Z0-9_-]+\.[a-zA-Z0-9_-]+\.[a-zA-Z0-9_-]+'  # JWTs
curl -s $BUNDLE_URL | grep -oE 'AKIA[A-Z0-9]{16}|ASIA[A-Z0-9]{16}'  # AWS keys
curl -s $BUNDLE_URL | grep -oE 'hooks\.slack\.com/services/[A-Z0-9/]+'  # Slack
curl -s $BUNDLE_URL | grep -oE 'https://[a-f0-9]+@[a-z0-9.-]+\.ingest\.sentry\.io/[0-9]+'  # Sentry DSN
curl -s ${BUNDLE_URL}.map  # source maps if exposed
```

**Upshift hits:** W26 (Slack webhook), W27 (API keys), W30 (Sentry DSN with wallet correlation).

### Completion criteria for Pass 2

- All 5 sub-passes (2A-2E) executed
- Each new finding documented in `findings/NEW-##/SUMMARY.md`
- Inventory updated at `recon/INVENTORY-PASS-2.md` with delta vs Pass 1

**Time budget:** 6-12 hours on an Upshift-class target.

**Anti-stop signal in Pass 2:** "Pass 1 already gave me 14 findings, this is enough." → **NO.** Pass 2 produced 16 of Upshift's 48 findings. Without it, you stop at the median hunter ceiling.

## Pass 3 -- Mirror invariant audit

**Lens:** "If protection P exists at endpoint A, why is it missing at endpoint B?"

This is the pass that produced F1 ($308M unauth API endpoint). The reasoning was:
- Pass 1 V2 confirmed: GET `/integrations/methods` returns 401 (auth middleware works for GET)
- POST same endpoint returns 422 (body validator runs but auth middleware does NOT for POST)

The asymmetry -- same endpoint, different auth coverage by HTTP verb -- is a mirror invariant violation. The protocol clearly intended both verbs to be authenticated (GET enforces it), so the missing POST auth is an oversight, not design. **This is the most reliably criticality-amplifying pass.**

CLAUDE.md rule #41 ("MANDATORY: Mirror invariant audit for in/out protocols") is the source for this pass. The Upshift-specific application:

### Mirror pairs to audit

| Pair type | Example | What asymmetry to look for |
|---|---|---|
| HTTP verb pair | GET vs POST same endpoint | Auth middleware coverage |
| Network pair | prod vs staging same endpoint | Auth, rate limit, body validation |
| Protocol pair | REST vs GraphQL same resource | Permission scope, field-level access |
| Chain pair | Ethereum vs Arbitrum same contract | Owner address, parameters, recovery roles |
| Function pair | `deposit()` vs `withdraw()` | Reentrancy guard, oracle freshness check |
| Role pair | admin vs operator | Privilege overlap, missing splits |
| State pair | activated vs deactivated | Whether deactivation actually disables the surface |

### How to run Pass 3

For each primitive found in Pass 1 + Pass 2, identify its **mirror pair** and ask: "Is the protection symmetric?"

Concrete drill, using F1 as the template:

1. Pass 1 V2 found: POST `/integrations/methods` returns 422 (body validator runs, auth does NOT)
2. Pass 3 question: "What does GET on the same path return?"
3. Run: `curl -i https://api.target.com/integrations/methods` → 401 (auth runs)
4. Asymmetry confirmed: middleware ordering is wrong, body validator runs before auth middleware on POST
5. **The asymmetry IS the finding.** No further proof needed for the bug class. To make it a Critical, chain it to the on-chain effect (which Pass 4 does).

Apply this pattern to every primitive:

| Primitive | Mirror question | Upshift result |
|---|---|---|
| `/openapi.json` exposed | "Is `/openapi.json` exposed on staging too?" | Yes, with MORE routes (W11) |
| Operator wallet single-EOA | "Are other privileged wallets (treasury, fee collector) also single-EOA?" | Yes, all 4 privileged wallets are EOA (W23) |
| API endpoint accepts JWT | "Does the WebSocket endpoint accept the same JWT?" | Yes, but with different scope (W9 RBAC leak) |
| Frontend rate-limited | "Is the API rate-limited too?" | No (W6 missing rate limit) |
| GET returns 200 with body | "Does HEAD return the same headers?" | Yes (information leak in HEAD W21) |
| Withdrawal requires 2FA | "Does deposit refund require 2FA?" | No (W17 OTC DB write bypass) |

### Completion criteria for Pass 3

- Every primitive from Pass 1 + Pass 2 has at least one mirror pair audit
- Each asymmetry found documented in `findings/W##/MIRROR-AUDIT.md`
- Inventory updated at `recon/INVENTORY-PASS-3.md` with asymmetry findings

**Time budget:** 4-8 hours.

**Anti-stop signal in Pass 3:** "Pass 1+2 found 30 findings, this is too many already." → **NO.** Pass 3 is where the Critical chains form. The amplification factor (Pass 1 W34 + Pass 3 mirror = F1 chain enabler) is multiplicative, not additive. Skipping Pass 3 = leaving the $308M chain on the table.

## Pass 4 -- Chain construction

**Lens:** "Which 2+ findings, combined, create an attack chain that no single finding could?"

This is where the engagement narrative emerges. F1 alone is a Critical (unauth on-chain state mod). W34 alone is a Critical (hardcoded executor master password). But F1+W34 chained creates a **$308M drainable in 15 minutes by any internet user at zero attacker gas cost** -- a categorically more severe finding than either component.

The protocol team understands chains differently than they understand individual findings. A chain is undeniable. An individual finding can be argued ("the executor key is segmented", "the admin role is restricted to internal IPs", etc.). A chain shows the actual attacker walking through the front door.

### How to run Pass 4

Layout all primitives from Pass 1+2+3 on a whiteboard (or in `recon/PRIMITIVES-MAP.md`). For each pair (and triplet, and quadruplet), ask:

1. "If an attacker has primitive A, does primitive B amplify it?"
2. "Does the combination unlock an action that neither alone could?"
3. "Can the chain be executed by a single actor without privileged access?"

**Common amplification patterns:**

| Combination | Amplification | Upshift example |
|---|---|---|
| Credential leak + unauth API | Credential becomes irrelevant, API is the bypass | W34 + F1 = $308M |
| Read-only role escalation + write endpoint | Read role can now write | W9 + W17 |
| Cross-chain replay + signature reuse | Single signature drains N chains | F1 + 14-chain role replication = $308M |
| Staging admin + prod read replica | Staging endpoint writes to prod-adjacent data | W28 + W32 |
| Sentry DSN + wallet correlation | Wallet activity de-anonymized via error logs | W30 + W26 |
| Lambda body validation gap + Lambda IAM scope | Anonymous attacker invokes IAM-scoped action | W29 + AWS misconfig |

**Per-chain output:** For each chain identified, write `findings/CHAIN-##/CHAIN-PROOF.md` with:

```markdown
# Chain ##: [name]

## Components
- Primitive A: W## ([severity])
- Primitive B: W## ([severity])
- (Optional) Primitive C: W## ([severity])

## Combined attack
[Step-by-step what an attacker does, with concrete commands]

## Combined severity
[Always > max(component severities)]

## Combined impact (numeric)
[$X drainable / Y users affected / Z chains hit]

## Why the components alone don't justify this severity
[The component-only argument that would dismiss each individual finding]

## Why the chain is undismissable
[The asymmetry / amplification that makes the chain qualitatively different]
```

### Completion criteria for Pass 4

- All primitives mapped at `recon/PRIMITIVES-MAP.md`
- At least 1 chain attempted (even if it fails, document why)
- For each successful chain: `findings/CHAIN-##/CHAIN-PROOF.md` with concrete numeric impact
- Chain proofs cross-referenced from individual finding files (so reviewers can navigate either direction)

**Time budget:** 4-8 hours. Often less, because Pass 4 is recombinant -- the work is reasoning about existing primitives, not finding new ones.

**Anti-stop signal in Pass 4:** "I have 40 findings, the report writeup is going to be massive." → **NO.** Pass 4 is what makes the engagement memorable to the sponsor. F1+W34 = $308M is the line that opened Alex Elkrief's reply at 19:44 the same day. Without it, the disclosure is "40 findings of various severity" -- a bulk dump that gets routed to a junior triager and slow-walked.

## After Pass 4 -- Submission gate (NOT another pass)

Pass 4 is the last hunting pass. Everything after is submission discipline.

At submission gate, apply the **theoretical-bug-kill rule** (`feedback_theoretical_bug_kill_2026_04_24.md`): for each finding, ask whether it is concrete enough to ship.

**Critical clarification:** the theoretical-bug-kill rule applies at SUBMISSION, never at HUNT TIME. A finding that is too theoretical to ship as a standalone may still be load-bearing for a chain, may inform the architectural narrative for a fortress follow-up, or may become concrete on a future re-verification when the protocol changes around it. Killing a theoretical finding at hunt time deprives Pass 4 of a chain component.

The decision tree at submission:

```
Is the finding concrete (reproducible PoC, observable state change)?
├─ YES → Submit individually
└─ NO  → Is it a chain component?
        ├─ YES → Include in chain finding, do not submit standalone
        └─ NO  → Is it architectural narrative material for fortress phase?
                ├─ YES → Park in fortress notes, do not submit, mention in fortress email
                └─ NO  → Discard, document why in `findings/KILLED-##/REASON.md`
```

## The 4-pass discipline as guard against Upshift-class regression

The reason this file exists: on the original Upshift engagement, the rhythm of Pass 1 → Pass 2 → Pass 3 → Pass 4 is what produced 48 findings. A future session that skips any pass will under-deliver. Specifically:

- Skipping Pass 1 → no inventory, every later pass guesses
- Skipping Pass 2 → 16 findings missed, miss the proxy governance + operator + staging surfaces
- Skipping Pass 3 → no F1-class amplifier, miss every mirror-invariant Critical
- Skipping Pass 4 → no $308M chain, no narrative weight in the disclosure

**Hard rule:** a `/upshift` engagement against a target classified Upshift-class executes all 4 passes. The trigger to move from Pass N to Pass N+1 is "Pass N completion criteria met", NOT "Pass N feels long". The trigger to STOP is "all 4 passes complete + submission gate cleared", NOT "I have enough findings".

If you find yourself wanting to stop early, re-read IMMORTAL-MODE.md. The 5 anti-stop guards in that file exist specifically to override the "I have enough" instinct.
