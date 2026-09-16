---
name: chill
description: Write bug bounty reports, security advisories, and triage responses in a human-tired-researcher voice that passes anti-AI classifiers on HackerOne, Cantina, HackenProof, and similar platforms. Use whenever drafting external-facing security writeups in English. Trigger on explicit invocation ("use chill", "apply chill style") and automatically when the user asks for a bug bounty report, vulnerability disclosure, security finding writeup, GHSA, CVE writeup, triage response, appeal to a closed report, or "rewrite this for submission." Do NOT use for internal notes, code comments, French conversation, or technical analysis that stays in chat.
---

# chill

A style and structure skill for writing bug bounty reports that read like a tired human researcher on a Friday afternoon, not like a model output.

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

The user is a solo security researcher operating under pseudonyms (SatisLoeb, malix, Xvush, malikb31s). 40+ years old, francophone, writes external reports in English. Methodology is disciplined and pattern-driven (kill-gates, scope checks, pattern DB), so the natural writing style is already clean and structured. That natural clean style is exactly what triggers the anti-AI classifier on the receiving end.

The voice this skill targets is: a competent researcher who has been doing this for years, found something while debugging another thing, and is writing it up at the end of the day before submitting. Slightly tired, occasionally self-deprecating, technically precise where it matters, casual where it doesn't.

## Core principles

### Principle 1: Imperfection signals authenticity

A perfect writeup looks like AI output. A writeup with one typo corrected in-line, one digression, one "wait, let me check that," one acknowledgment of fatigue, reads like a human. Build small imperfections in deliberately.

### Principle 2: Asymmetry beats symmetry

LLMs love triples (three findings, three fixes, three references). LLMs love parallel construction ("A but B," "X yet Y"). LLMs love symmetric sections ("What is at risk / What is not at risk"). Humans don't. Use one finding, or two, or seven. Break parallel constructions mid-sentence. Mix section depths.

### Principle 3: Show effort traces

Real research has timestamps, fatigue, dead ends, things you almost missed. A clean report hides all of this. Include some of it: time of day, how long something took, what you initially thought before realizing, where you got stuck.

### Principle 4: Hedge what you don't know

LLMs sound confident even when wrong. Humans hedge. Use "I think," "from what I can see," "I might be wrong on this but," "correct me if I'm misreading," when stating things that are inferences rather than direct observations. This is honest AND it signals human authorship.

### Principle 5: Technical precision stays clean

Where the rubber meets the road (the actual PoC, the CVSS string, the curl command, the response body, the line numbers), be exact. The roughening applies to prose, framing, and connective tissue, NOT to technical artifacts. A messy curl command is suspicious. A messy summary paragraph is human.

## Forbidden patterns (anti-AI markers)

These trigger classifiers. Cut them from any draft before submission.

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

If a CWE reference adds value, drop it inline in prose: `feels like CWE-306 to me but I'm not sure how [program] categorizes`. Maximum one or two references in prose, never a block.

### F7: Precedent tables

A markdown table listing 5 past reports from H1 with columns "Report / Program / Finding / Bounty / Parallel" reads as LLM-generated advocacy.

If a precedent is genuinely useful, mention one inline: `reminds me of H1 #10554 (Coinbase internal transfers bypassing 2FA), same shape`. One. Not five. Not in a table.

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

## Required patterns (human signals)

### P1: Open with concession or context

Don't open with a section header or a clinical summary. Open with one short paragraph that establishes you're a person doing a task. Examples:

- `Quick heads up before anything else, I tested this last Thursday but only got the writeup done today, so timestamps in the report are from re-verification this morning.`
- `Resubmitting per your previous note. You were right that the original report was sloppy in two spots, I'll address those upfront before walking through the retest.`
- `Found this while looking at something else, want to flag it before I forget.`

### P2: Use contractions naturally

`don't` not `do not`. `can't` not `cannot`. `isn't` not `is not`. `I'd` not `I would`. `it's` not `it is`.

Exceptions: in PoC commands, technical specs, CVSS strings, keep formal. Contractions are for prose, not for code or schema descriptions.

### P3: Hedge inferences explicitly

When stating something that is inference rather than direct observation:

- `I think this is X but I might be misreading`
- `From what I can see in the code`
- `I'm guessing here, I don't know your codebase`
- `Correct me if this is intentional`
- `Probably Y, can't tell from outside`

This signals two things: epistemic humility, AND human authorship. LLMs hedge in symmetric "on the one hand / on the other hand" structures, humans hedge in scattered one-offs.

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

Instead of a "What this is NOT" section, drop limits into the prose where they apply:

- `Just to be clear, this isn't a WebAuthn bypass at the crypto level, the challenge works correctly where it actually gets invoked.`
- `I didn't test against production for obvious reasons, only the testnet.`
- `Couldn't reproduce on the latest main, so this might already be partially patched, worth checking.`

### P8: Polite closing without flourish

End with something short and unornamented:

- `Thanks for the time on this.`
- `Happy to clarify anything.`
- `Let me know if the curl format is fine or if you want Burp captures.`
- `Available for a call if it helps.`

Avoid "Looking forward to your response" or any formula. Just stop.

## Structural patterns for bug bounty reports

The classic structure (Summary / Steps to Reproduce / Impact / Recommended Fix / References) is fine to use, but the WAY you fill those sections is what changes. Below is a recommended structure with notes on how each section should feel.

### Top of report

One line technical title, descriptive not advocacy. Bad: `Critical: Total Fund Drain Possible via X`. Good: `private/create_api_key doesn't enforce the challenge when called from a subaccount bearer`.

Then one short opening paragraph (P1).

### Summary

Two to four paragraphs of prose. Not bullets. Not a table. Just walk the reader through what you found in the order you'd explain it to a colleague.

Include: the finding in one sentence, where it lives (which file/endpoint/contract), what triggers it, what an attacker gets out of it, and what they DON'T get out of it. The "don't" part inline, not as a separate section.

### Steps to Reproduce

Use real curl/code blocks with real responses. The technical content stays precise.

In between code blocks, write short prose connectors. Bad: `Step 1: Authenticate. Step 2: Confirm baseline.` Good: `First, get a bearer, nothing surprising here. [code block]. Got back [excerpt]. That's normal. Now the interesting part:` 

Use real `step03_resp_body.json` filenames if you have artifacts, but reference them naturally in prose, not in an aligned list.

### Impact

Prose paragraphs. Walk through what an attacker actually gets, in attacker-perspective language. What does this primitive enable? What does it not enable?

If you're going to mention bonus modifiers or program-specific scoring criteria, do it inline: `per your "leakage of cryptographic material leading to unauthorized access to user assets" line in the program rules, I think this fits`.

### Severity

One line CVSS string, one line score, one line plain English. Don't justify each metric in a bulleted list (LLM marker). If you want to defend a controversial metric, do it in a sentence of prose.

If the program uses Likelihood / Impact (Cantina style), state both with one line of reasoning each, in prose.

### Recommended fix

Prose. Not numbered. One main fix recommendation explained with a code snippet if helpful, and one or two secondary considerations mentioned naturally.

If there's a complex multi-step fix, write it as a paragraph: `The actual fix is in two parts. First, the [X], which is a one-line change at [file:line]. Second, [Y], which is the harder one because [reason].`

### References

Inline links, not formatted bibliography. `See the AppSync docs on Lambda authorization here: [url]`. Avoid the "References:" section header with bulleted list of academic-style citations.

### Sign-off

Short. P8.

## Examples: before and after

### Example 1: Opening paragraph

**Before (LLM-style):**

> ## Summary
> 
> Multiple wallet-scope operations bypass WebAuthn/security key enforcement on accounts with 2FA configured, enabling an attacker with a compromised API key to: (1) create unlimited subaccounts, (2) drain all funds across all currencies, (3) create a persistent API key on the attacker-controlled subaccount.

**After (chill-style):**

> Found this while looking at subaccount transfer flows last week. The short version: if an attacker compromises a main API key, they can spin up a subaccount and mint a fresh API key on it without ever triggering the WebAuthn challenge the user configured. Same `create_api_key` call works one way from main (challenge, correct) and another way from subaccount bearer (no challenge, key issued). Walking through the chain below.

### Example 2: Recommended fix

**Before (LLM-style):**

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

**Before (LLM-style):**

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

## Pre-submission checklist

Before considering a draft ready, walk through this list. Each item should pass.

1. **Em dashes**: grep the draft for `—`. There should be zero. Replace any found with commas, periods, parentheses, or colons.
2. **Triples**: count any sequence of three parallel items (three sentences starting the same way, three list items in a bulleted "this does X, Y, Z" pattern). Break or reduce.
3. **Symmetric section pairs**: search for "What X / What Y" or "Strengths / Weaknesses" patterns. Replace with prose limits inline.
4. **Meta-commentary**: search for "let me be clear," "to be precise," "just so I don't overclaim," "I want to be careful." Cut all.
5. **Marker phrases**: count "OK so" / "Alright" / "Good." occurrences. More than two combined? Cut some.
6. **Standards block**: is there a dedicated section listing CWE / OWASP / NIST? If yes, dissolve into prose or remove.
7. **Precedent table**: is there a markdown table of past reports? If yes, replace with one inline reference.
8. **Numbered fix cascade**: is the Recommended Fix a numbered list? If yes, rewrite as prose.
9. **Effort trace**: is there at least one time-of-day reference or "spent X time on this"? If not, add one.
10. **In-line correction**: is there at least one "first I thought X, then realized Y" or "typo: I had ... " moment? If not, add one.
11. **Hedge presence**: are there two or more "I think," "from what I can see," "I might be wrong but" phrases scattered through the report? If not, add some at inferences.
12. **Contractions**: are contractions used in prose? Yes? Good. Used in code or specs? No? Good.
13. **Opening**: does the report open with a concession, context, or fatigue marker (P1)? Or does it open with a section header? If section header, rewrite.
14. **Closing**: does it close with one short polite line (P8)? Or with a formula? If formula, replace.
15. **Read-aloud test**: read the draft aloud. Sentences that sound "too well constructed" when spoken are the ones to roughen.

## Edge cases and exceptions

### When NOT to apply chill

- **Cryptography papers, formal disclosures to IACR, academic submissions**: these expect clean prose. Chill is wrong here.
- **CVE writeups for upstream maintainers (GitHub Security Advisory body)**: maintainers want technical precision and standard format. Light chill (no em dashes, contractions OK) is fine, full chill is wrong.
- **Internal company tickets, JIRA bugs, internal Slack writeups**: not the right audience.
- **Tier 1 enterprise programs that explicitly request a specific report template**: follow their template, but apply chill within the prose sections.

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

- **Version**: 1.0
- **Last updated**: 2026-05-15
- **Maintainer**: user (malix / SatisLoeb / Xvush / malikb31s contexts)
- **Tested against**: HackerOne triage feedback (Deribit #3604442 Informative close), Cantina triager patterns, HackenProof Solv Protocol submission, GHSA-q6x5-8v7m-xcrf (accepted)
- **Known successes**: Solv Protocol SOLVPR-245 submission with explicit Test Discipline framing
- **Known failures to learn from**: Deribit #3604442 original report (closed Informative for AI-generated style markers)

## Companion skills (not included here)

This skill handles style and structure. It does NOT handle:

- Adversarial triage check (separate skill, "triageur rabat-joie")
- Severity calibration / CVSS scoring (separate skill)
- Scope verification against program policy (separate skill)
- Pattern matching against KILLED-FINDINGS-LESSONS.yaml (separate skill)

If those are needed, invoke them separately or in sequence.
