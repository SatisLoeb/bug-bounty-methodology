#!/usr/bin/env bash
# Bounty Intake VPS worker — drains the intake queue via a headless Claude Code run.
# Runs from cron or a systemd timer. Single-flight via flock.
set -uo pipefail
cd "$(dirname "$0")"
[ -f .env ] || { [ -f .env.example ] && cp .env.example .env; }
[ -f .env ] && { set -a; . ./.env; set +a; }
: "${ARTIFACT_URL:?set ARTIFACT_URL in .env (copy .env.example)}"
LOG="${WORKER_LOG:-./worker.log}"
LOCK="${WORKER_LOCK:-/tmp/bounty-intake-worker.lock}"
PERM="${CLAUDE_PERM_FLAGS:---permission-mode acceptEdits}"
exec 9>"$LOCK"; flock -n 9 || { echo "$(date -u +%FT%TZ) already running, skip" >>"$LOG"; exit 0; }
PROMPT="$(sed "s|__ARTIFACT_URL__|$ARTIFACT_URL|g" drain-prompt.md)"
echo "=== $(date -u +%FT%TZ) drain start ===" >>"$LOG"
# shellcheck disable=SC2086
timeout "${WORKER_TIMEOUT:-900}" claude -p "$PROMPT" \
  --allowedTools ToolSearch ArtifactData Bash Read Write Edit WebFetch \
  $PERM --output-format text >>"$LOG" 2>&1
echo "=== $(date -u +%FT%TZ) drain end rc=$? ===" >>"$LOG"
exit 0
