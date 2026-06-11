# Upshift Reference Engagement -- Annotated Walkthrough

This file is the gold-standard reference for the methodology. It documents the original Upshift Finance engagement end-to-end so a future session with no context can reconstruct what happened, why each decision was made, and what almost killed the engagement. Every other companion file in this skill generalizes from these specifics; reading this file before generalizing keeps the methodology grounded.

If you are running `/upshift` for the first time, read this file before starting your engagement. If you are a future session resuming this skill, read this file to recover the operational context that the other files abstract away.

## Target identification

Target: **Upshift Finance** (also known as August Digital, also known as Fractal Protocol -- three brands, one stack).

Profile match against the Upshift-class candidate criteria:
- TVL: $308M (snapshot 2026-03-02; 68 vaults across 27 chains)
- Backend orchestration: yes (FastAPI on api.upshift.finance + backend.fractalprotocol.org + api.augustdigital.io, three live backends with overlap)
- Executor wallet pattern: yes (operator hot wallet `0xE0b7DEab801D864650DEc58CbD1b3c441D058C79` signs across 14 chains; executor identity `0x931250786dFd106B1E63C7Fd8f0d854876a45200` for 6 execution endpoints)
- Smart contract audits: ChainSecurity (jan 2025) on the contracts; no audit visible on the off-chain stack
- Disclosure profile: no bug bounty program; security@ exists (operator: aya@); CTO/CEO reachable on LinkedIn

This profile is the prototype for the candidate scoring rubric in `TARGET-SELECTION.md`.

## Engagement timeline

| Date | Event | Decision |
|------|-------|----------|
| 2026-03-02 | Recon + hunt completed; 48 findings catalogued (7 Critical, ~10 High, ~31 Medium/Low); on-chain proof tx mined on HyperEVM (`0x5458171c...`) and Ethereum mainnet (`0xe0a8ff7a...`) | Stop hunt, write reports |
| 2026-03-03 | Initial email to aya@ (Upshift security contact, found in security@-style channel) titled "Critical Security Vulnerability -- Active Risk" | Standard Stage 1 disclosure |
| 2026-03-03 → 2026-04-19 | **47 days of complete silence** | Wrong call to wait this long; should have escalated at day 14 per protocol |
| 2026-04-19 | Decision to escalate | Drafted LinkedIn DM + public X post (held in reserve) |
| 2026-04-19 | LinkedIn DM sent to Alex Elkrief (Co-Founder & Co-CEO) | Stage 2 escalation -- correct execution but ~30 days late |
| 2026-04-22 | Alex acknowledged on LinkedIn; deleted public LinkedIn comment; requested secure email at alex@augustdigital.io | Stage 2 succeeded -- LinkedIn-to-CEO is the unlock for ghosted security@ contacts |
| 2026-04-22 | Re-verification email sent to alex@augustdigital.io with three reports (`EXECUTIVE-WORSTCASE.md`, `DISCLOSURE-CRITICAL.md`, `DISCLOSURE-F1.md`) attached + the WORSTCASE 1490-line technical version. Subject framing put `$308M drainable in ~15 minutes at $0` in the first sentence | Stage 3 -- re-verification at day N+50 strengthens severity narrative; severity figure in first sentence forces engagement |
| 2026-04-23 19:44 UTC | Alex acknowledged the email: "Acknowledged -- we have received your disclosure and all attached reports. We are reviewing the materials in detail with our security team and will revert to you by end of day tomorrow with our initial assessment and next steps." | 24h ack after 47-day silence -- the LinkedIn-DM-to-CEO unlock works |
| 2026-04-24 → 2026-04-25 02:00 UTC | Patches landed within ~30h of ack: F1 endpoint refactored (404 across all variants), W34 master password rotated + bundle rebuilt (`index-Bu3SA1OT.js` → `index-BVDjb3I4.js`), W26 Slack webhook revoked (404). Three Criticals neutralized before formal assessment email | Implicit severity confirmation -- protocols don't ship emergency patches in <30h unless the threat is real |
| 2026-04-25 ~02:00 UTC | Fortress follow-up email sent (Stage 4) -- confirmed the 3 patches with byte-identical evidence, flagged W16 (SIWE static nonce) and F3 (NAV manipulation) as still live, offered remaining 45 findings in 3 delivery formats (full tarball / severity-tiered batches / per-theme architectural calls) | Stage 4 timing critical -- sent during the 30-hour engagement window while team is in active flow, before attention dissipates |

The engagement is alive at this snapshot. Future updates land in `~/.claude/projects/-home-malix-Desktop-BUGS/memory/project_upshift_finance.md`.

## What worked

### Combined-chain construction (F1+W34=$308M)

The single most important move. F1 alone (unauthenticated POST → on-chain state mod) is a Critical, but it requires the attacker to also have a way to actually execute a transfer once the permission is granted. W34 alone (hardcoded executor master password) is a Critical, but it requires the attacker to have a target action that the executor can be made to sign. **Either alone is dismissable as "operator-trusted" or "requires social engineering". Combined as the F1+W34 chain, neither dismissal works.**

The chain is the killshot:
1. Pull master password from public bundle (W34, 2 lines of curl, no auth)
2. Authenticate as executor via `/auth/sign` with the password (no auth)
3. Use F1 to whitelist `ERC20.transfer` for any target subaccount (no auth)
4. Use executor JWT to call `tx_batcher/execute`, backend signs and broadcasts the transfer to attacker wallet (legit operator action)
5. Loop across 2,212 roles × 14 chains covering $308M TVL

Attacker pays zero gas (operator + executor wallets pay all fees). End-to-end ~15 min. **The chain has 9/9 E2E checks pass on production**, only the final transfer is not executed because executing it would steal user funds.

This is `HUNT-METHODOLOGY.md` Pass 4 in action. The chain is what you build AFTER you have the individual findings, not at the same time. Many hunters stop at the individual findings.

### On-chain proof in the email's first paragraph

The 2026-04-22 email opened with the on-chain tx hash `0x5458171c6b26b285d33b4cefab6afb90089610cc5499083af022b5e9eec6b4b7` mined on HyperEVM block 28,676,655. This is undismissable evidence -- the receipt is on-chain, anyone can verify it on a block explorer in 30 seconds. The phrase "i re-verified both primitives against today's production build -- both are live byte-identical to their march state, 51 days after the initial report" was the second sentence.

Putting evidence first and severity ($308M) in the same first paragraph compresses the entire engagement story into the 5 seconds an executive spends on the first paragraph of a cold email.

### kabayanerve voice in the email

The email is first person, lowercase, no em-dashes, no corporate filler. Direct technical prose. "thanks for the ack. writing from the gmail i used with aya on 2026-03-03 so the thread is linkable." -- this is the opening. No formal greeting, no "I hope this email finds you well", no preamble.

When Alex replied 24h later he matched the register: short, direct, action-oriented. The voice signals "engineer to engineer, not lawyer to lawyer", which routes the conversation to the security team instead of legal.

### Re-verification before the email

Both primitives were re-verified live against production in the morning before the email was sent. The email said "i re-verified both primitives against today's production build -- both are live byte-identical to their march state". This phrase preempts the most common dismissal ("we patched that") and forces the reader to confirm the live state before responding. Alex couldn't reply "thanks, we already fixed that" because the email already showed they hadn't.

`RE-VERIFICATION-MONITOR.md` formalizes this discipline: every disclosure has a re-verification check that runs before any communication.

### Fortress framing (Stage 4)

The 2026-04-25 follow-up email did not say "you missed two more bugs, please patch". It said "i had compiled a much fuller findings bundle from the original session -- 42 web/API/infra findings plus 5 pipeline-expansion findings plus the F1 (NAV) on-chain finding... if you want to make Upshift a fortress -- not just patch the immediate threats but harden the architecture against the next round of attackers -- here's what that bundle covers".

This is a re-frame from threat to opportunity. The sponsor was asked to choose between "you have a problem, fix it" and "you have an opportunity to be unbreakable, here's the path". Almost no executive picks the first frame when the second is offered.

The fortress framing converts the engagement from a patch transaction to a hardening relationship. This is also where the ex-gratia conversation becomes natural -- the sponsor is being asked to participate in their own protection, not pay protection money.

## What almost killed the engagement

### 47 days of silence after Stage 1

The single biggest mistake. The initial email to aya@ on 2026-03-03 received zero response. The correct protocol (codified now in `DISCLOSURE-PROTOCOL.md`) is to escalate at day 14 via LinkedIn DM to a C-level. We waited until day 47.

Reasons we waited too long:
- No public clock running -- nothing forced the issue
- Hesitation about appearing pushy
- Belief that "they're probably triaging internally" (they were not)

Lessons:
- 14 days of silence is the maximum. After 14 days, escalate.
- "They're probably triaging" is an assumption, not evidence. Evidence is a reply.
- Silence past 14 days is itself information: the security@ channel is broken or unmonitored.

### Decision not to engage SEAL-911

In late march we drafted a SEAL-911 escalation request (the DeFi security incident response collective). We held it because Alex's LinkedIn was about to be tried first. SEAL-911 would have pulled in third-party pressure within 48h. In retrospect, holding it was correct -- LinkedIn-DM-to-CEO turned out to work -- but the threshold should have been "if LinkedIn DM gets no reply in 7 days, escalate to SEAL-911".

`DISCLOSURE-PROTOCOL.md` codifies SEAL-911 as the Stage 2.5 fallback if Stage 2 (LinkedIn DM) gets no reply.

### Almost dumping all 48 findings in the first email

The original draft of the 2026-04-22 email had all 48 findings inline. We cut it down to 3 (F1, W34/F2, F3 NAV) the night before sending. Dumping 48 findings would have:
- Buried the killshot ($308M chain) under noise
- Looked padded and unprofessional
- Forced the security team to triage 48 things instead of engage on 3
- Reduced the ex-gratia framing (more findings = looks like fishing)

Lesson: the first disclosure email ships the killshot only. The remaining bundle ships at Stage 4 (fortress) once the team is engaged.

`DISCLOSURE-PROTOCOL.md` Stage 1 explicitly limits the first email to the strongest 1-3 findings.

## The 10 attack vectors as applied to Upshift

This is the mapping from the abstract vectors in `SURFACE-ATTACK-PATTERNS.md` to the concrete Upshift findings. Use this as the worked example when applying the vectors to a new target.

| Vector | Upshift findings | Notes |
|--------|------------------|-------|
| V1 Bundle harvest | W34 (master password), NEW-02 (Helius RPC key), W27 (multiple API keys) | The `index-Bu3SA1OT.js` 6.18MB bundle was the source. grep for `VITE_APP_*` and `NEXT_PUBLIC_*` is the bread-and-butter. |
| V2 Unauth API endpoint sweep | F1, W2, W3, W4, W17, W19, W29 | OpenAPI was exposed at `/openapi.json` -- 124+ endpoints catalogued in 30 seconds. Without OpenAPI, route extraction from JS bundle is the fallback. |
| V3 Operator wallet audit | NEW-04 (single-key architecture), F3 (operator EOA on coreUSDC) | Read `operator()` on each vault contract via `eth_call`. EOA classification = `eth_getCode` returns `0x`. |
| V4 Off-chain → on-chain trigger trace | F1 (the entire class) | The signature finding of the engagement. Look for any API endpoint where the response body indicates an on-chain transaction was attempted (e.g., `tx_hash`, `Multicall3:`, `Fireblocks:`). |
| V5 Staging/dev backend recon | W32 (staging backend = production read replica), W28 (dev/QA backends) | Subdomain enum found `backend.staging.fractalprotocol.org` exposing prod data. Check every `staging.*`, `dev.*`, `qa.*` for production-data access. |
| V6 Lambda/serverless surface | W29 (`lakejdgkzc.execute-api.eu-west-1.amazonaws.com/logUpshiftDeposit`) | grep JS bundle for `execute-api.*amazonaws.com`. Lambdas are often outside the audit perimeter. |
| V7 SIWE/auth state machine | W16 (SIWE bypass + permanent static nonce) | Per the original report: 1 of 8 EIP-4361 fields validated server-side. Test the nonce stability with 2 consecutive `GET /users/{addr}/nonce` calls. |
| V8 Slack/PagerDuty/notification webhook leak | W26 (Slack webhook in `NEXT_PUBLIC_SLACK_WEBHOOK_*`) | Next.js makes `NEXT_PUBLIC_*` env vars browser-accessible by design. Webhooks in this prefix are always exposed. |
| V9 Sentry/analytics correlation | W30 (Sentry + wallet correlation) | Check what data flows to Sentry/Mixpanel/Amplitude/GTM. Wallet addresses leaking to third-party analytics = privacy + correlation attack. |
| V10 Proxy governance chain | NEW-01 (no timelock + weak multisigs), W35 (EOA proxy admin), W39 (sentETH 1-of-1 Safe) | Trace EOA → Safe → Timelock → ProxyAdmin → Implementation per proxy. The weakest link is the effective security. |

## The 4-pass methodology as applied to Upshift

This is what `HUNT-METHODOLOGY.md` formalizes, with the Upshift-specific timeline.

**Pass 1: Primary scan (10 vectors).** Run all 10 vector kits. Outcome on Upshift: ~25 findings (W1-W25 roughly, plus partial F1 awareness). This is what most hunters would call "a complete engagement".

**Pass 2: Expansion (NEW-01-05).** After Pass 1, refocus on architectural patterns: proxy governance chain, RPC keys across providers, multi-RPC endpoint exposure, operator wallet audit on-chain, naming deception in role identifiers. Outcome on Upshift: 5 NEW-01-05 findings + amplified versions of W1-W25 (e.g., W1 became F1 once we traced its full impact). This pass catches what Pass 1's surface scan missed.

**Pass 3: Mirror invariant audit.** For every bidirectional pair, enumerate validation sets V_in and V_out. Outcome on Upshift: revealed the GET-vs-POST asymmetry on `/integrations/methods` (GET checks auth, POST does not -- the F1 root cause), staging-vs-prod asymmetry (read-replica without auth gating), validator-coverage asymmetry on SIWE (1 of 8 fields). This pass added W16 (SIWE) and confirmed F1's structural nature.

**Pass 4: Chain construction.** Combine 2+ findings into amplified chains. Outcome on Upshift: F1+W34 = $308M chain. Without Pass 4, F1 and W34 would have been two separate Criticals. With Pass 4, they became the headline.

Each pass took 4-8 hours. Total hunt time: ~30 hours over 3 days. This is what `IMMORTAL-MODE.md` codifies as the discipline that produces 48 findings instead of 12.

## The 4-stage disclosure protocol as applied to Upshift

This is what `DISCLOSURE-PROTOCOL.md` formalizes, with the Upshift-specific moves.

**Stage 1 (2026-03-03).** Initial email to aya@ titled "Critical Security Vulnerability -- Active Risk". Three findings inline (F1, W34, F3 -- the strongest 3). On-chain tx hash in the first paragraph. Direct prose, kabayanerve voice. **Sent. Then 47 days of silence.**

**Stage 2 (2026-04-19).** LinkedIn DM to Alex Elkrief (Co-Founder & Co-CEO). Subject framing: "silent disclosure on a Critical -- needs your direct attention". Did not threaten public disclosure. Did not bring up the 47-day silence at aya@. Frame: "I want to give you the same information as the security@ channel got, in case the channel didn't surface it." Within 3 days Alex replied requesting secure email.

**Stage 3 (2026-04-22).** Re-verification email to alex@augustdigital.io. Three reports attached (`EXECUTIVE-WORSTCASE.md`, `DISCLOSURE-CRITICAL.md`, `DISCLOSURE-F1.md`) plus the WORSTCASE 1490-line technical version. Re-verification proof in the email body. **24h ack from Alex.**

**Stage 4 (2026-04-25, ~02:00 UTC).** Fortress follow-up sent ~30 hours after ack, while patches were landing. Confirmed 3 patches (F1, W34, W26) with byte-identical evidence; flagged 2 still-live (W16, F3); offered remaining 45 findings in 3 delivery formats. Awaiting response as of skill authoring time.

The Stage 4 timing is critical: too early (before patches land) looks pushy; too late (after engagement attention dissipates) loses the window. The 24-48h window after patch ack is the optimal zone. `RE-VERIFICATION-MONITOR.md` codifies the timing detection.

## The patches and what they tell us

Within 30 hours of Alex's ack, three patches were live in production:

| Finding | Pre-patch state | Post-patch state | Patch type |
|---------|-----------------|------------------|------------|
| F1 | `POST /integrations/methods` returned 422 (body validator runs without auth) | All variants return 404 (`/v1`, `/v2`, `/api`, `/admin/*`, `/backend/*`) | Endpoint refactor |
| W34 | `VITE_APP_MASTER_PASSWORD = "0adfa598..."` in `index-Bu3SA1OT.js` | `index-BVDjb3I4.js` (rebuilt); password absent + constant name removed | Secret rotation + bundle rebuild |
| W26 | Slack webhook at `T04CM84GAV6/B0A2DS3ST8C/...` accepted POSTs | Returns 404 | Webhook revoked |

The patch types tell us:
- F1 was treated as architectural (endpoint refactor, not just adding auth middleware)
- W34 was treated as infrastructure (rotation + rebuild, not just changing the password value)
- W26 was treated as accidental disclosure (revocation, not retrospective audit)

The team's patch quality matches a sophisticated security response. The 30-hour timeline matches a team that prioritized correctly under pressure. **This is what a successful Upshift-class engagement looks like from the sponsor side.**

Two findings remain unpatched at skill-authoring time:
- W16 (SIWE static nonce) -- requires backend auth refactor; possibly scheduled for later batch
- F3 (NAV manipulation) -- requires UUPS contract upgrade; bound by 48h timelock

The fortress follow-up flagged both. Their resolution will inform the engagement closure.

## Memory artifacts referenced by this engagement

- `~/.claude/projects/-home-malix-Desktop-BUGS/memory/project_upshift_finance.md` -- per-engagement state file (template for `MEMORY-PROTOCOL.md`)
- `~/Desktop/BUGS/upshift-recon/` -- workspace tree (template for `WORKSPACE-TEMPLATE.md`)
- `~/Desktop/BUGS/upshift-recon/upshift-newfindings/MASTER-FINDINGS.md` -- 48-finding aggregate
- `~/Desktop/BUGS/upshift-recon/upshift-newfindings/PIPELINE-EXPANSION-FINDINGS.md` -- NEW-01-05
- `~/Desktop/BUGS/upshift-recon/reports/EXECUTIVE-WORSTCASE.md` -- 1-page exec summary template
- `~/Desktop/BUGS/upshift-recon/reports/ALEX-EMAIL-DISCLOSURE.md` -- Stage 3 email template (kabayanerve voice)
- `~/Desktop/BUGS/upshift-recon/reports/ALEX-FOLLOWUP-FORTRESS.md` -- Stage 4 fortress follow-up template
- `~/Desktop/BUGS/upshift-recon/evidence/web/findings/UPSHIFT-W*.md` -- 42 individual finding files (W1-W40 with W16/W17 having 2 versions)
- `~/Desktop/BUGS/upshift-recon/evidence/FINDING-F1-NAV-BYPASS.md` -- F3 NAV finding (the on-chain Critical)

These are the source material. `SURFACE-ATTACK-PATTERNS.md` extracts the executable kits from them. `DISCLOSURE-PROTOCOL.md` extracts the email voice from them. `IMMORTAL-MODE.md` extracts the discipline from the 4-pass timeline. Reading the source material directly is faster than re-deriving the methodology.

## What this engagement is worth

Realistic ex-gratia range for an Upshift-class engagement of this severity, engaged this thoroughly, with the fortress framing accepted: **$50K-$250K**. The number depends on:
- Whether the sponsor accepts the fortress framing (fortress accepted = top of range)
- TVL at risk × time-window-of-exposure (Upshift: $308M × 51 days = strong)
- Patch speed as implicit severity confirmation (30h = very strong)
- Whether the engagement converts to a per-theme architectural-call series (high) or a one-shot bundle delivery (medium)
- Whether the relationship continues for re-audit on the v2 architecture post-patch (highest)

This range is for the entire engagement, not per finding. If the sponsor wants to pay per-finding (rare), the math is different and usually worse for the hunter.

The engagement is not closed at skill-authoring time. The actual ex-gratia outcome lands in `~/.claude/projects/-home-malix-Desktop-BUGS/memory/project_upshift_finance.md` when it does.

## How to read this file

Read this file once, end-to-end, before your first `/upshift` engagement. Re-read sections when:
- You're about to send a Stage N email -- re-read "What worked" and "What almost killed the engagement"
- You're at Pass 2 of the hunt and considering stopping -- re-read "The 4-pass methodology"
- You're about to send the fortress follow-up -- re-read "Stage 4" + "What this engagement is worth"
- A future session has lost context and needs to know what `/upshift` actually means in practice -- read the entire file

This file is the source of truth for what the methodology produces when it works. Every other file in this skill is a generalization of what's documented here.
