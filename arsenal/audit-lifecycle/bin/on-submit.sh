#!/usr/bin/env bash
# INVOCATION CONDITION: at send time of a finding, after preflight-mechanical.sh PASS.
# Appends entry to OUTCOMES.jsonl with timestamps + preflight status.
#
# Usage: on-submit.sh <FINDING_ID> [outcome] [workspace-path]
#   outcome default: "submitted"
#   Later status updates (acknowledged/fixed/bounty_paid/dismissed/etc) handled by
#   separate tooling — this script records the submit event.
set -euo pipefail

FINDING_ID="${1:?Usage: on-submit.sh <FINDING_ID> [outcome] [workspace-path]}"
OUTCOME="${2:-submitted}"
WORKSPACE="${3:-${WORKSPACE:-$(pwd)}}"

if ! command -v jq >/dev/null 2>&1; then
  echo "[lifecycle] ERROR: jq required but not installed" >&2
  exit 1
fi

# Extract finding drafted_at from lifecycle-status
DRAFTED=$(grep -E "^finding:.*:$FINDING_ID$" "$WORKSPACE/.lifecycle-status" 2>/dev/null | head -1 | awk -F: '{print $2":"$3":"$4}' || echo "")

# Extract preflight state
PREFLIGHT_LINE=$(grep -E "^preflight:(PASS|FAIL):.*:$FINDING_ID" "$WORKSPACE/.lifecycle-status" 2>/dev/null | tail -1 || echo "")
if [ -n "$PREFLIGHT_LINE" ]; then
  PREFLIGHT_RUN="true"
  GATES_RUN_AT=$(echo "$PREFLIGHT_LINE" | awk -F: '{print $3":"$4":"$5}')
  if echo "$PREFLIGHT_LINE" | grep -q "^preflight:PASS:"; then
    REJECTED_BY_GATE='[]'
  else
    REJECTED_BY_GATE='["preflight-fail"]'
  fi
else
  PREFLIGHT_RUN="false"
  GATES_RUN_AT=""
  REJECTED_BY_GATE='[]'
fi

# Extract tier commits from severity-commit.md if present
COMMIT_FILE="$WORKSPACE/findings/${FINDING_ID}-severity-commit.md"
EVIDENCE_TIER="unknown"
CHAIN_TIER="unknown"
IMPACT_TIER="unknown"
SEVERITY_COMMITTED="unknown"
if [ -f "$COMMIT_FILE" ]; then
  EVIDENCE_TIER=$(grep -oE '^- \[x\] \*\*L[1-4]' "$COMMIT_FILE" | head -1 | grep -oE 'L[1-4]' || echo "unknown")
  CHAIN_TIER=$(grep -oE '^- \[x\] \*\*(unverified|partial|full_ethical)' "$COMMIT_FILE" | head -1 | grep -oE '(unverified|partial|full_ethical)' || echo "unknown")
  IMPACT_TIER=$(grep -oE '^- \[x\] \*\*(narrative|computed_W1|W5_anchored|both_W1_W5)' "$COMMIT_FILE" | head -1 | grep -oE '(narrative|computed_W1|W5_anchored|both_W1_W5)' || echo "unknown")
  SEVERITY_COMMITTED=$(grep -oE 'Committed severity: \[x\] (Critical|High|Medium|Low|Informational)' "$COMMIT_FILE" | grep -oE '(Critical|High|Medium|Low|Informational)' || echo "unknown")
fi

NOW="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
PROTOCOL=$(basename "$WORKSPACE" | sed 's/-audit$//; s/-recon$//')

# Interactive prompts for surface / platform / hours_invested
# Skip prompts if env vars pre-set (allows scripting)
if [ -z "${HOURS_INVESTED:-}" ] && [ -t 0 ]; then
  echo ""
  read -p "[submit] hours_invested (total: recon + drafting + gates + response) [0]: " HOURS_INVESTED
  HOURS_INVESTED="${HOURS_INVESTED:-0}"
fi
HOURS_INVESTED="${HOURS_INVESTED:-0}"

if [ -z "${SURFACE:-}" ] && [ -t 0 ]; then
  echo "[submit] surface options:"
  echo "  sc-solidity | sc-solana | sc-rust | sc-move | sc-cairo | sc-clarity"
  echo "  web | api | graphql | websocket"
  echo "  auth-oauth | auth-jwt | auth-saml"
  echo "  infra-cdn | infra-dns | infra-cloud | infra-kubernetes"
  echo "  bridge | crosschain-messaging | relayer"
  echo "  supply-chain | dependency | sdk"
  echo "  mobile-android | mobile-ios | desktop | ai-llm | other"
  read -p "[submit] surface [other]: " SURFACE
  SURFACE="${SURFACE:-other}"
fi
SURFACE="${SURFACE:-other}"

if [ -z "${PLATFORM:-}" ] && [ -t 0 ]; then
  echo "[submit] platform options: hackerone | cantina | c4 | sherlock | hackenproof | immunefi | intigriti | bugcrowd | codehawks | direct | ghsa | cve | other"
  read -p "[submit] platform [other]: " PLATFORM
  PLATFORM="${PLATFORM:-other}"
fi
PLATFORM="${PLATFORM:-other}"

if [ -z "${BOUNTY_PROGRAM:-}" ] && [ -t 0 ]; then
  read -p "[submit] bounty_program name/URL (optional) [$PROTOCOL]: " BOUNTY_PROGRAM
  BOUNTY_PROGRAM="${BOUNTY_PROGRAM:-$PROTOCOL}"
fi
BOUNTY_PROGRAM="${BOUNTY_PROGRAM:-$PROTOCOL}"

# Build OUTCOMES entry
ENTRY=$(jq -c -n \
  --arg id "$FINDING_ID" \
  --arg protocol "$PROTOCOL" \
  --arg severity_committed "$SEVERITY_COMMITTED" \
  --arg evidence_tier "$EVIDENCE_TIER" \
  --arg chain_tier "$CHAIN_TIER" \
  --arg impact_tier "$IMPACT_TIER" \
  --arg drafted_at "$DRAFTED" \
  --arg gates_run_at "$GATES_RUN_AT" \
  --arg submitted_at "$NOW" \
  --arg outcome "$OUTCOME" \
  --arg surface "$SURFACE" \
  --arg platform "$PLATFORM" \
  --arg bounty_program "$BOUNTY_PROGRAM" \
  --argjson hours_invested "$HOURS_INVESTED" \
  --argjson preflight_run "$PREFLIGHT_RUN" \
  --argjson rejected_by_gate "$REJECTED_BY_GATE" \
  '{
    id: $id,
    protocol: $protocol,
    severity_committed: $severity_committed,
    evidence_tier: $evidence_tier,
    chain_tier: $chain_tier,
    impact_tier: $impact_tier,
    drafted_at: $drafted_at,
    gates_run_at: $gates_run_at,
    submitted_at: $submitted_at,
    outcome: $outcome,
    surface: $surface,
    platform: $platform,
    bounty_program: $bounty_program,
    hours_invested: $hours_invested,
    preflight_run: $preflight_run,
    rejected_by_gate: $rejected_by_gate,
    held_reason: "n/a",
    uncertainty_source: "n/a",
    retroactive: false
  }')

echo "$ENTRY" >> "$WORKSPACE/OUTCOMES.jsonl"
echo "submit:$NOW:$FINDING_ID:$OUTCOME" >> "$WORKSPACE/.lifecycle-status"

echo "[lifecycle] on-submit: $FINDING_ID → $OUTCOME"
echo "[lifecycle] OUTCOMES entry:"
echo "$ENTRY" | jq .
