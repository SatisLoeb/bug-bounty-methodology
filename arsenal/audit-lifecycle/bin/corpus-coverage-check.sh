#!/usr/bin/env bash
# corpus-coverage-check.sh — MECHANICAL GATE against "I had the corpus and improvised anyway".
# The encoded!=applied fix: a NO-GO or submission is ILLEGAL until every top-payout-density
# class from the relevant corpus has an EXECUTED artifact logged in CORPUS-COVERAGE.md.
# Source of truth: THIS script. gravedigger prose is human reference; on drift, the script wins.
#
# MULTI-CORPUS (2026-07-31). Was web-only, so SC and node targets had NO coverage gate at all
# (preflight-mechanical fires this "never on SC/other"). The Immunefi audit-comp corpus covers
# exactly that hole: 2403 Smart Contract + 505 Blockchain/DLT findings, payer-assigned severity.
#
#   --corpus web            default — web rows emitted byte-identical to the previous version
#   --corpus immunefi       SC / node targets; rows tagged `imf/<class>`, ranked by payout-weight
#   --corpus web,immunefi   a target with both surfaces; both must be covered
#
# preflight-mechanical.sh needs NO change: its trigger already includes `[ -f CORPUS-COVERAGE.md ]`,
# so an SC target becomes gated the moment it emits a ledger, while a target that never emits one
# stays ungated exactly as today. Opt-in by emitting — no existing workflow starts failing.
set -euo pipefail
LED_NAME="CORPUS-COVERAGE.md"
WQUERY="$HOME/arsenal/tools/web-corpus-query.sh"
IQUERY="$HOME/arsenal/tools/immunefi-corpus-query.sh"
usage(){
  echo "usage: $0 --emit [--corpus web|immunefi|web,immunefi] <shape[,shape2]> <workspace>"
  echo "       $0 --check <workspace>"
  exit 2
}
[ $# -ge 2 ] || usage
MODE="$1"; shift

if [ "$MODE" = "--emit" ]; then
  CORPORA="web"
  if [ "${1:-}" = "--corpus" ]; then shift; CORPORA="${1:?--corpus needs a value}"; shift; fi
  SHAPES="${1:?shape required}"; WS="${2:?workspace path required}"; LED="$WS/$LED_NAME"

  case ",$CORPORA," in *,web,*) [ -e "$WQUERY" ] || { echo "FATAL: web-corpus-query.sh missing ($WQUERY)"; exit 1; };; esac
  case ",$CORPORA," in *,immunefi,*) [ -e "$IQUERY" ] || { echo "FATAL: immunefi-corpus-query.sh missing ($IQUERY)"; exit 1; };; esac

  mkdir -p "$WS"
  {
    echo "# CORPUS COVERAGE LEDGER — shape(s): $SHAPES   corpus: $CORPORA"
    echo "#"
    echo "# HARD GATE (corpus-coverage-check.sh --check): no NO-GO / no submission until EVERY row"
    echo "# below has methods-run flipped to [x] AND a non-empty result AND a non-empty artifact path."
    echo "# Fill a row by: web-corpus-query.sh --methods <class>  -> run the recipe on the target -> log the result."
    echo "#   rows tagged 'imf/' come from the Immunefi audit-comp corpus (payer-assigned severity):"
    echo "#   fill those via  immunefi-corpus-query.sh --class <class>  (detection tell + Crit/High exemplars)."
    echo "# A row still [ ] = a class you did NOT run = the improvisation failure this gate exists to stop."
    echo "# (Rule: LEAD with --methods on the top-2 classes BEFORE any bundle/black-box improvisation.)"
    echo
    echo "| class | payout-density | methods-run | result (finding/null) | executed artifact |"
    echo "|---|---|---|---|---|"
    # `|| true` on every pipeline: a shape absent from one corpus makes its query exit
    # non-zero, and under `set -euo pipefail` that would abort the whole emit block and
    # leave a truncated ledger (measured: `--corpus web,immunefi JWT-session` produced a
    # web-only file and rc=1, silently dropping the corpus the operator asked for).
    case ",$CORPORA," in *,web,*)
      IFS=','; for SH in $SHAPES; do
        { "$WQUERY" "$SH" 2>/dev/null | grep -E '^[[:space:]]+[0-9]+\.[[:space:]]' \
          | awk '{cls=$2; rest=$0; sub(/.*\$/,"$",rest); print "| " cls " | " rest " | [ ] |  |  |"}'; } || true
      done | sort -u
    ;; esac
    case ",$CORPORA," in *,immunefi,*)
      # `--route` rows are "  1. consensus  101  212  0.38  <vein>" -> class=$2 n=$3 weight=$4 C+H=$5.
      # `logic` is the untagged RESIDUE (31.5% of that corpus), not a huntable class — it must never
      # become a ledger row, or the gate would demand an executed artifact for "no class fits".
      IFS=','; for SH in $SHAPES; do
        { "$IQUERY" --route "$SH" 2>/dev/null | grep -E '^[[:space:]]+[0-9]+\.[[:space:]]' \
          | awk '$2 != "logic" { print "| imf/" $2 " | wgt " $4 " (C+H " $5 ") | [ ] |  |  |" }'; } || true
      done | sort -u
    ;; esac
  } > "$LED"
  NROWS=$(grep -cE '^\| ' "$LED" || true)
  echo "wrote $LED  ($((NROWS - 1)) class rows, corpus: $CORPORA)"
  # A corpus that contributed nothing is a silent coverage hole: the ledger would look
  # complete while an entire requested corpus was never consulted. Say so out loud.
  # Count data rows per corpus. Not a prefix heuristic: `| info-disclosure |` is a WEB class
  # that starts with 'i', so anything keying on the first letter mis-reports it as an imf row.
  DATA=$(grep -E '^\| ' "$LED" | grep -vE '^\|[[:space:]]*class[[:space:]]*\|' || true)
  N_IMF=$(printf '%s\n' "$DATA" | grep -c '^| imf/' || true)
  N_WEB=$(printf '%s\n' "$DATA" | grep -vc '^| imf/' || true)
  case ",$CORPORA," in *,immunefi,*)
    [ "${N_IMF:-0}" -gt 0 ] || echo "WARN: corpus 'immunefi' contributed 0 rows — that shape does not exist there. Its shapes: lending, vault/yield, AMM/DEX, perp/derivatives, bridge/cross-chain, staking/LST, stablecoin/RWA, NFT/gaming, governance/DAO, 'L1/L2 node', other.";;
  esac
  case ",$CORPORA," in *,web,*)
    [ "${N_WEB:-0}" -gt 0 ] || echo "WARN: corpus 'web' contributed 0 rows — check the shape name against '$WQUERY --list'.";;
  esac
  case ",$CORPORA," in *,web,*)
    echo "-> LEAD here: web-corpus-query.sh --methods <top-class>  for every [ ] row, BEFORE improvising.";;
  esac
  case ",$CORPORA," in *,immunefi,*)
    echo "-> LEAD here: immunefi-corpus-query.sh --class <class>  for every imf/ [ ] row, BEFORE improvising.";;
  esac
  exit 0
fi

if [ "$MODE" = "--check" ]; then
  WS="${1:?workspace path required}"; LED="$WS/$LED_NAME"
  if [ ! -f "$LED" ]; then
    echo "FAIL: no $LED_NAME in $WS."
    echo "  You are about to close/submit a target WITHOUT a corpus-coverage ledger."
    echo "  Did you query the corpus, or did you improvise? Run:"
    echo "    corpus-coverage-check.sh --emit [--corpus web|immunefi] <shape> $WS"
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
  N=$(echo "$ROWS" | grep -c . || true)
  # A ledger with zero class rows previously PASSed ("all 0 classes covered") — the gate
  # rubber-stamping itself. An empty ledger means the emit found no classes, i.e. the corpus
  # was never actually consulted, which is precisely the improvisation this gate exists to stop.
  if [ "${N:-0}" -eq 0 ]; then
    echo "FAIL: $LED_NAME has ZERO class rows — the corpus was never consulted."
    echo "  An empty ledger is not coverage. Re-emit with a shape that exists:"
    echo "    corpus-coverage-check.sh --emit [--corpus web|immunefi] <shape> $WS"
    exit 1
  fi
  echo "PASS: all $N top-payout-density corpus classes have an executed artifact in $LED_NAME."
  exit 0
fi
usage
