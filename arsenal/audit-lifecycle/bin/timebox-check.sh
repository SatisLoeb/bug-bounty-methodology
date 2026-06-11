#!/usr/bin/env bash
# timebox-check.sh — Mechanize the 8h rule vs L1 exception.
#
# CLAUDE.md Time-Boxing rule: 8h max surface scan, MOVE ON after 8h/0 findings.
# EXCEPTION: high-value blockchain L1 targets with deep cross-subsystem complexity.
#
# Calibration metric: LOC × subsystem_count
#   - LOC: source files in scope (Rust/Go/Java/C++/Solidity)
#   - subsystem_count: top-level dirs with >500 LOC AND distinct concerns
#
# Empirical thresholds (calibrated on Monad, TRON java-tron, and standard workspaces):
#   - LOC < 30K OR subsystems < 4  → STANDARD_8H
#   - LOC >= 30K AND subsystems >= 4 → L1_EXCEPTION eligible
#   - LOC >= 100K (blockchain L1 scale) → L1_EXCEPTION mandatory
#
# Usage:
#   timebox-check.sh <target-dir>              # Analyze and verdict
#   timebox-check.sh <target-dir> --calibrate  # Show raw numbers, no verdict
#   timebox-check.sh --recalibrate             # Re-run on Monad + TRON to refine

set -uo pipefail

BOLD=$(tput bold 2>/dev/null || echo "")
RED=$(tput setaf 1 2>/dev/null || echo "")
GREEN=$(tput setaf 2 2>/dev/null || echo "")
YELLOW=$(tput setaf 3 2>/dev/null || echo "")
BLUE=$(tput setaf 4 2>/dev/null || echo "")
RESET=$(tput sgr0 2>/dev/null || echo "")

THRESHOLD_LOC_L1_ELIGIBLE=30000
THRESHOLD_SUBSYS_L1_ELIGIBLE=4
THRESHOLD_LOC_L1_MANDATORY=100000
SUBSYSTEM_MIN_LOC=500

usage() {
  cat <<EOF
Usage: $0 <target-dir>              # Verdict
       $0 <target-dir> --calibrate  # Raw metrics only
       $0 --recalibrate             # Re-run on L1 reference targets

Calibrated thresholds:
  LOC < $THRESHOLD_LOC_L1_ELIGIBLE OR subsystems < $THRESHOLD_SUBSYS_L1_ELIGIBLE → STANDARD_8H
  LOC >= $THRESHOLD_LOC_L1_ELIGIBLE AND subsystems >= $THRESHOLD_SUBSYS_L1_ELIGIBLE → L1_EXCEPTION
  LOC >= $THRESHOLD_LOC_L1_MANDATORY → L1_EXCEPTION mandatory
EOF
}

# Count lines of code across recognized extensions
count_loc() {
  local dir="$1"
  # Use -L to follow symlinks (subtrees often symlinked)
  find "$dir" -type f \( \
    -name "*.rs" -o -name "*.go" -o -name "*.java" -o -name "*.kt" \
    -o -name "*.c" -o -name "*.cpp" -o -name "*.cc" -o -name "*.h" -o -name "*.hpp" \
    -o -name "*.sol" -o -name "*.cairo" -o -name "*.move" \
    -o -name "*.py" -o -name "*.js" -o -name "*.ts" -o -name "*.tsx" -o -name "*.jsx" \
  \) \
    ! -path "*/node_modules/*" \
    ! -path "*/target/*" \
    ! -path "*/dist/*" \
    ! -path "*/build/*" \
    ! -path "*/.git/*" \
    ! -path "*/vendor/*" \
    ! -path "*/__pycache__/*" \
    ! -path "*/venv/*" \
    ! -path "*/test/*" \
    ! -path "*/tests/*" \
    ! -path "*/spec/*" \
    -print0 2>/dev/null | xargs -0 wc -l 2>/dev/null | awk 'END{print $1}'
}

# Count subsystems: top-level directories (depth 1-2) with >SUBSYSTEM_MIN_LOC LOC
count_subsystems() {
  local dir="$1"
  local count=0
  local list=""

  # Inspect depth-1 children first
  for child in "$dir"/*/; do
    [ -d "$child" ] || continue
    local name="$(basename "$child")"
    # Skip common non-source dirs
    case "$name" in
      node_modules|target|dist|build|.git|vendor|__pycache__|venv|test|tests|docs|scripts|examples) continue ;;
    esac
    local child_loc="$(count_loc "$child")"
    child_loc="${child_loc:-0}"
    if [ "$child_loc" -ge "$SUBSYSTEM_MIN_LOC" ] 2>/dev/null; then
      count=$((count+1))
      list="$list$name($child_loc)\n"
    fi
  done

  # If only 1-2 child dirs, inspect depth 2 for monorepo pattern (crates/, pkg/, src/)
  if [ "$count" -le 2 ]; then
    for nest in "$dir/crates" "$dir/pkg" "$dir/packages" "$dir/src" "$dir/contracts" "$dir/apps"; do
      [ -d "$nest" ] || continue
      for child in "$nest"/*/; do
        [ -d "$child" ] || continue
        local name="$(basename "$child")"
        case "$name" in
          node_modules|target|dist|build|.git|vendor|__pycache__|venv|test|tests|docs|scripts|examples) continue ;;
        esac
        local child_loc="$(count_loc "$child")"
        child_loc="${child_loc:-0}"
        if [ "$child_loc" -ge "$SUBSYSTEM_MIN_LOC" ] 2>/dev/null; then
          count=$((count+1))
          list="$list$(basename "$nest")/$name($child_loc)\n"
        fi
      done
    done
  fi

  echo "$count|$list"
}

# Verdict logic
verdict() {
  local loc="$1" subs="$2"
  if [ "$loc" -ge "$THRESHOLD_LOC_L1_MANDATORY" ] 2>/dev/null; then
    echo "L1_EXCEPTION_MANDATORY"
  elif [ "$loc" -ge "$THRESHOLD_LOC_L1_ELIGIBLE" ] 2>/dev/null && [ "$subs" -ge "$THRESHOLD_SUBSYS_L1_ELIGIBLE" ] 2>/dev/null; then
    echo "L1_EXCEPTION_ELIGIBLE"
  else
    echo "STANDARD_8H"
  fi
}

# Single-target analysis
analyze_one() {
  local dir="$1"
  local calibrate_mode="${2:-0}"

  if [ ! -d "$dir" ]; then
    echo "${RED}ERROR${RESET}: not a directory: $dir" >&2
    return 2
  fi

  echo "${BOLD}Analyzing:${RESET} $dir"

  local loc
  loc="$(count_loc "$dir")"
  loc="${loc:-0}"
  echo "  LOC (source, excl. tests/vendor): ${BLUE}$loc${RESET}"

  local subs_output
  subs_output="$(count_subsystems "$dir")"
  local subs="${subs_output%%|*}"
  local subs_list="${subs_output#*|}"
  echo "  Subsystems (>${SUBSYSTEM_MIN_LOC} LOC): ${BLUE}$subs${RESET}"
  if [ -n "$subs_list" ] && [ "${subs_list// /}" != "" ]; then
    echo -e "$subs_list" | grep -v '^$' | head -10 | sed 's/^/    - /'
    local total_shown
    total_shown=$(echo -e "$subs_list" | grep -c '^' || echo 0)
    if [ "$total_shown" -gt 10 ] 2>/dev/null; then
      echo "    ... and $((total_shown - 10)) more"
    fi
  fi

  if [ "$calibrate_mode" = "1" ]; then
    echo "  Raw metrics: LOC=$loc, subsystems=$subs"
    return 0
  fi

  local v
  v="$(verdict "$loc" "$subs")"

  echo
  case "$v" in
    L1_EXCEPTION_MANDATORY)
      echo "${BOLD}${RED}VERDICT: L1_EXCEPTION_MANDATORY${RESET}"
      echo "  This target meets blockchain L1 scale criteria."
      echo "  8h rule does NOT apply. Deep cross-subsystem analysis expected (24-48h+)."
      echo "  Follow CLAUDE.md rule #33 (lock contention cross-subsystem audit)."
      ;;
    L1_EXCEPTION_ELIGIBLE)
      echo "${BOLD}${YELLOW}VERDICT: L1_EXCEPTION_ELIGIBLE${RESET}"
      echo "  Target is large and multi-subsystem. 8h rule may be extended."
      echo "  Justify extension with specific cross-subsystem interaction analysis."
      ;;
    STANDARD_8H)
      echo "${BOLD}${GREEN}VERDICT: STANDARD_8H${RESET}"
      echo "  Apply CLAUDE.md 8h rule: if 0 findings after 8h scan, MOVE ON."
      echo "  No L1 exception — target is too small or too unified."
      ;;
  esac
  return 0
}

# Recalibration on L1 reference targets
recalibrate() {
  echo "${BOLD}Recalibration pass${RESET} — checking Monad, TRON, and comparison targets"
  echo

  # Use known L1 targets from BUGS/
  for candidate in \
      "$HOME/Desktop/BUGS/monad-audit/monad-bft" \
      "$HOME/Desktop/BUGS/monad-audit/monad" \
      "$HOME/Desktop/BUGS/tron-recon" \
      "$HOME/Desktop/BUGS/xrpl-attackathon-audit" \
      "$HOME/Desktop/BUGS/k2-lend-audit"; do
    if [ -d "$candidate" ]; then
      analyze_one "$candidate" 1
      echo
    fi
  done

  # Comparison: a small SC target
  for candidate in \
      "$HOME/Desktop/BUGS/polymarket-cantina-tracker" \
      "$HOME/Desktop/BUGS/ethena-bbp"; do
    if [ -d "$candidate" ]; then
      analyze_one "$candidate" 1
      echo
    fi
  done

  echo "${BOLD}Recalibration data:${RESET}"
  echo "  Current thresholds (LOC=$THRESHOLD_LOC_L1_ELIGIBLE+ AND subsystems=$THRESHOLD_SUBSYS_L1_ELIGIBLE+ → L1 eligible)"
  echo "  Adjust constants at the top of this script if empirical results suggest different."
}

# Parse args
if [ $# -eq 0 ]; then
  usage
  exit 1
fi

case "$1" in
  -h|--help)
    usage
    exit 0
    ;;
  --recalibrate)
    recalibrate
    exit 0
    ;;
  *)
    TARGET="$1"
    shift
    CAL=0
    [ "${1:-}" = "--calibrate" ] && CAL=1
    analyze_one "$TARGET" "$CAL"
    ;;
esac
