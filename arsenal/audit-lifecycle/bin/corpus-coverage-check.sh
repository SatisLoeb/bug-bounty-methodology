#!/usr/bin/env bash
# corpus-coverage-check.sh — MECHANICAL GATE against "I had the web corpus and improvised anyway".
# The encoded!=applied fix: a web/API NO-GO or submission is ILLEGAL until every top-payout-density
# class from the web corpus has an EXECUTED artifact logged in CORPUS-COVERAGE.md.
# Source of truth: THIS script. gravedigger prose is human reference; on drift, the script wins.
set -euo pipefail
LED_NAME="CORPUS-COVERAGE.md"
QUERY="$HOME/arsenal/tools/web-corpus-query.sh"
usage(){ echo "usage: $0 --emit <shape[,shape2]> <workspace>   |   --check <workspace>"; exit 2; }
[ $# -ge 2 ] || usage
MODE="$1"

if [ "$MODE" = "--emit" ]; then
  SHAPES="$2"; WS="${3:?workspace path required}"; LED="$WS/$LED_NAME"
  [ -x "$QUERY" ] || { echo "FATAL: web-corpus-query.sh missing/----not-exec ($QUERY)"; exit 1; }
  mkdir -p "$WS"
  {
    echo "# CORPUS COVERAGE LEDGER — shape(s): $SHAPES"
    echo "#"
    echo "# HARD GATE (corpus-coverage-check.sh --check): no NO-GO / no submission until EVERY row"
    echo "# below has methods-run flipped to [x] AND a non-empty result AND a non-empty artifact path."
    echo "# Fill a row by: web-corpus-query.sh --methods <class>  -> run the recipe on the target -> log the result."
    echo "# A row still [ ] = a class you did NOT run = the improvisation failure this gate exists to stop."
    echo "# (Rule: LEAD with --methods on the top-2 classes BEFORE any bundle/black-box improvisation.)"
    echo
    echo "| class | payout-density | methods-run | result (finding/null) | executed artifact |"
    echo "|---|---|---|---|---|"
    IFS=','; for SH in $SHAPES; do
      "$QUERY" "$SH" 2>/dev/null | grep -E '^[[:space:]]+[0-9]+\.[[:space:]]' \
        | awk '{cls=$2; rest=$0; sub(/.*\$/,"$",rest); print "| " cls " | " rest " | [ ] |  |  |"}'
    done | sort -u
  } > "$LED"
  echo "wrote $LED"
  echo "-> LEAD here: web-corpus-query.sh --methods <top-class>  for every [ ] row, BEFORE improvising."
  exit 0
fi

if [ "$MODE" = "--check" ]; then
  WS="${2:?workspace path required}"; LED="$WS/$LED_NAME"
  if [ ! -f "$LED" ]; then
    echo "FAIL: no $LED_NAME in $WS."
    echo "  You are about to close/submit a web target WITHOUT a corpus-coverage ledger."
    echo "  Did you query the corpus, or did you improvise? Run:  corpus-coverage-check.sh --emit <shape> $WS"
    exit 1
  fi
  ROWS=$(grep -E '^\|' "$LED" | grep -vE '^\|[[:space:]]*class[[:space:]]*\||^\|[-: ]+\|' || true)
  UNRUN=$(echo "$ROWS" | grep -F '[ ]' || true)
  # empty result/artifact cells: a row marked [x] but with blank col4 or col5
  EMPTY=$(echo "$ROWS" | awk -F'|' 'NF>=6 && $4 ~ /\[x\]/ { if ($5 ~ /^[[:space:]]*$/ || $6 ~ /^[[:space:]]*$/) print }' || true)
  FAIL=0
  if [ -n "$UNRUN" ]; then echo "FAIL: corpus classes not yet run (each is a missed-finding risk):"; echo "$UNRUN"; FAIL=1; fi
  if [ -n "$EMPTY" ]; then echo "FAIL: rows marked run but missing result/artifact:"; echo "$EMPTY"; FAIL=1; fi
  [ "$FAIL" = 0 ] || exit 1
  N=$(echo "$ROWS" | grep -c . || echo 0)
  echo "PASS: all $N top-payout-density corpus classes have an executed artifact in $LED_NAME."
  exit 0
fi
usage
