#!/bin/bash
# bounty-monitor.sh — Check for new bug bounty programs across platforms
# Usage: ./bounty-monitor.sh [--notify]
# Run via cron: */30 * * * * /path/to/bounty-monitor.sh --notify >> /tmp/bounty-monitor.log

set -uo pipefail

STATE_DIR="$HOME/.bounty-monitor"
mkdir -p "$STATE_DIR"

NOTIFY=0
[[ "${1:-}" == "--notify" ]] && NOTIFY=1

RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
NC='\033[0m'

check_new() {
  local platform="$1"
  local url="$2"
  local state_file="$STATE_DIR/${platform}.hash"

  local content
  content=$(curl -s "$url" --max-time 15 2>/dev/null | head -5000)

  if [[ -z "$content" ]]; then
    return
  fi

  local current_hash
  current_hash=$(echo "$content" | md5sum | cut -d' ' -f1)

  if [[ -f "$state_file" ]]; then
    local prev_hash
    prev_hash=$(cat "$state_file")
    if [[ "$current_hash" != "$prev_hash" ]]; then
      echo -e "${RED}[NEW]${NC} $platform has changes! Check: $url"
      if [[ $NOTIFY -eq 1 ]]; then
        # Desktop notification (Linux)
        notify-send "Bounty Monitor" "$platform has new programs!" 2>/dev/null || true
      fi
    fi
  else
    echo -e "${GREEN}[INIT]${NC} $platform — baseline saved"
  fi

  echo "$current_hash" > "$state_file"
}

echo "========================================"
echo " Bounty Monitor — $(date '+%Y-%m-%d %H:%M')"
echo "========================================"

# Cantina bounties
check_new "cantina-bounties" "https://cantina.xyz/bounties"

# Cantina competitions
check_new "cantina-competitions" "https://cantina.xyz/competitions"

# HackenProof programs
check_new "hackenproof" "https://hackenproof.com/programs"

# Code4rena audits
check_new "code4rena" "https://code4rena.com/audits"

# Sherlock contests
check_new "sherlock" "https://audits.sherlock.xyz/contests"

# Hats Finance
check_new "hats-finance" "https://app.hats.finance/bug-bounties"

echo ""
echo "Done. State saved in $STATE_DIR/"
