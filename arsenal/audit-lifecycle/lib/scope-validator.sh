#!/usr/bin/env bash
# scope-validator.sh — validates a filled {id}-scope-check.md before drafting proceeds.
#
# Exit 0 = PASS (operator may proceed to stage 2 gates)
# Exit 1 = BLOCKED with reasons (operator must fix or KILL)
#
# Checks:
#   1. Scope section (Step 1) has non-placeholder content
#   2. OOS list (Step 2) has non-placeholder content
#   3. OOS grid (Step 3) has at least one checkbox filled per row (no blank rows)
#   4. Asset match (Step 4) has one box checked
#   5. Verdict (Step 5) has exact signature line
#   6. If any MATCH checkbox in Step 3 is ticked, the same row must have justification text
#
# Usage: scope-validator.sh <scope-check-file>
set -euo pipefail

FILE="${1:?Usage: scope-validator.sh <scope-check-file>}"

if [ ! -f "$FILE" ]; then
  echo "[scope-validator] ERROR: file not found: $FILE" >&2
  exit 1
fi

FAIL=0
LOG=""

# Check 1 — Step 1 scope section filled (no bracketed placeholder)
if grep -qE '^\[paste the scope section' "$FILE"; then
  LOG="$LOG\n[scope-1] FAIL: Step 1 (in-scope assets) still has placeholder text"
  FAIL=$((FAIL + 1))
fi

# Check 2 — Step 2 OOS section filled
if grep -qE '^\[paste the "Out of Scope"' "$FILE"; then
  LOG="$LOG\n[scope-2] FAIL: Step 2 (program-specific OOS) still has placeholder text"
  FAIL=$((FAIL + 1))
fi

# Check 3 — Step 3 grid: every OOS row must have exactly one checkbox filled
# Pattern: | <OOS token> | [ ] / [ ] | ...  (blank)
#          | <OOS token> | [x] / [ ] | ...  (MATCH)
#          | <OOS token> | [ ] / [x] | ...  (NOMATCH)
BLANK_ROWS=$(grep -cE '^\|[^|]*\| \[ \] / \[ \] \|' "$FILE" || true)
if [ "$BLANK_ROWS" -gt 0 ]; then
  LOG="$LOG\n[scope-3] FAIL: $BLANK_ROWS OOS grid row(s) have no checkbox filled (both MATCH and NOMATCH empty)"
  FAIL=$((FAIL + 1))
fi

# Check 3b — Any row with BOTH boxes ticked is ambiguous, block
DOUBLE_ROWS=$(grep -cE '^\|[^|]*\| \[x\] / \[x\] \|' "$FILE" || true)
if [ "$DOUBLE_ROWS" -gt 0 ]; then
  LOG="$LOG\n[scope-3b] FAIL: $DOUBLE_ROWS OOS grid row(s) have both MATCH and NOMATCH ticked (ambiguous)"
  FAIL=$((FAIL + 1))
fi

# Check 3c — Any MATCH row must have justification (not empty trailing cell)
# Pattern: | ... | [x] / [ ] | <justification> |
# We require the justification cell to be non-empty (at least 10 chars of non-whitespace)
MATCH_ROWS_NO_JUSTIFICATION=$({ grep -E '^\|[^|]*\| \[x\] / \[ \] \|' "$FILE" || true; } | \
  awk -F'|' '{
    # field 4 is the justification (fields are: "", "token", "checkboxes", "justif", "")
    gsub(/^[ \t]+|[ \t]+$/, "", $4)
    if (length($4) < 10) print
  }' | wc -l)
if [ "$MATCH_ROWS_NO_JUSTIFICATION" -gt 0 ]; then
  LOG="$LOG\n[scope-3c] FAIL: $MATCH_ROWS_NO_JUSTIFICATION MATCH row(s) without sufficient justification text"
  LOG="$LOG\n          MATCH means the finding hits an OOS token — required explanation of why it still qualifies"
  FAIL=$((FAIL + 1))
fi

# Check 4 — Step 4 asset match: exactly one checkbox ticked
ASSET_MATCHES=$(grep -cE '^- \[x\]' "$FILE" || true)
# We expect the verdict line's [x] + exactly one Step 4 [x]. Count all [x] occurrences in asset block.
# Simpler: extract the asset-check subsection and count [x]
ASSET_BLOCK=$(awk '/^## Step 4/,/^## Step 5/' "$FILE" | grep -cE '^- \[x\]' || true)
if [ "$ASSET_BLOCK" -lt 1 ]; then
  LOG="$LOG\n[scope-4] FAIL: Step 4 (asset scope match) has no checkbox ticked"
  FAIL=$((FAIL + 1))
fi
if [ "$ASSET_BLOCK" -gt 1 ]; then
  LOG="$LOG\n[scope-4] FAIL: Step 4 (asset scope match) has multiple checkboxes ticked (exactly one required)"
  FAIL=$((FAIL + 1))
fi

# Check 5 — Verdict signature
if grep -qE '^\*\*Signed by operator:\*\* `\[x\] SCOPE_CHECK_SIGNED_PROCEED`' "$FILE"; then
  SIGNED="PROCEED"
elif grep -qE '^\*\*Signed by operator:\*\* `\[x\] SCOPE_CHECK_SIGNED_KILL`' "$FILE"; then
  SIGNED="KILL"
elif grep -qE '^\*\*Signed by operator:\*\* `\[x\] SCOPE_CHECK_SIGNED_AMEND`' "$FILE"; then
  SIGNED="AMEND"
else
  LOG="$LOG\n[scope-5] FAIL: no valid verdict signature found"
  LOG="$LOG\n          expected exact string: \`[x] SCOPE_CHECK_SIGNED_PROCEED\` (or _KILL or _AMEND)"
  FAIL=$((FAIL + 1))
  SIGNED="MISSING"
fi

# Report
if [ $FAIL -eq 0 ]; then
  echo "[scope-validator] $FILE"
  echo "[scope-validator] verdict: $SIGNED"
  echo "[scope-validator] RESULT: PASS"
  if [ "$SIGNED" = "PROCEED" ]; then
    exit 0
  elif [ "$SIGNED" = "KILL" ]; then
    echo "[scope-validator] NOTE: verdict is KILL — do NOT proceed to stage 2. Log to OUTCOMES.jsonl."
    exit 2
  elif [ "$SIGNED" = "AMEND" ]; then
    echo "[scope-validator] NOTE: verdict is AMEND — reframe finding before re-running scope check."
    exit 2
  fi
else
  echo "[scope-validator] $FILE"
  echo -e "[scope-validator] FAILURES:$LOG"
  echo "[scope-validator] RESULT: BLOCKED ($FAIL failure(s))"
  exit 1
fi
