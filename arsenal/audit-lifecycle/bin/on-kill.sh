#!/usr/bin/env bash
# on-kill.sh — record a dismissed/killed finding as a new kill-pattern rule.
#
# Usage: on-kill.sh <finding-id> <reason-short> [workspace]
# Example: on-kill.sh SNOW-002 "theoretical multi-party" /home/malix/Desktop/BUGS/snowbridge-audit
#
# Appends to OUTCOMES.jsonl + prompts operator to add a rule to KILLED-FINDINGS-LESSONS.yaml
set -euo pipefail

FINDING_ID="${1:?Usage: on-kill.sh <FINDING_ID> <reason-short> [workspace]}"
REASON="${2:?Usage: on-kill.sh <FINDING_ID> <reason-short> [workspace]}"
WORKSPACE="${3:-${WORKSPACE:-$(pwd)}}"
LESSONS="${KILLED_LESSONS:-$HOME/Desktop/BUGS/KILLED-FINDINGS-LESSONS.yaml}"

NOW="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

# Log to workspace-local OUTCOMES.jsonl
cat >> "$WORKSPACE/OUTCOMES.jsonl" <<EOF
{"id":"$FINDING_ID","outcome":"dismissed","held_reason":"gate_failed_unresolved","result_at":"$NOW","reward":0,"notes":"KILL: $REASON"}
EOF

# Mark in .lifecycle-status
echo "killed:$NOW:$FINDING_ID:$REASON" >> "$WORKSPACE/.lifecycle-status"

cat <<EOF
[on-kill] logged dismissal of $FINDING_ID: $REASON

NEXT STEP — codify the lesson so next finding doesn't repeat the mistake:

Edit $LESSONS and append:

  - id: [short-slug-for-this-rule]
    derived_from: [$FINDING_ID]
    trigger_pattern: "[describe when this type of finding should be KILLed pre-submit]"
    kill_reason: "$REASON"
    pre_submit_check: "[concrete check operator should run]"
    rule_strength: candidate
    added: $(date -u +%Y-%m-%d)
    count: 1

If a rule with the same pattern already exists:
  - increment its count: field
  - add this finding to its derived_from: list
  - if count reaches 2+, promote rule_strength to confirmed

Lessons file: $LESSONS
EOF
