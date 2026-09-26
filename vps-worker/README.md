# Bounty Intake — VPS worker

Headless drain worker for the **Bounty Intake** page (the claude.ai Artifact whose bar you paste
target links into). The page is only the queue; this worker does the real triage in the background,
with no terminal open on your laptop.

```
[Artifact page: paste link]  ->  (shared db: status=pending)  ->  [VPS worker: headless claude -p]
        instant                                                     1. read pending  (ArtifactData)
                                                                    2. resolve scope  (Cantina API | Immunefi mirror)
                                                                    3. class + saturation + GO/NO-GO/RE-SOURCE + advice
                                                                    4. write card back (status=done)  -> board updates live
```

## Why a VPS
The worker is a headless `claude -p` run on a schedule. It needs an always-on machine — your Hostinger
VPS. No browser is required for the common case: Cantina is read from its public API, Immunefi from a
local JSON mirror of the program index (both browser-less). A target that truly needs a logged-in
browser is written back with `needs_browser:true` instead of being guessed.

## Deploy
1. Put this repo on the VPS (e.g. `git clone <this repo> ~/bug-bounty-methodology`).
2. `cd ~/bug-bounty-methodology/vps-worker && ./install.sh`
3. Edit `.env` (ARTIFACT_URL is already set; pick CLAUDE_PERM_FLAGS).
4. Authenticate Claude Code on the VPS: run `claude` once and log in, **or** export
   `CLAUDE_CODE_OAUTH_TOKEN` (make it with `claude setup-token` where you're logged in).
5. **`./verify.sh` — must print ALL GREEN.** This is the gate: it proves the headless run can reach
   the queue with `ArtifactData`. Do not enable the timer until it passes.
6. Enable the timer (systemd) or cron — see `install.sh` output.

## The permission reality
A server has no one to answer permission prompts. `--permission-mode acceptEdits` (default) may still
block Bash/tool calls. For a genuinely unattended worker on an **isolated** VPS, set
`CLAUDE_PERM_FLAGS=--dangerously-skip-permissions` in `.env`. That grants the headless agent full tool
access — only do it on a machine dedicated to this, never your daily box.

## What it does / does NOT do
- DOES: read the queue, resolve scope/impacts/audits, class + saturation, GO/NO-GO/RE-SOURCE verdict,
  one-paragraph advice, all in English, written back to each card live.
- DOES NOT push to your drift-watch/git. When a target warrants drift-watch, it appends a line to
  `drift-proposals.tsv` and flags `drift_proposal:true`. You promote proposals manually (auto-push
  from an autonomous agent is deliberately off in v1).
- NEVER fabricates: unresolved scope -> `needs_browser:true`, never invented.

## Files
- `drain-prompt.md`  the worker's instructions (English). `__ARTIFACT_URL__` is filled by worker.sh.
- `worker.sh`        one drain run (flock single-flight); invoked by the timer/cron.
- `verify.sh`        pre-flight gate (claude present, authed, ArtifactData headless OK).
- `rapide-resolve.sh` browser-less program resolver (Cantina API / Immunefi mirror / GitHub).
- `install.sh`, `bounty-intake-worker.{service,timer}`, `.env.example`.
- `drift-proposals.tsv`  (created at runtime) proposed drift-watch rows awaiting manual promotion.

## Depth
v1 here is **Full** (intake + scope + saturation + advice). It reuses the same shared db as the local
v1; the only change from local is that the worker runs unattended on the VPS and writes English.
