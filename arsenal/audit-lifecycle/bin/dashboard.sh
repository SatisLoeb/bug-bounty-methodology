#!/usr/bin/env bash
# dashboard.sh — Daily digest for solo hunter workflow.
#
# Aggregates:
#   - WIP state (Active / Ready / Waiting counts, via memory/project_*.md pattern match)
#   - findings-state.sh output (overdue relances, dispute windows, nudges, wins)
#   - archive-stale.sh output (stale triage, disclosure deadlines)
#   - OUTCOMES.jsonl last 7d (wins + losses)
#   - WIP violations (Active>3, Ready>2, combined>5)
#
# Usage:
#   dashboard.sh              # Terminal digest
#   dashboard.sh --short      # Just the violation summary
#   dashboard.sh --markdown   # Markdown output (pipe to email or file)

set -uo pipefail

MEMORY_DIR="$HOME/.claude/projects/-home-malix-Desktop-BUGS/memory"
BUGS_ROOT="$HOME/Desktop/BUGS"
LIFECYCLE_BIN="$HOME/arsenal/audit-lifecycle/bin"
TODAY_EPOCH=$(date +%s)
TODAY_ISO=$(date -u +%Y-%m-%d)

# Limits (from WIP-LIMITS.md)
MAX_ACTIVE=3
MAX_READY=2
MAX_COMBINED=5

MODE="full"
while [ $# -gt 0 ]; do
  case "$1" in
    --short) MODE="short" ;;
    --markdown) MODE="markdown" ;;
    -h|--help)
      echo "Usage: $0 [--short|--markdown]"
      exit 0
      ;;
  esac
  shift
done

if [ "$MODE" = "markdown" ]; then
  BOLD=""; RED=""; GREEN=""; YELLOW=""; BLUE=""; RESET=""
  H1="# "; H2="## "; H3="### "
else
  BOLD=$(tput bold 2>/dev/null || echo "")
  RED=$(tput setaf 1 2>/dev/null || echo "")
  GREEN=$(tput setaf 2 2>/dev/null || echo "")
  YELLOW=$(tput setaf 3 2>/dev/null || echo "")
  BLUE=$(tput setaf 4 2>/dev/null || echo "")
  RESET=$(tput sgr0 2>/dev/null || echo "")
  H1=""; H2=""; H3=""
fi

# =============================================================
# Section 1: WIP counts (parse project_*.md status patterns)
# =============================================================
count_status() {
  local pattern="$1"
  local count=0
  for f in "$MEMORY_DIR"/project_*.md; do
    [ -f "$f" ] || continue
    # Skip files already archived
    if grep -q '^> \*\*ARCHIVED' "$f"; then continue; fi
    # Skip closed/paid
    if grep -qiE 'EXHAUSTED|CLOSED|DROPPED|\bARCHIVED\b' "$f"; then continue; fi
    if echo "$pattern" | grep -q "active"; then
      if grep -qiE '^## (Active|ACTIVE)|status:\s*active|In progress|in progress' "$f" 2>/dev/null; then
        count=$((count+1))
      fi
    elif echo "$pattern" | grep -q "ready"; then
      if grep -qiE '^## (Ready to Submit|READY)|ready.to.submit|status:\s*ready' "$f" 2>/dev/null; then
        count=$((count+1))
      fi
    elif echo "$pattern" | grep -q "waiting"; then
      if grep -qiE 'Waiting Triage|waiting.*triage|in review|submitted|awaiting' "$f" 2>/dev/null; then
        count=$((count+1))
      fi
    fi
  done
  echo "$count"
}

# Use MEMORY.md master index as authoritative (quicker, more reliable)
count_memory_section() {
  local section="$1"
  if [ ! -f "$MEMORY_DIR/MEMORY.md" ]; then
    echo "?"
    return
  fi
  python3 <<EOF
import re
with open("$MEMORY_DIR/MEMORY.md") as f:
    text = f.read()
pattern = r'## $section\s*\n(.*?)(?=\n## |\Z)'
m = re.search(pattern, text, re.DOTALL)
if not m:
    print("?")
else:
    section_text = m.group(1)
    lines = [l for l in section_text.split('\n') if l.strip().startswith('- [')]
    print(len(lines))
EOF
}

ACTIVE_COUNT=$(count_memory_section "Active")
READY_COUNT=$(count_memory_section "Ready to Submit")
WAITING_COUNT=$(count_memory_section "Waiting Triage")

# =============================================================
# Section 2: Last-7d wins from OUTCOMES.jsonl
# =============================================================
wins_last_7d() {
  local cutoff_epoch=$((TODAY_EPOCH - 7*86400))
  if [ ! -f "$BUGS_ROOT/OUTCOMES.jsonl" ]; then echo "0|"; return; fi
  python3 <<EOF
import json, sys, time
count = 0
items = []
try:
    with open("$BUGS_ROOT/OUTCOMES.jsonl") as f:
        for line in f:
            line = line.strip()
            if not line: continue
            try:
                d = json.loads(line)
            except Exception:
                continue
            outcome = d.get("outcome", "")
            if outcome not in ("accepted", "acknowledged", "fixed", "bounty_paid", "awarded"):
                continue
            date_str = d.get("result_at") or d.get("date_resolved") or d.get("ts") or d.get("date_submitted") or ""
            date_str = date_str[:10] if date_str else ""
            if not date_str: continue
            try:
                t = time.mktime(time.strptime(date_str, "%Y-%m-%d"))
            except Exception:
                continue
            if t >= $cutoff_epoch:
                count += 1
                payout = d.get("reward", d.get("payout_usd", 0))
                protocol = d.get("protocol", "")
                fid = d.get("id", "")
                items.append(f"{date_str} {protocol} {fid} \${payout}")
except FileNotFoundError:
    pass
print(f"{count}|" + "\n".join(items))
EOF
}

# =============================================================
# Section 3: Relances due today (parse memory for "Next follow-up" or "Next relance")
# =============================================================
relances_due_today() {
  local max_date
  max_date="$(date -d "+1 day" +%Y-%m-%d)"
  local min_date
  min_date="$(date -d "-365 days" +%Y-%m-%d)"
  for f in "$MEMORY_DIR"/project_*.md; do
    [ -f "$f" ] || continue
    if grep -q '^> \*\*ARCHIVED' "$f"; then continue; fi
    local name
    name="$(basename "$f" .md | sed 's/^project_//')"
    local next_dates
    next_dates="$(grep -iE 'Next (follow-up|relance|ping)' "$f" 2>/dev/null | grep -oE '20[0-9]{2}-[0-9]{2}-[0-9]{2}' | head -3)"
    for d in $next_dates; do
      # Due if d <= today
      local e
      e="$(date -d "$d" +%s 2>/dev/null || echo 0)"
      if [ "$e" -le "$TODAY_EPOCH" ] && [ "$e" -gt 0 ]; then
        local days_late
        days_late=$(( (TODAY_EPOCH - e) / 86400 ))
        echo "$name|$d|$days_late"
      fi
    done
  done
}

# =============================================================
# OUTPUT
# =============================================================

if [ "$MODE" = "short" ]; then
  # Minimal violation-focused output
  echo "${BOLD}WIP:${RESET} Active=$ACTIVE_COUNT/$MAX_ACTIVE  Ready=$READY_COUNT/$MAX_READY  Waiting=$WAITING_COUNT"
  short_violations=""
  if [ "$ACTIVE_COUNT" != "?" ] && [ "$ACTIVE_COUNT" -gt "$MAX_ACTIVE" ] 2>/dev/null; then
    short_violations="$short_violations Active>max"
  fi
  if [ "$READY_COUNT" != "?" ] && [ "$READY_COUNT" -gt "$MAX_READY" ] 2>/dev/null; then
    short_violations="$short_violations Ready>max"
  fi
  if [ -n "$short_violations" ]; then
    echo "${RED}VIOLATIONS:${RESET}$short_violations"
  fi
  exit 0
fi

echo "${H1}${BOLD}Dashboard — $TODAY_ISO${RESET}"
echo

# -- WIP section
echo "${H2}${BOLD}WIP Status${RESET}"
wip_line() {
  local name="$1" count="$2" max="$3"
  local status_color="$GREEN"
  local violated=""
  if [ "$count" != "?" ] && [ "$count" -gt "$max" ] 2>/dev/null; then
    status_color="$RED"
    violated=" ${RED}(VIOLATION — close one)${RESET}"
  elif [ "$count" != "?" ] && [ "$count" -eq "$max" ] 2>/dev/null; then
    status_color="$YELLOW"
    violated=" ${YELLOW}(at cap)${RESET}"
  fi
  echo "  ${status_color}●${RESET} ${BOLD}$name${RESET}: $count/$max${violated}"
}
wip_line "Active" "$ACTIVE_COUNT" "$MAX_ACTIVE"
wip_line "Ready to Submit" "$READY_COUNT" "$MAX_READY"
echo "  ${BLUE}○${RESET} ${BOLD}Waiting Triage${RESET}: $WAITING_COUNT  (uncapped, governed by archive-stale.sh)"
echo

# -- Disclosure deadline + stale from archive-stale.sh --json
echo "${H2}${BOLD}Stale & Disclosure Deadlines${RESET}"
STALE_JSON="$(bash "$LIFECYCLE_BIN/archive-stale.sh" --json 2>/dev/null)"
if [ -n "$STALE_JSON" ]; then
  URGENT_COUNT=$(echo "$STALE_JSON" | python3 -c "import json,sys; print(len(json.load(sys.stdin).get('deadline_urgent',[])))" 2>/dev/null || echo "?")
  STALE_COUNT=$(echo "$STALE_JSON" | python3 -c "import json,sys; print(len(json.load(sys.stdin).get('stale',[])))" 2>/dev/null || echo "?")

  if [ "$URGENT_COUNT" != "?" ] && [ "$URGENT_COUNT" -gt 0 ]; then
    echo "  ${RED}⚠  Urgent deadlines (≤14d):${RESET} $URGENT_COUNT"
    echo "$STALE_JSON" | python3 <<'EOF' 2>/dev/null
import json, sys
try:
    d = json.loads(sys.stdin.read())
    for u in d.get("deadline_urgent", []):
        print(f"       - {u['project']}: {u['deadline']} (T{u['days_until']:+d}d)")
except Exception:
    pass
EOF
  fi

  if [ "$STALE_COUNT" != "?" ] && [ "$STALE_COUNT" -gt 0 ]; then
    echo "  ${YELLOW}●  Stale projects (≥30d + ≥2 relances):${RESET} $STALE_COUNT"
    echo "$STALE_JSON" | python3 <<'EOF' 2>/dev/null
import json, sys
try:
    d = json.loads(sys.stdin.read())
    for s in d.get("stale", []):
        print(f"       - {s['project']}: last {s['last_activity']} ({s['age_days']}d ago, {s['relances']} relances)")
except Exception:
    pass
EOF
    echo "       → Run: archive-stale.sh (interactive forced-decision pass)"
  fi

  if [ "$URGENT_COUNT" = "0" ] && [ "$STALE_COUNT" = "0" ]; then
    echo "  ${GREEN}✓${RESET} No stale or urgent items"
  fi
fi
echo

# -- Relances due today
echo "${H2}${BOLD}Relances Due${RESET}"
RELANCES="$(relances_due_today 2>/dev/null)"
if [ -n "$RELANCES" ]; then
  echo "$RELANCES" | while IFS='|' read -r name due_date days_late; do
    if [ "$days_late" -eq 0 ] 2>/dev/null; then
      echo "  ${YELLOW}●${RESET} $name — due today ($due_date)"
    else
      echo "  ${RED}●${RESET} $name — ${RED}${days_late}d overdue${RESET} (was due $due_date)"
    fi
  done
else
  echo "  ${GREEN}✓${RESET} No relances scheduled through today"
fi
echo

# -- findings-state.sh output (overdue, disputes, nudges, wins)
echo "${H2}${BOLD}Finding-Level State${RESET}"
FS_OUT="$("$LIFECYCLE_BIN/findings-state.sh" 2>/dev/null | grep -vE '^$' | head -50)"
if [ -n "$FS_OUT" ]; then
  echo "$FS_OUT" | sed 's/^/  /'
else
  echo "  (findings-state.sh returned empty or errored)"
fi
echo

# -- Last 7 days wins
echo "${H2}${BOLD}Last 7 Days Wins${RESET}"
WINS_RAW="$(wins_last_7d)"
WIN_COUNT=$(echo "$WINS_RAW" | head -1 | cut -d'|' -f1)
WIN_ITEMS=$(echo "$WINS_RAW" | tail -n +1 | cut -d'|' -f2-)
if [ "${WIN_COUNT:-0}" -gt 0 ] 2>/dev/null; then
  echo "  ${GREEN}✓${RESET} $WIN_COUNT win(s) in last 7 days:"
  echo "$WIN_ITEMS" | grep -v '^$' | sed 's/^/       /'
else
  echo "  (no wins recorded in last 7d — check OUTCOMES.jsonl format)"
fi
echo

# -- Action items summary
echo "${H2}${BOLD}Today's Action Items${RESET}"
declare -a ACTIONS
if [ "$ACTIVE_COUNT" != "?" ] && [ "$ACTIVE_COUNT" -gt "$MAX_ACTIVE" ] 2>/dev/null; then
  ACTIONS+=("Close 1 Active project (currently $ACTIVE_COUNT/$MAX_ACTIVE)")
fi
if [ "$READY_COUNT" != "?" ] && [ "$READY_COUNT" -gt "$MAX_READY" ] 2>/dev/null; then
  ACTIONS+=("Submit oldest Ready (currently $READY_COUNT/$MAX_READY)")
fi
if [ -n "${URGENT_COUNT:-}" ] && [ "$URGENT_COUNT" != "?" ] && [ "$URGENT_COUNT" -gt 0 ] 2>/dev/null; then
  ACTIONS+=("Review $URGENT_COUNT urgent disclosure deadline(s)")
fi
if [ -n "${STALE_COUNT:-}" ] && [ "$STALE_COUNT" != "?" ] && [ "$STALE_COUNT" -gt 0 ] 2>/dev/null; then
  ACTIONS+=("Run archive-stale.sh for $STALE_COUNT stale project(s)")
fi
if [ -n "$RELANCES" ]; then
  RC=$(echo "$RELANCES" | wc -l)
  ACTIONS+=("Send $RC relance(s)")
fi

if [ "${#ACTIONS[@]}" -eq 0 ]; then
  echo "  ${GREEN}✓ No immediate action items — hunt time${RESET}"
else
  for i in "${!ACTIONS[@]}"; do
    echo "  $((i+1)). ${ACTIONS[$i]}"
  done
fi
echo
echo "${BOLD}Generated:${RESET} $(date -u +%Y-%m-%dT%H:%M:%SZ)"
