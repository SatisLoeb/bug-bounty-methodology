---
name: hunt-methodology
description: The 4-pass hunt discipline, generalized from upshift to any surface. Pass 1 = primary vector-pack scan in parallel. Pass 2 = expansion (the patterns the pack systematically misses). Pass 3 = mirror invariant audit (every bidirectional pair, V_in vs V_out). Pass 4 = chain construction (combine 2+ findings into an amplified attack). The seam statement from Phase 0 is the hypothesis Pass 3 and Pass 4 test. This is what took upshift from 12 findings to 48 -- domain-independent.
---

# Hunt methodology -- the 4-pass discipline (universal)

## Why 4 passes, not 1

A single pass through a vector pack surfaces ~10-15 findings. That is the median hunter's ceiling in 8 hours. The Upshift engagement produced 48 because it ran **4 sequential passes**, each with a different lens. This file is the upshift 4-pass discipline with the DeFi specifics removed -- it applies identically to web2, infra, crypto-libs, and ML systems.

| Pass | Lens | What it produces | Trigger to start |
|---|---|---|---|
| Pass 1 | "Is the obvious thing broken?" | base findings from the vector pack | after recon + seam statement |
| Pass 2 | "What patterns did Pass 1 systematically miss?" | expansion findings (the pack's blind spots) | after Pass 1 inventory complete |
| Pass 3 | "If protection P exists at A, why is it missing at B?" | mirror-invariant / asymmetry findings -- where the seam's Criticals form | after Pass 2 |
| Pass 4 | "Which 2+ findings combined create an attack no single one could?" | amplified chains -- the headline | after all primitives mapped |

The arithmetic that matters: Pass 1 ≈ what 90% of hunters call "a complete engagement". Passes 2-3-4 are the other ~70% of the findings AND the headline chain. Skipping any pass under-delivers in a *named* way (see end of file).

## Pass 1 -- Primary scan (vector pack in parallel)

**Lens:** "Is the obvious thing broken?"

**Method:** load the one vector pack the seam selected. Run all its vectors in parallel -- each is a self-contained detection kit (the read-only ones go in one parallel Bash batch). There are zero dependencies between vectors.

**Per-finding output:** for each hit, write a stub at `findings/<id>/SUMMARY.md` with vector ID, raw evidence, primitive name, severity guess. **Do not write the full report yet** -- that comes after Pass 4. Pass 1's job is to *inventory primitives*, not to write reports.

**Completion criteria:**
- Every vector run end-to-end (or explicit null-result logged)
- Each hit has a stub finding file
- `recon/INVENTORY-PASS-1.md` lists every primitive found

**Anti-stop signal:** "I found a Critical, let me write it up." → **NO.** Writing breaks the scanning rhythm and starves Pass 2-4. Continue to Pass 1 completion.

**Time budget:** 4-8h on a high-value target. If still scanning past 8h, you are deep-diving prematurely -- move to Pass 2 even if Pass 1 feels incomplete.

## Pass 2 -- Expansion (the pack's blind spots)

**Lens:** "What patterns did Pass 1 systematically miss?"

Vector packs are tuned to common, directly-targetable patterns. Pass 2 catches the architectural patterns that *emerge from inspecting what Pass 1 surfaced* -- they aren't directly targeted by any single vector.

The universal expansion sub-passes (each pack specializes these):

### 2A -- Authority/governance chain
For every privileged role / admin / owner / upgrade authority / trust anchor found in Pass 1, trace the FULL chain of who controls it, to the root. On upshift this was the proxy governance chain (EOA→Safe→Timelock→ProxyAdmin→Impl). Generalized:
- Web2: session → role → tenant-admin → platform-admin → who can mint an admin?
- Infra: IAM role → assume-role chain → trust policy → root account → who can pass-role?
- Crypto-lib: key → key-derivation → trust root → who controls the CA / the signing key / the verification key?
- ML: tool scope → agent identity → service account → who can grant tool access?

Looking for: single-point-of-failure at the root, naming deception (a thing called "multisig"/"timelock"/"MPC" that is actually a single key -- the upshift NEW-05 class, recurrent everywhere).

### 2B -- Secret/credential hygiene sweep
Beyond the primary vector grep, run a forensic pass for any credential that crossed a build-time→run-time or internal→external boundary. The upshift W26/W27/W34-secondary class. Generalized in each pack's kit (bundle grep / image layers / CI logs / model cards / config dumps).

### 2C -- Privileged-actor behavior under stress
For each privileged actor found in Pass 1, ask the deeper questions: what if it's compromised? rotated? out of resources? Is there recovery, pause, override? How long has the credential been static (exposure window)?

### 2D -- Secondary/shadow surface
Staging, dev, QA, replica, debug, legacy, internal-only-but-reachable. The upshift W28/W31/W32 class. Each pack has its own shadow-surface enumeration. The recurring win: a shadow surface with weaker auth than prod that reads/writes prod-adjacent data.

### 2E -- Error/telemetry leak
What does the system leak when it fails or reports? Stack traces, internal IDs, topology, correlation data. The upshift W22/W30 class.

**Completion criteria:** all 5 sub-passes executed; each new finding stubbed; `recon/INVENTORY-PASS-2.md` with delta vs Pass 1.

**Time budget:** 6-12h.

**Anti-stop signal:** "Pass 1 gave me 14 findings, enough." → **NO.** Pass 2 was 16 of upshift's 48.

## Pass 3 -- Mirror invariant audit (the Critical-forming pass)

**Lens:** "If protection P exists at endpoint/path/binding A, why is it missing at B?"

This is the pass that produced F1 ($308M). The reasoning: Pass 1 found POST `/integrations/methods` returns 422 (validator runs, auth doesn't); Pass 3 asked "what does GET return?" → 401 (auth runs). **Same endpoint, different auth coverage by verb = mirror-invariant violation.** The protocol clearly *intended* both authed (GET enforces it), so the missing POST auth is an oversight, not design. **This is the most reliably criticality-amplifying pass, and it is exactly the seam from Phase 0 made concrete.**

CLAUDE.md Rule #41 is the source. Generalized: a side is NOT "clean" without a written `V_in vs V_out` line. Presence-scanning misses absence-of-protection bugs.

### Mirror pairs to audit (universal -- each pack adds its own)

| Pair type | What asymmetry to look for |
|---|---|
| Verb / method pair | same resource, different protection per HTTP verb / RPC method / API call |
| Network pair | prod vs staging vs replica -- auth, rate-limit, validation drift |
| Protocol pair | REST vs GraphQL vs gRPC for the same resource -- permission scope, field access |
| Binding pair | language-A vs language-B impl of the same primitive -- edge-input handling |
| Direction pair | encode/decode, serialize/deserialize, ingress/egress, request/response, train/inference |
| Tenant pair | tenant A vs tenant B -- isolation symmetry |
| Build/run pair | build-time check vs run-time check -- does the run-time trust the build-time? |
| Trust pair | trusted-input path vs untrusted-input path reaching the same sink |
| State pair | activated vs deactivated -- does deactivation actually disable the surface? |

### How to run Pass 3

For each primitive from Pass 1+2, identify its mirror pair and ask: "Is the protection symmetric?" Concrete drill (F1 template):
1. Pass 1 found: POST X returns 422 (validator runs, auth does not)
2. Pass 3 asks: "What does GET X return?"
3. Run it: 401 (auth runs)
4. Asymmetry confirmed: middleware ordering wrong, validator before auth on POST
5. **The asymmetry IS the finding.** To make it Critical, chain it to the downstream effect (Pass 4).

**Completion criteria:** every primitive has ≥1 mirror-pair audit with a written `V_in vs V_out` line; asymmetries documented in `findings/<id>/MIRROR-AUDIT.md`; `recon/INVENTORY-PASS-3.md`.

**Time budget:** 4-8h.

**Anti-stop signal:** "Pass 1+2 found 30, too many already." → **NO.** Pass 3 is where the seam's Criticals form. The amplification is multiplicative, not additive.

## Pass 4 -- Chain construction (the headline)

**Lens:** "Which 2+ findings, combined, create an attack no single one could?"

This is where the engagement narrative emerges. On upshift, F1 alone is a Critical and W34 alone is a Critical, but F1+W34 chained = *$308M drainable in 15 min by any internet user at $0 attacker cost* -- categorically more severe than either component. **A chain is undismissable; an individual finding can be argued away** ("the key is segmented", "the role is IP-restricted"). The chain shows the attacker walking through the front door.

### How to run Pass 4

Lay out all primitives (`recon/PRIMITIVES-MAP.md`). For each pair (and triplet), ask:
1. If an attacker has primitive A, does B amplify it?
2. Does the combination unlock an action neither alone could?
3. Can the chain be executed by a single actor without privileged access?

**Universal amplification patterns:**

| Combination | Amplification |
|---|---|
| Credential leak + unauth trigger | credential becomes irrelevant, the trigger IS the bypass (the F1+W34 killshot shape) |
| Read-only escalation + write sink | read role can now write |
| Replay primitive + state mutation | single artifact applies N times |
| Shadow surface + prod-adjacent data | staging/debug endpoint writes prod data |
| Info leak + targeting | leak maps the exact blast radius for a second primitive (the upshift W19 × F3 shape -- a leak doesn't add loss, it removes enumeration cost) |
| Untrusted-input + privileged sink | injection reaches execution (SSRF, prompt-injection-to-tool, LLM-output-to-shell) |
| Upgrade/replace authority + any Medium | the Medium becomes Critical if the attacker can swap the implementation |

**Per-chain output:** `findings/CHAIN-<id>/CHAIN-PROOF.md` with: components (each with severity), combined attack (step-by-step concrete commands), combined severity (always > max component), combined impact (numeric, sourced), why-components-alone-don't-justify, why-the-chain-is-undismissable.

**Completion criteria:** all primitives mapped; ≥1 chain attempted (document failures too); each successful chain has a CHAIN-PROOF with sourced numeric impact; chains cross-referenced from component findings.

**Time budget:** 4-8h (often less -- Pass 4 is recombinant reasoning over existing primitives, not new finding).

**Anti-stop signal:** "I have 40 findings, the writeup will be massive." → **NO.** Pass 4 is what gets the email opened in 24h instead of routed to a junior triager as "40 findings of various severity".

## After Pass 4 -- the gates, not another pass

Pass 4 is the last hunting pass. Everything after is submission discipline:
1. **ANTI-INFLATION.md** -- scope / magnitude / mechanism honesty (the pass that makes findings survive triage).
2. **theoretical-bug-kill** at the submission gate ONLY (never at hunt time -- a theoretical finding may be a chain component or fortress ammo).
3. Kill-gate → severity-commit → report-nerve/chill → D7/D8/D9 → preflight 22/24.

Decision tree at submission:
```
Concrete (reproducible PoC, observed state delta)?
├─ YES → submit individually
└─ NO  → chain component?
        ├─ YES → include in chain finding, don't submit standalone
        └─ NO  → fortress-narrative material?
                ├─ YES → park in fortress notes, mention in fortress email
                └─ NO  → discard, document why in findings/KILLED-<id>/REASON.md
```

## The 4-pass discipline as regression guard

A session that skips a pass under-delivers in a named way:
- Skip Pass 1 → no inventory; every later pass guesses
- Skip Pass 2 → miss the authority-chain / secret / shadow-surface findings (~1/3 of yield)
- Skip Pass 3 → no mirror-invariant Critical; the seam stays abstract instead of proven
- Skip Pass 4 → no headline chain; the disclosure is a bulk dump that gets slow-walked

**Hard rule:** an upshift2 engagement executes all 4 passes. The trigger Pass N → N+1 is "Pass N completion criteria met", never "Pass N feels long". The trigger to STOP is "all 4 passes complete + immortal-mode green + submission gates cleared", never "I have enough". If you want to stop early, re-read `IMMORTAL-MODE.md`.
