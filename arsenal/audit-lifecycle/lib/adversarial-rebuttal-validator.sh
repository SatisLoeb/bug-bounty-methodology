#!/usr/bin/env bash
# Adversarial Rebuttal Validator
# Verifies that the {FINDING_ID}-adversarial-rebuttal.md file is properly populated.
#
# Usage: adversarial-rebuttal-validator.sh <path-to-rebuttal.md>
# Exit codes:
#   0 = PASS (verdict signed, ≥6 angles filled, no fatal placeholder text)
#   1 = BLOCKED (missing required content)
#   2 = KILL or NEEDS_MORE_EVIDENCE (finding should not proceed to submit)
set -euo pipefail

REBUTTAL_FILE="${1:?Usage: adversarial-rebuttal-validator.sh <rebuttal-file>}"

if [ ! -f "$REBUTTAL_FILE" ]; then
  echo "[adv-rebuttal] ERROR: rebuttal file not found: $REBUTTAL_FILE" >&2
  exit 1
fi

EXIT_CODE=0
ERRORS=()
WARNINGS=()

# Check 1: All 6 mandatory angles have headers
for i in 1 2 3 4 5 6; do
  if ! grep -qE "^## Angle $i:" "$REBUTTAL_FILE"; then
    ERRORS+=("Angle $i header missing")
    EXIT_CODE=1
  fi
done

# Check 2: No <fill — ...> placeholders remain in mandatory sections (Angles 1-6)
# Extract the Angles 1-6 section
awk '
  /^## Angle 1:/ { in_section=1 }
  /^## Optional additional angles/ { in_section=0 }
  in_section { print }
' "$REBUTTAL_FILE" > /tmp/adv-rebuttal-mandatory-$$.md

PLACEHOLDER_COUNT=$(grep -cE "<fill[^>]*>" /tmp/adv-rebuttal-mandatory-$$.md || true)
if [ "$PLACEHOLDER_COUNT" -gt 0 ]; then
  ERRORS+=("$PLACEHOLDER_COUNT unfilled <fill ...> placeholders in mandatory angles 1-6")
  EXIT_CODE=1
fi

# Check 3: Verdict line is signed
VERDICT_LINE=$(grep -E '^\*\*Signed by operator:\*\* `\[x\] ADVERSARIAL_REBUTTAL_SIGNED_' "$REBUTTAL_FILE" || true)
if [ -z "$VERDICT_LINE" ]; then
  ERRORS+=("Verdict not signed (expected: '**Signed by operator:** \`[x] ADVERSARIAL_REBUTTAL_SIGNED_<verdict>\`')")
  EXIT_CODE=1
fi

# Check 4: Extract the verdict and act on it
VERDICT=""
if [ -n "$VERDICT_LINE" ]; then
  VERDICT=$(echo "$VERDICT_LINE" | sed -E 's/.*ADVERSARIAL_REBUTTAL_SIGNED_([A-Z_]+)`.*/\1/')
fi

case "$VERDICT" in
  READY_TO_SUBMIT)
    # Continue with other checks; do not flag the verdict itself
    ;;
  DOWNGRADE_REQUIRED)
    WARNINGS+=("Verdict is DOWNGRADE_REQUIRED — finding cannot submit at current severity. Re-run rebuttal at downgraded severity.")
    EXIT_CODE=1
    ;;
  KILL)
    echo "[adv-rebuttal] VERDICT: KILL"
    echo "[adv-rebuttal] Finding should NOT be submitted. Log to OUTCOMES.jsonl with held_reason=adversarial_rebuttal_fatal."
    exit 2
    ;;
  NEEDS_MORE_EVIDENCE)
    echo "[adv-rebuttal] VERDICT: NEEDS_MORE_EVIDENCE"
    echo "[adv-rebuttal] Acquire required evidence before re-running rebuttal."
    exit 2
    ;;
  "")
    # Already flagged above as missing
    ;;
  *)
    ERRORS+=("Unknown verdict '$VERDICT' — expected READY_TO_SUBMIT / DOWNGRADE_REQUIRED / KILL / NEEDS_MORE_EVIDENCE")
    EXIT_CODE=1
    ;;
esac

# Check 5: Aggregate signal count section is filled (not all <yes/no>)
SIGNAL_SECTION=$(awk '/^\*\*Aggregate signal count:\*\*/,/^\*\*Decision matrix:\*\*/' "$REBUTTAL_FILE" || true)
UNFILLED_SIGNALS=$(echo "$SIGNAL_SECTION" | grep -cE "<yes/no>" || true)
if [ "$UNFILLED_SIGNALS" -gt 0 ]; then
  ERRORS+=("$UNFILLED_SIGNALS unfilled <yes/no> signal markers — fill aggregate signal count")
  EXIT_CODE=1
fi

# Check 6: Rationale paragraph is filled
RATIONALE_LINE=$(awk '/^\*\*Rationale \(one paragraph\):\*\*/{getline; print}' "$REBUTTAL_FILE" || true)
if [ -z "$RATIONALE_LINE" ] || echo "$RATIONALE_LINE" | grep -qE "<fill"; then
  ERRORS+=("Rationale paragraph not filled")
  EXIT_CODE=1
fi

# Cleanup
rm -f /tmp/adv-rebuttal-mandatory-$$.md

# Output
if [ ${#ERRORS[@]} -gt 0 ]; then
  echo "[adv-rebuttal] BLOCKED — issues found:"
  for err in "${ERRORS[@]}"; do
    echo "  - $err"
  done
fi

if [ ${#WARNINGS[@]} -gt 0 ]; then
  echo "[adv-rebuttal] WARNINGS:"
  for w in "${WARNINGS[@]}"; do
    echo "  - $w"
  done
fi

if [ $EXIT_CODE -eq 0 ]; then
  echo "[adv-rebuttal] PASS — verdict: $VERDICT"
fi

exit $EXIT_CODE
