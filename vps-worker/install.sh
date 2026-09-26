#!/usr/bin/env bash
# One-time setup on the VPS. Idempotent.
set -euo pipefail
cd "$(dirname "$0")"
echo "== Bounty Intake VPS worker — install =="

command -v claude >/dev/null || { echo "Install Claude Code first:  npm i -g @anthropic-ai/claude-code"; exit 1; }
echo "claude: $(claude --version)"

[ -f .env ] || { cp .env.example .env; echo "Created .env — edit ARTIFACT_URL / CLAUDE_PERM_FLAGS before continuing."; }
# shellcheck disable=SC1091
set -a; . ./.env; set +a

MIR="${IMMUNEFI_MIRROR:-$HOME/immunefi-mirror}"
if [ ! -d "$MIR" ]; then
  echo "Cloning Immunefi JSON mirror -> $MIR (browser-less Immunefi scope)"
  git clone --depth 1 https://github.com/infosec-us-team/Immunefi-Bug-Bounty-Programs-Unofficial "$MIR" || \
    echo "  (clone failed — Immunefi targets will set needs_browser:true until the mirror exists)"
fi

echo
echo "Next:"
echo "  1) ./verify.sh                 # confirm claude auth + ArtifactData headless (must be ALL GREEN)"
echo "  2a) systemd (recommended):"
echo "       mkdir -p ~/.config/systemd/user"
echo "       cp bounty-intake-worker.service bounty-intake-worker.timer ~/.config/systemd/user/"
echo "       systemctl --user daemon-reload && systemctl --user enable --now bounty-intake-worker.timer"
echo "       loginctl enable-linger \$USER   # keep the timer running while logged out"
echo "  2b) cron alternative:"
echo "       (crontab -l 2>/dev/null; echo \"*/3 * * * * $(pwd)/worker.sh\") | crontab -"
echo
echo "Logs: tail -f $(pwd)/worker.log"
