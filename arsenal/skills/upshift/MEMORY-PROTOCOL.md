---
name: memory-protocol
description: Per-engagement memory file conventions. project_<target>.md follows the upshift template (status, primitives table, disclosure timeline, patch verification table, files staged for delivery, lessons encoded). upshift_target_queue.md tracks the cross-engagement queue. MEMORY.md index gets one-line entries per active engagement. State transitions trigger memory updates.
---

# Memory protocol -- per-engagement memory conventions

## Why this matters

The Upshift engagement spanned 51+ days with three multi-week silences in between. Without `~/.claude/projects/-home-malix-Desktop-BUGS/memory/project_upshift_finance.md`, every re-engagement would have started cold. The memory file is what keeps the relationship state coherent across compactions, sessions, and weeks of waiting.

Every Upshift-class engagement gets its own memory file. The `upshift_target_queue.md` tracks the cross-engagement queue. `MEMORY.md` (index) gets a one-line pointer per engagement.

## File 1: per-engagement memory file

Path: `~/.claude/projects/-home-malix-Desktop-BUGS/memory/project_<target>.md`

The file structure mirrors the existing `project_upshift_finance.md` (which is the reference template). Required sections:

```markdown
---
name: <Target Name> Disclosure Status
description: <One-line description of the engagement, current state, headline finding, current contact, expected next event>
type: project
originSessionId: <UUID of the session that initialized this memory>
---

## Current status (<date>)

<1-2 paragraphs describing where the engagement stands today.>

**ACK status:** <pending / received on <date> by <who>>
**Last comms direction:** <inbound / outbound / quiet>
**Next event awaited:** <what we are waiting for, by when>
**Engagement state:** <pre_engagement / awaiting_ack / acked / partially_patched / fully_patched / engagement_active / engagement_closed>

### Patch verification (<date>)

| Primitive | Pre-patch | Post-patch | Status |
|---|---|---|---|
| F1 [name] | <observation> | <observation> | NEUTRALIZED / PATCHED / STILL_LIVE / AMBIGUOUS |
| ... | ... | ... | ... |

**Combined-chain `<headline>` →** BROKEN / PARTIAL / STILL REACHABLE.

### What this means

<Strategic interpretation of the patch state -- what does it tell us about the team's engagement, severity recognition, willingness to deepen the engagement>

## Worst-case combined chain (re-verified <date>)

<Restate the headline chain in concise form. This is the load-bearing paragraph for any future session that has lost the conversation context.>

## Primitives (each with detection + status)

### F1 (CRITICAL) -- <name>

<2-paragraph description: detection, current status, severity context>

### F2 (CRITICAL, chains with F1) -- <name>

<Same structure>

### F3 (HIGH) -- <name>

<Same structure>

[... continue for every primitive that is currently in the disclosure scope ...]

## Disclosure timeline

| Date | Event |
|---|---|
| <YYYY-MM-DD> | <event description> |
| ... | ... |

## Attached artifacts (from <date> email)

- `<artifact>.md` -- <description>
- ...

## Procedural posture (stated in <date> email)

- <bullet list of the procedural commitments made in the disclosure: no public writeup, PGP available, etc>

## Next actions

**If <recipient> responds within <window>:**
- <action 1>
- <action 2>

**If silence past <date>:**
- <action 1>

**If silent past <date>:**
- <escalation>

## Files staged for delivery (when <recipient> picks format)

### Option 1 -- full bundle
<path or description>

### Option 2 -- severity-tiered batches
<list of finding IDs per batch>

### Option 3 -- per-theme calls
<list of architectural themes with finding IDs each>

## Realistic expected value

<Range with reasoning>

## Lessons encoded

- **<Lesson name>:** <observation> -- references `feedback_<topic>.md` if applicable
- ...
```

## When to update the per-engagement memory file

| Event | Update |
|---|---|
| Stage 1 email sent | Add timeline row, set state to `awaiting_ack`, set "next event awaited" |
| Stage 2 LinkedIn DM sent | Add timeline row, no state change |
| Ack received | Set state to `acked`, update "ACK status", set "next event awaited" to fortress trigger |
| Drift alert (patch landed) | Update patch verification table, possibly transition to `partially_patched` or `fully_patched` |
| All primitives patched | Transition to `fully_patched`, set "next action" to fortress email within 24h |
| Stage 4 fortress email sent | Add timeline row, transition to `engagement_active`, set "next event awaited" to delivery format choice |
| Delivery format chosen by recipient | Update "files staged for delivery" with chosen format, update "next action" |
| Engagement closed | Transition to `engagement_closed`, update "lessons encoded", document final ex-gratia (if any) |

## File 2: cross-engagement queue

Path: `~/.claude/projects/-home-malix-Desktop-BUGS/memory/upshift_target_queue.md`

This file tracks ALL Upshift-class targets in any state (candidate, queued, active, closed). It is the master registry.

```markdown
---
name: Upshift-Class Target Queue
description: Cross-engagement registry of all targets matching the Upshift architectural pattern (off-chain orchestration with executor wallets). Tracks candidate / queued / active / closed status, triage scores, and engagement state per target. v1 alimentation manuelle per user instruction.
type: project
---

# Upshift-class target queue

## Active engagements

| Target | State | Triage | TVL | Acker | Last action | Next event | Memory file |
|---|---|---|---|---|---|---|---|
| Upshift Finance | engagement_active | 47/50 | $308M | Alex Elkrief (Co-CEO) | Fortress email sent 2026-04-25 02:00 UTC | Awaiting Alex's delivery format choice | [project_upshift_finance.md](project_upshift_finance.md) |

## Queued (triage score >= 35, awaiting engagement slot)

| Target | Score | TVL | Notes |
|---|---|---|---|
| _none yet -- v1 starts with Upshift only_ | | | |

## Triage backlog (candidates, not yet scored)

(See TARGET-SELECTION.md candidate pool. v1 does not auto-populate; user manually adds scored targets to "Queued" after running /upshift --triage.)

## Alumni (engagement closed)

| Target | Closed date | Final state | Ex-gratia | Lessons file |
|---|---|---|---|---|
| _none yet_ | | | | |

## Cross-engagement patterns

- **Methodology proven on Upshift:** 4-pass discipline + kabayanerve voice + fortress timing produces 48 findings, 24h ack, 30h patches, ex-gratia conversation open
- **Disclosure rhythm that worked:** Stage 1 → 14d → Stage 2 LinkedIn → Stage 3 re-verification at day 30+ → Stage 4 fortress within 24-48h of patch ack
- **Voice rules that landed:** first person, no em-dashes, evidence inline, anti-pattern naming, no bounty demand
```

## When to update the queue file

| Event | Update |
|---|---|
| New target manually added to candidate pool | No queue update (TARGET-SELECTION.md handles candidates) |
| /upshift --triage <target> runs | If score >= 35, add row to "Queued" table |
| /upshift --engage <target> runs | Move row from "Queued" → "Active engagements", create per-engagement memory file |
| Engagement closes | Move row from "Active" → "Alumni" with closed date + ex-gratia outcome + lessons file pointer |
| New cross-engagement pattern observed | Update "Cross-engagement patterns" section |

## File 3: MEMORY.md index update

Path: `~/.claude/projects/-home-malix-Desktop-BUGS/memory/MEMORY.md`

The master index gets one-line pointers per active Upshift-class engagement. Format (matches existing convention):

```markdown
- [<Target>](project_<target>.md) -- <state> + <severity tier of headline> + <current acker or "no contact"> + <next event awaited>
```

Example for Upshift (current entry, retained):
```markdown
- [Upshift Finance](project_upshift_finance.md) -- engagement_active, $308M chain BROKEN post-patch, Alex Elkrief acker, awaiting delivery format choice
```

When a new engagement starts, add a similar line under the Active section of MEMORY.md.

## Lessons-encoded files (per-engagement)

After an engagement closes (or even mid-engagement when a notable lesson emerges), create a `feedback_<target>_<lesson>.md` file:

```markdown
---
name: <Lesson title>
description: <One-line description of the lesson>
type: feedback
originSessionId: <UUID>
---

# <Lesson title>

## What happened

<Concrete description of the situation that produced the lesson>

## Why it matters

**Why:** <The reason this lesson is load-bearing -- typically an avoidable cost or a validated approach>

**How to apply:** <When/where this lesson kicks in for future engagements>

## Specifics

<Concrete commands, dates, dollar amounts, contact handles, etc. that anchor the lesson>

## Anti-pattern

<What NOT to do, named explicitly>

## Validated pattern

<What TO do, named explicitly>
```

Example lessons that came out of Upshift (one file each):
- `feedback_upshift_kabayanerve_voice_em_dash_purge.md` -- em-dashes are LLM signature, sed sweep before every send
- `feedback_upshift_fortress_timing_24_48h_window.md` -- fortress email sent within 24-48h of patch ack converts patch sprint into hardening engagement
- `feedback_upshift_47_day_silence_recovery_via_linkedin.md` -- Stage 2 LinkedIn DM after 14-day silence is the unlock for unresponsive teams
- `feedback_upshift_4_pass_discipline_vs_first_critical_stop.md` -- 4-pass discipline produces 48 findings vs 12 for normal hunters; never stop at first Critical
- `feedback_upshift_byte_identical_re_verification_strengthens_severity.md` -- re-verifying day N+50 with byte-identical primitives makes severity narrative undismissable

## Verifying the memory state before recommending action

Per CLAUDE.md memory rules, before acting on remembered facts:
- Verify the memory is still correct (re-read the source file or re-check the live state)
- A memory that names a specific endpoint, address, or contact is a claim about a moment in time -- verify before recommending

For Upshift-class engagements specifically: before sending ANY outbound communication, run the daily re-verification check from RE-VERIFICATION-MONITOR.md. The memory file's "patch verification" table should reflect today's state, not last week's.

## Memory updates that survive compaction

Compaction can drop arbitrary parts of the conversation context, but the memory files are persistent. The recovery pattern after compaction is:

1. Read `MEMORY.md` (always loaded)
2. Identify the active engagement(s) from the index
3. Read the per-engagement file(s)
4. Read `upshift_target_queue.md` for cross-engagement context
5. Run the daily re-verification check to confirm today's state matches the memory

This sequence reconstructs the engagement state in <2 minutes of reading. The voice, the cadence, the next-event-awaited, the contact relationship -- all preserved.

## What NOT to put in memory

Per CLAUDE.md auto-memory rules:
- No code patterns, file paths, or project structure (re-derivable from the workspace)
- No git history (`git log` is authoritative)
- No ephemeral task state (TaskCreate is for that)
- No CLAUDE.md content (already loaded)

For Upshift-class specifically: do NOT put the full report content, the full curl outputs, or the full PoC code in memory. Those go in the workspace at `~/Desktop/BUGS/<target>-recon/`. Memory files contain pointers and summaries, not artifacts.
