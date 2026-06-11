---
name: disclosure-protocol
description: 4-stage disclosure flow with kabayanerve voice email templates. Stage 1 initial email to security contact. Stage 2 silent escalation if no response (LinkedIn DM to Co-CEO). Stage 3 re-verification email at day N+30/50. Stage 4 fortress follow-up within 24-48h of patch acknowledgement to convert the patch transaction into a hardening engagement covering remaining findings.
---

# Disclosure protocol -- 4-stage flow

## Voice rules (apply to every stage)

The voice is what we call **kabayanerve voice**. It came out of the Transak engagement, was hardened on Polymarket #197, and was production-tested on the Upshift FORTRESS email that converted a 30-hour patch sprint into an open invitation for the rest of the bundle.

**Hard rules:**

1. **First person.** "I have confirmed that..." not "It has been confirmed that...". The hunter is the source of evidence, not a passive narrator.

2. **No em-dashes.** The Unicode em-dash character (U+2014) is an LLM signature. Replace every occurrence with two ASCII hyphens. Run `sed -i 's/\xe2\x80\x94/--/g'` on every email file before sending (the `\xe2\x80\x94` is the UTF-8 byte sequence for the em-dash, used to avoid quoting issues in shell). This is non-negotiable. If you find yourself reaching for the em-dash, the recipient's spam filter (mental or technical) will clock the email as machine-written.

3. **Epistemic precision.** "I have confirmed" vs "I have not confirmed" vs "I am flagging in case it is not on your radar" vs "I deliberately did not push the verification further because the next step would have meant submitting a payload that could write to your infrastructure". Each phrase carries different weight. Use the right one.

4. **Anti-pattern naming.** Name what you did NOT do. "No payload was submitted that could write to your systems." "I held back the wider inventory because dumping fifty issues on day one is not how this works." Naming what you avoided establishes operational discipline more than naming what you did.

5. **Evidence inline.** Curl commands, RPC reads, on-chain hashes -- inside the email body, not "see attached". The recipient's first scan should hit verifiable artifacts within 30 seconds.

6. **No corporate filler.** No "I hope this email finds you well", no "Please find attached", no "Looking forward to your response". The first line is the substance. The last line is the substance.

7. **No threats.** No "90-day public disclosure", no "I will publicly release if I do not hear back". The disclosure clock is implicit in the timeline, not stated. State your terms once in Stage 1, never repeat.

8. **No credit fishing.** No "I am a security researcher with X years of experience". The findings are the credentials.

9. **Lowercase opening optional but consistent.** "hi alex," is the Upshift voice. "Hi Alex," is also fine. Pick one and hold it across the thread.

10. **Sign with first name only.** "best, malik" not "Sincerely, Malik B. (Independent Security Researcher)".

## Stage 1 -- Initial email to first-found security contact

**When:** Immediately after Pass 4 chain construction is complete + at least one Critical or High is concrete.

**To (in priority order):**
1. `security.txt` at `https://target.com/.well-known/security.txt`
2. `SECURITY.md` in the protocol's main GitHub repo
3. `security@target.com` if it exists
4. Bug bounty platform's "direct contact" field (if program is on Immunefi or HackenProof but the user prefers direct)
5. CTO/security lead's email from public sources (LinkedIn, GitHub commits, conference talks)

**Subject line template:** `[Target] security disclosure -- [highest severity class] [primitive name]`

Example: `Upshift security disclosure -- CRITICAL on-chain state modification + NAV manipulation chain`

**Body template (kabayanerve voice):**

```
hi [first name],

[1 sentence: who I am if needed, otherwise straight to substance]

i'm sending [N] [findings/reports/artifacts]. the headline is: [combined chain impact in dollar/scope terms in one sentence]. details below.

### finding 1 -- [name] ([severity])

[Concrete primitive description in 2-3 sentences. Include: HTTP verb + path / contract address + function / on-chain target.]

[Inline curl or eth_call command + expected response]

[Re-verified date + result]

### finding 2 -- [name] ([severity])

[Same structure]

### the chain -- [combined impact in headline form]

[Step-by-step combined attack, numbered]

[Closing note: "only the final step was not executed because doing so would steal user funds"]

### attached

[List of artifacts with one-line descriptions]

### a few procedural notes

- i have no public writeup of any of this.
- i'm not holding any public-disclosure clock today; happy to start a coordinated disclosure window from the date you engage.
- pgp available if you prefer encrypted attachments
- happy to get on a call. signal or wire preferred for voice.
- no bounty demand on my side. ex-gratia is your call, not gating disclosure on reward.
- happy to switch to french on this thread if that's easier.

best,
[first name]
[email]
```

**Pre-send checklist:**

- [ ] Em-dash sweep: `grep $'\xe2\x80\x94' email.md && echo "FAIL: em-dashes present"` -- must return nothing
- [ ] Re-verify the headline finding is still live in production within 24h of send
- [ ] Verify recipient email is correct (typos kill disclosures)
- [ ] Offer alternate channel (Signal, Wire, PGP) so they can choose comfort level
- [ ] If sending from a fresh Gmail, mention the prior-thread context if any ("writing from the gmail i used with [previous contact] on [date] so the thread is linkable")

**What this does NOT do:**

- Does not threaten public disclosure
- Does not demand bounty
- Does not overload with all 40+ findings (max 3 in initial email)
- Does not posture as adversarial
- Does not credit-fish

## Stage 2 -- Silent escalation (if no response in 14 days)

**When:** 14 calendar days after Stage 1 with no acknowledgement.

**Why 14 days, not 7:** security@ inboxes route through ticketing systems, are often monitored part-time by the protocol's most overloaded engineer, and 7 days is below the threshold where polite escalation is justified. 14 days is the industry-soft threshold (CERT/CC, Project Zero soft policy). You will not look impatient.

**Channel for escalation:** LinkedIn DM to Co-CEO or CTO of the protocol.

**Why LinkedIn:** LinkedIn DMs land in the recipient's primary notification stream (mobile push), bypass ticketing systems entirely, and the recipient cannot delete the message from the protocol side (it's their personal account). The Co-CEO or CTO has personal incentive to respond rather than route to a junior triager.

**Tone:** No pressure, no "I sent you an email and you ignored it". Open with the substance, mention the email channel as background.

**Template:**

```
Hi [first name],

I sent a security disclosure to [email address used] on [date] -- two CRITICAL findings on [primitive description in <15 words]. The combined chain is [headline impact in dollar/scope].

Flagging here in case the email routed to a low-priority queue or did not surface on your team's radar yet. Happy to re-send the full bundle, switch to PGP, or jump on a quick call -- whatever shape works on your end.

Best,
[first name]
```

**What this does NOT do:**

- Does not blame ("you ignored my email")
- Does not threaten ("if I do not hear back I will...")
- Does not redact substance ("contact me for details") -- the LinkedIn DM should give the recipient enough to immediately understand severity
- Does not include the full report (LinkedIn DMs are not for that; the email is)

**If the LinkedIn DM gets acknowledged:** the recipient will typically reply within a few hours and request you re-send the original email to a different address (their personal email, an internal Slack channel, etc.). Comply immediately. The 14-day clock resets.

**If the LinkedIn DM is silent for another 7 days:** Stage 3 (re-verification) starts.

## Stage 3 -- Re-verification email at day N+30 to N+50

**When:** 30-50 days after Stage 1 if no engagement, OR after Stage 2 LinkedIn DM is silent for 7+ days.

**Why this stage exists:** Re-verifying that the primitives are still live 30-50 days later is what converts a "you ignored my email" framing into a "the threat is still live and I am still here" framing. The protocol team cannot dismiss byte-identical primitives.

**Critical move:** the re-verification email is sent to the next escalation contact, not the original one. If Stage 1 went to security@ and Stage 2 was a LinkedIn DM to the CTO, Stage 3 goes to the Co-CEO or to a different decision-maker.

**Subject line:** `[Target] disclosure re-verification -- [days since first disclosure] days, [N] primitives still live`

Example: `Upshift disclosure re-verification -- 51 days, 2 CRITICAL primitives still live`

**Body structure:**

```
hi [first name],

[1 sentence: context for who I am and why I am writing to you specifically]

i sent a security disclosure to [previous contact + email] on [date]. [If LinkedIn DM happened, mention it here in 1 sentence.] [N] days have passed; i'm writing to confirm the primitives are still live and to surface them at a level where they can get attention.

i re-verified both primitives against today's production build. both are live byte-identical to their original state, [N] days after the initial report.

### finding 1 -- [name] ([severity])

[Re-verification curl + response, with TODAY's date stamped]

### finding 2 -- [name] ([severity])

[Same]

### the chain

[Restate the combined impact briefly. Reviewers in this stage have not seen the original email; they need the headline number again.]

### what's changed since [original date]

[If anything has changed: e.g., bundle hash, frontend route, contract upgrade. If nothing has changed: "the bundles are different file names but the secret is byte-identical, which means the bundle was rebuilt without rotating credentials".]

### attached

[Same artifacts as Stage 1, possibly updated with re-verification dates inside]

### procedural posture (unchanged from [original date])

- no public writeup
- not holding a public-disclosure clock today; happy to start coordinated disclosure window from today
- pgp available
- voice call ok (signal/wire preferred)
- no bounty demand
- [N] findings total -- only top 3 in this email, full bundle on request

best,
[first name]
```

**Why this works:**

- Restating the procedural posture in identical language to Stage 1 reads as steady, not aggressive
- Re-verification with today's date stamp converts theoretical risk into immediate observable risk
- Mentioning "byte-identical" explicitly removes the "we patched that, you're stale" out
- The N-day count creates time pressure without any threat

## Stage 4 -- Fortress follow-up (within 24-48h of patch acknowledgement)

**When:** ANY of the following triggers:
1. The protocol acknowledges the disclosure and commits to a fix timeline
2. You observe the patches landing in production (pre-acknowledgement is OK -- the patch landing IS engagement)
3. The protocol responds to Stage 3 with substantive triage questions

**Why 24-48h:** the engagement window is open while the team is in active patch mode. Sending the fortress email while they are still iterating on remediation converts the patch transaction into a longer hardening engagement. Wait a week and the team has moved on; the next disclosure will be triaged as a fresh ticket against a closed thread.

**The strategic move:** the fortress email is NOT another finding submission. It is an offer to convert the patch sprint into a sustained hardening engagement. The framing is: "you patched what was disclosed; here is what it would take to make the architecture itself resistant to the next attacker".

**Subject line:** `Re: [original subject thread] -- patch verification + the rest of the bundle`

**Body structure:**

```
Subject: Re: [original subject thread] -- patch verification + the rest of the bundle

Hi [first name],

Quick follow-up while we wait for your team's formal assessment. I ran a passive verification pass against production around [time] this morning to confirm what's been patched and what's still live. Everything below is `eth_call` read-only, GET-only, or no-op POST -- no payload was submitted that could write to your systems.

### What I have confirmed is patched

[Per primitive: 1-2 sentences each. Use crisp action verbs. "X is rotated and removed." "Y returns 404 across the original path and every plausible variant I tried." "Step N of the combined chain is closed."]

[Closing: "The [combined-chain headline] from the [date] email is no longer reachable through the original primitives. That's the headline outcome and your team moved on it inside [N] hours of acknowledgement. I want that on the record."]

### What I have not confirmed is patched

I am flagging [N] items that don't show patch signals yet, in case they are scheduled for a later batch and not on your team's radar from the first triage pass.

[Per still-live primitive: re-verification with today's date, concrete eth_call or curl, reasoning why this is independent of the patched chain]

[For ambiguous items: "Two more items are unclear and I deliberately did not push the verification further because the next step would have meant submitting a payload that could write to your infrastructure. [Item A] [observation that suggests partial fix]. [Item B] [observation that is ambiguous]. Both outcomes are good; I would value your team's confirmation of which one."]

### The rest of the bundle

[1 paragraph: what was sent (the top 3), what was held back (the wider inventory), why the wider inventory was held back ("dumping fifty issues on day one is not how this works")]

That wider inventory is [N] findings total from the original session. [Breakdown by category and severity in 2-3 sentences. Name each category with concrete count.]

The reason I am writing now rather than waiting another week is that the patches you've shipped already validate the methodology. [Reasoning: the patches show the team understood the chain, went after root cause, will translate cleanly to the rest.] The right moment to ship the rest is while that engagement is fresh, not after another [duration] of background risk.

The framing is straightforward -- it is the difference between patching what was disclosed and hardening the architecture so the next attacker hits a wall rather than another hole. The fortress version covers [list of architectural themes, each in 1 phrase: operator key architecture across all production vaults, the proxy governance chain audit, the authentication state machine, the API surface posture, the on-chain ↔ off-chain accounting reconciliation, the staging environment isolation, the secret hygiene sweep].

I can deliver this in whatever shape works for your team. [Three concrete delivery options:]
- Full bundle as one tarball (~N MB), all findings + reports + evidence -- useful if you want your security team to triage in parallel
- Severity-tiered batches: HIGHs first, then MEDIUMs, then LOWs
- Per-theme architectural calls: pick one theme per call (e.g., the proxy governance chain across all nine proxies), I walk through findings + remediation + verification methodology, and your team validates each thread to closure

Same procedural posture as the [original date] email. No public disclosure clock running. No bounty demand on my side. PGP available if you want me to encrypt the bundle -- send me your key and I will re-send over that channel. Signal or Wire for voice if we go with the per-theme call format.

Best,
[first name]

PS -- [Optional: one observation that signals you are still actively reading the post-patch architecture, e.g., "I noticed `/openapi.json` is 404 now too. Good move. The new admin routes I see in the bundle suggest a real re-architecture..."]. [Optional offer: "If that's accurate and you want a passive review of the new design before any further launch, I am available -- same methodology as today, no live exploitation, just a read-through against the documented invariants."]
```

**Why the fortress framing works (Upshift case study):**

The Upshift FORTRESS email was sent at 02:00 UTC, ~30 hours after Alex's 19:44 acknowledgement. The team was actively patching when the email arrived. The email did three things simultaneously:

1. **Recognized the patch sprint publicly.** "Your team moved on it inside 30 hours of acknowledgement. I want that on the record." This is a non-monetary credit transfer. Engineers love being recognized for shipping fast.

2. **Surfaced the remaining live primitives without re-shaming.** "I am flagging two items that don't show patch signals yet, in case they are scheduled for a later batch." The framing is "I trust you have a plan, just confirming these are on it" -- not "you missed these".

3. **Opened the door for the wider engagement.** The 3 delivery options (tarball / batches / per-theme calls) put the team in control of the cadence. They cannot say no to all three; the path of least resistance is to pick one.

The ex-gratia outcome conversation is naturally delayed to AFTER the team picks a delivery format. Asking for money in the fortress email closes the door. Letting the engagement deepen first opens the door wider.

## State machine for the disclosure thread

| State | Trigger to enter | Action | Trigger to exit |
|---|---|---|---|
| `awaiting_ack` | Stage 1 sent | Wait 14 days | Ack received → `acked`. 14 days silence → `silent_pending_escalation` |
| `silent_pending_escalation` | 14 days no ack | Send Stage 2 LinkedIn DM | DM acked → `acked`. 7 more days silence → `re_verification_due` |
| `re_verification_due` | 30+ days since Stage 1 | Send Stage 3 re-verification email | Response → `acked`. Continued silence → `escalation_required` |
| `acked` | Substantive response received | Provide requested format / answer questions | Patches deployed → `partially_patched` or `fully_patched` |
| `partially_patched` | Some primitives patched, others still live | Continue thread, surface what's still live in normal cadence | All primitives patched → `fully_patched` |
| `fully_patched` | All disclosed primitives patched | Send Stage 4 fortress email within 24-48h | Team picks delivery format → `engagement_active` |
| `engagement_active` | Team picked delivery format for the rest of bundle | Deliver per chosen format, deepen the thread | All findings delivered + closed → `engagement_closed` |
| `engagement_closed` | All findings delivered and triaged | Wind down, stay available for re-verification on future patches | Memory marker -- protocol joins "alumni" status |
| `escalation_required` | Stage 3 silent past 10 days | Last-resort: investor contacts, light public mention via gated post on hunter forums | Resolved or formally abandoned |

**Update the per-engagement memory file (`project_<target>.md`) on every state transition.** See MEMORY-PROTOCOL.md.

## Channel ladder

| Channel | When to use |
|---|---|
| `security@target.com` | Stage 1 default if it exists |
| `security.txt` listed contact | Stage 1 if security@ does not exist |
| Direct CTO/CEO email (from LinkedIn or GitHub commits) | Stage 1 if no security infrastructure |
| LinkedIn DM | Stage 2 escalation |
| Personal email of executive (if discoverable) | Stage 3 if Stage 2 silent |
| Twitter DM | Last resort, only if executive maintains active Twitter |
| Investor contact | Last resort escalation only, AFTER Stage 3 silent past 10 days |
| Public gated post (hunter forums, e.g., Cantina internal) | Last resort, never first |
| Full public disclosure | Only after 90+ days of substantive non-engagement, with documented timeline |

The channel choice signals trust. Starting with security@ signals "I am following protocol". Jumping straight to LinkedIn signals "I do not trust your support process". Choose carefully -- the wrong channel at the wrong stage poisons the relationship.

## What never to do

1. **Never publish before you have given the protocol meaningful time** -- 90 days minimum, longer if engagement is active and patches are landing.
2. **Never demand bounty in the disclosure email.** State your terms ("no demand, but ex-gratia welcome") once and move on.
3. **Never include all 40+ findings in the first email.** Top 3 max. The rest comes after engagement.
4. **Never re-send the same email if you don't get a response.** The escalation path is channel-change, not channel-repeat.
5. **Never lie about the verification state.** If you have not re-verified in N days, say so. If a primitive is ambiguous, say so. Epistemic precision is what makes the disclosure undismissable.
6. **Never use em-dashes.** Run the sed sweep before every send.
7. **Never reference a previous contact's silence directly in the escalation.** "I sent a disclosure on [date] and you ignored it" is wrong. "I sent a disclosure on [date]; flagging here in case it routed to a low-priority queue" is right. The silence is the recipient's problem to acknowledge or not.
8. **Never threaten public disclosure as leverage.** Coordinated-disclosure timeline is implicit in the procedural posture, not weaponized.
9. **Never combine the patch verification and the "you should pay me" message.** The fortress email opens the door; the ex-gratia conversation comes naturally as the engagement deepens.
10. **Never sign with a fake corporate signature block.** First name only. The findings carry the credentials.
