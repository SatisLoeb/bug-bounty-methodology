#!/usr/bin/env bash
# precedent-scan.sh — Fast W5 slot population from local H1 corpus.
#
# Input:  a vulnerability class / keyword (quoted)
# Output: (1) human-readable research sources
#         (2) copy-paste-ready W5 block in REPORT-STANDARD.md syntax
#
# Sources grep'd:
#   - arsenal/methodology/H1-HUNTING-PATTERNS.md  (2,500+ disclosed, $81M corpus)
#   - arsenal/methodology/H1-STATISTICS.md        ($/hour ROI tables)
#   - arsenal/tracking/OUTCOMES.jsonl             (local paid records only)
#
# Designed to satisfy WEIGHT-CARD.md W5 numerical anchor requirement and
# PREFLIGHT-CHECK.md D8 gating. The copy-paste block is the critical
# deliverable — if it required manual reformatting, the slot would get
# skipped under deadline pressure.
#
# Usage:
#   precedent-scan.sh "IDOR"
#   precedent-scan.sh "SSRF"
#   precedent-scan.sh "race condition"
#   precedent-scan.sh "auth bypass"
#   precedent-scan.sh "hardcoded credential"

set -u

if [ "$#" -lt 1 ]; then
  echo "Usage: $(basename "$0") <class-or-keyword>" >&2
  echo "Example: $(basename "$0") \"IDOR\"" >&2
  exit 2
fi

QUERY="$1"
ARSENAL="${ARSENAL_ROOT:-$HOME/arsenal}"
PATTERNS="$ARSENAL/methodology/H1-HUNTING-PATTERNS.md"
STATS="$ARSENAL/methodology/H1-STATISTICS.md"
OUTCOMES="$ARSENAL/tracking/OUTCOMES.jsonl"

# -----------------------------------------------------------------------------
# Section 1: research sources (human-readable)
# -----------------------------------------------------------------------------

printf '=== Research sources for: "%s" ===\n\n' "$QUERY"

printf -- "--- H1-HUNTING-PATTERNS.md ---\n"
if [ -f "$PATTERNS" ]; then
  # Return matching report rows (lines containing dollar figures near the query)
  # Shows each match with 3 lines of context.
  grep -niE "$QUERY" "$PATTERNS" \
    | grep -E '\$[0-9]' \
    | head -20 || true
  printf "\n"
  printf "(detailed sections — grep -niA5 \"%s\" %s)\n\n" "$QUERY" "$PATTERNS"
else
  printf "(file not found: %s)\n\n" "$PATTERNS"
fi

printf -- "--- H1-STATISTICS.md ---\n"
if [ -f "$STATS" ]; then
  grep -niE "$QUERY" "$STATS" | grep -E '\$[0-9]' | head -10 || true
  printf "\n"
else
  printf "(file not found: %s)\n\n" "$STATS"
fi

printf -- "--- OUTCOMES.jsonl (local paid records) ---\n"
if [ -f "$OUTCOMES" ] && command -v jq >/dev/null 2>&1; then
  jq -c --arg q "$QUERY" '
    select(
      (.payout_usd // 0) > 0 and
      ((.finding // "") + " " + (.lesson // "") + " " + ((.tags // []) | join(" ")))
        | ascii_downcase
        | contains($q | ascii_downcase)
    )
    | { protocol, finding, severity_claimed, payout_usd, platform: .channel }
  ' "$OUTCOMES" 2>/dev/null || printf "(no local paid records match)\n"
  printf "\n"
else
  printf "(OUTCOMES.jsonl or jq missing — skipping local paid records)\n\n"
fi

# -----------------------------------------------------------------------------
# Section 2: Copy-paste-ready W5 block (REPORT-STANDARD.md syntax)
# -----------------------------------------------------------------------------
#
# Strategy: extract rows from the H1-HUNTING-PATTERNS.md payout hierarchy table
# that match the query, then emit them in REPORT-STANDARD W5 table format
# verbatim. If no rows match, emit a "no paid precedents found" marker so the
# absence is visible (not a silent empty block).

printf "\n=== W5 — copy-paste into REPORT-STANDARD Weight Accounting ===\n\n"

# Build table rows from the top-of-file payout hierarchy table in H1-HUNTING-PATTERNS.md
# Format in source:  "| N | Class name | $X-$Y | trend | volume |"
ROWS=""
if [ -f "$PATTERNS" ]; then
  ROWS=$(grep -iE "^\| *[0-9]+ *\|" "$PATTERNS" \
    | grep -iE "$QUERY" \
    | grep -E '\$[0-9]' || true)
fi

# Also pull specific per-finding rows (report # + $ amount) from the detail sections
DETAILS=""
if [ -f "$PATTERNS" ]; then
  DETAILS=$(grep -niE "$QUERY" "$PATTERNS" \
    | grep -iE "Source:" \
    | grep -E '\$[0-9]' \
    | head -5 || true)
fi

# Also pull matching rows from H1-STATISTICS ROI tables
STATS_ROWS=""
if [ -f "$STATS" ]; then
  STATS_ROWS=$(grep -iE "^\| " "$STATS" \
    | grep -iE "$QUERY" \
    | grep -E '\$[0-9]' || true)
fi

# Emit the W5 block
cat <<'W5_HEADER'
**W5 — Precedent anchor:**

| Report | Class | Payout | Source |
| --- | --- | --- | --- |
W5_HEADER

EMITTED=0

# 1. Hierarchy rows first (broad class → range)
if [ -n "$ROWS" ]; then
  while IFS= read -r line; do
    # Extract class name (column 2) and payout range (first $ pattern)
    CLASS=$(printf '%s' "$line" | awk -F'|' '{gsub(/^ +| +$/,"",$3); print $3}')
    PAYOUT=$(printf '%s' "$line" | grep -oE '\$[0-9]+[KM]?-\$[0-9]+[KM]?|\$[0-9]+[KM]?' | head -1)
    [ -n "$CLASS" ] && [ -n "$PAYOUT" ] && {
      printf '| H1-HUNTING-PATTERNS.md (class table) | %s | %s | H1 disclosed corpus |\n' "$CLASS" "$PAYOUT"
      EMITTED=$((EMITTED + 1))
    }
  done <<< "$ROWS"
fi

# 2. Detail rows (specific disclosed reports with amounts)
if [ -n "$DETAILS" ]; then
  while IFS= read -r line; do
    # Format: "<lineno>:- **Source:** <text with report ID and $>"
    SOURCE_TEXT=$(printf '%s' "$line" | sed -E 's/^[0-9]+:-?\s*\*\*Source:\*\*\s*//')
    # Extract first report ID (HackerOne #NNN, PayPal #NNN, etc.) and first $ amount
    REPORT_ID=$(printf '%s' "$SOURCE_TEXT" | grep -oE '#[0-9]+|CVE-[0-9]{4}-[0-9]+' | head -1)
    PAYOUT=$(printf '%s' "$SOURCE_TEXT" | grep -oE '\$[0-9,]+' | head -1)
    [ -n "$REPORT_ID" ] && [ -n "$PAYOUT" ] && {
      printf '| %s | %s | %s | H1 disclosed |\n' "$REPORT_ID" "$QUERY" "$PAYOUT"
      EMITTED=$((EMITTED + 1))
    }
  done <<< "$DETAILS"
fi

# 3. ROI rows from statistics
if [ -n "$STATS_ROWS" ]; then
  while IFS= read -r line; do
    CLASS=$(printf '%s' "$line" | awk -F'|' '{gsub(/^ +| +$/,"",$2); print $2}')
    PAYOUT=$(printf '%s' "$line" | grep -oE '\$[0-9]+[KM]?-\$[0-9]+[KM]?|\$[0-9]+[KM]?' | head -1)
    [ -n "$CLASS" ] && [ -n "$PAYOUT" ] && {
      printf '| H1-STATISTICS.md (ROI table) | %s | %s | H1 $81M corpus |\n' "$CLASS" "$PAYOUT"
      EMITTED=$((EMITTED + 1))
    }
  done <<< "$STATS_ROWS"
fi

# 4. Local paid records from OUTCOMES.jsonl
if [ -f "$OUTCOMES" ] && command -v jq >/dev/null 2>&1; then
  LOCAL_ROWS=$(jq -r --arg q "$QUERY" '
    select(
      (.payout_usd // 0) > 0 and
      ((.finding // "") + " " + (.lesson // "") + " " + ((.tags // []) | join(" ")))
        | ascii_downcase
        | contains($q | ascii_downcase)
    )
    | "| \(.protocol) | \(.finding) | $\(.payout_usd) | \(.channel // "local") |"
  ' "$OUTCOMES" 2>/dev/null || true)
  if [ -n "$LOCAL_ROWS" ]; then
    printf '%s\n' "$LOCAL_ROWS"
    EMITTED=$((EMITTED + $(printf '%s\n' "$LOCAL_ROWS" | wc -l)))
  fi
fi

# Fallback — no matches at all
if [ "$EMITTED" -eq 0 ]; then
  printf '| (no paid precedents found) | %s | — | — |\n' "$QUERY"
  printf '\n**W5 EMPTY** — no paid precedents matched "%s" in the local corpus.\n' "$QUERY"
  printf 'Options: (a) strengthen W1 with computed dollar loss from on-chain inputs,\n'
  printf '         (b) broaden the keyword and retry,\n'
  printf '         (c) manually cite C4/Cantina/Sherlock reports,\n'
  printf '         (d) downgrade severity to reflect missing market anchor.\n'
fi

printf "\n====================================================================\n"
printf "Emitted %d row(s). Copy the block above into REPORT-STANDARD.md Weight Accounting section.\n" "$EMITTED"

exit 0
