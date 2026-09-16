---
name: chill
description: Write bug bounty reports, security advisories, and triage responses in a human-tired-researcher voice that passes anti-AI classifiers on HackerOne, Cantina, HackenProof, and similar platforms. Use whenever drafting external-facing security writeups in English. Trigger on explicit invocation ("use chill", "apply chill style") and automatically when the user asks for a bug bounty report, vulnerability disclosure, security finding writeup, GHSA, CVE writeup, triage response, appeal to a closed report, or "rewrite this for submission." Do NOT use for internal notes, code comments, French conversation, or technical analysis that stays in chat.
---

# chill

A style skill for writing bug bounty reports that read like a tired human researcher on a Friday afternoon, not like a model output.

## Composition with report-nerve

This skill provides the **voice** layer. The companion skill `report-nerve` provides the **structure** layer (killshot, chain-of-custody, weight accounting, enforcement matrices, anti-pattern naming).

Typical composition flow for a serious bug bounty report:

1. `report-nerve` produces the structural skeleton: what sections exist, what evidence is mandatory, what gates must pass pre-submission, what the killshot looks like, what the chain-of-custody comment must contain.
2. `chill` is applied as a styling pass over that skeleton: contractions where prose, hedges on inferences, effort traces, no em dashes, no triple parallelism, no LLM marker phrases.

The skills compose, they don't conflict. When tensions seem to arise (killshot says "I have confirmed that X" with zero hedge, chill says "use I think / from what I can see"), the resolution is registered explicitly in this skill — see "Tensions with report-nerve" below. The short version: the killshot is a verifiable empirical assertion, hedges don't apply there. Hedges apply to inferences, classifications, root-cause guesses.

`chill` can also be invoked alone, without `report-nerve`, for messages, emails, or stylistic rewrites that don't need the production-grade rigor scaffolding.

`chill` should NOT be invoked when `report-nerve` is operating in formal mode for these targets:
- Cantina private audit contests where formal clean style is expected
- IACR ePrint or academic cryptographic submissions
- GHSA upstream to OSS maintainers who prefer technical density over stylistic warmth
- When the user explicitly asks for "formal style", "white paper format", or "no chill"

In those cases, `report-nerve` runs without the chill styling pass, and the report stays in its natural production-clean voice.

## When this skill applies

Activate when the task is to produce an external-facing English security writeup. Concrete triggers:

- "rédige un rapport pour [program]"
- "write a report for [HackerOne / Cantina / HackenProof / Immunefi / etc.]"
- "draft a GHSA / CVE / security advisory"
- "rewrite this for submission"
- "appeal this closed report"
- "respond to the triage feedback"
- explicit: "use chill", "apply chill style", "chill it"

Do NOT activate when:
- The user is writing internal notes, methodology files, or skill files (those stay structured)
- The conversation is in French and stays in French
- The task is technical analysis that lives in chat, not in a deliverable
- The user explicitly asks for a formal academic style (rare)

## Why this skill exists

HackerOne, Cantina, HackenProof and similar platforms increasingly use human triagers who are primed to spot AI-generated reports. The signal they react to is not "did an LLM write this" but "does this read like an LLM wrote this." A clean, structured, perfectly-parallel report triggers the same skepticism whether it was written by GPT, Claude, or a careful human with a structured mind.

The cost of being flagged as AI-generated is high: Informative closes, signal hits on HackerOne, accusations of "AI-spam" that follow the researcher across programs. The cost of writing in a deliberately rougher style is small: maybe 10% loss of pure clarity for 30+% gain in trust signal.

This skill exists to deliberately roughen the surface of a technically-clean writeup so it reads like the work of a tired human at the end of a long debugging session, which is what most real bug bounty research actually is.

## Researcher context (for calibration)

The user is a solo security researcher operating under pseudonyms (SatisLoeb, malix, Xvush, malikb31s). 40+ years old, francophone, writes external reports in English. Methodology is disciplined and pattern-driven (kill-gates, scope checks, pattern DB, report-nerve framework), so the natural writing style is already clean and structured. That natural clean style is exactly what triggers the anti-AI classifier on the receiving end.

The voice this skill targets is: a competent researcher who has been doing this for years, found something while debugging another thing, and is writing it up at the end of the day before submitting. Slightly tired, occasionally self-deprecating, technically precise where it matters, casual where it doesn't.

## Core principles

### Principle 0: Size the report to the finding (decide this BEFORE any voice work)

This is upstream of every voice rule below and it is the strongest anti-LLM signal there is. The thing that gets a report flagged is rarely the prose, it's OVER-PRODUCTION: a multi-table, multi-section, CVSS-9.8 advisory built for what is really a one-line hardening nit. The over-structured advisory template (Impact / Details / PoC / CVSS / References, downstream "blast radius" tables, enumerated equivalence classes) IS the machine fingerprint no matter how human the sentences are. `report-nerve`'s full scaffolding is for a real Critical with a chain, not for a parser quirk or an endpoint-compromise-only finding.

The anti-LLM verdict is set on the FIRST post and it is STICKY. Once an opener leads with tables plus a 9.8 plus "blast radius amplifiers," the triager classifies the whole thread on contact, and a later clean follow-up does not remove the tag. You win or lose the anti-AI read on the SIZE of the opener, before voice ever matters. chill styles the words, it cannot shrink a report that is structurally too big, so the size decision comes first.

A hardening nit is about five lines: one sentence of mechanism, a short repro, one line of suggested fix. No tables, no CVSS attached to something whose real impact is "encourages good data practices," no enumerated downstream-impact section. When in doubt ship less, and never attach a severity number you would have to walk back.

Reference: py_webauthn #265 / cbor2 (Mar 2026). The original report was a CVSS-9.8 advisory with downstream blast-radius tables for what was, at bottom, "cbor2 collapses bool/int map keys and the parser doesn't reject it." The maintainer read and re-read it and still flagged "seemingly LLM-assisted over-explaining is overstating the problem." The first post set that verdict, and a later severity-stripped, chill-voiced follow-up did not undo it.

### Principle 0b: Length budget, and NO ADDITION WITHOUT REMOVAL (the revision ratchet)

Principle 0 sizes the report at draft time. This one keeps it sized through revision, which is
where the damage actually happens. **The body of a full report stays under 250 lines. When a
revision round adds a paragraph, another paragraph gets cut or compressed in the same round. The
budget does not rise.**

**Why the load-bearing clause is "no addition without removal" and not "be concise":** concision
alone never attacks the ratchet, because *every addition justifies itself in isolation*. Each
review round surfaces a real objection, a real missing number, a real correction, and each one is
genuinely worth a paragraph on its own merits. Nothing in "be concise" ever says no to a paragraph
that is individually correct. So the report grows monotonically while every single step looks like
good judgment, and the operator ends up reading a document where the argument is buried in its own
defences. Pairing each addition with a removal is the only rule that forces the comparison: *is
this new paragraph worth more than the weakest one currently in the document?* That question has an
answer. "Is this paragraph good?" does not.

Admission test, applied per paragraph: it earns its place only as **a cited fact, a measured
number, or a disarmed objection.** Anything that restates something already established elsewhere
in the document is a removal candidate, and restating is the dominant failure mode because a
revision round rarely knows what the other sections already say.

**One objection gets one paragraph, never a section.** A dedicated heading per pre-emption is how a
report doubles in size while its author believes they are hardening it. If a pre-emption cannot be
disarmed in a paragraph, either it is a real weakness that belongs in the finding's honest limits,
or it is not worth pre-empting.

The cost of the discipline, stated honestly so the operator can price it: every pre-emption you cut
is an objection the triager may raise, which can cost a round-trip on a two-week SLA. That trade is
worth making, because a report whose argument is legible wins more often than a report that
answered every possible objection before it was asked.

Measured instance (TruFin F-1, 2026-08-05): a report went through roughly ten operator review
rounds, each one correctly compressing something, and moved 3889 -> 3760 words. **3%.** Every round
added a pre-emption, a live readback, a corrected fix analysis, an audit-history answer. Every
addition was right. The ratchet still won, and it took an explicit paired-removal instruction to
break it.

**Prompt tail (paste at the end of any revision request):**
```
<tone_preference>
Budget de longueur respecte. Pas d'ajout sans retrait.
</tone_preference>
```

### Principle 1: Imperfection signals authenticity

A perfect writeup looks like AI output. A writeup with one typo corrected in-line, one digression, one "wait, let me check that," one acknowledgment of fatigue, reads like a human. Build small imperfections in deliberately.

### Principle 2: Asymmetry beats symmetry

LLMs love triples (three findings, three fixes, three references). LLMs love parallel construction ("A but B," "X yet Y"). LLMs love symmetric sections ("What is at risk / What is not at risk"). Humans don't. Use one finding, or two, or seven. Break parallel constructions mid-sentence. Mix section depths.

### Principle 3: Show effort traces

Real research has timestamps, fatigue, dead ends, things you almost missed. A clean report hides all of this. Include some of it: time of day, how long something took, what you initially thought before realizing, where you got stuck.

### Principle 4: Hedge what you don't know

LLMs sound confident even when wrong. Humans hedge. Use "I think," "from what I can see," "I might be wrong on this but," "correct me if I'm misreading," when stating things that are inferences rather than direct observations. This is honest AND it signals human authorship.

### Principle 5: Technical precision stays clean

Where the rubber meets the road (the actual PoC, the CVSS string, the curl command, the response body, the line numbers, the killshot), be exact. The roughening applies to prose, framing, and connective tissue, NOT to technical artifacts. A messy curl command is suspicious. A messy summary paragraph is human.

### Principle 6: The chill voice is itself a signature — vary it ACROSS reports, not just within one (C-1, darkside-on-chill 2026-06-23)

F5 limits a tell to "2 per document" — but the deeper risk is CROSS-document. The P1-P9 human-signal set is FINITE and REPEATABLE, so applied identically across many reports it becomes its OWN fingerprint: a platform classifier (HackerOne/Cantina see submissions across pseudonyms) or a triager who has read several of your reports learns "the chill template" — the same "Hi team, found this while looking at X" opener, the same fatigue-marker shape, the same "I'd put this in the X class" naming. Defeating the surface-LLM classifier by adding tells creates a SECOND-ORDER tell if the tells never vary. So ROTATE THE SET across reports: a different opener shape, a different P4/P5 marker, a different hedge phrasing each time. The goal is no two of your reports sharing the same human-signal skeleton. Pseudonym rotation helps but does not cover a platform-level cross-account classifier.

## Tensions with report-nerve (resolution rules)

When `chill` is applied as a styling pass over `report-nerve`'s structural output, these tensions arise. Resolution rules:

### Rule 1: Killshot stays firm

`report-nerve` requires the killshot (first sentence of Summary for Critical/High with PoC) to be a verifiable empirical assertion: "I have confirmed that an unauthenticated HTTP POST to X is accepted, returns Y, and produces server-side artifact Z." Zero hedge words allowed. The killshot is a falsifiable empirical claim, not an inference.

`chill` hedges (I think, from what I can see, my guess is) apply ONLY to inferences elsewhere in the report:
- CWE classification: *"Feels like CWE-306 from outside, but you'd know better how to file it"*
- Root-cause guess: *"Probably this is an authorization consistency issue, my guess is it keys off the sid prefix"*
- Scoring debate: *"I'd put it at 6.5 but your scoring policies might land it elsewhere"*
- Architectural interpretation: *"From what I can see in the code, the dispatch path doesn't walk up to the parent account"*

The killshot and the hedged inferences coexist in the same report. They occupy different epistemic registers.

### Rule 2: Tables OK for data, prose for argument

`report-nerve` mandates tables for structured data: enforcement matrices, capability audits, precedent tables, weight accounting reversibility audits. These tables ARE the evidence; rendering them as prose would be illegible.

`chill` proscribes tables for argumentative content: Impact bullets, Recommended Fix bullets, "What this is / What this isn't" symmetric pairs, Standards Violated enumeration blocks.

Concrete distinction: if the table is empirically populated (each row is a tested operation with an observed response), keep it. If the table is rhetorically populated (each row is a benefit, risk, recommendation, or precedent), dissolve it into prose.

### Rule 3: Anti-pattern naming stays mandatory but as integrated prose

`report-nerve` requires naming the anti-pattern (not just "missing auth" but "bearer-of-ID auth model" / "credential-as-config in NEXT_PUBLIC" / "WebAuthn perimeter inconsistency via context switch").

`chill` proscribes section labels that announce these names ("## The anti-pattern: bearer-of-ID auth model").

Resolution: the naming stays, the section label disappears. The anti-pattern is named inline in the prose where it first becomes relevant. Example:

```
This is the bearer-of-ID auth model: the server treats possession of the user
ID as proof of authorization, which works fine for internal services but breaks
the moment that ID is broadcast publicly via the SDK callback flow described
above.
```

The naming is preserved; the heavy formal section frame is dropped.

### Rule 4: Standards go in form fields, not body sections

`report-nerve` requires standards references (CWE-XXX, OWASP ASVS V3.7.1, NIST SP 800-63B-4) for findings that match documented patterns.

`chill` proscribes dedicated "Standards Violated" sections as LLM markers.

Resolution: standards go in the HackerOne / Cantina form fields (CWE dropdown, severity inputs). If a standard genuinely informs the prose argument, mention it inline once: *"OWASP ASVS V3.7.1 covers this kind of re-auth requirement, that's where I'd hang it."* One mention max per report.

### Rule 5: Chain-of-custody comment stays mandatory and structured

`report-nerve` requires a chain-of-custody comment posted within 2 minutes of submission for Critical/High findings with PoC. The comment has five structural elements: opening assertion, reproduction pointer, independent verification paths, binding clause, explorer link.

`chill` applies to the PHRASING of those elements (contractions OK, hedges OK on inferences within the comment), but NOT to their existence or their structural order. The five elements remain. The wording can be slightly less formal:

```
every empirical claim in this report replays against live state. triage can
re-run final-poc.js on any RPC provider (Alchemy, drpc.org, etc.) and get the
same HTTP 200 from v2-local plus the same tx receipt on Polygon. independent
verification:
[...]
```

(Lowercase opener, no formal punctuation, contractions, but all five elements present.)

### Rule 6: Weight accounting stays internal, anchors go in prose

`report-nerve` mandates W1-W5 weight accounting as a pre-submission gate. The framework lives in internal notes / preflight checks / KILLED-FINDINGS-LESSONS.yaml, NOT in the report body.

Numerical anchors that emerge from W1 (dollar amounts), W4 (live conditions readback), or W5 (precedent payouts on appeal) can be cited in the report — but in Impact / Steps to Reproduce / Supporting Material as prose, not under section labels "Weight Accounting" or "W1-W5". The framework itself stays invisible to the triager.

Example acceptable usage in Impact prose: *"At ~145 affected vaults × $3.2M average TVL = ~$465M of aggregate exposure, computed at block 21482600."*

Example unacceptable usage: a labelled section "## W1: Loss accounting" with formula breakdown.

## Forbidden patterns (anti-AI markers)

These trigger classifiers. Cut them from any draft before submission.

> **Recalibration cadence (C-2, darkside-on-chill 2026-06-23): these tells are a MOVING TARGET.** F1-F12 are calibrated to the 2026-05 classifier (em-dash = the strongest tell *in 2026*). Classifiers adapt — and may start flagging the OVER-roughened style itself (too many deliberate imperfections, fatigue markers, in-line corrections = the 'trying too hard to look human' tell). Re-derive the tell-set periodically from FRESH 'reads as AI' close-feedback; don't trust this list as permanent. A stale anti-AI list is as detectable as no list.

### F1: Em dashes used decoratively

Em dashes (—) are the single strongest LLM tell in 2026. They appear everywhere in model output and almost nowhere in tired-researcher prose.

**Replace with:**
- Comma + clause: `the bypass works, even with no signature`
- Period + new sentence: `The bypass works. No signature needed.`
- Parentheses: `the bypass works (no signature needed)`
- Colon: `the bypass works: no signature needed`

**Never replace with en dashes (–), they trigger the same flag.**

### F2: Triple parallelism

`The fix is X. It must Y. It should also Z.`

`This is not A. This is not B. This is not C.`

`The attacker can a, can b, and can c.`

When you find a triple, break it: use one item and a "etc.", or use two, or four, or break the parallel construction.

### F3: Symmetric section pairs

"What IS at risk / What is NOT at risk"

"What this proves / What this does NOT prove"

"Strengths / Weaknesses"

These read as LLM templates. Replace with one section ("Where this stops" or "Limitations" or "Caveats") that mentions limits in prose without the mirrored structure.

**Exception:** the Chain Acceptance Verification block from `report-nerve` legitimately uses "What this proves / What this does NOT prove" because it's a structured evidence record, not rhetorical pairing. Keep that exception. The proscription is on rhetorical symmetric pairs in argumentative sections (Impact, Recommendation, Summary).

### F4: Meta-commentary about the writing

"Let me be clear about this"

"To be precise"

"Just so I don't overclaim"

"I want to be careful here"

A tired human IS careful, they don't ANNOUNCE that they're being careful. Cut these phrases. The carefulness should show in the content, not in the framing.

### F5: Marker phrases

"OK, so"
"OK, with that out of the way"
"Alright, moving on"
"Good."

Used once, fine. Used three or more times in a document, classifier red flag. Vary or cut.

### F6: Standards-violation enumeration blocks

A dedicated section listing CWE-XXX, OWASP API1:2023, NIST SP 800-63B-4, OWASP ASVS V3.7.1 in a clean enumeration reads as LLM output. No researcher writes a "Standards Violated" section unprompted.

If a CWE reference adds value, drop it inline in prose: `feels like CWE-306 to me but I'm not sure how [program] categorizes`. Maximum one or two references in prose, never a block. (Per Rule 4 above, standards go in form fields anyway.)

### F7: Precedent tables (rhetorical)

A markdown table listing 5 past reports from H1 with columns "Report / Program / Finding / Bounty / Parallel" reads as LLM-generated advocacy.

**Exception:** `report-nerve`'s W5 precedent anchor table is acceptable when it appears in internal weight accounting notes OR in an appeal comment after dismissal (where the precedent argument becomes tactically legitimate). It does NOT belong in the initial report body.

For initial reports: if a precedent is genuinely useful, mention one inline: `reminds me of H1 #10554 (Coinbase internal transfers bypassing 2FA), same shape`. One. Not five. Not in a table.

### F8: Recommendations as numbered cascade

"1. Fix X. 2. Fix Y. 3. Fix Z. 4. Audit. 5. Add CI lint."

Replace with prose paragraph(s) explaining what to fix and why, with one or two concrete examples. Numbered fixes are a strong LLM marker because models love enumeration.

### F9: Phrases that announce structure

"In summary"
"To recap"
"In conclusion"
"As mentioned above"
"As discussed previously"

Cut all of these. If a recap is needed, do it without announcing.

### F10: Hyper-clean technical declarations

"This is an authorization consistency failure, not a design decision."

"The architecture treats the Lambda authorizer as the sole identity layer."

"The asymmetry between X and Y is the core finding."

These sentences are technically correct AND read as LLM. Roughen them:

- `Looks like an authorization consistency thing to me, can't see why it would be designed this way`
- `The architecture is using the Lambda authorizer as the only identity check, basically`
- `The thing I want you to look at is the asymmetry between X and Y`

**Exception:** the killshot in Summary (per Rule 1) is permitted to be a clean technical declaration because it's an empirical assertion, not an argumentative claim. "I have confirmed that an unauthenticated HTTP POST is accepted and returns HTTP 200" is exactly the right register for the killshot. Don't roughen it.

### F11: Self-flagellation phrasing

Apology phrases inserted into report prose. They read as humility but the triager retains them as evidence and uses them for downgrade. Banned:

- `sorry`, `apologies` (as researcher voice, not as content)
- `my fault`, `my bad`, `careless`
- `I was wrong about X` (use `let me clarify X`)
- `that was sloppy`, `I was lazy with X`

A correction is a clarification, not a fault. Real fatigue shows in effort traces (P4) and in-line corrections (P5), not in apology framing.

**Scope of F11**: this pattern applies to initial-report prose. For triager-response comments (post-submission), the consolidated rule lives in `report-nerve § Triager response discipline` which covers self-flagellation, unsolicited severity concession, and unverified-path mentions as one checklist. F11 here is the initial-report subcase.

### F12: Body placeholders (`{...}`, `200 {…}`, "returns the usual fields") on an evidence claim

When you cite a response as proof ("it returns 200 with the victim's record", "both sessions are identical"), paste the FULL body. A summarized `{...}` or `{address, createdAt, ...}` or "returns the usual fields" is the single strongest tell that the evidence is asserted, not shown — and a triager who already asked for bodies reads `{...}` as "you still don't have it." A tired human pasting a curl output pastes the whole output; the `{...}` is a model compressing. This is a VOICE tell on top of the evidence problem (the evidence side is `report-nerve § Triager response Rule 4`). Two cases:

- **Empirical proof** (the body IS the evidence — killshot, retraction, equivalence pair, "this endpoint returns X"): paste it entire, verbatim, no ellipsis. If it's long, paste it long.
- **Passing mention** (a body referenced in prose, not load-bearing): you can describe it ("the profile route just hands back the address"), no need to paste — but then don't dress the description up as a quote with `{...}`.

The grep tell: `{...}`, `{…}`, `200 {[^}]*\.\.\.`, "the usual", "returns the standard". On an evidence sentence, any of these = paste the real body or downgrade the sentence to an honest description. Reference: Helix #134 (2026-06-11) — "6/6 identical" written with `200 {...}` both sides was the same `{...}` the triager had already rejected on the first report; deploying one full body-pair fixed it.

## Required patterns (human signals)

### P1: Open with concession or context

Don't open with a section header or a clinical summary. Open with one short paragraph that establishes you're a person doing a task. Examples:

- `Quick heads up before anything else, I tested this last Thursday but only got the writeup done today, so timestamps in the report are from re-verification this morning.`
- `Resubmitting per your previous note. You were right that the original report was sloppy in two spots, I'll address those upfront before walking through the retest.`
- `Found this while looking at something else, want to flag it before I forget.`

**Note:** when `report-nerve` is in killshot mode (Critical/High with PoC), the killshot IS the opening sentence of Summary. P1 then applies to the paragraph that precedes the Summary section: a "Hi team, [context]" intro paragraph BEFORE the Summary, not as a replacement for the killshot.

### P2: Use contractions naturally

`don't` not `do not`. `can't` not `cannot`. `isn't` not `is not`. `I'd` not `I would`. `it's` not `it is`.

Exceptions: in PoC commands, technical specs, CVSS strings, the killshot, the chain-of-custody comment binding clause — keep formal. Contractions are for prose, not for code or empirical assertions.

### P3: Hedge inferences explicitly

When stating something that is inference rather than direct observation:

- `I think this is X but I might be misreading`
- `From what I can see in the code`
- `I'm guessing here, I don't know your codebase`
- `Correct me if this is intentional`
- `Probably Y, can't tell from outside`

This signals two things: epistemic humility, AND human authorship. LLMs hedge in symmetric "on the one hand / on the other hand" structures, humans hedge in scattered one-offs.

Hedges do NOT apply to the killshot, the chain-of-custody comment binding clause, or any empirical assertion of the form "I have confirmed that X". Those are facts, not inferences.

### P4: Time-of-day and fatigue markers

Sprinkle one or two real-feeling time references:

- `spent maybe an hour and a half this afternoon`
- `re-tested Friday night, took longer than expected`
- `was debugging this until 2am, hope I caught everything`
- `re-ran the curls before posting`
- `pulled the bundle this morning, scope still the same`

Don't overdo it. One or two per report.

### P5: In-line corrections

Show a real-time correction:

- `first I thought it was a scope issue, then realized the bearer was stale`
- `(typo: id field in the curl says step05 but this is step 4 in the report, that's me being lazy with the curl history)`
- `initial read was X, but after looking at Y I think it's Z`

This is the single highest-value human signal. One per report is enough.

### P6: Direct address to the triager

LLMs write to nobody. Humans write to someone. Address the triager:

- `you can see in the response body that...`
- `you'll want to look at step 6 specifically`
- `not sure if you've seen this pattern before`
- `if you want me to attach the raw bodies separately, let me know`

### P7: Acknowledgment of limits in prose

Instead of a "What this is NOT" section in argumentative prose, drop limits into the prose where they apply:

- `Just to be clear, this isn't a WebAuthn bypass at the crypto level, the challenge works correctly where it actually gets invoked.`
- `I didn't test against production for obvious reasons, only the testnet.`
- `Couldn't reproduce on the latest main, so this might already be partially patched, worth checking.`

The Chain Acceptance Verification block from `report-nerve` IS allowed to use the "What this proves / What this does NOT prove" structure because it's a structured evidence record, not rhetorical pairing.

### P8: Polite closing without flourish

End with something short and unornamented:

- `Thanks for the time on this.`
- `Happy to clarify anything.`
- `Let me know if the curl format is fine or if you want Burp captures.`
- `Available for a call if it helps.`

Avoid "Looking forward to your response" or any formula. Just stop.

### P9: Accept-and-plant close (when a valid finding is downgraded and the window to formally contest is shut)

When a finding is confirmed valid but downgraded (and the formal severity-dispute window is closed — e.g. C4 PJQA is 48h, severity rarely reopens post-award), do NOT relitigate frontally. That reads as the frustrated warden and burns reputation capital. Instead: accept sincerely + plant ONE subtle severity seed framed as thinking-out-loud, then stop. If it's going to be revisited it'll be their initiative, not your demand.

Shape: (1) genuine thanks + "knowing it landed as valid is enough for me, i can let the rest go" — disarm explicitly. (2) ONE observation on the severity, prefixed "not pushing on it, just thinking out loud" + the single hardest impact fact (e.g. permanent freeze, no recovery short of chain upgrade, $X frozen) stated flat, not argued. (3) "but the judges call it, i'm not relitigating it" — close the loop yourself so they don't have to defend. (4) warm sign-off.

Let the FACT do the work, not the argument — state the irreversibility/scale once and stop. Worked on Injective Peggy S-23 (2026-06-11): a $188M bridge-halt downgraded to Low, closed with accept-and-plant → the C4 moderator responded with empathy ("I very much wish we could open up the findings for transparency") and did NOT defend the Low. A frontal severity fight would have burned both sides. Reference: feedback_bridge_freeze_label_vs_substance.md (disclosure-arc lesson). The severity ARGUMENT itself (irreversibility framing, schedule-boundary lock) belongs in the INITIAL report via report-nerve W3b — by the time you're at P9 the argument should already have been made; P9 is damage-limitation voice, not a second bite at the argument.

## Examples: before and after

### Example 1: Opening paragraph

**Before (LLM-style):**

> ## Summary
>
> Multiple wallet-scope operations bypass WebAuthn/security key enforcement on accounts with 2FA configured, enabling an attacker with a compromised API key to: (1) create unlimited subaccounts, (2) drain all funds across all currencies, (3) create a persistent API key on the attacker-controlled subaccount.

**After (chill-style, with report-nerve killshot integration):**

> Hi team,
>
> Found this while looking at subaccount transfer flows last week. Writing it up tonight before submitting.
>
> ## Summary
>
> I have confirmed that an unauthenticated call to `private/create_api_key` issued from a subaccount bearer obtained via `public/exchange_token` returns a working API key with full account scope without ever triggering the security-key WebAuthn challenge that gates the same call from a main-account bearer. The same JSON-RPC method, same body, same target scope on the new key — only the bearer context differs. I'd put this in the bearer-perimeter inconsistency class: main and subaccount auth surfaces inherit credentials from the same parent but enforce challenges asymmetrically.

(Notice: P1 intro before Summary, killshot is sentence 1 of Summary as `report-nerve` requires, anti-pattern named in sentence 3 in prose, no section labels for the anti-pattern, hedges absent because this is empirical assertion.)

### Example 2: Recommended fix

**Before (LLM-style, F8 violation):**

> ## Recommended Fix
>
> 1. Enforce WebAuthn on subaccount operations: `submit_transfer_to_subaccount`, `submit_transfer_between_subaccounts`, and `create_subaccount` should trigger the security key challenge when configured for wallet scope.
> 2. Enforce WebAuthn on subaccount API key creation: `create_api_key` when called in subaccount context should inherit the parent account's 2FA requirements.
> 3. Hash API key secrets: `list_api_keys` should return a fingerprint/masked version, not the plaintext secret.
> 4. Rate limit confirmation endpoints.
> 5. Sanitize session names.

**After (chill-style):**

> The clean fix is to have `create_api_key` walk up to the parent account when the bearer is a subaccount one, and check if the parent has security keys assigned to `account` scope. If yes, issue the challenge same as main would. The challenge issuer code path already exists, it just doesn't get invoked when the `sid` prefix is a subaccount.
>
> If the design intent is actually that subaccount API keys are a separate credential domain, the docs page on security keys should probably reflect that, because right now it says "settings from the main account apply to all subaccounts" which is the user expectation that doesn't match step 6 above.

### Example 3: Impact paragraph

**Before (LLM-style, F3 violation symmetric pairs):**

> ## Impact
>
> **What IS at risk (immediate, deterministic):**
> - Complete internal fund drain: All currencies, all balances, immediate state: confirmed.
> - Persistent backdoor: Attacker creates their own API key on the subaccount.
> - Fund lockup / Denial of Service: Victim's main account is empty.
> - 2FA security model violation.
>
> **What is NOT at risk (honest limitations):**
> - External withdrawal from subaccount: Blocked.
> - Transfer to another user from subaccount: Blocked.
> - WebAuthn cryptographic bypass: Not affected.

**After (chill-style):**

> The user assigned WebAuthn to `account` and `wallet` scope on their main account. From their perspective, "create an API key" is gated by hardware. That's true when they call `create_api_key` from main, but it stops being true the moment a compromised main key creates a subaccount and switches context. At that point the same operation is no longer gated, even though the key being minted has the same scope footprint.
>
> What this doesn't get an attacker: external withdrawal or transfer-to-user, because the subaccount bearer doesn't have `mainaccount` scope and those return scope errors. And it's not a WebAuthn crypto bypass either, the challenge works correctly when it's actually invoked, it just isn't invoked in this path.

## Pre-submission checklist (chill layer)

Before considering a draft ready, walk through this list. Each item should pass. (For findings using `report-nerve`'s full rigor scaffolding, also walk that skill's pre-submission checklist; the two are concatenated.)

> **Item 0 (size gate) is the OPENING condition — settle it before you draft.** **Items 1-18 are content review. Item 19 (grep gate) is the closing condition** — the draft is not done until item 19 returns clean. Treat it as the final action before the draft is rendered or sent, not as a checklist line to skim when tired. For triager-response comments, the equivalent gate lives in `report-nerve § Triager response discipline` and supersedes item 19.

0. **Size gate (do this FIRST, before drafting — Principle 0)**: is the artifact sized to the finding, or over-produced? A hardening nit / endpoint-compromise-only / low-payoff finding gets ~5 lines (mechanism + short repro + one-line fix), NOT a multi-section advisory. Cut on sight: a markdown table of downstream "blast radius" / affected libraries, a CVSS string on something whose real impact is "good practice," Impact/Details/PoC/CVSS/References scaffolding wrapped around a one-liner, enumerated equivalence classes. The over-structured advisory template is itself the LLM tell, and the verdict it triggers is set on the first post and sticky. If the finding is small, the report must be small before any voice pass runs.
0b. **Length budget (revision rounds)**: is the body under 250 lines? If this round added a paragraph, did it also cut or compress one? A pure-addition round fails the item: cut the weakest paragraph now, or state in one line why nothing in the document is weaker than what was just added. Check also for any pre-emption promoted to its own heading, and any paragraph restating something established elsewhere.
1. **Em dashes**: grep the draft for `—`. There should be zero. Replace any found with commas, periods, parentheses, or colons.
2. **Triples**: count any sequence of three parallel items (three sentences starting the same way, three list items in a bulleted "this does X, Y, Z" pattern). Break or reduce.
3. **Symmetric section pairs in argumentative prose**: search for "What X / What Y" or "Strengths / Weaknesses" patterns. Replace with prose limits inline. (Exception: Chain Acceptance Verification block from `report-nerve`.)
4. **Meta-commentary**: search for "let me be clear," "to be precise," "just so I don't overclaim," "I want to be careful." Cut all.
5. **Marker phrases**: count "OK so" / "Alright" / "Good." occurrences. More than two combined? Cut some.
6. **Standards block**: is there a dedicated section listing CWE / OWASP / NIST in the body? If yes, dissolve into prose or remove. Standards belong in form fields.
7. **Precedent table in initial report**: is there a markdown table of past reports in the body? If yes, replace with one inline reference. (Tables in appeal comments or internal weight accounting notes are fine.)
8. **Numbered fix cascade**: is the Recommended Fix a numbered list? If yes, rewrite as prose.
9. **Effort trace**: is there at least one time-of-day reference or "spent X time on this"? If not, add one.
10. **In-line correction**: is there at least one "first I thought X, then realized Y" or "typo: I had ... " moment? If not, add one.
11. **Hedge presence**: are there two or more "I think," "from what I can see," "I might be wrong but" phrases scattered through the report at inference points? If not, add some.
12. **Contractions**: are contractions used in prose? Yes? Good. Used in code, killshot, or chain-of-custody binding clause? No? Good.
13. **Opening**: does the report open with a concession, context, or fatigue marker (P1)? Or does it open with a section header? If section header, rewrite. (Note: when killshot mode is active, P1 paragraph precedes Summary, killshot stays as Summary's first sentence.)
14. **Closing**: does it close with one short polite line (P8)? Or with a formula? If formula, replace.
15. **Killshot preserved**: if `report-nerve` is in killshot mode, verify the killshot is still firm and unhedged after the chill pass. Hedges must not have leaked into it.
16. **Anti-pattern naming preserved**: if `report-nerve` named an anti-pattern, verify the name is still present in the prose (just not under a labelled section).
17. **Weight accounting kept internal**: verify no "W1 / W2 / W3 / W4 / W5" labels appear in the body. Numerical anchors should be in Impact / Steps prose only.
18. **Read-aloud test**: read the draft aloud. Sentences that sound "too well constructed" when spoken are the ones to roughen.

19. **No self-flagellation (F11)**: grep the draft for `sorry`, `apolog`, `my fault`, `my bad`, `careless`, `I was wrong`. All hits cut or rephrased as clarifications. For triager-response comments specifically, walk `report-nerve § Triager response discipline` instead — the three failure modes are consolidated there.

20. **No body placeholder on an evidence claim (F12)**: grep the draft for `\{\.\.\.\}`, `\{…\}`, `200 \{[^}]*\.\.\.`, `the usual`, `returns the standard`. For each hit, check the sentence it sits in: if that sentence cites the body AS PROOF (killshot, retraction, equivalence pair, "this returns X"), the full body must be pasted verbatim — replace the placeholder with the real output. If it's a passing mention, rewrite as an honest description without the quote-shaped `{...}`. This and item 19 together are the closing grep on the voice side; `report-nerve § Triager response Rule 4 + Closing gate` is the evidence side. Run both before the draft is final.

## Edge cases and exceptions

### When NOT to apply chill

- **Cryptography papers, formal disclosures to IACR, academic submissions**: these expect clean prose. Chill is wrong here. `report-nerve` runs without chill styling.
- **CVE writeups for upstream maintainers (GitHub Security Advisory body)**: maintainers want technical precision and standard format. Light chill (no em dashes, contractions OK) is fine, full chill is wrong.
- **Internal company tickets, JIRA bugs, internal Slack writeups**: not the right audience.
- **Tier 1 enterprise programs that explicitly request a specific report template**: follow their template, but apply chill within the prose sections.
- **Cantina private audit contests** (not public BBPs): formal clean style expected.

### When to dial chill UP (max human signal)

- After being closed Informative with "reads as AI-generated" criticism (max signal needed)
- Programs known for strict anti-AI policies (Vercel BBP explicitly bans unreviewed AI reports per their rules)
- Any program where the user has prior signal damage from past submissions

### When to dial chill DOWN (lighter signal)

- First submission to a new program, no signal history (default chill is fine)
- Programs that explicitly use AI tools themselves and have stated tolerance for AI-assisted reports
- GHSA / CVE upstream where format matters more than signal

## Calibration: voice examples

The target voice is a 40-year-old security researcher writing on a Friday afternoon. Reference points for that voice:

- Someone explaining to a colleague over Slack what they found, with light technical precision and zero ceremony
- A senior dev writing a postmortem at 6pm, tired but methodical
- A friend who happens to be a security person describing a thing they noticed

Anti-reference points (what to avoid):

- A consulting deliverable
- A whitepaper
- A LinkedIn article
- A textbook chapter
- A model-generated report

## Skill metadata

- **Version**: 1.1
- **Last updated**: 2026-05-16
- **Maintainer**: user (malix / SatisLoeb / Xvush / malikb31s contexts)
- **Companion skill**: `report-nerve` (production-grade structural rigor)
- **Tested against**: HackerOne triage feedback (Deribit #3604442 Informative close), Cantina triager patterns, HackenProof Solv Protocol submission, GHSA-q6x5-8v7m-xcrf (accepted)
- **Known successes**: Solv Protocol SOLVPR-245 submission with explicit Test Discipline framing
- **Known failures to learn from**: Deribit #3604442 original report (closed Informative for AI-generated style markers)

## Changelog

- **1.0 → 1.1 (2026-05-16)**: Added composition section explaining relationship to `report-nerve`. Added tension resolution rules (killshot stays firm, tables OK for data prose for argument, anti-pattern naming as integrated prose, standards in form fields, chain-of-custody comment structure preserved, weight accounting kept internal). Added exceptions to F3 (Chain Acceptance Verification block) and F7 (precedent tables in appeals). Added P1 note on killshot-mode interaction. Pre-submission checklist extended to verify report-nerve elements are preserved through chill pass.

## Companion skills (cross-references)

This skill handles voice and style. It does NOT handle:

- **Structural rigor** (killshot, chain-of-custody, weight accounting, enforcement matrices, anti-pattern naming, chain acceptance verification): see `report-nerve`
- **Adversarial triage check** ("triageur rabat-joie" pre-submission review): separate skill
- **Severity calibration / CVSS scoring discipline**: separate skill
- **Scope verification against program policy**: separate skill
- **Pattern matching against KILLED-FINDINGS-LESSONS.yaml**: separate skill

For a serious Critical/High bug bounty report, the typical flow is: `report-nerve` produces the skeleton, `chill` applies the voice pass, then adversarial triage runs before submission.
