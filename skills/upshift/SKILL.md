---
name: upshift
description: End-to-end methodology for engaging DeFi protocols with off-chain orchestration (delta-neutral stables, RWA tokenized accounts, yield aggregators with keepers, LRTs, perp DEXes, vault curators). Codifies the Upshift Finance engagement that produced 48 findings, ack in 24h, and patches in 30h. Use when target has the profile: backend that signs on-chain transactions in response to off-chain events, executor/operator wallet pattern, contracts audited by a known firm but API/infra/frontend treated as a normal web project. Auto-orchestrates /gravedigger, /mrrobbot, /disclose. Includes immortal-mode discipline and live re-verification monitor for active disclosures.
---

# Upshift -- DeFi Off-chain Orchestration Hunt + Disclose + Harden

You are executing the Upshift methodology -- a full-engagement playbook for a specific class of DeFi target where the API, infra, frontend, and operator wallet layer constitute the real attack surface, not the smart contracts (which are usually audited by a known firm). This methodology was extracted from the Upshift Finance engagement: $308M TVL, 48 findings (7 Criticals, ~10 Highs, ~31 Mediums/Lows), acknowledgement from the Co-CEO in 24h after 51 days of silence, patches landed within 30h.

The core insight: **DeFi protocols in 2026 audit their contracts to death and treat their backend like a normal web project.** This skill exploits the gap. It does not work against well-architected protocols (Monetrix-style) and is not designed for them. It works against the architectural shape that has $50M+ TVL routed through a FastAPI/Express backend with one or more executor wallets.

**Immortal mode is the rule, not the exception.** This skill explicitly forbids the stop conditions that produce 12-finding engagements instead of 48-finding engagements. See `IMMORTAL-MODE.md`.

## Arguments

```
/upshift <target>                 # full engagement on <target> (default action)
/upshift --queue                  # show current target queue from memory
/upshift --triage <target>        # 30-min scoring pass on a candidate (0-10)
/upshift --engage <target>        # explicit full engagement (same as bare invocation)
/upshift --reverify <target>      # re-verify primitives on already-disclosed target
/upshift --monitor                # show all active disclosures + state
/upshift --fortress <target>      # send fortress follow-up email (post-ack engagement window)
/upshift --reference              # read UPSHIFT-REFERENCE.md (gold-standard walkthrough)
```

## Skill Resources

Read companion files per phase. SKILL.md is the entry point and the only file you must read first; everything else is per-phase consultation.

| File | Purpose | When to Read |
|------|---------|-------------|
| `UPSHIFT-REFERENCE.md` | Annotated walkthrough of the original Upshift engagement -- gold-standard reference | Read once before first engagement; re-read on `--reference` |
| `TARGET-SELECTION.md` | Candidate profile + triage scoring rubric + queue mechanism | Phase 0 -- before committing to engagement |
| `SURFACE-ATTACK-PATTERNS.md` | The 10 vector taxonomy with executable grep/curl/eth_call kits | Phase 2 -- surface scan; Phase 4 -- live re-verification |
| `HUNT-METHODOLOGY.md` | 4-pass discipline (primary → expansion → mirror invariant → chain construction) | Phase 3 -- the hunt itself |
| `IMMORTAL-MODE.md` | The 5 anti-stop guards. **Read this before every hunt session.** | Phase 3 -- anti-stop checkpoint at every "should I stop?" moment |
| `DISCLOSURE-PROTOCOL.md` | 4-stage disclosure flow with kabayanerve-voice email templates | Phase 6 -- disclosure execution |
| `RE-VERIFICATION-MONITOR.md` | Daily cron logic for active disclosures + state machine + drift alerts | Phase 7 -- post-disclosure monitoring; ongoing |
| `WORKSPACE-TEMPLATE.md` | Directory structure init for an Upshift-class engagement | Phase -1 -- workspace bootstrap |
| `MEMORY-PROTOCOL.md` | Per-engagement memory file conventions + cross-engagement queue maintenance | Phase 0, Phase 6, Phase 7 -- memory updates |

External gates (referenced per finding, not duplicated here):

| File | Purpose | When |
|------|---------|------|
| `~/Desktop/BUGS/KILL-GATE-TEMPLATE.md` | 10-question false positive elimination | Per finding candidate, before deep-dive |
| `~/Desktop/BUGS/PREFLIGHT-CHECK.md` | 24-point quality gate | Per finding, before submit |
| `~/Desktop/BUGS/CHAIN-PROOF-GATE.md` | D7 for auth-class findings | Per finding in auth-bypass / IDOR / signature-forge / JWT class |
| `~/Desktop/BUGS/WEIGHT-CARD.md` | D8 numerical anchor | Per finding claiming severity ≥ Low with dollar impact |
| `~/Desktop/BUGS/REPORT-STANDARD.md` | kabayanerve voice template | All report writing |

External playbooks (referenced for their coverage, not duplicated):

| File | What it covers (referenced for our vectors) |
|------|--------------------------------------------|
| `~/Desktop/BUGS/INFRA-ADJACENT-TO-SC-PLAYBOOK.md` | Relayers/oracles/RPCs/indexers/keepers/MPC -- ref for V3, V6, V10 |
| `~/Desktop/BUGS/WEB2-ON-SC-PROGRAMS-PLAYBOOK.md` | Web2 layer on bounty programs -- ref for V1, V2, V7, V8 |
| `~/Desktop/BUGS/DEFI-FULLSTACK-CHECKLIST.md` | Full-stack DeFi audit -- ref for V2 (API), V5 (staging) |
| `~/Desktop/BUGS/CRITICAL-HUNT-CHECKLIST.md` | Smart contract patterns -- ref for Phase 3 SC drilldown (NAV class) |

Skill orchestration (invoke when the phase says so, do not duplicate their work):

| Skill | When to invoke |
|-------|---------------|
| `/gravedigger` | Phase 1 -- recon (phases 0-2 of gravedigger). Pass target hints `upshift-class defi-orchestration executor-wallet` |
| `/mrrobbot` | Phase 3 -- if smart contracts are in scope, drill into the SC layer |
| `/disclose` | Phase 5 -- per-finding report formatting |
| `/expand-surface` | Phase 3 stall -- if hunt produces fewer than 10 findings after pass 2, check for a novel surface (AA, ZK, MPC) |

## Phase Flow

```
Phase -1: Lifecycle init                    SKILL.md → ~/arsenal/audit-lifecycle/bin/init-target.sh
Phase  0: Target selection                  TARGET-SELECTION.md → memory queue
Phase  1: Recon                             /gravedigger phases 0-2 with Upshift hints
Phase  2: Surface scan (10 vectors)         SURFACE-ATTACK-PATTERNS.md, all in parallel
Phase  3: Hunt (4-pass)                     HUNT-METHODOLOGY.md + IMMORTAL-MODE.md guards
Phase  4: Verify findings live              SURFACE-ATTACK-PATTERNS.md re-verification subset
Phase  5: Report (per finding)              /disclose with REPORT-STANDARD.md voice
Phase  6: Disclose (4-stage protocol)       DISCLOSURE-PROTOCOL.md
Phase  7: Monitor (re-verification cron)    RE-VERIFICATION-MONITOR.md
Phase  8: Harden (fortress delivery)        DISCLOSURE-PROTOCOL.md stage 4
```

### Phase -1: Lifecycle init (mandatory first action)

Per CLAUDE.md rule #38, the FIRST command of any new target engagement is the lifecycle init. This bootstraps the workspace, emits ROUTING.md, and primes OUTCOMES.jsonl.

```bash
TARGET_HINTS="upshift-class defi-orchestration executor-wallet web api defi" \
  ~/arsenal/audit-lifecycle/bin/init-target.sh <target>
```

Then read `WORKSPACE-TEMPLATE.md` and create the Upshift-specific subdirectories on top of the standard lifecycle workspace.

### Phase 0: Target selection

Before committing 40h+ to an engagement, score the candidate:

```bash
/upshift --triage <target>
```

This invokes the rubric in `TARGET-SELECTION.md`. Score 7+ proceeds; 4-6 deferred to queue; 0-3 dropped.

If you bypass triage (e.g., `/upshift --engage <target>` directly), you take responsibility for the time investment without the safety check.

### Phase 1: Recon (delegate to /gravedigger)

Invoke `/gravedigger <target>` with phases 0-2 only. Pass the Upshift hints in the workspace's ROUTING.md so gravedigger biases recon toward backend orchestration patterns. Output expected: protocol intelligence + surface map + initial JS bundle inventory + subdomain enumeration.

Do NOT duplicate gravedigger's work here. The skill orchestrates; gravedigger executes.

### Phase 2: Surface scan (10 vectors in parallel)

Read `SURFACE-ATTACK-PATTERNS.md`. Each vector has an executable kit. Run all 10 in parallel where possible (separate Bash calls in a single message). Capture output per vector to `evidence/web/{vector}/`.

The 10 vectors:
- V1 Bundle harvest
- V2 Unauth API endpoint sweep
- V3 Operator wallet audit
- V4 Off-chain → on-chain trigger trace
- V5 Staging/dev backend recon
- V6 Lambda/serverless surface
- V7 SIWE/auth state machine
- V8 Slack/PagerDuty/notification webhook leak
- V9 Sentry/analytics correlation
- V10 Proxy governance chain

### Phase 3: Hunt (4-pass methodology) -- IMMORTAL MODE

Read `HUNT-METHODOLOGY.md` and `IMMORTAL-MODE.md` BEFORE starting Phase 3. The methodology is:

**Pass 1: Primary scan.** Apply the 10 vectors. Open finding files for each hit.

**Pass 2: Expansion.** Re-scan with focus on patterns missed in Pass 1: proxy governance chain, RPC keys, multi-RPC, operator wallet, naming deception (the NEW-01-05 class from Upshift). Read `~/Desktop/BUGS/INFRA-ADJACENT-TO-SC-PLAYBOOK.md` for additional ideas.

**Pass 3: Mirror invariant audit.** Per CLAUDE.md rule #41 + IMMORTAL-MODE.md. For every bidirectional pair in the protocol (GET/POST, staging/prod, validator coverage, ingress/egress, deposit/withdraw, mint/burn), enumerate validation sets V_in and V_out side-by-side. Asymmetry without articulable design reason = finding candidate.

**Pass 4: Chain construction.** Combine 2+ findings into amplified attack chain. The Upshift F1+W34=$308M chain is the template. Look for: A enables auth, B enables on-chain action, A+B = exploit primitive.

After each pass, IMMORTAL-MODE.md guards apply. **Do not exit Phase 3 until at least 3 passes have completed AND the immortal-mode self-test confirms "code is solid" (not "I haven't dug deep enough yet")**. The signals that say "code is solid": forge lint shows 0 unsafe casts on the hot path, internal consistency metric is 100% (every protected primitive has a protected sibling), mirror invariant coverage is exhaustive (every bidirectional pair has explicit asymmetry justification or is symmetric). If ANY of these is not yet measured, you have not finished Phase 3.

### Phase 4: Verify findings live

For every finding, re-run its detection kit ONE MORE TIME against live production immediately before report writing. This catches: the protocol pre-emptively patched while you were drafting (rare); your initial test was wrong (more common); the finding is a flaky environmental artifact (rare).

`SURFACE-ATTACK-PATTERNS.md` includes a re-verification subset for each vector.

### Phase 5: Report

Invoke `/disclose` per finding. Use `~/Desktop/BUGS/REPORT-STANDARD.md` voice (kabayanerve, first-person, no em-dashes, no corporate filler, "I have confirmed" / "I have not confirmed", evidence inline, anti-pattern naming).

Combined-chain findings (like F1+W34) ship as ONE report with both primitives + the combined attack narrative, not two separate reports. The triager processes one chain story faster than two disconnected pieces.

### Phase 6: Disclose (4-stage protocol)

Read `DISCLOSURE-PROTOCOL.md`. Execute:
- **Stage 1:** Initial email to first-found security contact. If no security@/SECURITY.md/security.txt exists, the candidate scoring should have caught it; pivot to LinkedIn-DM-first if not.
- **Stage 2:** Silent-escalation if no response in 14 days -- LinkedIn DM to Co-CEO with `<silent disclosure on a Critical -- needs your direct attention>` subject. Do not threaten public disclosure.
- **Stage 3:** Re-verification email at day N+30 (or N+50 like Upshift if circumstances delay) -- re-confirm primitives are still live, attach updated proof, link the original thread.
- **Stage 4:** Fortress follow-up sent within 24-48h of patch acknowledgement -- offer remaining bundle in 3 formats (full tarball / severity-tiered batches / per-theme architectural calls). The "fortress" framing converts patch transaction into hardening engagement.

### Phase 7: Monitor (re-verification cron)

Read `RE-VERIFICATION-MONITOR.md`. Per active disclosure, register a daily check that verifies primitives live. State machine: `awaiting_ack` → `acked` → `partially_patched` → `fully_patched` → `engagement_closed`, with `escalation_required` as a side-state.

The monitor is the timing engine for Stage 4 fortress follow-ups. It says "team patched primitive X in 30h, FORTRESS window is open NOW, send the follow-up within 24-48h before engagement attention dissipates."

### Phase 8: Harden (fortress delivery)

If the sponsor accepts the fortress framing in their reply to Stage 4, deliver the remaining bundle in their chosen format:
- **Full tarball:** ship `~/Desktop/BUGS/<target>-recon/evidence/<date>-<target>-evidence.tar.gz` (PGP-encrypted if they sent a key)
- **Severity-tiered batches:** ship 3 emails over 1-2 weeks, HIGHs first then MEDIUMs then LOWs
- **Per-theme architectural calls:** schedule 1 call per architectural theme (operator key architecture, proxy governance, auth state machine, API surface posture, on-chain↔off-chain reconciliation, staging hygiene). Each call = walk through findings + remediation + verification methodology

This phase is where the engagement becomes ex-gratia-worthy in scale (typically $50K-$250K range for well-engaged Upshift-class targets).

## Auto-activation triggers

Beyond explicit `/upshift` invocation, this skill auto-activates when:
- `/gravedigger` Phase 0 detects: FastAPI/Express backend AND Solidity contracts in scope AND executor/keeper/operator wallet pattern (any role granted with `MINTER`, `MANAGER`, `KEEPER`, `OPERATOR`, `EXECUTOR` semantics, EOA-typed)
- `/mrrobbot` Phase 0 detects same
- User mentions in conversation: "DeFi protocol with backend", "executor wallet", "operator EOA controlling vault", "off-chain orchestration", "delta-neutral hedge with backend", "RWA tokenized account with operator"

When auto-activated, route to `/upshift --triage <target>` first to confirm the candidate matches the profile.

## Memory integration

Per `MEMORY-PROTOCOL.md`:
- `~/.claude/projects/-home-malix-Desktop-BUGS/memory/project_<target>.md` -- one file per active engagement, follows `project_upshift_finance.md` template
- `~/.claude/projects/-home-malix-Desktop-BUGS/memory/upshift_target_queue.md` -- cross-engagement queue, manually curated

Update memory at: Phase 0 (queue update), Phase 6 (disclosure timeline), Phase 7 (monitor state), Phase 8 (harden delivery).

## Anti-patterns (forbidden by this skill)

The following stop conditions are explicitly forbidden when running `/upshift`. They are the conditions that produce 12-finding engagements:

1. **"I found 3 Criticals, that's enough."** No. Pass 2 and Pass 3 are mandatory before Phase 4.
2. **"This target is taking too long."** Time is not a stop condition for Upshift-class targets. See IMMORTAL-MODE.md.
3. **"This bug is theoretical, skip it."** Wrong layer. Theoretical bugs that don't ship still inform the architectural narrative for fortress follow-up. Apply theoretical-bug-kill ONLY at submission gate.
4. **"The protocol is well-architected."** Verify with concrete signals before declaring this. If forge lint is silent, internal consistency is 100%, and mirror coverage is exhaustive, the verdict stands. Otherwise it is a guess.
5. **"This is operator-trusted, OOS."** Read DISCLOSURE-PROTOCOL.md anti-dismissal section. Many "operator-trusted" findings are actually contract-level whitelist bypasses that the operator's trust does not cover.

## Reference engagement

For the gold-standard walkthrough of how this methodology was applied end-to-end on Upshift Finance (target identification, recon, hunt across 10 vectors, 4-pass methodology, 4-stage disclosure, fortress follow-up, patch verification), read `UPSHIFT-REFERENCE.md`. It captures the timeline, decisions, and what almost killed the engagement (51 days of silence at Stage 2). The skill files are designed so that re-running Upshift today using only the skill files would produce the same outcome.
