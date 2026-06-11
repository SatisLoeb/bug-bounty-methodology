---
name: seam-thesis
description: How to locate the seam on a target the skill has never seen. The seam is the boundary between two disciplines/teams/layers/languages where each side is audited on its own and ownership of the boundary belongs to no one. This file is Phase 0 of upshift2 -- run it before opening code or any tool. Output: a one-paragraph seam statement that selects the vector pack and biases every later pass.
---

# Seam thesis -- locating the boundary nobody owns

## Why this is Phase 0 (before recon, before tools)

On Upshift, the finding that opened the Co-CEO's reply in 24h (F1+W34 = $308M) was not found by running a tool. It was found because the engagement *started* from the conviction that the off-chain→on-chain trigger was a seam nobody owned, then went looking for the specific instance of that seam. The tool runs came after the thesis.

A hunter who opens the code first pattern-matches against what they already know how to find. A hunter who locates the seam first goes looking for the thing the codebase's own auditors structurally could not see. The second hunter finds F1. The first finds W6 (a missing rate limit) and calls it a day.

**The seam is not a vulnerability. It is the *region* where vulnerabilities accumulate because no review process covers it.** Your job in Phase 0 is to name that region, then the vector pack tells you how to sweep it.

## The definition

A seam exists wherever **two distinct review regimes meet**, such that:

1. Each side has its own audit/review/test discipline.
2. Each discipline's scope *stops at the boundary* (the SC auditor's scope ends at the contract ABI; the web pentester's scope ends at the API response).
3. The boundary itself -- the translation, the trust-handoff, the data crossing from one regime to the other -- is owned by *neither* review.

The bug is almost never inside either regime (those are audited). It is in the **handoff**: the assumption one side makes about the other that the other does not actually guarantee.

## The seam catalogue (by surface)

Each surface has characteristic seams. This is where you START; the vector pack drills each one.

### Web2 / SaaS / API

| Seam | The unowned assumption | Where it breaks |
|---|---|---|
| Business-logic ↔ authz layer | "the auth middleware ran before this handler" | a verb/route/method the middleware doesn't cover (the F1 analogue: GET authed, POST not) |
| Tenant A ↔ tenant B | "the tenant_id is scoped by the query" | one query path that takes tenant_id from the body, not the session (IDOR / cross-tenant) |
| Billing/entitlement ↔ feature gate | "the paywall is enforced server-side" | a feature whose gate is client-side only, or whose entitlement check trusts a client-supplied plan claim |
| Client trust ↔ server trust | "the client validated this before sending" | a server endpoint that re-uses client-asserted state (price, role, quantity) without re-checking |
| State machine ↔ idempotency | "this transition only happens once" | a replayable request (no nonce / no idempotency key) that double-applies a state change |
| Sync API ↔ async worker | "the worker only processes validated jobs" | a queue an attacker can write to directly, bypassing the API validator |

### Infra / Cloud / Supply-chain

| Seam | The unowned assumption | Where it breaks |
|---|---|---|
| Build-time ↔ run-time | "the secret is only in CI, not in the artifact" | a secret baked into a layer/bundle/image that ships to where it can be read |
| IAM intent ↔ effective permission | "this role can only do X" | a transitive permission (pass-role, assume-role chain, wildcard policy) that grants Y |
| Declared IaC ↔ deployed state | "infra matches the Terraform" | drift -- a console-made change, a stale resource, an open SG the code doesn't show |
| Internal service ↔ exposed edge | "this is internal-only" | a service reachable from the internet via a misrouted LB / SSRF / forgotten public subnet |
| Dependency author ↔ consumer | "this package does what its README says" | typosquat, dependency confusion, post-install script, compromised maintainer, lockfile-vs-manifest drift |
| Container layer ↔ runtime policy | "the base image is trusted" | a layer with a leaked secret, a setuid binary, or a CVE the runtime policy doesn't catch |

### Crypto-libs / protocols

| Seam | The unowned assumption | Where it breaks |
|---|---|---|
| Spec MAY/MUST ↔ implementation | "the impl follows the RFC" | a MUST silently downgraded to a MAY; a validation the spec requires that the impl skips (the SIWE 1-of-8-fields analogue) |
| Language-A binding ↔ language-B binding | "all bindings behave identically" | one binding that handles an edge input (zero, identity element, malformed length) differently |
| Constant-time *claim* ↔ actual | "this comparison is constant-time" | a branch / early-return / table lookup that leaks timing on secret-dependent data |
| Test-vector coverage ↔ edge inputs | "the test vectors cover the input space" | an input class the vectors never exercise (identity point, all-zero, max-length, negative, NaN) |
| Serialize ↔ deserialize | "round-trip is lossless and validated" | a deserializer that accepts inputs the serializer never produces (canonicalization, malleability, length confusion) |
| Crypto primitive ↔ protocol composition | "the primitive is secure, so the protocol is" | a misuse: nonce reuse, missing domain separation, unauthenticated encryption, signature over the wrong bytes |

### ML / AI systems

| Seam | The unowned assumption | Where it breaks |
|---|---|---|
| Untrusted data ↔ privileged tool-exec | "the model only acts on trusted instructions" | indirect prompt injection -- attacker content in a doc/email/page becomes a tool call |
| Prompt boundary ↔ system prompt | "user input can't override the system prompt" | a delimiter/escape/role-confusion that promotes user text to system authority |
| RAG content trust ↔ action authority | "retrieved context is just context" | retrieved content that carries instructions the agent executes |
| Model supply-chain ↔ runtime | "the model weights are what we trained" | a poisoned/backdoored model, an unsigned weight pull, a model-card-vs-actual mismatch |
| Output ↔ downstream sink | "the model output is sanitized before use" | model output flowing unescaped into SQL / shell / HTML / a second agent (XSS-via-LLM, RCE-via-LLM) |
| Tool schema ↔ tool implementation | "the tool only does what its schema says" | a tool whose implementation has side effects or auth scope broader than its declared schema |

## The procedure (30-60 min, before any tool)

### Step 1 -- Map the disciplines

Ask: *who reviewed each part of this system, and where did each reviewer's scope stop?*

Concrete signals:
- Published audits / pentests -- read their scope sections. The scope section literally tells you where the review stopped. The seam is just past that line.
- Team structure -- separate repos, separate vendors, separate languages, "platform team" vs "product team", a SECURITY.md that covers one repo but not the sibling.
- Architecture docs / "how it works" pages -- every arrow between two boxes is a candidate seam.

Write `recon/DISCIPLINES-MAP.md`: list each component, who owns/reviewed it, and where that ownership stops.

### Step 2 -- Enumerate the boundaries

For each pair of adjacent components, name the boundary and the trust-handoff across it. Use the seam catalogue above as a prompt list. Don't filter yet -- list every boundary.

Write `recon/SEAM-CANDIDATES.md`.

### Step 3 -- Score each seam for unowned-ness

For each candidate, ask the three questions:
1. Is side A audited? Is side B audited?
2. Does either audit's scope explicitly cover the *handoff*?
3. If a bug lived exactly in the handoff, which review process would have caught it?

A seam where the answer to (3) is "none" is a high-value seam. That is where you point the vector pack.

### Step 4 -- Write the seam statement

One paragraph, the output of Phase 0:

```
The seam on <target> is between <discipline A> and <discipline B>.
<A> is reviewed by <process A, scope stops at X>. <B> is reviewed by <process B, scope stops at Y>.
The handoff -- <the specific translation/trust/data crossing> -- is owned by neither.
A bug in this handoff would look like <hypothesis>. The matching vector pack is <pack>.
```

This statement is load-bearing. It goes in `recon/SEAM-STATEMENT.md` and is restated at the top of the eventual report (it is the "internal consistency" argument -- "you protect this everywhere except the seam, so the gap is an oversight, not design").

## The "no seam" verdict

Sometimes there is no seam: one team owns the whole stack, reviewed coherently end-to-end, with the handoffs explicitly in scope. This is the Monetrix case from upshift's IMMORTAL-MODE.md -- a well-architected target where the methodology correctly says "stop". When you reach this verdict:

- It must be *measured*, not felt (IMMORTAL-MODE.md Guard 4). The measurement here: every boundary in `recon/SEAM-CANDIDATES.md` has a named review process that covers its handoff.
- If even one boundary has "none" for review coverage, you do not have a no-seam verdict. You have an un-swept seam.
- Route a genuine no-seam target away from upshift2.

## Why the seam thesis beats vector-first hunting

Vector-first hunting (run the kit, see what hits) finds the findings the kit was tuned for. It is necessary (Pass 1 is vector-first) but insufficient -- it cannot find the finding that lives *between* two vectors, because no single vector targets a handoff.

Seam-first hunting names the handoff, then asks "which combination of vectors would expose a bug HERE?" That question is what `HUNT-METHODOLOGY.md` Pass 3 (mirror invariant) and Pass 4 (chain construction) operationalize. The seam statement from Phase 0 is the hypothesis those passes test. Without it, Pass 3 and Pass 4 wander; with it, they aim.

The seam is the difference between "I ran some tools and found some bugs" and "I knew where the bug had to be and I went and proved it."
