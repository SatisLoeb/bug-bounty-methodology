#!/usr/bin/env bash
# INVOCATION CONDITION: FIRST action of any new target engagement, regardless of skill
# (gravedigger, mrrobbot, manual). Idempotent.
#
# Enforces CLAUDE.md rule #38.
#
# Usage: init-target.sh <target-name> [workspace-path] [--scope-url <url>]
# Env:
#   TARGET_HINTS    — classifier keywords for target-router.sh (MERGED with auto-detected)
#   SCOPE_URL       — program page URL for auto-extraction (alternative to --scope-url)
#   NO_AUTODETECT   — set to 1 to skip auto-detection entirely (use only TARGET_HINTS)
#   WORKSPACE       — override default workspace path
#   LIFECYCLE_ENFORCE — soft (warnings only) or hard (blocks). Default: soft.
#
# Auto-detection: if NO_AUTODETECT is unset, runs lib/auto-detect-hints.sh which scans
# SCOPE_URL body + workspace (manifests, docs, source extensions, directory names) and
# merges detected keywords with user-supplied TARGET_HINTS. The merge is a set union —
# user hints are NEVER overridden or dropped.
set -euo pipefail

TARGET="${1:?Usage: init-target.sh <target-name> [workspace-path] [--scope-url <url>]}"
shift

WORKSPACE=""
SCOPE_URL="${SCOPE_URL:-}"
while [ $# -gt 0 ]; do
  case "$1" in
    --scope-url) SCOPE_URL="$2"; shift 2 ;;
    --scope-url=*) SCOPE_URL="${1#--scope-url=}"; shift ;;
    *) WORKSPACE="$1"; shift ;;
  esac
done
WORKSPACE="${WORKSPACE:-${WORKSPACE_ENV:-$HOME/Desktop/BUGS/${TARGET}-audit}}"

LIFECYCLE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEMPLATES="$LIFECYCLE_DIR/templates"
LIB="$LIFECYCLE_DIR/lib"

mkdir -p "$WORKSPACE"/{findings,evidence,submissions}

# Copy SEVERITY-COMMIT template to workspace root (used as per-finding source by on-finding.sh)
if [ ! -f "$WORKSPACE/SEVERITY-COMMIT-template.md" ]; then
  cp "$TEMPLATES/SEVERITY-COMMIT.md" "$WORKSPACE/SEVERITY-COMMIT-template.md"
fi

# Initialize PROGRESS.md with gate stack if missing (don't overwrite existing)
if [ ! -f "$WORKSPACE/PROGRESS.md" ]; then
  sed "s/{TARGET}/$TARGET/g; s|\[path\]|$WORKSPACE|g; s|\[timestamp\]|$(date -u +%Y-%m-%dT%H:%M:%SZ)|" \
    "$TEMPLATES/PROGRESS.md" > "$WORKSPACE/PROGRESS.md"
fi

# Initialize SCOPE.md (program scope + OOS, populated by operator before first on-finding)
if [ ! -f "$WORKSPACE/SCOPE.md" ]; then
  if [ -n "$SCOPE_URL" ]; then
    # Auto-extract from URL
    bash "$LIFECYCLE_DIR/bin/scope-parser.sh" "$SCOPE_URL" "$WORKSPACE/SCOPE.md" "$TARGET" 2>&1 | sed 's/^/  /'
  else
    sed "s/{TARGET}/$TARGET/g" "$TEMPLATES/SCOPE-workspace.md" > "$WORKSPACE/SCOPE.md"
  fi
fi

# Auto-detect hints from SCOPE_URL + workspace contents (idempotent)
# Merge result with user-supplied TARGET_HINTS (set union — user hints never dropped)
AUTO_HINTS=""
if [ "${NO_AUTODETECT:-0}" != "1" ]; then
  AUTO_HINTS=$(bash "$LIB/auto-detect-hints.sh" "$WORKSPACE" "$SCOPE_URL" 2>/dev/null | tr -s ' ' | sed 's/^ //; s/ $//')
fi

# Union: combine, split on spaces, sort -u, re-join
MERGED_HINTS=""
if [ -n "${TARGET_HINTS:-}" ] || [ -n "$AUTO_HINTS" ]; then
  MERGED_HINTS=$(printf '%s\n%s\n' "${TARGET_HINTS:-}" "$AUTO_HINTS" \
    | tr ' ' '\n' | sort -u | grep -v '^$' | tr '\n' ' ' | sed 's/ $//')
fi

# Run target-router.sh with merged hints, emit ROUTING.md
TARGET_HINTS="$MERGED_HINTS" bash "$LIB/target-router.sh" "$TARGET" > "$WORKSPACE/ROUTING.md"

# Initialize SURFACE-INVENTORY.md stub (Phase-0 auto-sweep fills it before the first hunt).
# Living memory of EVERY surface (in-scope + adjacent), hunt-independent. See
# ~/.claude/skills/SURFACE-INVENTORY-PLAYBOOK.md. Twin of the end-of-engagement COVERAGE-LEDGER.
if [ ! -f "$WORKSPACE/SURFACE-INVENTORY.md" ] && [ -f "$TEMPLATES/SURFACE-INVENTORY.md" ]; then
  sed -e "s/{TARGET}/$TARGET/g" -e "s/{DATE}/$(date -u +%Y-%m-%d)/g" \
    "$TEMPLATES/SURFACE-INVENTORY.md" > "$WORKSPACE/SURFACE-INVENTORY.md"
  echo "  SURFACE-INVENTORY.md stub written — run the Phase-0 auto-sweep before the first hunt"
fi

# Run timebox-check.sh if source code is already present (e.g., git-cloned in workspace)
# Picks up LOC + subsystem count and advises STANDARD_8H or L1_EXCEPTION
TIMEBOX_FILE="$WORKSPACE/.timebox-verdict"
if [ ! -f "$TIMEBOX_FILE" ]; then
  # Try common subdirectories where source is cloned
  for src_candidate in "$WORKSPACE" "$WORKSPACE/src" "$WORKSPACE/$TARGET" \
                        "$WORKSPACE/contracts" "$WORKSPACE/node" "$WORKSPACE/protocol"; do
    if [ -d "$src_candidate" ]; then
      # Only run if candidate has >500 LOC of source to be worth analyzing
      SAMPLE_LOC=$(find "$src_candidate" -type f \( -name "*.rs" -o -name "*.go" -o -name "*.sol" -o -name "*.java" -o -name "*.py" -o -name "*.ts" \) 2>/dev/null | head -1)
      if [ -n "$SAMPLE_LOC" ]; then
        bash "$LIFECYCLE_DIR/bin/timebox-check.sh" "$src_candidate" > "$TIMEBOX_FILE" 2>&1 || true
        break
      fi
    fi
  done
fi

# Run saturation-score.sh — UPSTREAM target-gate (Mezo $0 lesson: don't prove-null on a picked-clean core).
# Computes audit_count/auditor_tier/adversarial-devtests/freshness + scans for a PAYABLE SURFACE.
# HIGH score (>=60) = RE-SOURCE to a payable surface (web/API/off-chain/fresh), NOT prove-null on the core.
# See feedback_fortress_target_selection_ev_gate.md + feedback-default-posture-thief-not-fortress-prover.md.
SATURATION_FILE="$WORKSPACE/.saturation-score"
if [ ! -f "$SATURATION_FILE" ]; then
  bash "$LIFECYCLE_DIR/bin/saturation-score.sh" --workspace "$WORKSPACE" > "$SATURATION_FILE" 2>&1 || true
  echo "" ; echo "SATURATION SCORE → $SATURATION_FILE :"
  sed 's/^/  /' "$SATURATION_FILE" 2>/dev/null | head -10
  grep -qiE 'HIGH SATURATION' "$SATURATION_FILE" 2>/dev/null && \
    echo "  ⚠️  HIGH SATURATION — RE-SOURCE to a payable surface (web/API/off-chain/fresh); do NOT prove-null on the core."
fi

# Initialize OUTCOMES.jsonl if missing (workspace-local, separate from global tracking)
[ ! -f "$WORKSPACE/OUTCOMES.jsonl" ] && : > "$WORKSPACE/OUTCOMES.jsonl"

# Copy schema reference for local use
[ ! -f "$WORKSPACE/OUTCOMES-schema.json" ] && cp "$TEMPLATES/OUTCOMES-schema.json" "$WORKSPACE/OUTCOMES-schema.json"

# Write lifecycle status marker (append, idempotent — multiple init calls tracked)
NOW="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo "init:$NOW:$TARGET:${MERGED_HINTS:-none}" >> "$WORKSPACE/.lifecycle-status"

cat <<EOF
[lifecycle] init-target: $TARGET
 workspace:     $WORKSPACE
 routing:       $WORKSPACE/ROUTING.md
 progress:      $WORKSPACE/PROGRESS.md
 scope:         $WORKSPACE/SCOPE.md  ← POPULATE BEFORE FIRST FINDING
 outcomes:      $WORKSPACE/OUTCOMES.jsonl
 user hints:    ${TARGET_HINTS:-<none>}
 auto-detected: ${AUTO_HINTS:-<none — NO_AUTODETECT=1 or nothing found>}
 merged:        ${MERGED_HINTS:-<none — routing will be UNKNOWN>}
$(if [ -f "$TIMEBOX_FILE" ]; then
  echo " timebox:       $(grep -oE 'L1_EXCEPTION_MANDATORY|L1_EXCEPTION_ELIGIBLE|STANDARD_8H' "$TIMEBOX_FILE" | head -1) (see $TIMEBOX_FILE)"
fi)

NEXT STEPS:
 1. Populate $WORKSPACE/SCOPE.md with program scope + OOS list (copy from program page)
 2. Read $WORKSPACE/ROUTING.md → apply mandatory checklists for target class
 3. For blind spot warnings (ZK/MPC/rollup): flag limitation in findings explicitly
 4. Begin Phase 0 (gravedigger) or Phase 0 (mrrobbot) per chosen skill methodology
 5. For each finding candidate: run ~/arsenal/audit-lifecycle/bin/on-finding.sh <FINDING_ID> --stage 1
    (fills scope-check.md → scope-validator → --stage 2 for kill-gate + severity-commit + etc.)
EOF
