#!/usr/bin/env bash
# INVOCATION CONDITION: creation of any finding candidate, BEFORE opening the draft file.
# Two-stage gate:
#   Stage 1 (default): creates {id}-scope-check.md ONLY. Operator fills, runs scope-validator.
#   Stage 2: creates kill-gate, severity-commit, chain-proof, weight-card — requires scope PASS.
#
# Enforces CLAUDE.md rules #27 (scope before draft), #36, #37, #38, #39.
#
# Usage: on-finding.sh <FINDING_ID> [workspace-path] [--stage 1|2]
set -euo pipefail

FINDING_ID="${1:?Usage: on-finding.sh <FINDING_ID> [workspace-path] [--stage 1|2]}"
shift

# Parse remaining args
STAGE=1
WORKSPACE="${WORKSPACE:-$(pwd)}"
while [ $# -gt 0 ]; do
  case "$1" in
    --stage)
      STAGE="$2"
      shift 2
      ;;
    --stage=*)
      STAGE="${1#--stage=}"
      shift
      ;;
    *)
      # Positional: workspace path
      WORKSPACE="$1"
      shift
      ;;
  esac
done

LIFECYCLE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEMPLATES="$LIFECYCLE_DIR/templates"
LIB="$LIFECYCLE_DIR/lib"
BUGS_ROOT="$HOME/Desktop/BUGS"

# Precondition: init-target.sh must have run
if ! grep -q "^init:" "$WORKSPACE/.lifecycle-status" 2>/dev/null; then
  echo "[lifecycle] ERROR: init-target.sh not run for this workspace." >&2
  echo "[lifecycle]        Run: $LIFECYCLE_DIR/bin/init-target.sh <target-name> $WORKSPACE" >&2
  exit 1
fi

FINDINGS_DIR="$WORKSPACE/findings"
mkdir -p "$FINDINGS_DIR"
NOW="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

# =========================================================
# STAGE 1 — Scope check only
# =========================================================
if [ "$STAGE" = "1" ]; then
  SCOPE_FILE="$FINDINGS_DIR/${FINDING_ID}-scope-check.md"

  if [ ! -f "$SCOPE_FILE" ]; then
    sed "s/{FINDING_ID}/$FINDING_ID/g" "$TEMPLATES/SCOPE-CHECK.md" > "$SCOPE_FILE"
  fi

  # ADVISORY: AI bot check (non-blocking, warns on V12/Zellic/Olympix)
  if [ -f "$WORKSPACE/.target-repo" ]; then
    BOT_LOG="$FINDINGS_DIR/${FINDING_ID}-ai-bot-check.log"
    if bash "$LIFECYCLE_DIR/bin/ai-bot-check.sh" --workspace "$WORKSPACE" > "$BOT_LOG" 2>&1; then
      echo "ai-bot-check:$NOW:clean" >> "$WORKSPACE/.lifecycle-status"
    else
      RC=$?
      if [ $RC -eq 1 ]; then
        echo "ai-bot-check:$NOW:BOT_DETECTED" >> "$WORKSPACE/.lifecycle-status"
        echo "[lifecycle] WARNING: AI auditor bot detected on target repo." >&2
        echo "[lifecycle]          See: $BOT_LOG" >&2
        echo "[lifecycle]          V12-covered classes (access control / reentrancy / arithmetic)" >&2
        echo "[lifecycle]          have high dupe-risk. Prefer logic / economic / crypto classes." >&2
      else
        echo "ai-bot-check:$NOW:skipped_rc$RC" >> "$WORKSPACE/.lifecycle-status"
      fi
    fi
  fi

  echo "stage1:$NOW:$FINDING_ID" >> "$WORKSPACE/.lifecycle-status"

  cat <<EOF
[lifecycle] on-finding stage 1: $FINDING_ID

SCOPE CHECK INSTANTIATED:
 file: $SCOPE_FILE

MANDATORY ORDER:
 1. Fill $SCOPE_FILE:
    - Paste program scope (Step 1)
    - Paste OOS list (Step 2)
    - Cross-reference each OOS token (Step 3)
    - Check asset is in scope (Step 4)
    - Sign verdict (Step 5)
 2. Run: $LIB/scope-validator.sh $SCOPE_FILE
    → exit 0 = PASS (PROCEED) — can proceed to stage 2
    → exit 2 = KILL or AMEND — do NOT proceed, log to OUTCOMES.jsonl
    → exit 1 = BLOCKED — fix issues and re-run
 3. If PASS: $LIFECYCLE_DIR/bin/on-finding.sh $FINDING_ID $WORKSPACE --stage 2

BLOCKING RULE: Without scope-validator PASS, stage 2 refuses to instantiate gates.
This prevents 2-4h of drafting on OOS findings (enforces CLAUDE.md rule #27).
EOF
  exit 0
fi

# =========================================================
# STAGE 2 — Kill-gate, severity-commit, chain-proof, weight-card
# =========================================================
if [ "$STAGE" = "2" ]; then
  SCOPE_FILE="$FINDINGS_DIR/${FINDING_ID}-scope-check.md"

  # Precondition: scope-check must exist and validate PASS
  if [ ! -f "$SCOPE_FILE" ]; then
    echo "[lifecycle] ERROR: scope-check not found for $FINDING_ID" >&2
    echo "[lifecycle]        Run stage 1 first: $0 $FINDING_ID $WORKSPACE --stage 1" >&2
    exit 1
  fi

  # Run validator; stage 2 requires PROCEED signature specifically
  if ! bash "$LIB/scope-validator.sh" "$SCOPE_FILE" >/dev/null 2>&1; then
    echo "[lifecycle] ERROR: scope-check did not PASS for $FINDING_ID" >&2
    echo "[lifecycle]        Re-run validator to see failures:" >&2
    echo "[lifecycle]        $LIB/scope-validator.sh $SCOPE_FILE" >&2
    exit 1
  fi

  # Check the verdict is PROCEED (not KILL or AMEND)
  if ! grep -qE '^\*\*Signed by operator:\*\* `\[x\] SCOPE_CHECK_SIGNED_PROCEED`' "$SCOPE_FILE"; then
    echo "[lifecycle] ERROR: scope-check verdict is not PROCEED for $FINDING_ID" >&2
    echo "[lifecycle]        Stage 2 requires explicit PROCEED signature." >&2
    echo "[lifecycle]        If finding is OOS: log to OUTCOMES.jsonl with held_reason=scope_exclusion_oos" >&2
    exit 1
  fi

  # Copy per-finding gate templates (don't overwrite existing work)
  [ ! -f "$FINDINGS_DIR/${FINDING_ID}-severity-commit.md" ] && \
    sed "s/{FINDING_ID}/$FINDING_ID/g" "$TEMPLATES/SEVERITY-COMMIT.md" > "$FINDINGS_DIR/${FINDING_ID}-severity-commit.md"

  if [ ! -f "$FINDINGS_DIR/${FINDING_ID}-kill-gate.md" ]; then
    cp "$BUGS_ROOT/KILL-GATE-TEMPLATE.md" "$FINDINGS_DIR/${FINDING_ID}-kill-gate.md"
    # Inject known kill patterns from lessons YAML (enforces rule #1 feedback loop)
    bash "$LIB/inject-kill-lessons.sh" "$FINDINGS_DIR/${FINDING_ID}-kill-gate.md" 2>&1 | grep -v "^$" || true
  fi

  [ ! -f "$FINDINGS_DIR/${FINDING_ID}-chain-proof.md" ] && \
    cp "$BUGS_ROOT/CHAIN-PROOF-GATE.md" "$FINDINGS_DIR/${FINDING_ID}-chain-proof.md"

  [ ! -f "$FINDINGS_DIR/${FINDING_ID}-weight-card.md" ] && \
    cp "$BUGS_ROOT/WEIGHT-CARD.md" "$FINDINGS_DIR/${FINDING_ID}-weight-card.md"

  # Adversarial Rebuttal (D9) — semantic survival check before preflight.
  # Encodes lesson from Superform F-001 (2026-05-16): syntactic gates pass,
  # semantic review fails. See feedback_self_validation_failure_superform_f001.md.
  if [ ! -f "$FINDINGS_DIR/${FINDING_ID}-adversarial-rebuttal.md" ]; then
    sed "s/{FINDING_ID}/$FINDING_ID/g" "$TEMPLATES/ADVERSARIAL-REBUTTAL.md" > "$FINDINGS_DIR/${FINDING_ID}-adversarial-rebuttal.md"
  fi

  echo "finding:$NOW:$FINDING_ID" >> "$WORKSPACE/.lifecycle-status"
  echo "stage2:$NOW:$FINDING_ID" >> "$WORKSPACE/.lifecycle-status"

  cat <<EOF
[lifecycle] on-finding stage 2: $FINDING_ID
            scope-check verdict: PROCEED ✓

GATES INSTANTIATED:
 kill gate:       $FINDINGS_DIR/${FINDING_ID}-kill-gate.md
 severity commit: $FINDINGS_DIR/${FINDING_ID}-severity-commit.md
 chain proof:     $FINDINGS_DIR/${FINDING_ID}-chain-proof.md          (D7 — auth-class)
 weight card:     $FINDINGS_DIR/${FINDING_ID}-weight-card.md          (D8 — ≥ Low w/ \$ impact)
 adv rebuttal:    $FINDINGS_DIR/${FINDING_ID}-adversarial-rebuttal.md (D9 — semantic survival)

MANDATORY ORDER:
 1. Fill kill-gate.md (30 min max) — verdict PROCEED / KILL / DOWNGRADE
 2. If PROCEED: fill severity-commit.md with artifact-required inputs
    → run: $LIB/artifact-validator.sh $FINDINGS_DIR/${FINDING_ID}-severity-commit.md
    → validator MUST return PASS before opening draft
 3. Write draft file
 4. If auth-class: fill chain-proof.md (D7)
 5. If severity ≥ Low with dollar impact: fill weight-card.md (D8a + D8b)
 6. **Fill adversarial-rebuttal.md (D9 — MANDATORY before preflight)**
    → minimum 6 angles, written as the triager not the researcher
    → run: $LIB/adversarial-rebuttal-validator.sh $FINDINGS_DIR/${FINDING_ID}-adversarial-rebuttal.md
    → exit 0 = PASS (verdict READY_TO_SUBMIT) — proceed
    → exit 1 = BLOCKED (fix gaps and re-run, OR downgrade severity and re-run)
    → exit 2 = KILL or NEEDS_MORE_EVIDENCE — do NOT proceed
 7. Run preflight: $LIFECYCLE_DIR/bin/preflight-mechanical.sh <draft-path>
 8. If PASS: $LIFECYCLE_DIR/bin/on-submit.sh $FINDING_ID
 9. If hold:  $LIFECYCLE_DIR/bin/on-hold.sh $FINDING_ID <reason>

WHY D9 EXISTS:
 Per-finding gates D1-D8 operate at the syntactic level (slot has a value?). D9
 operates at the semantic level (does the value survive an adversary?). Without D9,
 self-validation passes while findings collapse under triager review. Reference:
 Superform F-001 (2026-05-16) — passed PREFLIGHT 22/24+, collapsed on operator
 adversarial review for 6 structural issues.
EOF
  exit 0
fi

echo "[lifecycle] ERROR: unknown stage '$STAGE'. Use --stage 1 or --stage 2." >&2
exit 1
