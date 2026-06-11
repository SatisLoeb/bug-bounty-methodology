#!/usr/bin/env bash
# ai-bot-check.sh — Detect AI auditor bots (V12, Zellic V12, Olympix, Cantina AI)
# installed on a target repo. If detected, SC findings in V12-covered classes
# are structurally high dupe-risk (feedback_v12_ai_auditor_dupe_risk.md).
#
# Enforces CLAUDE.md Step 0 Target Assessment Card.
#
# Usage:
#   ai-bot-check.sh <owner/repo>                    # Check one repo
#   ai-bot-check.sh --url <github-url>              # Check from URL
#   ai-bot-check.sh --workspace <path>              # Check target associated with workspace
#
# Exit codes:
#   0 — No AI bot detected → SC hunting PROCEED on all classes
#   1 — AI bot detected   → Downgrade V12-covered classes, route to uncovered classes
#   2 — Could not determine (rate limit, private repo, etc.) — manual verification required
#
# V12-COVERED classes (deprioritize on bot-detected targets):
#   - Access control / authorization
#   - Input validation
#   - Reentrancy (classic single-contract)
#   - Unchecked arithmetic / overflow
#   - Inline assembly DoS
#   - Transient storage reuse
#   - Missing tokenIn==tokenOut validation
#
# V12-UNCOVERED classes (still viable — target these):
#   - Logic bugs (business rule violations)
#   - Economic problems (incentive misalignment, fee extraction)
#   - Design flaws (architectural mistakes)
#   - Cryptographic mistakes
#   - Cross-chain interactions
#   - MEV / sandwich / timing
#   - Oracle manipulation (non-standard)
#   - Governance / upgrade chains

set -euo pipefail

BOLD=$(tput bold 2>/dev/null || echo "")
RED=$(tput setaf 1 2>/dev/null || echo "")
GREEN=$(tput setaf 2 2>/dev/null || echo "")
YELLOW=$(tput setaf 3 2>/dev/null || echo "")
BLUE=$(tput setaf 4 2>/dev/null || echo "")
RESET=$(tput sgr0 2>/dev/null || echo "")

usage() {
  cat <<EOF
Usage: $0 <owner/repo>
       $0 --url <github-url>
       $0 --workspace <workspace-path>

Detects V12 / Zellic V12 / Olympix / Cantina AI auditor bot installation.
EOF
  exit 1
}

[ $# -lt 1 ] && usage

# Parse input
REPO=""
case "$1" in
  --url)
    URL="$2"
    REPO="$(echo "$URL" | sed -E 's|https?://github.com/||' | sed -E 's|\.git$||' | cut -d'/' -f1,2)"
    ;;
  --workspace)
    WS="$2"
    if [ -f "$WS/.target-repo" ]; then
      REPO="$(cat "$WS/.target-repo")"
    else
      echo "ERROR: $WS/.target-repo not found. Write 'owner/repo' to it first." >&2
      exit 2
    fi
    ;;
  -h|--help)
    usage
    ;;
  */*)
    REPO="$1"
    ;;
  *)
    echo "ERROR: input must be owner/repo or --url or --workspace" >&2
    usage
    ;;
esac

if [ -z "$REPO" ] || ! echo "$REPO" | grep -qE '^[^/]+/[^/]+$'; then
  echo "ERROR: invalid repo format: '$REPO' (want owner/repo)" >&2
  exit 2
fi

echo "${BOLD}ai-bot-check${RESET}: scanning ${BLUE}$REPO${RESET}"
echo

# Check gh auth
if ! command -v gh >/dev/null 2>&1; then
  echo "${RED}ERROR${RESET}: gh CLI not installed. Install: https://cli.github.com/" >&2
  exit 2
fi

if ! gh auth status >/dev/null 2>&1; then
  echo "${YELLOW}WARNING${RESET}: gh not authenticated. Limited scan (public installations only)." >&2
fi

BOT_DETECTED=0
DETECTED_BOTS=()

# ===== Detection method 1: GitHub Apps (installations) =====
echo "${BOLD}[1/3]${RESET} Checking GitHub Apps installations..."

APPS_OUTPUT="$(gh api "repos/$REPO/installation" 2>&1 || echo "NO_ACCESS")"

if echo "$APPS_OUTPUT" | grep -qi "v12"; then
  BOT_DETECTED=1
  DETECTED_BOTS+=("v12-auditor (GitHub App)")
  echo "  ${RED}DETECTED${RESET}: v12-auditor app installation"
elif echo "$APPS_OUTPUT" | grep -qi "zellic"; then
  BOT_DETECTED=1
  DETECTED_BOTS+=("zellic (GitHub App)")
  echo "  ${RED}DETECTED${RESET}: zellic app installation"
elif echo "$APPS_OUTPUT" | grep -qi "olympix"; then
  BOT_DETECTED=1
  DETECTED_BOTS+=("olympix (GitHub App)")
  echo "  ${RED}DETECTED${RESET}: olympix app installation"
elif echo "$APPS_OUTPUT" | grep -qi "cantina"; then
  BOT_DETECTED=1
  DETECTED_BOTS+=("cantina (GitHub App)")
  echo "  ${RED}DETECTED${RESET}: cantina app installation"
elif echo "$APPS_OUTPUT" | grep -q "NO_ACCESS\|Not Found\|404"; then
  echo "  ${YELLOW}NO DIRECT APP${RESET} (may be installed at org level, scanning PR activity...)"
else
  echo "  ${GREEN}NO APP${RESET} detected via direct installation endpoint"
fi

# ===== Detection method 2: Recent PR check runs / comments =====
echo "${BOLD}[2/3]${RESET} Scanning recent PR activity for bot comments..."

# Get last 10 PRs
PRS="$(gh api "repos/$REPO/pulls?state=all&per_page=10" 2>/dev/null | \
  python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    for pr in data:
        print(pr.get('number', ''))
except Exception as e:
    pass
" || echo "")"

if [ -z "$PRS" ]; then
  echo "  ${YELLOW}NO PR DATA${RESET} available (empty repo or no access)"
else
  BOT_PATTERNS="v12|zellic|olympix|cantina-ai|audit-bot|security-bot"
  for pr_num in $PRS; do
    # Check PR comments
    COMMENTS="$(gh api "repos/$REPO/issues/$pr_num/comments" 2>/dev/null | \
      python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    for c in data:
        user = c.get('user', {}).get('login', '')
        body = c.get('body', '')[:200]
        print(f'{user}|{body}')
except Exception:
    pass
" 2>/dev/null || echo "")"

    if [ -n "$COMMENTS" ]; then
      if echo "$COMMENTS" | grep -iE "$BOT_PATTERNS" | head -1 >/tmp/bot-match.$$ 2>/dev/null; then
        MATCH="$(cat /tmp/bot-match.$$ 2>/dev/null)"
        if [ -n "$MATCH" ]; then
          BOT_NAME="$(echo "$MATCH" | head -1 | cut -d'|' -f1)"
          BOT_DETECTED=1
          DETECTED_BOTS+=("$BOT_NAME (PR #$pr_num commenter)")
          echo "  ${RED}DETECTED${RESET}: bot commenter '$BOT_NAME' on PR #$pr_num"
        fi
        rm -f /tmp/bot-match.$$
      fi
    fi

    # Check check runs (GitHub Actions / apps)
    HEAD_SHA="$(gh api "repos/$REPO/pulls/$pr_num" 2>/dev/null | \
      python3 -c "import json,sys; print(json.load(sys.stdin).get('head',{}).get('sha',''))" 2>/dev/null || echo "")"

    if [ -n "$HEAD_SHA" ]; then
      CHECKS="$(gh api "repos/$REPO/commits/$HEAD_SHA/check-runs" 2>/dev/null | \
        python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    for run in data.get('check_runs', []):
        app = run.get('app', {}).get('slug', '')
        name = run.get('name', '')
        print(f'{app}|{name}')
except Exception:
    pass
" 2>/dev/null || echo "")"

      if echo "$CHECKS" | grep -iE "$BOT_PATTERNS" | head -1 >/tmp/check-match.$$ 2>/dev/null; then
        MATCH="$(cat /tmp/check-match.$$ 2>/dev/null)"
        if [ -n "$MATCH" ]; then
          APP_SLUG="$(echo "$MATCH" | head -1 | cut -d'|' -f1)"
          BOT_DETECTED=1
          DETECTED_BOTS+=("$APP_SLUG (check run on PR #$pr_num)")
          echo "  ${RED}DETECTED${RESET}: check run app '$APP_SLUG' on PR #$pr_num"
        fi
        rm -f /tmp/check-match.$$
      fi
    fi
  done
  if [ $BOT_DETECTED -eq 0 ]; then
    echo "  ${GREEN}NO BOT ACTIVITY${RESET} across last 10 PRs"
  fi
fi

# ===== Detection method 3: .github/workflows scan =====
echo "${BOLD}[3/3]${RESET} Scanning .github/workflows for audit bot actions..."

WORKFLOWS="$(gh api "repos/$REPO/contents/.github/workflows" 2>/dev/null | \
  python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    for f in data:
        print(f.get('name', ''))
except Exception:
    pass
" 2>/dev/null || echo "")"

if [ -n "$WORKFLOWS" ]; then
  for wf in $WORKFLOWS; do
    CONTENT="$(gh api "repos/$REPO/contents/.github/workflows/$wf" 2>/dev/null | \
      python3 -c "import json,sys,base64; print(base64.b64decode(json.load(sys.stdin).get('content','')).decode('utf-8', errors='replace'))" 2>/dev/null || echo "")"

    if echo "$CONTENT" | grep -iE "v12-auditor|zellic-v12|olympix/|cantina.*audit" >/dev/null; then
      BOT_DETECTED=1
      MATCHED="$(echo "$CONTENT" | grep -iE "v12-auditor|zellic-v12|olympix/|cantina.*audit" | head -1 | tr -d '\n' | cut -c1-80)"
      DETECTED_BOTS+=("$wf uses audit bot: $MATCHED")
      echo "  ${RED}DETECTED${RESET}: $wf references audit bot"
    fi
  done
  if [ $BOT_DETECTED -eq 0 ]; then
    echo "  ${GREEN}NO BOT WORKFLOW${RESET} detected"
  fi
else
  echo "  ${YELLOW}NO WORKFLOWS${RESET} directory or no access"
fi

# ===== Verdict =====
echo
echo "================================================"
if [ $BOT_DETECTED -eq 1 ]; then
  echo "${BOLD}${RED}VERDICT: AI AUDITOR BOT DETECTED${RESET}"
  echo
  echo "Detected bots:"
  for bot in "${DETECTED_BOTS[@]}"; do
    echo "  - $bot"
  done
  echo
  echo "${BOLD}Hunting recommendation:${RESET}"
  echo "  DEPRIORITIZE (high dupe-risk — V12 covers):"
  echo "    - Access control / authorization"
  echo "    - Input validation / missing checks"
  echo "    - Reentrancy (single-contract classic)"
  echo "    - Unchecked arithmetic / overflow"
  echo "    - Inline assembly DoS"
  echo "    - tokenIn==tokenOut-style missing validation"
  echo
  echo "  PRIORITIZE (V12-uncovered classes):"
  echo "    - Business logic bugs"
  echo "    - Economic / incentive misalignment"
  echo "    - Cryptographic mistakes"
  echo "    - Cross-chain interactions"
  echo "    - Oracle manipulation (non-standard)"
  echo "    - Governance / upgrade chain flaws"
  echo "    - MEV / timing / sandwich"
  echo "    - Design flaws (architectural)"
  echo
  echo "  Reference: feedback_v12_ai_auditor_dupe_risk.md"
  exit 1
else
  echo "${BOLD}${GREEN}VERDICT: NO AI AUDITOR BOT DETECTED${RESET}"
  echo
  echo "SC hunting: ${GREEN}PROCEED${RESET} on all classes (no structural dupe-risk from AI bot)."
  echo "Standard dupe checks still apply (prior audits, submissions, leaderboard)."
  exit 0
fi
