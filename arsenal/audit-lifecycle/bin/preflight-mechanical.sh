#!/usr/bin/env bash
# INVOCATION CONDITION: before any finding submission, after draft written and all gates filled.
# Runs 4 deterministic gates (hard block on failure). Returns 0 = PASS, 1 = BLOCKED.
#
# Phase A (skeleton): minimal checks that are safely deterministic.
# Phase B (after diagnostic validates patterns): full grep patterns with tuned thresholds.
#
# Gates in scope (deterministic only):
#   D0-init    — lifecycle markers (init + finding) present
#   D0-commit  — SEVERITY-COMMIT validator signed
#   D8b-stub   — if TVL claim detected, cast-call readback block must exist in draft
#   D10        — compliance tokens must have article citation within 5 lines
#   hygiene    — LLM boilerplate markers
#
# Semantic gates (D7 hedge, D8a narrative, D11 self-red-team) are NOT in this script.
# They are manual checklists with signature — see findings/{id}-chain-proof.md and the
# SELF-RED-TEAM.md template (Phase C deliverable). The point is to NOT give false
# assurance via grep on semantic content.
#
# Usage: preflight-mechanical.sh <draft-path> [finding-id] [workspace-path]
set -euo pipefail

DRAFT_PATH="${1:?Usage: preflight-mechanical.sh <draft-path> [finding-id] [workspace-path]}"
FINDING_ID="${2:-$(basename "$DRAFT_PATH" .md | sed 's/-draft$//; s/-report$//')}"
WORKSPACE="${3:-${WORKSPACE:-$(pwd)}}"
LIFECYCLE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LIB="$LIFECYCLE_DIR/lib"
ENFORCE="${LIFECYCLE_ENFORCE:-soft}"

FAIL=0
WARN=0
LOG=""

if [ ! -f "$DRAFT_PATH" ]; then
  echo "[preflight-mechanical] ERROR: draft not found: $DRAFT_PATH" >&2
  exit 1
fi

# D0-init — lifecycle init marker present
if ! grep -q "^init:" "$WORKSPACE/.lifecycle-status" 2>/dev/null; then
  LOG="$LOG\n[D0-init] FAIL: init-target.sh not run for this workspace"
  FAIL=$((FAIL + 1))
fi

# D-corpus — web/API targets must complete the corpus-coverage ledger before submission.
# encoded!=applied fix (Injective-web 2026-06-27: had the web corpus, improvised, missed info-disclosure #1 class).
# Conditional: fires ONLY on web targets (ROUTING.md WEB-CORPUS section, written by target-router on web hints,
# OR an existing CORPUS-COVERAGE.md) — never on SC/other. Tool-existence guarded (G-2).
CORPUS_GATE="$LIFECYCLE_DIR/bin/corpus-coverage-check.sh"
if grep -qiE 'WEB CORPUS|web-corpus-query' "$WORKSPACE/ROUTING.md" 2>/dev/null || [ -f "$WORKSPACE/CORPUS-COVERAGE.md" ]; then
  if [ -x "$CORPUS_GATE" ]; then
    if ! "$CORPUS_GATE" --check "$WORKSPACE" >/dev/null 2>&1; then
      LOG="$LOG\n[D-corpus] FAIL: web target — corpus-coverage-check.sh --check failed (unrun corpus class or missing CORPUS-COVERAGE.md)"
      LOG="$LOG\n           run: $CORPUS_GATE --emit <shape> $WORKSPACE  then web-corpus-query.sh --methods per [ ] row"
      FAIL=$((FAIL + 1))
    fi
  else
    LOG="$LOG\n[D-corpus] WARN: corpus-coverage-check.sh missing ($CORPUS_GATE) — web coverage UNVERIFIED"
    WARN=$((WARN + 1))
  fi
fi

# D0-scope — scope-check PASS marker present for this finding ID
# Enforces rule #27 (scope before draft). scope-check.md must exist AND validate PROCEED.
SCOPE_FILE="$WORKSPACE/findings/${FINDING_ID}-scope-check.md"
if [ ! -f "$SCOPE_FILE" ]; then
  LOG="$LOG\n[D0-scope] FAIL: scope-check file missing: $SCOPE_FILE"
  LOG="$LOG\n           run: $LIFECYCLE_DIR/bin/on-finding.sh $FINDING_ID $WORKSPACE --stage 1"
  FAIL=$((FAIL + 1))
elif ! grep -qE '^\*\*Signed by operator:\*\* `\[x\] SCOPE_CHECK_SIGNED_PROCEED`' "$SCOPE_FILE"; then
  LOG="$LOG\n[D0-scope] FAIL: scope-check verdict is not PROCEED for $FINDING_ID"
  LOG="$LOG\n           run: $LIB/scope-validator.sh $SCOPE_FILE"
  FAIL=$((FAIL + 1))
fi

# D0-finding — on-finding stage 2 marker present for this finding ID
if ! grep -qE "^stage2:.*:$FINDING_ID$" "$WORKSPACE/.lifecycle-status" 2>/dev/null; then
  LOG="$LOG\n[D0-finding] FAIL: on-finding.sh --stage 2 not run for $FINDING_ID"
  FAIL=$((FAIL + 1))
fi

# D0-commit — SEVERITY-COMMIT validated
COMMIT_FILE="$WORKSPACE/findings/${FINDING_ID}-severity-commit.md"
if [ -f "$COMMIT_FILE" ]; then
  if ! grep -qE 'Validator verdict:\s+\[x\] PASS' "$COMMIT_FILE"; then
    LOG="$LOG\n[D0-commit] FAIL: SEVERITY-COMMIT artifact-validator not PASS for $FINDING_ID"
    LOG="$LOG\n            run: $LIB/artifact-validator.sh $COMMIT_FILE"
    FAIL=$((FAIL + 1))
  fi
else
  LOG="$LOG\n[D0-commit] FAIL: SEVERITY-COMMIT file missing: $COMMIT_FILE"
  FAIL=$((FAIL + 1))
fi

# D8b — TVL/supply claim requires cast-call readback block (Reserve F-003 lesson)
# Phase B: require dollar amount or percentage + claim keyword proximity, not bare tokens.
# Pattern: "$X at risk" / "$X TVL" / "X% of TVL" / "funds drained" / "totalSupply affected"
# where the dollar/percent amount and the claim verb are in the same or adjacent line.
#
# Before tuning this flagged "No TVL claims" in prose. Now it requires both:
#   (a) quantitative anchor: $[amount] or [N]% of TVL or totalSupply = or named contract
#   (b) claim verb: at risk / extractable / drained / affected / frozen / locked / stolen / lost
D8B_QUANT='\$[0-9,]+\s*[KMB]?|[0-9]+%\s+of\s+(TVL|total|supply)|totalSupply\s*[=→:]\s*[0-9]|balanceOf\s*\([^)]*\)\s*[=→:]'
D8B_CLAIM='at risk|extractable|drained|affected|frozen|locked permanently|stolen|lost forever|siphoned'

if grep -qiE "$D8B_QUANT" "$DRAFT_PATH" 2>/dev/null && grep -qiE "$D8B_CLAIM" "$DRAFT_PATH" 2>/dev/null; then
  # Both a quantitative anchor AND a claim verb present → this is a TVL-scaled claim
  # Now look for on-chain readback block
  D8B_READBACK='cast call|cast storage|evm_call|evm_read_storage|block\s+(number\s+)?1[0-9]{7}|block\s*#\s*1[0-9]{7}|at block 1[0-9]{7}'
  if ! grep -qE "$D8B_READBACK" "$DRAFT_PATH" 2>/dev/null; then
    LOG="$LOG\n[D8b] FAIL: TVL-scaled dollar claim detected (quantitative anchor + claim verb) without on-chain readback block"
    LOG="$LOG\n      matched quant: $(grep -noE "$D8B_QUANT" "$DRAFT_PATH" | head -2)"
    LOG="$LOG\n      matched claim: $(grep -noiE "$D8B_CLAIM" "$DRAFT_PATH" | head -2)"
    LOG="$LOG\n      run cast call on every contract named in the severity claim, paste literal output"
    FAIL=$((FAIL + 1))
  fi
fi

# D10 — compliance tokens must have article citation within 5 lines
COMPLIANCE_TOKENS='GLBA|FTC Act|CCPA|GDPR|SHIELD|HIPAA|PSD2|PCI-DSS|SOX|eIDAS'
while IFS= read -r match; do
  [ -z "$match" ] && continue
  line_no=$(echo "$match" | cut -d: -f1)
  start=$((line_no > 5 ? line_no - 5 : 1))
  end=$((line_no + 5))
  # Check if article/section citation appears near this match
  if ! sed -n "${start},${end}p" "$DRAFT_PATH" | grep -qE 'Art(\.|icle) ?[0-9]|§ ?[0-9]|Section ?[0-9]|Req(\.|uirement) ?[0-9]|CWE-[0-9]|CVSS'; then
    LOG="$LOG\n[D10] FAIL: compliance token at line $line_no without article/section citation within 5 lines"
    FAIL=$((FAIL + 1))
  fi
done < <(grep -nE "$COMPLIANCE_TOKENS" "$DRAFT_PATH" 2>/dev/null || true)

# Hygiene — LLM boilerplate markers (conservative list to avoid false positives)
LLM_MARKERS='As an AI|I apologize for|I cannot provide|I hope this helps|Please note that this'
if grep -qE "$LLM_MARKERS" "$DRAFT_PATH" 2>/dev/null; then
  LOG="$LOG\n[hygiene] FAIL: LLM boilerplate markers detected"
  LOG="$LOG\n          matches: $(grep -nE "$LLM_MARKERS" "$DRAFT_PATH" | head -3)"
  FAIL=$((FAIL + 1))
fi

# D9 — Adversarial Rebuttal signed READY_TO_SUBMIT
# Encodes lesson from Superform F-001 (2026-05-16): syntactic gates D0-D8 pass but
# semantic review fails. D9 forces the operator to write the triager's rebuttal
# before submission. See feedback_self_validation_failure_superform_f001.md.
REBUTTAL_FILE="$WORKSPACE/findings/${FINDING_ID}-adversarial-rebuttal.md"
if [ ! -f "$REBUTTAL_FILE" ]; then
  LOG="$LOG\n[D9] FAIL: adversarial-rebuttal file missing: $REBUTTAL_FILE"
  LOG="$LOG\n     run: $LIFECYCLE_DIR/bin/on-finding.sh $FINDING_ID $WORKSPACE --stage 2"
  LOG="$LOG\n     (stage 2 instantiates the template; then fill and validate)"
  FAIL=$((FAIL + 1))
else
  # Run the validator
  if ! bash "$LIB/adversarial-rebuttal-validator.sh" "$REBUTTAL_FILE" >/tmp/d9-validator-$$.log 2>&1; then
    RC=$?
    if [ $RC -eq 2 ]; then
      LOG="$LOG\n[D9] FAIL: adversarial-rebuttal verdict is KILL or NEEDS_MORE_EVIDENCE"
      LOG="$LOG\n     finding should not be submitted at this severity"
      LOG="$LOG\n     see: $REBUTTAL_FILE"
    else
      LOG="$LOG\n[D9] FAIL: adversarial-rebuttal not properly populated"
      LOG="$LOG\n     details:"
      while IFS= read -r line; do
        LOG="$LOG\n       $line"
      done < /tmp/d9-validator-$$.log
      LOG="$LOG\n     run: $LIB/adversarial-rebuttal-validator.sh $REBUTTAL_FILE"
    fi
    FAIL=$((FAIL + 1))
  fi
  rm -f /tmp/d9-validator-$$.log
fi

# Report
NOW="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

echo "[preflight-mechanical] $DRAFT_PATH"
echo "[preflight-mechanical] enforce mode: $ENFORCE"
if [ $FAIL -eq 0 ]; then
  echo "[preflight-mechanical] RESULT: PASS"
  echo "preflight:PASS:$NOW:$FINDING_ID" >> "$WORKSPACE/.lifecycle-status"
  exit 0
else
  echo -e "[preflight-mechanical] FAILURES:$LOG"
  echo "[preflight-mechanical] RESULT: BLOCKED ($FAIL failure(s))"
  echo "preflight:FAIL:$NOW:$FINDING_ID:$FAIL" >> "$WORKSPACE/.lifecycle-status"
  if [ "$ENFORCE" = "hard" ]; then
    exit 1
  else
    echo "[preflight-mechanical] enforce=soft → returning 0 with warnings"
    echo "[preflight-mechanical] NOTE: in hard enforce, this would block submission"
    exit 0
  fi
fi
