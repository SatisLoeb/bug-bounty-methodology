---
name: immortal-mode
description: The anti-stop discipline, generalized from upshift to any surface. 5 guards that override the "I have enough" / "this is taking too long" / "the code is solid" instincts. The key move "solid = measured, not felt" requires three green signals; in upshift2 those signals are parameterized per surface. Read before every Phase 3 hunt session; re-read the relevant guard at every "should I stop?" moment.
---

# Immortal mode -- the anti-stop discipline (universal)

This is the most important file in upshift2, exactly as it was in upshift. Every other file teaches a technique; this one teaches a *refusal*.

The operator's standing requirement, carried from upshift: **never quit like we did on the first Upshift session, always go deep, ignore token budget and time budget.** The 48-finding engagement vs the 12-finding engagement is not technique, tooling, or domain expertise. It is the refusal to stop at the first Critical, the second, the third -- every stop point overridden, and what looked like diminishing returns turned out to be the exact moment the seam's architectural patterns surfaced.

Read this before every Phase 3 session. Re-read the relevant guard at every "should I stop?" moment.

## The five anti-stop guards

### Guard 1 -- The 8h timebox is forbidden on seam-engagement targets

CLAUDE.md prescribes an 8h timebox per *contest*: no finding after 8h → move on. Correct for bounty-platform contests with high turnover. **It does not apply to upshift2 seam engagements** -- high-value targets with direct-disclosure or sustained-engagement economics. One extra day of hunting is rounding error against one extra Critical.

The 4-pass methodology requires a minimum of 3 passes before a stop is even *legal*. If you hit 8h and want to stop, you are at end of Pass 1 or middle of Pass 2 -- the expansion patterns (Pass 2) and the mirror-invariant Criticals (Pass 3) and the headline chain (Pass 4) are all still ahead of you, unreachable in 8 hours.

Fires when: "I've been on this X hours, time to wrap up" / re-reading prior findings to "consolidate" instead of digging new vectors / drafting the report before the hunt is done.

Do instead: recognize it as the guard firing; open HUNT-METHODOLOGY.md; check which pass you're actually in; if <Pass 4 or any pass incomplete, continue.

### Guard 2 -- Token-budget self-throttling is forbidden

The instinct to "save tokens" is real and wrong on a high-value target. The math: a full seam engagement is large; a single Critical missed because of token-conservation dwarfs the tokens saved by orders of magnitude.

Fires when: summarizing instead of analyzing / avoiding tool calls because "this is many turns" / "I'll just provide an outline" / proposing to "wrap up" before the methodology is complete.

Do instead: continue as if the budget were unlimited. If a sub-task is genuinely huge (10K+ lines to read), use a subagent -- but that is an *efficiency* choice, not a stop choice.

### Guard 3 -- Minimum 3 expansion passes before "no more findings"

Declaring "I found everything" is **illegal** before completing 3 passes (primary, expansion, mirror) and attempting the 4th (chain). Pass 3 catches what the surface scan misses *by definition* -- it audits absences, not presences. Pass 4 creates new severity tiers from existing findings.

Fires when: "I have N findings, that's plenty" / drafting the disclosure before Pass 3 / opening the disclosure protocol before attempting Pass 4.

Do instead: open HUNT-METHODOLOGY.md, find your pass, continue if <3 complete or Pass 4 unattempted.

### Guard 4 -- "Solid" requires measured signals, not intuition

The most dangerous thought: "this system seems well-built, I've found what's there." This thought has been wrong every time it appeared during upshift. It is almost always "I haven't dug deep enough yet" disguised as judgment.

The discipline: **"solid" is a measurement, not an opinion.** Three concrete signals, all green:

1. **The surface's own linter/checker is silent on the hot path.** Parameterized per surface:
   - Web2/SaaS: the authz layer covers every state-mutating route (the auth-coverage matrix has no holes); CodeQL/Semgrep clean on the injection/authz queries
   - Infra: `checkov`/`tfsec`/`prowler` clean on the privilege-escalation and public-exposure rules; no IAM wildcard on a sensitive action
   - Crypto-libs: differential fuzz vs a reference impl finds zero divergence on edge inputs; the constant-time checker (`dudect`/`ctgrind`) is clean on secret-dependent paths
   - ML: the prompt-injection probe suite finds zero tool-call escalation from untrusted content; output flows to no unescaped sink
2. **Internal consistency = 100%.** Count protected primitives vs unprotected siblings. Every protected primitive has a protected sibling, with an explicit articulable reason for any asymmetry. This is the mirror-invariant coverage expressed as a ratio. Green only at 100%.
3. **Seam coverage is exhaustive.** Every boundary in `recon/SEAM-CANDIDATES.md` has either a written `V_in vs V_out` symmetric result OR an explicit articulable design reason for the asymmetry. An unswept seam = not solid.

If any signal is not green, the system is not solid -- keep digging into the not-green signal. If all three are green AND Pass 4 is complete, "solid" is a measured fact and you may stop.

Fires when: "this team knows what they're doing" / "the architecture looks clean" / "the API is well-built" / comparing favorably to a well-architected target you remember.

Do instead: stop, open this guard, run the three measurements explicitly, document the results. If even one is not green, name what it would take to make it green -- that's your next task.

### Guard 5 -- theoretical-bug-kill applies at submission, not at hunt

The theoretical-bug-kill rule (kill findings without concrete impact even when mechanically correct) applies ONLY at the submission gate (Phase 4b/5), NEVER at hunt time (Phase 3).

Why: a theoretical bug found in Pass 1 may, by Pass 4, become the second link in a chain that elevates a Medium to a Critical (the upshift W19×F3 shape -- W19 alone is a Medium info-leak, chained it is the targeting layer for the F3 drain). Killing it at hunt time forecloses that. Theoretical bugs also feed the fortress narrative ("this is a *class* of bug, not a one-off; the next one will be the same shape, different location").

Fires when: dismissing a finding because "the impact is too small to ship" / skipping a vector because "the value would be negligible" / filtering findings during hunt instead of during submit.

Do instead: document fully, tag `theoretical-keep-for-narrative`, revisit at Phase 5 and Phase 8. If still no concrete impact at Phase 5, kill it *then*.

## The "I should stop" decision tree

Every time "I should stop" appears, run this:

```
[Thought: I should stop]
   ├─→ Pass 1 complete (all vectors)?           NO → continue Pass 1
   ├─→ Pass 2 complete (expansion)?             NO → continue Pass 2
   ├─→ Pass 3 complete (mirror invariant)?      NO → continue Pass 3
   ├─→ Pass 4 attempted (chain construction)?   NO → attempt Pass 4
   ├─→ All three Guard-4 signals green?         NO → dig the not-green signal
   └─→ Theoretical findings triaged to standalone/chain/narrative?
                                                NO → triage them now (Guard 5)
                                                YES → STOP IS LEGAL → Phase 4 (verify live)
```

If any node returns NO, you cannot legally stop. "I should stop" is the guard firing, not a real signal.

## What "going deep" actually feels like

The behavior doesn't feel productive moment-to-moment:

- After 6h: ~15 findings, re-reading the same code, diminishing returns. **This is exactly when Pass 2 starts producing** -- the authority-chain / secret / shadow-surface findings don't show in the primary grep; they show when you re-read with a different lens.
- After 12h: ~25 findings, obvious vectors covered, feels done. **This is exactly when Pass 3 mirror-invariant produces the structural Criticals** -- F1 was found in Pass 3, not Pass 1, because Pass 1 caught "unauth POST" but Pass 3 caught "GET authed, POST not, and POST triggers the privileged action".
- After 20h: ~40 findings, exhausted, marginal value seems to drop. **This is exactly when Pass 4 produces the killshot** -- F1+W34 was constructed at the end, after both had been catalogued for hours.

The diminishing-returns intuition is wrong on seam targets. The returns aren't diminishing -- they're *shifting* from individual findings → architectural patterns → amplified chains. Each shift requires the previous layer exhausted.

## What stopping early costs

The first Upshift session stopped at ~25 findings, including F1 individually but NOT F1+W34. The disclosure ran 47 days without ack because the email had no killshot. The chain came in the second session. Cost of stopping early: 47 days of $308M-at-risk exposure, near disclosure-failure, no fortress framing possible. Value of going to 48: 24h ack, 30h patches, fortress conversation open. That is the ROI of immortal mode, in days of risk and dollars of revenue.

## When immortal mode does NOT apply

- Bounty-platform contests with HM-only payout and high turnover → standard 8h timebox.
- Genuinely well-built targets where Guard-4 signals are all *measured* green within Pass 1 -- and the seam thesis returned a no-seam verdict (every boundary has a named review covering its handoff). The Monetrix case: signals green with concrete measurement after 4h, stopping was correct.
- Targets with no seam (route away from upshift2).

The discipline cuts both ways: refuse to stop too early on a seam target, refuse to over-invest on a no-seam target. SEAM-THESIS.md + Guard 4 are the gates that decide which.

## Self-test before any stop

Read this aloud before deciding to stop. If it sounds wrong, you're stopping too early.

> I have completed Pass 1 (all vectors documented or null-result), Pass 2 (expansion sub-passes 2A-2E), Pass 3 (mirror invariant, every bidirectional pair classified with a written V_in vs V_out line), Pass 4 (chain construction attempted, all 2-finding combinations evaluated). Guard-4 signals: the surface linter is silent on the hot path, internal consistency is 100%, seam coverage is exhaustive. Theoretical findings are triaged. All five guards clear. Stop is legal.

If even one statement is not true at the moment you read this, you are not allowed to stop. Continue.
