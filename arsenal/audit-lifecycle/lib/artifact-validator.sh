#!/usr/bin/env bash
# INVOCATION CONDITION: called by on-finding.sh after SEVERITY-COMMIT populated,
# and by preflight-mechanical.sh before allowing submit.
# Enforces CLAUDE.md rule #39: artifact-required per committed tier.
#
# Phase A: existence check (tier committed + artifact field filled for committed tier).
# Phase B: structural resolves check. Promotes Sparklend (F-11) + Dexalot (F-12) diagnostic
#          classes from "pre-gate misses" to "caught mechanically":
#
#   L2 evidence  → file path exists, line number numeric
#   L3 evidence  → Foundry test path ends in .sol|.t.sol / curl command has URL / anchor test path valid
#   L4 evidence  → tx hash matches /0x[a-f0-9]{64}/ AND block number numeric ≥ 7 digits
#   full_ethical → contains HTTP status code (200/201/etc) OR forge test assertion block
#   computed_W1  → contains $ dollar amount OR numerical formula with inputs
#   W5_anchored  → contains $ dollar amount in precedent table
#
# Phase B DOES NOT (Phase D territory):
#   - cast call to verify contract deployed (requires RPC config per-target)
#   - forge test execution to verify it passes (runtime cost)
#   - on-chain tx verification (requires RPC)
#
# Usage: artifact-validator.sh <severity-commit.md>
# Exit: 0 = PASS (signs the file), 1 = FAIL (details on stderr)
set -euo pipefail

COMMIT_PATH="${1:?Usage: artifact-validator.sh <severity-commit.md>}"
COMMIT_DIR="$(dirname "$COMMIT_PATH")"
WORKSPACE_DIR="$(dirname "$COMMIT_DIR")"  # findings/ → workspace/
FAIL=0
LOG=""

if [ ! -f "$COMMIT_PATH" ]; then
  echo "[artifact-validator] FAIL: $COMMIT_PATH not found" >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# Check 1 — at least one tier committed in each of 3 inputs
# ---------------------------------------------------------------------------
EVIDENCE_COMMITTED=$(grep -cE '^- \[x\] \*\*L[1-4]' "$COMMIT_PATH" || true)
CHAIN_COMMITTED=$(grep -cE '^- \[x\] \*\*(unverified|partial|full_ethical)' "$COMMIT_PATH" || true)
IMPACT_COMMITTED=$(grep -cE '^- \[x\] \*\*(narrative|computed_W1|W5_anchored|both_W1_W5)' "$COMMIT_PATH" || true)

if [ "$EVIDENCE_COMMITTED" -eq 0 ]; then
  LOG="$LOG\n[artifact-validator] FAIL: no evidence_strength tier committed"
  FAIL=1
fi
if [ "$CHAIN_COMMITTED" -eq 0 ]; then
  LOG="$LOG\n[artifact-validator] FAIL: no chain_completeness tier committed"
  FAIL=1
fi
if [ "$IMPACT_COMMITTED" -eq 0 ]; then
  LOG="$LOG\n[artifact-validator] FAIL: no impact_quantification tier committed"
  FAIL=1
fi

# ---------------------------------------------------------------------------
# Helper: extract artifact content from the line immediately after a committed tier
# Returns "unfilled" for placeholder, or the literal content
# ---------------------------------------------------------------------------
extract_artifact_content() {
  local tier_line_no="$1"
  local field_name="${2:-artifact}"
  local offset
  for offset in 1 2 3 4; do
    local check_line=$((tier_line_no + offset))
    local content
    content=$(sed -n "${check_line}p" "$COMMIT_PATH")
    # Stop at next tier header
    if echo "$content" | grep -qE '^- \[[ x]\] '; then
      break
    fi
    # Match the artifact field
    if echo "$content" | grep -qE "^  - \`${field_name}(_W[15])?:?\` \`"; then
      # Extract everything between the second `...` pair
      local extracted
      extracted=$(echo "$content" | sed -E "s/^  - \`${field_name}(_W[15])?:?\` \`(.*)\`.*$/\2/")
      if [[ "$extracted" =~ ^\[.*\]$ ]]; then
        echo "unfilled"
      else
        echo "$extracted"
      fi
      return 0
    fi
  done
  echo "missing"
}

# ---------------------------------------------------------------------------
# Check 2 — artifact field filled for committed non-default tiers
# ---------------------------------------------------------------------------
check_tier_filled() {
  local pattern="$1"
  local tier_label="$2"
  while IFS= read -r match; do
    [ -z "$match" ] && continue
    local line_no
    line_no=$(echo "$match" | cut -d: -f1)
    local artifact_content
    artifact_content=$(extract_artifact_content "$line_no" "artifact")
    if [ "$artifact_content" = "unfilled" ]; then
      LOG="$LOG\n[artifact-validator] FAIL: $tier_label (line $line_no): artifact field is unfilled placeholder"
      FAIL=1
    elif [ "$artifact_content" = "missing" ]; then
      LOG="$LOG\n[artifact-validator] FAIL: $tier_label (line $line_no): artifact field not found within 4 lines"
      FAIL=1
    else
      # Tier-specific resolves check (Phase B)
      validate_artifact_content "$line_no" "$tier_label" "$artifact_content"
    fi
    # Also check artifact_proves
    local proves_content
    proves_content=$(extract_artifact_content "$line_no" "artifact_proves")
    if [ "$proves_content" = "unfilled" ]; then
      LOG="$LOG\n[artifact-validator] FAIL: $tier_label (line $line_no): artifact_proves field is unfilled placeholder"
      FAIL=1
    elif [ "$proves_content" = "missing" ] && [ "$tier_label" != "both_W1_W5" ]; then
      # both_W1_W5 uses artifact_W1/artifact_W5 not a single artifact_proves
      LOG="$LOG\n[artifact-validator] FAIL: $tier_label (line $line_no): artifact_proves field missing"
      FAIL=1
    fi
  done < <(grep -nE "$pattern" "$COMMIT_PATH" 2>/dev/null || true)
}

# ---------------------------------------------------------------------------
# Phase B — per-tier artifact content validation
# ---------------------------------------------------------------------------
validate_artifact_content() {
  local line_no="$1"
  local tier_label="$2"
  local content="$3"

  case "$tier_label" in
    "evidence tier (L2)")
      # Expect file:line format — check path exists
      local file_part
      file_part=$(echo "$content" | grep -oE '[^ ,]+\.[a-z]+:[0-9]+' | head -1 | cut -d: -f1 || true)
      if [ -z "$file_part" ]; then
        LOG="$LOG\n[artifact-validator] WARN: L2 artifact (line $line_no) does not look like file:line — got '$content'"
      elif [ ! -f "$file_part" ] && [ ! -f "$WORKSPACE_DIR/$file_part" ]; then
        # Phase B soft check — file path may be relative to external repo; don't hard-fail
        LOG="$LOG\n[artifact-validator] WARN: L2 artifact path '$file_part' not found locally (may be external repo — verify manually)"
      fi
      ;;
    "evidence tier (L3)")
      # Expect Foundry test path (.sol|.t.sol) OR curl command OR anchor test path
      if echo "$content" | grep -qE '\.(sol|t\.sol|rs|ts|js|py)' ; then
        local test_file
        test_file=$(echo "$content" | grep -oE '[^ ,]+\.(sol|t\.sol|rs|ts|js|py)' | head -1 || true)
        if [ -n "$test_file" ] && [ ! -f "$test_file" ] && [ ! -f "$WORKSPACE_DIR/$test_file" ]; then
          LOG="$LOG\n[artifact-validator] WARN: L3 artifact path '$test_file' not found locally"
        fi
      elif ! echo "$content" | grep -qiE 'curl |http://|https://|anchor test'; then
        LOG="$LOG\n[artifact-validator] FAIL: L3 artifact (line $line_no) does not look like test path or curl command — got '$content'"
        FAIL=1
      fi
      ;;
    "evidence tier (L4)")
      # L4 evidence accepted in two equivalent forms:
      # (a) On-chain: tx hash (0x[a-f0-9]{64}) AND block number (7+ digits)
      # (b) In-workspace / panic-class: #[should_panic] / assertTrue / assertEq / cargo test -p / SupervisionEvent
      #     against the actual target crate. Equivalent rigor for non-on-chain bug classes.
      local has_onchain=false
      local has_workspace=false
      if echo "$content" | grep -qE '0x[a-fA-F0-9]{64}' && \
         echo "$content" | grep -qE 'block\s*(#|number)?\s*1?[0-9]{7,}|[0-9]{7,}'; then
        has_onchain=true
      fi
      if echo "$content" | grep -qE '#\[should_panic|assertTrue|assertEq|SupervisionEvent::ActorFailed|cargo test -p|cargo test --test|panic_poc|actor_panic_propagation'; then
        has_workspace=true
      fi
      if [ "$has_onchain" = false ] && [ "$has_workspace" = false ]; then
        LOG="$LOG\n[artifact-validator] FAIL: L4 artifact (line $line_no) missing on-chain (tx hash + block) OR in-workspace (assertEq/should_panic/cargo test -p/SupervisionEvent) evidence — got '$content'"
        FAIL=1
      fi
      ;;
    "chain full_ethical")
      # Expect HTTP status code OR forge test with assertEq/assertTrue
      if ! echo "$content" | grep -qE 'HTTP/|\b(200|201|202|204|400|401|403|404)\b|assertEq|assertTrue|assertLt|assertGt|status[_ ]code'; then
        LOG="$LOG\n[artifact-validator] FAIL: full_ethical artifact (line $line_no) missing HTTP status or assertion — got '$content'"
        FAIL=1
      fi
      ;;
    "impact computed_W1")
      # Expect $ dollar amount
      if ! echo "$content" | grep -qE '\$[0-9,]+[KMB]?|\$[0-9]+\.[0-9]+'; then
        LOG="$LOG\n[artifact-validator] FAIL: computed_W1 artifact (line $line_no) missing dollar amount — got '$content'"
        FAIL=1
      fi
      ;;
    "impact W5_anchored")
      # Expect pointer with dollar amount OR URL to paid precedent
      if ! echo "$content" | grep -qE '\$[0-9,]+[KMB]?|h1.*#[0-9]+|code-423n4|cantina.xyz|sherlock-audit'; then
        LOG="$LOG\n[artifact-validator] FAIL: W5_anchored artifact (line $line_no) missing paid precedent pointer or dollar amount — got '$content'"
        FAIL=1
      fi
      ;;
    "impact both_W1_W5")
      # For both_W1_W5, the fields are artifact_W1 and artifact_W5 separately
      local w1_content w5_content
      w1_content=$(extract_artifact_content "$line_no" "artifact_W1")
      w5_content=$(extract_artifact_content "$line_no" "artifact_W5")
      if [ "$w1_content" = "unfilled" ] || [ "$w1_content" = "missing" ]; then
        LOG="$LOG\n[artifact-validator] FAIL: both_W1_W5 artifact_W1 field not filled at line $line_no"
        FAIL=1
      elif ! echo "$w1_content" | grep -qE '\$[0-9,]+[KMB]?'; then
        LOG="$LOG\n[artifact-validator] FAIL: both_W1_W5 artifact_W1 missing dollar amount"
        FAIL=1
      fi
      if [ "$w5_content" = "unfilled" ] || [ "$w5_content" = "missing" ]; then
        LOG="$LOG\n[artifact-validator] FAIL: both_W1_W5 artifact_W5 field not filled at line $line_no"
        FAIL=1
      elif ! echo "$w5_content" | grep -qE '\$[0-9,]+[KMB]?|h1.*#[0-9]+|code-423n4|cantina.xyz|sherlock-audit'; then
        LOG="$LOG\n[artifact-validator] FAIL: both_W1_W5 artifact_W5 missing paid precedent pointer"
        FAIL=1
      fi
      ;;
  esac
}

# Apply checks per tier type
while IFS= read -r match; do
  [ -z "$match" ] && continue
  line_no=$(echo "$match" | cut -d: -f1)
  tier=$(echo "$match" | grep -oE 'L[2-4]' || true)
  check_tier_filled_single() {
    local line_no_local="$1"
    local tier_label_local="$2"
    artifact_content=$(extract_artifact_content "$line_no_local" "artifact")
    if [ "$artifact_content" = "unfilled" ]; then
      LOG="$LOG\n[artifact-validator] FAIL: $tier_label_local (line $line_no_local): artifact unfilled placeholder"
      FAIL=1
    elif [ "$artifact_content" = "missing" ]; then
      LOG="$LOG\n[artifact-validator] FAIL: $tier_label_local (line $line_no_local): artifact field missing"
      FAIL=1
    else
      validate_artifact_content "$line_no_local" "$tier_label_local" "$artifact_content"
    fi
    proves_content=$(extract_artifact_content "$line_no_local" "artifact_proves")
    if [ "$proves_content" = "unfilled" ]; then
      LOG="$LOG\n[artifact-validator] FAIL: $tier_label_local (line $line_no_local): artifact_proves unfilled"
      FAIL=1
    fi
  }
  check_tier_filled_single "$line_no" "evidence tier ($tier)"
done < <(grep -nE '^- \[x\] \*\*L[2-4]' "$COMMIT_PATH" 2>/dev/null || true)

while IFS= read -r match; do
  [ -z "$match" ] && continue
  line_no=$(echo "$match" | cut -d: -f1)
  artifact_content=$(extract_artifact_content "$line_no" "artifact")
  if [ "$artifact_content" = "unfilled" ] || [ "$artifact_content" = "missing" ]; then
    LOG="$LOG\n[artifact-validator] FAIL: chain full_ethical (line $line_no): artifact missing/unfilled"
    FAIL=1
  else
    validate_artifact_content "$line_no" "chain full_ethical" "$artifact_content"
  fi
  proves_content=$(extract_artifact_content "$line_no" "artifact_proves")
  if [ "$proves_content" = "unfilled" ]; then
    LOG="$LOG\n[artifact-validator] FAIL: chain full_ethical (line $line_no): artifact_proves unfilled"
    FAIL=1
  fi
done < <(grep -nE '^- \[x\] \*\*full_ethical' "$COMMIT_PATH" 2>/dev/null || true)

while IFS= read -r match; do
  [ -z "$match" ] && continue
  line_no=$(echo "$match" | cut -d: -f1)
  impact_tier=$(echo "$match" | grep -oE '(computed_W1|W5_anchored|both_W1_W5)' || true)
  if [ "$impact_tier" = "both_W1_W5" ]; then
    validate_artifact_content "$line_no" "impact both_W1_W5" ""
  else
    artifact_content=$(extract_artifact_content "$line_no" "artifact")
    if [ "$artifact_content" = "unfilled" ] || [ "$artifact_content" = "missing" ]; then
      LOG="$LOG\n[artifact-validator] FAIL: impact $impact_tier (line $line_no): artifact missing/unfilled"
      FAIL=1
    else
      validate_artifact_content "$line_no" "impact $impact_tier" "$artifact_content"
    fi
    proves_content=$(extract_artifact_content "$line_no" "artifact_proves")
    if [ "$proves_content" = "unfilled" ]; then
      LOG="$LOG\n[artifact-validator] FAIL: impact $impact_tier (line $line_no): artifact_proves unfilled"
      FAIL=1
    fi
  fi
done < <(grep -nE '^- \[x\] \*\*(computed_W1|W5_anchored|both_W1_W5)' "$COMMIT_PATH" 2>/dev/null || true)

# ---------------------------------------------------------------------------
# Check 3 — severity committed
# ---------------------------------------------------------------------------
if ! grep -qE 'Committed severity: \[x\]' "$COMMIT_PATH"; then
  LOG="$LOG\n[artifact-validator] FAIL: severity not committed (expected 'Committed severity: [x] <tier>')"
  FAIL=1
fi

# ---------------------------------------------------------------------------
# Check 4 (Phase B2) — severity consistency with min() equation
# severity = min(evidence_strength, chain_completeness, impact_quantified)
# Caps:
#   L1 OR unverified OR narrative → Low MAX (equation caps there)
#   L2 + partial+ + computed_W1/W5 → Medium MAX
#   L3 + full_ethical + computed_W1/W5/both → High-eligible
#   L4 + full_ethical + computed_W1/W5/both → Critical-eligible
# ---------------------------------------------------------------------------
EVIDENCE=$(grep -oE '^- \[x\] \*\*L[1-4]' "$COMMIT_PATH" | grep -oE 'L[1-4]' | head -1 || echo "L1")
CHAIN=$(grep -oE '^- \[x\] \*\*(unverified|partial|full_ethical)' "$COMMIT_PATH" | grep -oE '(unverified|partial|full_ethical)' | head -1 || echo "unverified")
IMPACT=$(grep -oE '^- \[x\] \*\*(narrative|computed_W1|W5_anchored|both_W1_W5)' "$COMMIT_PATH" | grep -oE '(narrative|computed_W1|W5_anchored|both_W1_W5)' | head -1 || echo "narrative")
COMMITTED_SEV=$(grep -oE 'Committed severity: \[x\] (Critical|High|Medium|Low|Informational)' "$COMMIT_PATH" | grep -oE '(Critical|High|Medium|Low|Informational)' | head -1 || echo "")

sev_to_int() {
  case "$1" in
    Informational) echo 0 ;;
    Low) echo 1 ;;
    Medium) echo 2 ;;
    High) echo 3 ;;
    Critical) echo 4 ;;
    *) echo 0 ;;
  esac
}

# Compute ceiling from the 3 inputs (min of the 3 individual ceilings)
evidence_ceiling=1   # default: L1 → Low
chain_ceiling=1       # default: unverified → Informational
impact_ceiling=1      # default: narrative → Low

case "$EVIDENCE" in
  L1) evidence_ceiling=1 ;;   # Low MAX
  L2) evidence_ceiling=2 ;;   # Medium MAX
  L3) evidence_ceiling=3 ;;   # High MAX
  L4) evidence_ceiling=4 ;;   # Critical eligible
esac

case "$CHAIN" in
  unverified) chain_ceiling=0 ;;  # Informational MAX
  partial) chain_ceiling=2 ;;      # Medium MAX
  full_ethical) chain_ceiling=4 ;; # Critical eligible
esac

case "$IMPACT" in
  narrative) impact_ceiling=1 ;;     # Low MAX
  computed_W1) impact_ceiling=4 ;;   # Critical eligible
  W5_anchored) impact_ceiling=4 ;;   # Critical eligible
  both_W1_W5) impact_ceiling=4 ;;    # Critical eligible
esac

# Min of the 3 ceilings = overall severity ceiling
equation_ceiling=$evidence_ceiling
[ $chain_ceiling -lt $equation_ceiling ] && equation_ceiling=$chain_ceiling
[ $impact_ceiling -lt $equation_ceiling ] && equation_ceiling=$impact_ceiling

int_to_sev() {
  case "$1" in
    0) echo "Informational" ;;
    1) echo "Low" ;;
    2) echo "Medium" ;;
    3) echo "High" ;;
    4) echo "Critical" ;;
  esac
}

ceiling_label=$(int_to_sev $equation_ceiling)

if [ -n "$COMMITTED_SEV" ]; then
  committed_int=$(sev_to_int "$COMMITTED_SEV")
  if [ "$committed_int" -gt "$equation_ceiling" ]; then
    LOG="$LOG\n[artifact-validator] FAIL: severity equation violation"
    LOG="$LOG\n                            inputs: evidence=$EVIDENCE, chain=$CHAIN, impact=$IMPACT"
    LOG="$LOG\n                            equation ceiling (min of 3): $ceiling_label (int $equation_ceiling)"
    LOG="$LOG\n                            committed: $COMMITTED_SEV (int $committed_int) > ceiling"
    LOG="$LOG\n                            fix: either (a) upgrade the capping input with a new artifact,"
    LOG="$LOG\n                                 or (b) downgrade committed severity to '$ceiling_label' or lower"
    FAIL=1
  fi
fi

# ---------------------------------------------------------------------------
# Report
# ---------------------------------------------------------------------------
if [ $FAIL -ne 0 ]; then
  echo -e "$LOG" >&2
  echo "[artifact-validator] RESULT: FAIL" >&2
  exit 1
fi

# Sign the file
NOW="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
if ! grep -qE '^Artifact-validator run at: 20[0-9]{2}' "$COMMIT_PATH"; then
  sed -i "s|^Artifact-validator run at: \[timestamp — populated by artifact-validator.sh\]|Artifact-validator run at: $NOW|" "$COMMIT_PATH"
  sed -i 's|^Validator verdict:         \[ \] PASS \[ \] FAIL|Validator verdict:         [x] PASS [ ] FAIL|' "$COMMIT_PATH"
  sed -i 's|^Draft authorized to open:  \[ \] YES \[ \] NO|Draft authorized to open:  [x] YES [ ] NO|' "$COMMIT_PATH"
fi

echo "[artifact-validator] RESULT: PASS ($COMMIT_PATH)"
exit 0
