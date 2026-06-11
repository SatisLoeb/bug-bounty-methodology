#!/usr/bin/env bash
# inject-kill-lessons.sh — append relevant kill-pattern rules to a kill-gate.md file.
#
# Usage: inject-kill-lessons.sh <kill-gate-path> [lessons-yaml-path]
#
# Reads KILLED-FINDINGS-LESSONS.yaml. For each rule marked rule_strength:confirmed
# or rule_strength:candidate, appends a "Known kill patterns" section to the
# kill-gate file of the new finding. Operator reviews each pattern against the
# current finding.
#
# Called by on-finding.sh --stage 2 automatically.
set -euo pipefail

KILL_GATE="${1:?Usage: inject-kill-lessons.sh <kill-gate-path> [lessons-yaml]}"
LESSONS="${2:-$HOME/Desktop/BUGS/KILLED-FINDINGS-LESSONS.yaml}"

if [ ! -f "$KILL_GATE" ]; then
  echo "[inject-kill-lessons] ERROR: kill-gate not found: $KILL_GATE" >&2
  exit 1
fi

if [ ! -f "$LESSONS" ]; then
  echo "[inject-kill-lessons] WARN: lessons file not found, skipping injection: $LESSONS" >&2
  exit 0
fi

# Check if already injected
if grep -q "^## Known kill patterns" "$KILL_GATE"; then
  echo "[inject-kill-lessons] already injected, skipping"
  exit 0
fi

# Parse YAML (light — grep-based, sufficient for this schema)
# Emit one markdown checklist entry per rule
TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT

cat >> "$TMP" <<'EOF'

---

## Known kill patterns (auto-injected from KILLED-FINDINGS-LESSONS.yaml)

**Instructions:** For each rule below, cross-reference your finding. If the rule matches, apply the pre-submit check. If the check fails, KILL or DOWNGRADE.

EOF

# Parse rules via awk
awk '
  /^  - id:/ { gsub(/^  - id: */, ""); id=$0; rule_str=""; next }
  /^    derived_from:/ { gsub(/^    derived_from: */, ""); derived=$0 }
  /^    trigger_pattern:/ { gsub(/^    trigger_pattern: */, ""); gsub(/^"/, ""); gsub(/"$/, ""); trig=$0 }
  /^    kill_reason:/ { gsub(/^    kill_reason: */, ""); gsub(/^"/, ""); gsub(/"$/, ""); kr=$0 }
  /^    pre_submit_check:/ { gsub(/^    pre_submit_check: */, ""); gsub(/^"/, ""); gsub(/"$/, ""); psc=$0 }
  /^    rule_strength:/ { gsub(/^    rule_strength: */, ""); rs=$0 }
  /^    count:/ {
    gsub(/^    count: */, ""); ct=$0
    printf "### %s  (strength: %s · fired %sx · from %s)\n\n", id, rs, ct, derived
    printf "- [ ] **When it applies:** %s\n", trig
    printf "- **Why previous finding died:** %s\n", kr
    printf "- **Pre-submit check:** %s\n\n", psc
    id=""; derived=""; trig=""; kr=""; psc=""; rs=""; ct=""
  }
' "$LESSONS" >> "$TMP"

cat >> "$TMP" <<'EOF'

**Operator acknowledgement:** After reviewing all patterns above, check this box to confirm each was cross-referenced against the current finding:

- [ ] All injected kill patterns reviewed. Finding does not match any, or matches with documented justification in the dismissal matrix.

If any pattern matched without justification, STOP. Reframe the finding or KILL. Do not continue to severity-commit.
EOF

# Append to kill-gate
cat "$TMP" >> "$KILL_GATE"

NOW="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo "[inject-kill-lessons] injected $(awk '/^  - id:/ { c++ } END { print c }' "$LESSONS") kill-pattern rules at $NOW"
echo "[inject-kill-lessons] into: $KILL_GATE"
