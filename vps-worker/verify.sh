#!/usr/bin/env bash
# Run this ONCE on the VPS before enabling the timer. Confirms the 3 prerequisites.
set -uo pipefail
cd "$(dirname "$0")"
[ -f .env ] || { [ -f .env.example ] && cp .env.example .env && echo "[.env created from .env.example — edit if needed]"; }
[ -f .env ] && { set -a; . ./.env; set +a; }
: "${ARTIFACT_URL:?set ARTIFACT_URL in .env (copy .env.example)}"
PERM="${CLAUDE_PERM_FLAGS:---permission-mode acceptEdits}"
echo "[1/3] claude CLI present"
command -v claude >/dev/null && claude --version || { echo "  FAIL: install Claude Code (npm i -g @anthropic-ai/claude-code)"; exit 1; }
echo "[2/3] claude authenticated (headless smoke)"
echo | timeout 90 claude -p "reply with exactly: OK" 2>/dev/null | grep -q OK \
  && echo "  auth OK" || { echo "  FAIL: run 'claude' once to log in, or export CLAUDE_CODE_OAUTH_TOKEN"; exit 1; }
echo "[3/3] ArtifactData usable headless (reads the live queue)"
OUT=$(timeout 180 claude -p "Load ArtifactData via ToolSearch (query select:ArtifactData), then call ArtifactData action=list collection=targets url=$ARTIFACT_URL . Output ONLY: COUNT=<number of documents>." \
  --allowedTools ToolSearch ArtifactData $PERM 2>&1)
if echo "$OUT" | grep -qE 'COUNT=[0-9]+'; then
  echo "  ArtifactData OK ($(echo "$OUT" | grep -oE 'COUNT=[0-9]+' | head -1))"
  echo "ALL GREEN — safe to enable the timer (systemctl --user enable --now bounty-intake-worker.timer)."
else
  echo "  FAIL: ArtifactData not usable headless. Last output:"; echo "$OUT" | tail -6
  echo "  -> If tools are blocked, set CLAUDE_PERM_FLAGS=--dangerously-skip-permissions in .env (isolated VPS only) and retry."
  exit 2
fi
