#!/usr/bin/env bash
# precedent-scan.sh — emit copy-paste-ready W5 precedent anchor block for Weight Card
#
# Usage:
#   ./precedent-scan.sh "IDOR"
#   ./precedent-scan.sh "SSRF"
#   ./precedent-scan.sh "auth bypass"
#   ./precedent-scan.sh "race condition"
#   ./precedent-scan.sh "JWT"
#
# Wraps arsenal/methodology/H1-HUNTING-PATTERNS.md, H1-STATISTICS.md, and
# arsenal/tracking/OUTCOMES.jsonl. Emits two sections:
#   1. Research sources — grep matches with surrounding context
#   2. W5 precedent anchor block — markdown table matching REPORT-STANDARD.md
#      Weight Accounting W5 format exactly, directly pasteable without edit
#
# Anti-friction rule: the output of section 2 MUST fit the REPORT-STANDARD template
# without reformatting. If you change the template, update this script accordingly.

set -euo pipefail

# Resolve arsenal root relative to this script, with fallback to $HOME/arsenal
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ARSENAL_ROOT="${ARSENAL_ROOT:-$(cd "$SCRIPT_DIR/.." && pwd)}"
if [ ! -d "$ARSENAL_ROOT/methodology" ]; then
  ARSENAL_ROOT="$HOME/arsenal"
fi

PATTERNS_FILE="$ARSENAL_ROOT/methodology/H1-HUNTING-PATTERNS.md"
STATS_FILE="$ARSENAL_ROOT/methodology/H1-STATISTICS.md"
OUTCOMES_FILE="$ARSENAL_ROOT/tracking/OUTCOMES.jsonl"

usage() {
  cat <<EOF
Usage: $(basename "$0") "<vulnerability class>"

Examples:
  $(basename "$0") "IDOR"
  $(basename "$0") "SSRF"
  $(basename "$0") "auth bypass"
  $(basename "$0") "race condition"
  $(basename "$0") "JWT"
  $(basename "$0") "hardcoded credential"

Output:
  Section 1: research sources with grep matches
  Section 2: W5 precedent anchor block — paste directly into REPORT-STANDARD.md
             Weight Accounting section

Environment:
  ARSENAL_ROOT=/path/to/arsenal   Override arsenal root (default: auto-detect)
EOF
  exit "${1:-0}"
}

if [ $# -eq 0 ] || [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
  usage
fi

CLASS="$1"

# Case-insensitive grep pattern. Accept multi-word classes.
PATTERN="$CLASS"

# Helper: extract lines matching class AND containing a dollar figure
extract_dollar_lines() {
  local file="$1"
  [ -f "$file" ] || return 0
  grep -i "$PATTERN" "$file" | grep -E '\$[0-9]+' || true
}

# Helper: extract a vulnerability class label from a matched line
# Grabs the first ALL-CAPS or Title Case phrase that isn't "HackerOne"
extract_class_label() {
  local line="$1"
  echo "$line" \
    | grep -oE '\b([A-Z][a-zA-Z-]+[- ]){0,3}(IDOR|SSRF|RCE|XSS|XXE|SQLi|CSRF|SSTI|LFI|RFI|auth|bypass|race|JWT|OAuth|deserialization|smuggling|poisoning|takeover|injection|prototype|race condition|account takeover|priv ?esc)' \
    | head -1 \
    || echo "$PATTERN"
}

# Helper: extract a single dollar amount from a line, returning the first $X,XXX form
extract_first_dollar() {
  echo "$1" | grep -oE '\$[0-9]+(,[0-9]{3})*(\.[0-9]+)?[KkMm]?' | head -1 || echo '$?'
}

# Helper: extract a report ID (HackerOne #NNNN or similar) from a line
extract_report_id() {
  local line="$1"
  local id=""
  id=$(echo "$line" | grep -oE '(HackerOne|H1|Mozilla|PayPal|GitLab|Shopify|Slack|Stripe|Dropbox|GitHub|Razer|NordVPN|InnoGames|TikTok|Omise|QIWI|Aiven|PortSwigger|Lyft|IBB|Tools for Humanity|NiceHash|DoD|Microsoft|Google|Apple|Twitter|Reverb|curl|Request Finance)[[:space:]]*#?[0-9]*' | head -1)
  if [ -z "$id" ]; then
    id="H1 disclosed"
  fi
  echo "$id"
}

# ===========================================================================
# Section 1: Research sources
# ===========================================================================

echo "============================================================"
echo "  Precedent scan — \"$CLASS\""
echo "  $(date -u '+%Y-%m-%dT%H:%M:%SZ')"
echo "============================================================"
echo ""

echo "=== Research sources ==="
echo ""

H1_HUNTING_MATCHES=""
H1_STATS_MATCHES=""
OUTCOMES_MATCHES=""

if [ -f "$PATTERNS_FILE" ]; then
  echo "--- H1-HUNTING-PATTERNS.md ---"
  H1_HUNTING_MATCHES=$(extract_dollar_lines "$PATTERNS_FILE")
  if [ -n "$H1_HUNTING_MATCHES" ]; then
    echo "$H1_HUNTING_MATCHES" | sed 's/^/  /'
  else
    echo "  (no dollar-anchored matches for \"$CLASS\")"
  fi
  echo ""
fi

if [ -f "$STATS_FILE" ]; then
  echo "--- H1-STATISTICS.md ---"
  H1_STATS_MATCHES=$(extract_dollar_lines "$STATS_FILE")
  if [ -n "$H1_STATS_MATCHES" ]; then
    echo "$H1_STATS_MATCHES" | sed 's/^/  /'
  else
    echo "  (no dollar-anchored matches for \"$CLASS\")"
  fi
  echo ""
fi

if [ -f "$OUTCOMES_FILE" ] && command -v jq >/dev/null 2>&1; then
  echo "--- OUTCOMES.jsonl (local paid records) ---"
  # Match any field containing the class, paid records only (reward != "$0" and outcome includes paid/fixed/bounty_paid)
  OUTCOMES_MATCHES=$(jq -cr --arg cls "$CLASS" '
    select(
      (.reason // "" | test($cls; "i")) or
      (.severity // "" | test($cls; "i")) or
      (.protocol // "" | test($cls; "i")) or
      (.id // "" | test($cls; "i"))
    )
    | select(.reward != "$0" and .reward != null and .reward != "")
    | "  \(.protocol) \(.id) \(.severity // "?") — \(.reward) (\(.outcome // "?"))"
  ' "$OUTCOMES_FILE" 2>/dev/null || true)
  if [ -n "$OUTCOMES_MATCHES" ]; then
    echo "$OUTCOMES_MATCHES"
  else
    echo "  (no local paid records for \"$CLASS\")"
  fi
  echo ""
fi

# ===========================================================================
# Section 2: W5 precedent anchor block — copy-paste ready
# ===========================================================================

echo "============================================================"
echo "=== W5 — copy-paste into REPORT-STANDARD Weight Accounting ==="
echo "============================================================"
echo ""

# Count how many usable rows we can emit
# Use printf to ensure we only count non-empty lines containing a dollar sign
ROWS_FROM_HUNTING=0
if [ -n "$H1_HUNTING_MATCHES" ]; then
  ROWS_FROM_HUNTING=$(printf '%s\n' "$H1_HUNTING_MATCHES" | grep -c '\$' || true)
fi
ROWS_FROM_OUTCOMES=0
if [ -n "$OUTCOMES_MATCHES" ]; then
  ROWS_FROM_OUTCOMES=$(printf '%s\n' "$OUTCOMES_MATCHES" | grep -c '\$' || true)
fi
TOTAL_ROWS=$((ROWS_FROM_HUNTING + ROWS_FROM_OUTCOMES))

if [ "$TOTAL_ROWS" -eq 0 ]; then
  cat <<EOF
**W5 — Precedent anchor:**

(no paid precedents found for "$CLASS" — strengthen W1 with computed loss or downgrade severity)

EOF
else
  cat <<'EOF'
**W5 — Precedent anchor:**

| Report | Class | Payout | Source |
| --- | --- | --- | --- |
EOF

  # Emit rows from H1-HUNTING-PATTERNS (up to 3)
  if [ -n "$H1_HUNTING_MATCHES" ]; then
    echo "$H1_HUNTING_MATCHES" | head -3 | while IFS= read -r line; do
      [ -z "$line" ] && continue
      REPORT_ID=$(extract_report_id "$line")
      # Extract first dollar amount
      PAYOUT=$(extract_first_dollar "$line")
      # Use the user-supplied class as the label (clean and consistent)
      printf "| %s | %s | %s | H1 disclosed |\n" "$REPORT_ID" "$CLASS" "$PAYOUT"
    done
  fi

  # Emit rows from OUTCOMES.jsonl
  if [ -n "$OUTCOMES_MATCHES" ]; then
    echo "$OUTCOMES_MATCHES" | head -3 | while IFS= read -r line; do
      [ -z "$line" ] && continue
      # Parse format: "  protocol id severity — $reward (outcome)"
      PROTO=$(echo "$line" | awk '{print $1}')
      ID=$(echo "$line" | awk '{print $2}')
      REWARD=$(echo "$line" | grep -oE '\$[0-9]+[KkMm]?[0-9,]*' | head -1 || echo '$?')
      printf "| %s %s | %s | %s | OUTCOMES.jsonl |\n" "$PROTO" "$ID" "$CLASS" "$REWARD"
    done
  fi

  echo ""
fi

echo "============================================================"
echo ""
echo "To use: copy the W5 block (between the === markers above) and paste"
echo "into the 'Weight Accounting' section of your REPORT-STANDARD.md draft."
echo "Verify dollar amounts are real before submission. Each row must have a"
echo "dollar figure — unpaid 'related H1 #xxx' rows do NOT satisfy D8."
echo ""
