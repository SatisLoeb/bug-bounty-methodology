#!/usr/bin/env bash
# dup-fossil-check.sh — PHASE 0 GATE
#
# A dated "known / accepted / by design" note in the TARGET'S OWN repo is not a
# design-intent argument to rebut. It is a DUP FOSSIL: teams do not pre-emptively
# document an obscure mechanism, they document it because someone REPORTED it, and
# the commit lands within days of the triage response.
#
# Proven on TruFin F-1 (2026-08-05): report #79034 filed 2026-05-20; README commit
# 9cc8862 "known and accepted operational property" landed 2026-05-21 — ONE DAY later.
# The note was read, argued against for six review rounds, and shipped anyway.
# Closed duplicate in 3h07, $0. Corpus dup-checks could never have caught it:
# they cover audit COMPETITIONS; private program submissions exist in no corpus.
# This grep is the only dup signal available before submitting.
#
# Usage: dup-fossil-check.sh <repo-path> [mechanism-keyword ...]
set -uo pipefail

REPO="${1:?usage: dup-fossil-check.sh <repo-path> [mechanism-keyword ...]}"; shift || true
cd "$REPO" 2>/dev/null || { echo "[dup-fossil] not a directory: $REPO"; exit 2; }
git rev-parse --git-dir >/dev/null 2>&1 || { echo "[dup-fossil] not a git repo: $REPO"; exit 2; }

MARKERS=("known and accepted" "known issue" "known limitation" "by design" "intentional"
         "accepted operational" "accepted risk" "will not fix" "wontfix" "as designed"
         "expected behaviour" "expected behavior" "documented limitation"
         "inherited" "temporarily" "does not cause loss" "restores automatically")
# "inherited" and "temporarily" are operator additions: they are the exact words TruFin used
# ("a documented chain-level parameter INHERITED by all pooled delegators", "can TEMPORARILY
# reject new unstakes"). Defensive-doc vocabulary is the tell, not just the word "known".

LAST_AUDIT="${LAST_AUDIT_DATE:-}"   # optional: export LAST_AUDIT_DATE=YYYY-MM-DD
HITS=0

echo "[dup-fossil] repo: $REPO"
[ -n "$LAST_AUDIT" ] && echo "[dup-fossil] last audit: $LAST_AUDIT (hits after this date are the dangerous ones)"

emit() { # date sha subject source
  printf "  %-12s %-10s %-28s %s\n" "$1" "$2" "$4" "$(echo "$3" | cut -c1-58)"
}

echo
echo "── acceptance markers ──"
# grep the CURRENT tree first (fast); pickaxe only the markers that actually exist.
# git log -S over every marker on a large repo is O(commits x markers) and will hang.
for m in "${MARKERS[@]}"; do
  git grep -l -i -F "$m" -- . >/dev/null 2>&1 || continue
  while IFS='|' read -r d sh subj; do
    [ -z "$d" ] && continue
    HITS=$((HITS+1)); emit "$d" "$sh" "$subj" "\"$m\""
  done < <(timeout 20 git log -S "$m" --format='%ad|%h|%s' --date=short -- . 2>/dev/null | head -3)
done

if [ "$#" -gt 0 ]; then
  echo
  echo "── mechanism keywords ──"
  for k in "$@"; do
    while IFS='|' read -r d sh subj; do
      [ -z "$d" ] && continue
      HITS=$((HITS+1)); emit "$d" "$sh" "$subj" "\"$k\""
    done < <(timeout 25 git log -S "$k" --format='%ad|%h|%s' --date=short -- . 2>/dev/null | head -5)
  done
fi

echo
if [ "$HITS" -eq 0 ]; then
  echo "[dup-fossil] RESULT: CLEAN — no acceptance marker found."
  echo
  echo "  THE TEST ONLY WORKS IN ONE DIRECTION. A dated note is STRONG evidence that"
  echo "  someone already filed. Its ABSENCE proves nothing: many projects close reports"
  echo "  without ever touching their docs, and private program submissions are invisible"
  echo "  from outside and appear in no corpus. CLEAN means 'no fossil found', never"
  echo "  'nobody reported this'. Weight the target regime accordingly: on code too fresh"
  echo "  for anyone to have had time to report, absence is meaningful; on 3-year-old code"
  echo "  it is worthless."
  exit 0
fi

cat <<EOF
[dup-fossil] RESULT: $HITS FOSSIL HIT(S) — treat the finding as PRESUMPTIVELY DUPLICATE.

  A dated acceptance note means a prior report almost certainly exists. To proceed
  you need a DIFFERENT IMPACT CLASS or a DIFFERENT ACTOR, not a better argument
  against the note. A strictly superior write-up of the same finding pays ZERO:
  novelty is binary and orthogonal to quality.

  Before spending another hour, answer in one line each:
    1. What impact does my finding reach that the note does NOT cover?
    2. Which actor reaches it that the note's threat model excludes?
  If either answer is "a better PoC" or "more precise numbers" — STOP, re-source.
EOF
exit 1
