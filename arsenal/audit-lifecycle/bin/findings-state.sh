#!/usr/bin/env bash
# findings-state.sh — consolidated view of all in-flight findings across workspaces.
#
# Parses:
#   - All *-audit/OUTCOMES.jsonl files under ~/Desktop/BUGS
#   - Global ~/Desktop/BUGS/OUTCOMES.jsonl
#
# Emits priority tables:
#   - OVERDUE RELANCE      — submitted >7 days ago, no result yet
#   - DISPUTE WINDOW       — duplicate/informative/disputed within last 30 days
#   - NUDGE CANDIDATES     — in review >14 days
#   - PAYMENT WAIT         — accepted but reward=0 and >14 days
#   - RECENT WINS          — accepted with reward>0 in last 30 days (for morale)
#
# Usage: findings-state.sh [--json]
set -euo pipefail

BUGS_ROOT="${BUGS_ROOT:-$HOME/Desktop/BUGS}"
JSON_OUT=0
[ "${1:-}" = "--json" ] && JSON_OUT=1

NOW_EPOCH=$(date +%s)

# Collect all OUTCOMES.jsonl entries with workspace attribution
TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT

# Global OUTCOMES.jsonl
if [ -f "$BUGS_ROOT/OUTCOMES.jsonl" ]; then
  awk -v ws="global" '{ print ws"\t"$0 }' "$BUGS_ROOT/OUTCOMES.jsonl" >> "$TMP"
fi

# Per-workspace OUTCOMES.jsonl
for oj in "$BUGS_ROOT"/*-audit/OUTCOMES.jsonl; do
  [ -f "$oj" ] || continue
  ws=$(basename "$(dirname "$oj")")
  awk -v ws="$ws" '{ print ws"\t"$0 }' "$oj" >> "$TMP"
done

# Parse with python for robust JSON + date arithmetic
python3 <<PYEOF
import json, sys, os, datetime
from collections import defaultdict

NOW = datetime.datetime.now(datetime.timezone.utc)

overdue_relance = []
dispute_window = []
nudge_candidates = []
payment_wait = []
recent_wins = []
killed_recent = []

def parse_date(s):
    if not s: return None
    try:
        if s.endswith('Z'):
            return datetime.datetime.fromisoformat(s.replace('Z', '+00:00'))
        return datetime.datetime.fromisoformat(s)
    except:
        return None

with open("$TMP") as f:
    for line in f:
        if '\t' not in line: continue
        ws, entry_raw = line.rstrip('\n').split('\t', 1)
        entry_raw = entry_raw.strip()
        if not entry_raw: continue
        try:
            e = json.loads(entry_raw)
        except:
            continue

        fid = e.get('id', '?')
        protocol = e.get('protocol', '?')
        outcome = e.get('outcome', 'unknown')
        severity = e.get('severity', '?')
        reward = e.get('reward', 0) or 0
        platform = e.get('platform', '?')
        finding_desc = e.get('finding', '')
        submitted_at = parse_date(e.get('submitted_at'))
        result_at = parse_date(e.get('result_at'))
        held_reason = e.get('held_reason', 'n/a')

        days_since_submit = None
        days_since_result = None
        if submitted_at:
            days_since_submit = (NOW - submitted_at).days
        if result_at:
            days_since_result = (NOW - result_at).days

        # Classify
        if outcome in ('submitted', 'pending') and days_since_submit is not None:
            if days_since_submit > 14:
                nudge_candidates.append((fid, protocol, platform, severity, days_since_submit, ws, finding_desc))
            elif days_since_submit > 7:
                overdue_relance.append((fid, protocol, platform, severity, days_since_submit, ws, finding_desc))

        if outcome in ('duplicate', 'informative', 'disputed', 'dismissed') and days_since_result is not None:
            if days_since_result <= 30:
                dispute_window.append((fid, protocol, platform, severity, outcome, days_since_result, ws, finding_desc))

        if outcome == 'accepted' and reward == 0 and days_since_result is not None:
            if days_since_result > 14:
                payment_wait.append((fid, protocol, platform, severity, days_since_result, ws, finding_desc))

        if outcome in ('accepted', 'bounty_paid') and reward > 0 and days_since_result is not None:
            if days_since_result <= 30:
                recent_wins.append((fid, protocol, platform, severity, reward, days_since_result, ws))

        if outcome == 'dismissed' and days_since_result is not None and days_since_result <= 14:
            killed_recent.append((fid, protocol, days_since_result, ws))

# Sort by urgency (most urgent first)
overdue_relance.sort(key=lambda x: -x[4])
nudge_candidates.sort(key=lambda x: -x[4])
dispute_window.sort(key=lambda x: x[5])
payment_wait.sort(key=lambda x: -x[4])
recent_wins.sort(key=lambda x: -x[4])

def header(title, rows, empty_msg="(none)"):
    print(f"\n━━━━━ {title} ━━━━━")
    if not rows:
        print(f"  {empty_msg}")

print("="*76)
print(f"  FINDINGS STATE — {NOW.strftime('%Y-%m-%d %H:%M UTC')}")
print("="*76)

header("OVERDUE RELANCE (>7d no result)", overdue_relance)
for fid, proto, plat, sev, days, ws, desc in overdue_relance:
    print(f"  {fid:<20} {proto:<15} {plat:<12} {sev:<10} {days}d  [{ws}]")
    if desc: print(f"    └─ {desc[:70]}")

header("NUDGE CANDIDATES (>14d in review — consider escalation)", nudge_candidates)
for fid, proto, plat, sev, days, ws, desc in nudge_candidates:
    print(f"  {fid:<20} {proto:<15} {plat:<12} {sev:<10} {days}d  [{ws}]")
    if desc: print(f"    └─ {desc[:70]}")

header("DISPUTE WINDOW (dup/info/dismissed ≤30d)", dispute_window)
for fid, proto, plat, sev, outcome, days, ws, desc in dispute_window:
    print(f"  {fid:<20} {proto:<15} {plat:<12} {sev:<10} {outcome:<12} {days}d  [{ws}]")
    if desc: print(f"    └─ {desc[:70]}")

header("PAYMENT WAIT (accepted but reward=0, >14d)", payment_wait)
for fid, proto, plat, sev, days, ws, desc in payment_wait:
    print(f"  {fid:<20} {proto:<15} {plat:<12} {sev:<10} {days}d  [{ws}]")

header("RECENT WINS (≤30d, reward>0)", recent_wins)
total_30d = 0
for fid, proto, plat, sev, reward, days, ws in recent_wins:
    total_30d += reward
    print(f"  {fid:<20} {proto:<15} {plat:<12} {sev:<10} \${reward:>7,}  {days}d ago")
if recent_wins:
    print(f"  ─────────────────────────────────────────── 30-day total: \${total_30d:,}")

header("RECENTLY KILLED (≤14d) — review KILLED-FINDINGS-LESSONS.yaml for new rules", killed_recent)
for fid, proto, days, ws in killed_recent:
    print(f"  {fid:<20} {proto:<15} killed {days}d ago  [{ws}]")

print()
print("="*76)
PYEOF
