---
name: disclosure-protocol
description: The 4-stage disclosure arc + kabayanerve voice + fortress framing, generalized from upshift to any surface, with a per-surface channel/EV calibration table. Stage 1 initial contact, Stage 2 silent escalation, Stage 3 re-verification, Stage 4 fortress follow-up. The arc is universal; the channel, the EV framing, and the "fortress" reframe are calibrated to whether the surface pays via bounty platform, GHSA/CVE, upstream maintainer, or vendor.
---

# Disclosure protocol -- 4-stage arc, calibrated per surface

The disclosure arc that converted Upshift's 30-hour patch sprint into an open hardening engagement is surface-independent in its *structure* and surface-dependent in its *channel and economics*. This file keeps the structure intact and adds the calibration.

For report structure, invoke `/report-nerve`. For voice on human-triager channels, invoke `/chill`. For channel-specific formatting, invoke `/disclose`, `/immunefi-submit`, or `/security-disclosure`. This file is the *campaign* layer above those.

## Voice rules (kabayanerve -- apply to every stage, every surface)

Carried verbatim from upshift, because they are surface-independent:

1. **First person.** "I have confirmed..." not "It has been confirmed...".
2. **No em-dashes.** U+2014 is the strongest LLM tell of 2026. `sed -i 's/\xe2\x80\x94/--/g'` every email before send. Non-negotiable on human-triager channels.
3. **Epistemic precision.** "I have confirmed" vs "I have not confirmed" vs "I am flagging in case it is not on your radar" vs "I deliberately did not push further because the next step would have written to your systems." Each carries different weight; use the right one.
4. **Anti-pattern naming.** Name what you did NOT do. "No payload was sent that could write." "I held the wider inventory because dumping fifty issues on day one is not how this works."
5. **Evidence inline.** Commands, reads, hashes, observed deltas -- in the body, not "see attached". First scan hits verifiable artifacts within 30 seconds.
6. **No corporate filler.** No "I hope this finds you well", no "please find attached".
7. **No threats.** No "90-day public disclosure" as leverage. The clock is implicit in the posture, stated once in Stage 1, never repeated.
8. **No credit fishing.** The findings are the credentials.
9. **Sign first name only.**

## Per-surface calibration table

| Surface | Primary channel | Stage-2 escalation | EV framing | Fortress reframe |
|---|---|---|---|---|
| Web2 / SaaS | bounty platform (H1/Bugcrowd) or security@ | LinkedIn DM to CTO/Head-of-Security | per-finding bounty + chain bonus; or retainer for continuous read-access | "harden the authz layer + tenant isolation so the next attacker hits a wall, not another hole" |
| Infra / Cloud / Supply-chain | security@ / vendor PSIRT; GHSA for OSS dep | escalate to the cloud-vendor PSIRT or the dependency's org | severity-based bounty; or CVE credit + vendor goodwill | "audit the full IAM/build-supply-chain posture, not just the one leaked secret" |
| Crypto-libs / protocols | upstream maintainer + GHSA (private advisory) | maintainer's security contact; CERT/CC for protocol-wide | often credit + CVE, sometimes a foundation bounty; reputational | "review the cross-binding + edge-input coverage across the whole library, not just this one function" |
| ML / AI systems | vendor security / model-host bounty; MCP-server maintainer | the platform's AI-safety / security team | emerging bounty programs; vendor goodwill; sometimes research credit | "harden the untrusted-content → tool-exec trust boundary across all agents/tools, not just this one injection path" |

**EV gate (from the operating standard):** >$5K STRONG GO · $1K-5K GO · $200-1K WEAK GO (<4h) · <$200 SKIP. For non-monetary channels (GHSA/CVE/credit), the EV is reputational + relationship + the harm prevented; weight accordingly, but do not invent a dollar figure where there is none.

**Money/impact-flow prefilter (apply at Phase 0, not at submission):** every candidate must produce a concrete `loss = $X` OR `harm = <quantified>` line in its PoC, or it dies at triage. State-misrepresentation / signature-hygiene without a direct impact line is a known triage-killer across channels.

## Stage 1 -- Initial contact

**When:** after Pass 4 chain construction + ANTI-INFLATION gate + at least one Critical/High is concrete.

**To (priority order, adapt per surface):** security.txt → SECURITY.md → security@ → bounty platform → maintainer/CTO from public sources.

**Subject:** `[Target] security disclosure -- [highest severity class] [primitive name]`

**Body (kabayanerve, max 3 findings -- the killshot only):**
```
hi [first name],

[1 sentence: who I am if needed, else straight to substance]

i'm sending [N] findings. the headline is: [combined chain impact in one sentence, with a sourced number]. details below.

### finding 1 -- [name] ([severity])
[primitive in 2-3 sentences: the exact entry point / file:line / endpoint]
[inline command + observed result]
[re-verified date + result]

### finding 2 -- [name] ([severity])
[same]

### the chain -- [combined impact headline]
[numbered step-by-step combined attack]
[closing: "only the final step was not executed because doing so would [steal funds / write to your systems / harm users]"]

### a few procedural notes
- no public writeup of any of this.
- not holding a public-disclosure clock; happy to start a coordinated window from the date you engage.
- pgp available if you prefer encrypted attachments.
- happy to get on a call.
- no bounty demand; ex-gratia / credit is your call, not gating disclosure.

best,
[first name]
```

**Pre-send checklist:** em-dash sweep returns nothing · headline re-verified live within 24h · recipient correct · alternate channel offered · ANTI-INFLATION gate passed on every claim.

## Stage 2 -- Silent escalation (no response in 14 days)

14 days, not 7 (CERT/CC soft threshold; you won't look impatient; below 14d, security@ inboxes haven't surfaced it yet).

**Channel:** the surface's Stage-2 row above (usually a direct human -- DM to a decision-maker who can't route it to a junior queue and whose personal account you can't be deleted from).

**Template:**
```
Hi [first name],

I sent a security disclosure to [channel] on [date] -- [N] [severity] findings on [primitive in <15 words]. The combined chain is [headline impact + sourced number].

Flagging here in case it routed to a low-priority queue or did not surface on your radar yet. Happy to re-send, switch to PGP, or jump on a quick call -- whatever works on your end.

Best,
[first name]
```
Does NOT blame, threaten, redact substance, or repeat the channel that went silent.

**Stage 2.5 fallback:** if Stage 2 is silent 7+ more days, the surface's incident-response collective (SEAL-911 for DeFi; CERT/CC for protocols/infra; the platform's safety team for ML) is the next lever before any public step.

## Stage 3 -- Re-verification (day N+30 to N+50)

Re-verify primitives are still live, byte-identical, with TODAY's date stamped. This converts "you ignored my email" into "the threat is still live and I am still here" -- and removes the "we already patched that" out. Send to the NEXT escalation contact, not the original.

**Subject:** `[Target] disclosure re-verification -- [N] days, [M] primitives still live`

Body: 1-sentence context → "i re-verified against today's production; both primitives are live byte-identical, [N] days after the initial report" → per-finding re-verification with today's date → restate the chain headline (this reader hasn't seen Stage 1) → "what's changed since [date]" (bundle rebuilt but secret byte-identical = rebuilt without rotating) → identical procedural posture to Stage 1.

## Stage 4 -- Fortress follow-up (within 24-48h of patch ack)

**Trigger:** the team acks + commits a timeline, OR you observe patches landing (the patch landing IS engagement), OR they respond with substantive triage questions.

**Why 24-48h:** the window is open while the team is in active patch flow. Sending while they iterate converts the patch transaction into a hardening engagement. Wait a week and they've moved on; the next disclosure is a fresh ticket against a closed thread.

**The move:** NOT another finding dump. An offer to convert the patch sprint into sustained hardening. Frame: "you patched what was disclosed; here is what it would take to make the architecture itself resistant to the next attacker."

Structure:
- **What I confirmed is patched** -- per primitive, crisp action verbs, observed-state evidence. Close: "[chain headline] is no longer reachable through the original primitives. Your team moved on it inside [N] hours of ack. I want that on the record." (Non-monetary credit transfer -- engineers value shipping-fast recognition.)
- **What I have not confirmed is patched** -- "flagging [N] items that don't show patch signals yet, in case they're a later batch and not on your radar from the first triage." (Frame: "I trust you have a plan, just confirming these are on it" -- not "you missed these".)
- **The rest of the bundle** -- what was sent (top 3), what was held (the wider inventory), why held ("dumping fifty issues on day one is not how this works"). The surface's fortress-reframe sentence from the calibration table. Three delivery options (full tarball / severity-tiered batches / per-theme architectural calls) -- the team picks the cadence; the path of least resistance is to pick one.
- **Same procedural posture.** No clock, no bounty demand, PGP available.

The ex-gratia / credit conversation is naturally delayed to AFTER they pick a format. Asking for money in the fortress email closes the door; letting the engagement deepen opens it wider.

## State machine (per disclosure thread)

| State | Enter | Action | Exit |
|---|---|---|---|
| awaiting_ack | Stage 1 sent | wait 14d | ack → acked; 14d silence → silent_pending_escalation |
| silent_pending_escalation | 14d no ack | Stage 2 | DM acked → acked; 7d silence → re_verification_due |
| re_verification_due | 30d+ since Stage 1 | Stage 3 | response → acked; silence → escalation_required |
| acked | substantive response | answer / provide format | patches deployed → partially/fully_patched |
| partially_patched | some patched | surface what's still live in normal cadence | all patched → fully_patched |
| fully_patched | all disclosed primitives patched | Stage 4 within 24-48h | team picks format → engagement_active |
| engagement_active | format chosen | deliver, deepen | all delivered → engagement_closed |
| escalation_required | Stage 3 silent 10d+ | incident-collective / gated public mention, last resort | resolved or formally abandoned |

Update the per-engagement memory file on every transition. Before ANY outbound send, re-run the finding's detection kit (state-verify at the submit-block, not the PoC-anchor block -- primitives get patched mid-thread).

## What never to do (carried from upshift)

1. Never publish before meaningful time (90 days minimum; longer if patches are landing).
2. Never demand bounty in the disclosure email. State terms once, move on.
3. Never include all findings in the first email. Top 3 max.
4. Never re-send the same email -- the escalation path is channel-change, not channel-repeat.
5. Never lie about verification state. If not re-verified in N days, say so. If ambiguous, say so.
6. Never use em-dashes. Run the sweep.
7. Never reference a previous contact's silence directly ("you ignored me" → "in case it routed to a low-priority queue").
8. Never threaten public disclosure as leverage.
9. Never combine patch-verification and "you should pay me" in one message.
10. Never sign a fake corporate block. First name only.
11. **Never self-concede severity before the triager's position is known.** Hold evidence for reactive deployment. Downgrade is the triager's job. Never post severity-amplifier comments unprompted.
12. **Never mention an AI triager in an appeal.** Substance appeal triggers human re-review; an AI-pique braques the human supervisor.
