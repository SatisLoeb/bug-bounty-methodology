---
name: protocole-forteresse-mandatory-hook
description: PreToolUse Skill hook injects the fortress-protocol mandatory-read directive before every hunting skill
metadata: 
  node_type: memory
  type: project
  originSessionId: 123dd578-164e-4675-8beb-aa21faeef483
---

A `PreToolUse` hook on the `Skill` tool in `~/.claude/settings.json` (installed 2026-07-05) injects a mandatory-read directive for `~/Desktop/BUGS/PROTOCOLE-FORTERESSE-v2.md` before any HUNTING skill runs. So when a Skill call carries a "PROTOCOLE FORTERESSE v2 - lecture OBLIGATOIRE" system-reminder, that's this hook — comply: Read the full protocol and apply its sequence.

Mechanism: the matcher only matches the tool name (`Skill`), so scoping-by-skill is done inside the command (jq on `.tool_input.skill`). It fires on every skill EXCEPT a denylist of harness utilities (update-config, keybindings-help, find-skills, claude-api, dataviz, artifact-design, claude-in-chrome, init, statusline-setup, fewer-permission-prompts, loop, schedule, run, verify, code-review, simplify, review, security-review). statusMessage "Protocole Forteresse v2 - lecture obligatoire" shows in the spinner when it fires.

To change scope: edit the `deny` array in the hook command. To make it literally every skill: empty the array. To flip to an allowlist: invert the jq condition. Machine-local (this machine's `~/.claude/settings.json`); replicate on machine-2 if wanted. See [[protocole-forteresse-v2]] and [[skill-infrastructure-topology]].

**2026-07-05 — the hook is NOT the persistence layer; it only fires at SKILL-start.** Operator flagged: the protocol rules don't persist during an engagement the way a skill's do, and a Bash/Workflow-driven hunt (e.g. Monad) NEVER invokes a skill → the hook never fires → the gates were never live → I made the reachability-kill-gate mistake ([[feedback-reachability-is-kill-gate-not-severity-modifier]]). Root cause: a passive protocol file decays out of context mid-engagement, and the failure was in PROSE reasoning (recommending "submit") which no tool-hook can catch. FIX: the compact **Forteresse hunt gate-card** (CP1→G12 one load-bearing line each + the 3 terminal verdicts + doctrine) + the reachability-kill-gate detail now live in `~/Desktop/BUGS/CLAUDE.md` (the persistently re-injected `claudeMd` channel) — so the gates accompany EVERY phase of every hunt, during reasoning, skill-invoked or not. Design principle: **persistent channel (CLAUDE.md) = compact gate-card (always live); protocol file = full detail (read on invocation); hook = skill-start read-directive only.** The full 145-line protocol stays in the file to avoid bloating the persistent channel.
