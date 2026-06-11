#!/usr/bin/env bash
# archive-stale.sh — Force decisions on stale Waiting Triage projects.
#
# Scans memory/project_*.md for stale projects (30j no-response + 2 relances sent).
# Respects disclosure_deadline field: if deadline within 14d, prompts escalation.
# Otherwise, prompts: (e)xtend / (E)scalate public / (A)rchive / (s)kip / (q)uit.
#
# Does NOT auto-archive. Presents forced choice interactively.
#
# Usage:
#   archive-stale.sh               # Interactive scan of all project_*.md
#   archive-stale.sh --dry-run     # List stale only, no prompts
#   archive-stale.sh --json        # JSON output of stale projects (for dashboard.sh)

set -uo pipefail
# Note: -e intentionally off; the scan loop uses conditional arithmetic
# comparisons that would trigger spurious exits on empty/unknown values.

MEMORY_DIR="$HOME/.claude/projects/-home-malix-Desktop-BUGS/memory"
OUTCOMES_FILE="$HOME/Desktop/BUGS/OUTCOMES.jsonl"
TODAY_EPOCH=$(date +%s)
STALE_DAYS=30
DEADLINE_WARN_DAYS=14

BOLD=$(tput bold 2>/dev/null || echo "")
RED=$(tput setaf 1 2>/dev/null || echo "")
GREEN=$(tput setaf 2 2>/dev/null || echo "")
YELLOW=$(tput setaf 3 2>/dev/null || echo "")
BLUE=$(tput setaf 4 2>/dev/null || echo "")
RESET=$(tput sgr0 2>/dev/null || echo "")

MODE="interactive"
while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) MODE="dry" ;;
    --json) MODE="json" ;;
    -h|--help)
      echo "Usage: $0 [--dry-run|--json]"
      exit 0
      ;;
  esac
  shift
done

# Extract the most recent date mentioned in a file (YYYY-MM-DD anywhere)
latest_date_in_file() {
  local f="$1"
  grep -oE '20[0-9]{2}-[0-9]{2}-[0-9]{2}' "$f" 2>/dev/null | sort -u | tail -1
}

# Count explicit relance/follow-up mentions
count_relances() {
  local f="$1"
  local c
  c=$(grep -cE 'follow-?up|relance|reminder sent|ping|nudge' "$f" 2>/dev/null | head -1)
  c=${c:-0}
  # sanitize: must be numeric
  if ! echo "$c" | grep -qE '^[0-9]+$'; then c=0; fi
  echo "$c"
}

# Extract optional disclosure_deadline (YYYY-MM-DD) if present
extract_deadline() {
  local f="$1"
  # Priority 1: explicit "disclosure_deadline: YYYY-MM-DD" field (if adopted)
  local d="$(grep -iE '^disclosure_deadline:\s*' "$f" 2>/dev/null | head -1 | grep -oE '20[0-9]{2}-[0-9]{2}-[0-9]{2}')"
  [ -n "$d" ] && { echo "$d"; return; }
  # Priority 2: "90-day public disclosure deadline YYYY-MM-DD"
  d="$(grep -iE '90-day.*deadline|disclosure deadline' "$f" 2>/dev/null | grep -oE '20[0-9]{2}-[0-9]{2}-[0-9]{2}' | head -1)"
  [ -n "$d" ] && { echo "$d"; return; }
  echo ""
}

# Detect project status from content (pattern match)
project_status() {
  local f="$1"
  if grep -qiE 'EXHAUSTED|CLOSED|DROPPED|rejected|ARCHIVED' "$f"; then
    echo "closed"
  elif grep -qiE 'AWARDED|PAID|Bounty paid|awarded.*\\$' "$f"; then
    echo "paid"
  elif grep -qiE 'Waiting.*triage|in review|submitted|awaiting' "$f"; then
    echo "waiting"
  elif grep -qiE 'Ready to submit|ready_to_submit' "$f"; then
    echo "ready"
  elif grep -qiE 'Active|ACTIVE|in progress' "$f"; then
    echo "active"
  else
    echo "unknown"
  fi
}

# Date diff in days (YYYY-MM-DD - today)
days_ago() {
  local d="$1"
  if [ -z "$d" ]; then echo "?"; return; fi
  local e
  e=$(date -d "$d" +%s 2>/dev/null || echo "")
  if [ -z "$e" ]; then echo "?"; return; fi
  echo $(( (TODAY_EPOCH - e) / 86400 ))
}

days_until() {
  local d="$1"
  if [ -z "$d" ]; then echo "?"; return; fi
  local e
  e=$(date -d "$d" +%s 2>/dev/null || echo "")
  if [ -z "$e" ]; then echo "?"; return; fi
  echo $(( (e - TODAY_EPOCH) / 86400 ))
}

# Main scan
declare -a STALE_LIST
declare -a DEADLINE_URGENT
STALE_LIST=()
DEADLINE_URGENT=()

for f in "$MEMORY_DIR"/project_*.md; do
  [ -f "$f" ] || continue
  name="$(basename "$f" .md | sed 's/^project_//')"

  status="$(project_status "$f")"
  # Only consider waiting/ready/active for staleness scan
  case "$status" in
    closed|paid) continue ;;
  esac

  latest="$(latest_date_in_file "$f")"
  age="$(days_ago "$latest")"
  relances="$(count_relances "$f")"
  deadline="$(extract_deadline "$f")"

  if [ -n "$deadline" ]; then
    until_deadline="$(days_until "$deadline")"
    if [ "$until_deadline" != "?" ]; then
      if [ "$until_deadline" -le "$DEADLINE_WARN_DAYS" ]; then
        DEADLINE_URGENT+=("$name|$status|$deadline|$until_deadline|$f")
        continue
      fi
    fi
  fi

  # Stale: age >= 30d AND at least 2 relance mentions
  if [ "$age" != "?" ]; then
    if [ "$age" -ge "$STALE_DAYS" ]; then
      if [ "$relances" -ge 2 ]; then
        STALE_LIST+=("$name|$status|$latest|$age|$relances|$f")
      fi
    fi
  fi
done

# ===== Output paths =====

if [ "$MODE" = "json" ]; then
  echo "{"
  echo '  "deadline_urgent": ['
  first=1
  for entry in "${DEADLINE_URGENT[@]:-}"; do
    [ -z "$entry" ] && continue
    IFS='|' read -r name status deadline until_d f <<<"$entry"
    [ $first -eq 0 ] && echo ","
    first=0
    printf '    {"project":"%s","status":"%s","deadline":"%s","days_until":%s}' "$name" "$status" "$deadline" "$until_d"
  done
  echo
  echo '  ],'
  echo '  "stale": ['
  first=1
  for entry in "${STALE_LIST[@]:-}"; do
    [ -z "$entry" ] && continue
    IFS='|' read -r name status latest age relances f <<<"$entry"
    [ $first -eq 0 ] && echo ","
    first=0
    printf '    {"project":"%s","status":"%s","last_activity":"%s","age_days":%s,"relances":%s}' "$name" "$status" "$latest" "$age" "$relances"
  done
  echo
  echo '  ]'
  echo "}"
  exit 0
fi

# Dry-run or interactive: print summary first
echo "${BOLD}archive-stale.sh${RESET} — scan at $(date -u +%Y-%m-%d)"
echo

if [ ${#DEADLINE_URGENT[@]} -gt 0 ]; then
  echo "${BOLD}${RED}━━━ DISCLOSURE DEADLINE URGENT (≤${DEADLINE_WARN_DAYS}d) ━━━${RESET}"
  for entry in "${DEADLINE_URGENT[@]}"; do
    IFS='|' read -r name status deadline until_d f <<<"$entry"
    echo "  ${RED}⚠${RESET}  ${BOLD}$name${RESET} ($status) — deadline $deadline (${YELLOW}T-${until_d}d${RESET})"
    echo "      → recommend: escalate_public OR request_extension"
  done
  echo
fi

if [ ${#STALE_LIST[@]} -eq 0 ]; then
  echo "${GREEN}No stale projects.${RESET}"
  exit 0
fi

echo "${BOLD}${YELLOW}━━━ STALE (≥${STALE_DAYS}d + ≥2 relances) ━━━${RESET}"
for entry in "${STALE_LIST[@]}"; do
  IFS='|' read -r name status latest age relances f <<<"$entry"
  echo "  ${YELLOW}●${RESET} ${BOLD}$name${RESET} ($status) — last $latest (${age}d ago, $relances relances)"
done
echo

if [ "$MODE" = "dry" ]; then
  echo "(dry-run — no prompts; run without --dry-run to force decisions)"
  exit 0
fi

# Interactive mode: iterate and force decision per stale
echo "${BOLD}Forced decision pass:${RESET}"
echo "  (e) extend — add deadline+2w, stay waiting"
echo "  (E) escalate public — mark for disclosure prep"
echo "  (A) archive — move to closed, stop tracking"
echo "  (s) skip — defer decision this pass"
echo "  (q) quit"
echo

for entry in "${STALE_LIST[@]}"; do
  IFS='|' read -r name status latest age relances f <<<"$entry"
  echo
  echo "${BOLD}─── $name ───${RESET}"
  echo "  status: $status | last activity: $latest ($age days) | relances: $relances"
  echo "  file: $f"
  head -20 "$f" | grep -v '^---$' | sed 's/^/    /'
  echo
  read -r -p "  Decision [e/E/A/s/q]: " choice
  NOW_ISO="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  case "$choice" in
    e|extend)
      EXT_DATE="$(date -d "+14 days" +%Y-%m-%d)"
      echo "  → Extended. Add to project file: 'Next relance: $EXT_DATE'"
      echo "{\"ts\":\"$NOW_ISO\",\"project\":\"$name\",\"action\":\"extended\",\"next_relance\":\"$EXT_DATE\"}" >> "$OUTCOMES_FILE"
      ;;
    E|escalate)
      echo "  → Flagged for public disclosure prep. Add to project file."
      echo "{\"ts\":\"$NOW_ISO\",\"project\":\"$name\",\"action\":\"escalate_public\",\"stale_days\":$age}" >> "$OUTCOMES_FILE"
      ;;
    A|archive)
      # Mark status as archived in file (prepend header note)
      TMP="$(mktemp)"
      {
        echo "> **ARCHIVED $(date -u +%Y-%m-%d):** stale ${age}d, $relances relances unanswered. No further action."
        echo
        cat "$f"
      } > "$TMP"
      mv "$TMP" "$f"
      echo "  → Archived (header prepended)."
      echo "{\"ts\":\"$NOW_ISO\",\"project\":\"$name\",\"action\":\"archived\",\"stale_days\":$age,\"relances\":$relances}" >> "$OUTCOMES_FILE"
      ;;
    s|skip)
      echo "  → Skipped."
      ;;
    q|quit)
      echo "  → Quit."
      exit 0
      ;;
    *)
      echo "  → (unrecognized, skipped)"
      ;;
  esac
done

echo
echo "${BOLD}${GREEN}archive-stale done.${RESET}"
