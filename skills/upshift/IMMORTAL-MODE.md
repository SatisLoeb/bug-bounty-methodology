# Immortal Mode -- The Anti-Stop Discipline

This file is the most important file in the `/upshift` skill. It encodes the discipline that produces 48-finding engagements instead of 12-finding engagements. Every other companion file teaches a technique; this file teaches a refusal.

The user's explicit requirement: **"ne jamais abandonner comme on a fait sur upshift et toujours aller en profondeur sans prendre en compte le budget de tokens ou de temps"**. Translation: never quit like we did on Upshift, always go deep, ignore token budget and time budget.

The Upshift engagement produced 48 findings. A standard hunt with the same target would have produced 8-12. The 36-finding delta is not technique, not tooling, not domain expertise. It is the refusal to stop at the first Critical, the second Critical, the third Critical. Every stop point on a normal hunt was overridden, and what looked like diminishing returns turned out to be the exact moment when the architectural patterns started to surface.

Read this file before every Phase 3 hunt session. Re-read the relevant guard at every "should I stop?" moment.

## The five anti-stop guards

### Guard 1 -- The 8h timebox is forbidden on Upshift-class targets

CLAUDE.md prescribes an 8h time-box per contest: if no finding after 8h of scanning, MOVE ON. This rule is correct for bounty-platform contests with high target turnover. **It does not apply to Upshift-class engagements.** Upshift-class targets have $50M+ TVL and the engagement has direct-disclosure economics ($50K-$250K ex-gratia range). The cost of one extra day of hunting is rounding error compared to the value of one extra Critical found.

The Upshift hunt itself ran ~30 hours over 3 days. The 4-pass methodology (`HUNT-METHODOLOGY.md`) takes a minimum of 3 passes before a stop is even legal. If you hit 8 hours and want to stop, you are at end of Pass 1 or middle of Pass 2. **The expansion patterns (NEW-01-05 in Upshift terminology) and the chain construction (F1+W34 = the killshot) live in Pass 3 and Pass 4. They are unreachable in 8 hours.**

When this guard fires:
- You catch yourself thinking "I've been on this target for X hours, time to wrap up"
- You catch yourself reading the previous passes' findings to "consolidate" rather than digging into new vectors
- You catch yourself drafting the report before the hunt is finished

What to do instead:
- Recognize the thought as the guard firing
- Open `HUNT-METHODOLOGY.md` and check which pass you're actually in
- If you're at Pass 1 or 2, keep going
- If you're at Pass 3 or 4 but haven't completed all the items in the pass, keep going
- If you've completed Pass 4 and the stop signals (Guard 4 below) all fire green, then you can stop -- but not before

### Guard 2 -- Token budget self-throttling is forbidden

Long sessions accumulate tokens. The instinct to "save tokens for later" is real and wrong on Upshift-class targets. The token economics:
- A full Upshift-class engagement: ~500K-2M tokens spread across hunt + report + disclosure
- A single Critical missed because of token-conservation: $50K+ ex-gratia delta
- Dollar-per-token math: stopping early costs orders of magnitude more than the tokens saved

When this guard fires:
- You catch yourself summarizing instead of analyzing ("let me just compress what I know so far")
- You catch yourself avoiding tool calls because "this is taking many turns"
- You catch yourself saying "I'll just provide an outline" instead of actually doing the work
- You catch yourself proposing to "wrap up" or "consolidate" before the methodology is complete

What to do instead:
- Recognize the thought
- Continue the methodology as if the token budget were unlimited
- If a sub-task is genuinely large (10K+ lines to read), use a subagent rather than reading directly -- but that's an efficiency choice, not a stop choice
- Trust that the user knows the engagement requires depth and has chosen to fund it

### Guard 3 -- Minimum 3 expansion passes before "no more findings"

The structural rule: **declaring "I found everything I'm going to find" is illegal before completing 3 expansion passes.** The passes:

1. **Primary scan (Pass 1):** the 10 vectors of `SURFACE-ATTACK-PATTERNS.md`. This is where the "obvious" findings live. Outcome on Upshift: ~25 findings.

2. **Expansion (Pass 2):** the NEW-01-05 class. Re-scan with focus on architectural patterns missed in Pass 1: proxy governance chain, RPC keys across providers, multi-RPC endpoint exposure, operator wallet audit on-chain, naming deception. Outcome on Upshift: 5 NEW-01-05 + amplified versions of W1-W25.

3. **Mirror invariant audit (Pass 3):** for every bidirectional pair in the protocol, enumerate validation sets V_in vs V_out. Asymmetry without articulable design reason = finding candidate. Outcome on Upshift: revealed F1's structural nature (GET vs POST asymmetry on `/integrations/methods`) and W16 (SIWE 1-of-8 fields).

4. **Chain construction (Pass 4):** combine 2+ findings into amplified attack chain. Outcome on Upshift: F1+W34 = $308M chain.

Pass 4 is technically not a "finding" pass -- it's an aggregation pass. But the chains it produces are the headline findings, so it counts.

**You may not declare the hunt complete after only Pass 1 and Pass 2.** Pass 3 (mirror invariant) catches things the surface scan misses by definition. Pass 4 (chain construction) creates new severity tiers from existing findings.

When this guard fires:
- You catch yourself thinking "I have N findings, that's plenty"
- You catch yourself drafting the disclosure email before Pass 3 is done
- You catch yourself opening the disclosure protocol before completing Pass 4

What to do instead:
- Open `HUNT-METHODOLOGY.md` and find your current pass
- If <3, continue
- If = 3 but Pass 3 items remain (mirror pairs not enumerated), continue
- If = 4 but no chains have been attempted, attempt chains (most engagements have at least one F1+W34-style chain)

### Guard 4 -- "Code is solid" requires concrete signals, not intuition

The most dangerous thought during a hunt: "this protocol seems well-architected, I've found what's there." This thought has been wrong every time it appeared during Upshift. It's almost always "I haven't dug deep enough yet" disguised as judgment.

The discipline: **"code is solid" is a measurement, not an opinion.** It requires three concrete signals all reading green:

1. **Forge lint signal.** If smart contracts are in scope, run `forge build --skip test 2>&1 | grep -B 2 -A 6 unsafe-typecast`. If there are zero `warning[unsafe-typecast]` hits on hot paths (whitelist checks, arithmetic on bounds-sensitive values, decimal conversions), this signal is green. If any hot path has an unsafe cast, the protocol is not solid -- the cast IS a finding (the MTX-003 class).

2. **Internal consistency signal.** Count the protected primitives vs the unprotected siblings. Examples:
   - Auth middleware: how many GET routes have it? How many POST routes have it? Asymmetry = unsafe.
   - Pause modifier: how many state-mutating functions on a contract have `whenNotPaused`? If one state-mutator lacks it, asymmetry = unsafe (the MTX-002 class).
   - SafeCast wrapping: how many narrowing casts use SafeCast? If one narrows without SafeCast, asymmetry = unsafe (the MTX-003 class).
   
   This signal is green only when 100% of protected primitives have protected siblings, with explicit articulable reason for any asymmetry.

3. **Mirror invariant coverage signal.** For every bidirectional pair (GET/POST, deposit/withdraw, mint/burn, lock/unlock, encode/decode, ingress/egress), the V_in / V_out validation sets must be enumerated. This signal is green only when every pair has either symmetric validation OR an explicit articulable design reason for the asymmetry. CLAUDE.md rule #41 codifies this for SC; the same discipline applies to API surface, staging vs prod, validator coverage, etc.

If any of the three signals is not green, the protocol is not solid. Keep digging.

If all three signals are green AND you've completed Pass 4 of `HUNT-METHODOLOGY.md`, then "code is solid" is a measured fact and you can stop. Until then, your judgment is unreliable -- it's pattern-matching against a small sample of "looks like other solid protocols I've seen", and the small sample is biased toward what was visible at the surface scan.

When this guard fires:
- You catch yourself saying "this team knows what they're doing"
- You catch yourself saying "the contracts look well-structured"
- You catch yourself saying "the API is clean"
- You catch yourself comparing favorably to a well-architected target you remember (e.g., Monetrix)

What to do instead:
- Stop. Open this file. Read this guard.
- Run the three measurements explicitly. Document the results.
- If even one is not green, name what it would take to make it green. That's your next task.

### Guard 5 -- Theoretical-bug-kill rule applies at submission, not at hunt

The `feedback_theoretical_bug_kill_2026_04_24.md` rule (memory) says: kill findings without concrete impact even when mechanically correct. **This rule applies ONLY at the submission gate (Phase 5 of the skill), NEVER at hunt time (Phase 3).**

Why the distinction matters: theoretical bugs that don't ship as standalone findings still inform the architectural narrative for the fortress follow-up (Phase 8). The Upshift fortress email used "the F1 incident desync is a class of bug, not a one-off; the next one will not be the same endpoint but it will be the same shape" -- that framing was only possible because we had catalogued multiple instances of the desync class during hunt, even though only F1 shipped as a Critical standalone finding.

Equivalent in normal hunts: a theoretical bug discovered during Pass 1 may, by Pass 4, become the second link in a chain that elevates a Medium to a Critical. Killing it at Pass 1 forecloses that possibility.

When this guard fires:
- You catch yourself dismissing a finding because "the impact is too small to ship"
- You catch yourself skipping a vector because "the dollar value would be negligible"
- You catch yourself filtering findings during hunt rather than during submit

What to do instead:
- Document the finding fully, including its impact analysis
- Tag it `theoretical-keep-for-narrative` rather than killing it
- Revisit at Phase 5 (per-finding submit decision) and Phase 8 (fortress narrative)
- If by Phase 5 it still has no concrete impact, kill it then -- but it lives until then

## The "I should stop" decision tree

Every time the thought "I should stop" appears, run this decision tree:

```
[Thought: I should stop]
   │
   ├─→ Have I completed Pass 1 (all 10 vectors)?
   │     NO  → continue Pass 1
   │     YES → next check
   │
   ├─→ Have I completed Pass 2 (architectural expansion)?
   │     NO  → continue Pass 2
   │     YES → next check
   │
   ├─→ Have I completed Pass 3 (mirror invariant audit)?
   │     NO  → continue Pass 3
   │     YES → next check
   │
   ├─→ Have I attempted Pass 4 (chain construction)?
   │     NO  → attempt Pass 4
   │     YES → next check
   │
   ├─→ Are all three Guard 4 signals green (forge lint, internal consistency, mirror coverage)?
   │     NO  → continue digging into the not-green signal
   │     YES → next check
   │
   └─→ Have I converted theoretical findings into either standalone shipments or narrative ammo?
         NO  → triage them now (Guard 5)
         YES → STOP IS LEGAL. Proceed to Phase 4 (verify findings live).
```

If any node in the tree returns NO, you cannot legally stop. The thought "I should stop" is the guard firing, not a real signal.

## What "going deep" actually feels like

The skill is asking for behavior that doesn't feel productive moment-to-moment. Concretely:

- After 6 hours: you have ~15 findings, you've been re-reading the same code, you feel diminishing returns. **This is exactly when Pass 2 starts producing.** The expansion vectors don't show up in the bundle grep -- they show up when you re-read with different lens (proxy chain, operator wallet, RPC keys).

- After 12 hours: you have ~25 findings, you've covered the obvious vectors. You feel like a normal engagement is done. **This is exactly when Pass 3 mirror invariant produces the structural Criticals.** F1 was found during Pass 3 on Upshift, not Pass 1, because Pass 1 caught "POST endpoint without auth" but Pass 3 caught "GET has auth, POST doesn't, and POST triggers operator wallet."

- After 20 hours: you have ~40 findings, you feel exhausted and the marginal value of each finding is decreasing. **This is exactly when Pass 4 chain construction produces the killshot.** F1+W34 was constructed at the end of Pass 4, after both F1 and W34 had been individually catalogued for hours. The chain is what gets the email opened in 24h instead of 14 days.

The diminishing-returns intuition is wrong on Upshift-class targets. The returns aren't diminishing -- they're shifting from "individual findings" to "architectural patterns" to "amplified chains". Each shift requires the previous layer to be exhausted.

## What "stopping too early" cost on prior engagements

The previous Upshift engagement (March 2026 first session) stopped at ~25 findings. The 25 included F1 individually but not F1+W34. The disclosure ran for 47 days without acknowledgement because the email did not have the killshot. The chain came in the second session (re-verification, April 2026) when we re-ran the methodology with more discipline.

The cost of stopping at 25 findings: **47 days of $308M-at-risk exposure, near-disclosure failure, no fortress engagement framing possible.**

The value of going to 48 findings: **24h ack, 30h patches, fortress conversation open, ex-gratia in $50K-$250K range realistic.**

This is the actual ROI of immortal mode, expressed in days of risk and dollars of revenue.

## When immortal mode does NOT apply

This skill is specifically for Upshift-class targets. It does not apply to:

- **Bounty-platform contests with HM-only payout** (e.g., Code4rena Monetrix style). These have a fixed pool, dup risk, and an explicit time-box. Standard 8h rule applies. Submit your strongest findings; do not over-invest.

- **Well-architected protocols** where Guard 4 signals are all measured green within Pass 1. The Monetrix engagement is the example: forge lint silent on hot paths after first vector pass, internal consistency 100%, mirror invariant exhaustive. After 4h the methodology said "this protocol is solid" with concrete signals. Stopping was correct.

- **Targets that don't match the Upshift profile** (per `TARGET-SELECTION.md`). If the target has no backend orchestration, no executor wallet, no off-chain → on-chain trigger pattern, the 10 vectors of `SURFACE-ATTACK-PATTERNS.md` will not produce findings. Use a different skill (`/gravedigger`, `/mrrobbot`, `/expand-surface`).

The discipline cuts both ways: refuse to stop too early on Upshift-class, refuse to over-invest on non-Upshift-class. `TARGET-SELECTION.md` is the gate that determines which mode applies.

## Self-test on every "should I stop?" moment

Read this guard out loud (or to yourself) before deciding to stop. If it sounds wrong, you're stopping too early.

> I have completed Pass 1 (all 10 vectors documented or explicitly null-result),
> Pass 2 (architectural expansion attempted, NEW-01-05 candidates evaluated),
> Pass 3 (mirror invariant audit run, every bidirectional pair classified),
> Pass 4 (chain construction attempted, all 2-finding combinations evaluated for amplification).
> Guard 4 signals: forge lint shows zero unsafe casts on hot paths, internal consistency is 100%,
> mirror invariant coverage is exhaustive.
> Theoretical findings are either documented as standalone or tagged as narrative ammo.
> All five guards are clear. Stop is legal. Proceeding to Phase 4 (verify findings live).

If even one of these statements is not true at the moment you read this, you are not allowed to stop. Continue.
