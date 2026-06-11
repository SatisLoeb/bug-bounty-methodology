#!/usr/bin/env bash
# INVOCATION CONDITION: at hold decision — finding exists but not being submitted yet.
# Populates held_reason + uncertainty_source (if self_uncertainty) at moment of hold,
# NOT retroactively (prevents rationalization bias).
#
# The distribution of held_reason over time is the signal of whether gates over-regulate:
#   - self_uncertainty + framing_unclear > 25% → gates produced submission aversion
#     distinct from overclaim aversion
#   - severity_doubt dominance within self_uncertainty → pre-gate is too punitive
#   - technical_doubt dominance → more on-chain verification needed
#   - scope_doubt dominance → stricter scope reading at target entry
#
# Usage: on-hold.sh <FINDING_ID> <held_reason> [uncertainty_source] [workspace-path]
#
# Valid held_reason values:
#   rep_gate                 — externe légitime (platform rep requirement not met)
#   deposit_pending          — externe légitime (Cantina deposit not made)
#   geo_block                — externe légitime (VPN/jurisdiction)
#   awaiting_validation      — interne légitime (on-chain query pending)
#   gate_failed_unresolved   — interne légitime (gate caught real issue, fixing)
#   self_uncertainty         — interne — SIGNAL to watch
#   framing_unclear          — interne — SIGNAL to watch
#
# Valid uncertainty_source (required if held_reason = self_uncertainty):
#   technical_doubt   — on-chain behavior unclear
#   severity_doubt    — tier unclear (pre-gate response)
#   scope_doubt       — in-scope unclear
set -euo pipefail

FINDING_ID="${1:?Usage: on-hold.sh <FINDING_ID> <held_reason> [uncertainty_source] [workspace-path]}"
HELD_REASON="${2:?held_reason required — see script header for enum}"
UNCERTAINTY_SOURCE="${3:-n/a}"
WORKSPACE="${4:-${WORKSPACE:-$(pwd)}}"

if ! command -v jq >/dev/null 2>&1; then
  echo "[lifecycle] ERROR: jq required but not installed" >&2
  exit 1
fi

# Validate held_reason enum
case "$HELD_REASON" in
  rep_gate|deposit_pending|geo_block|awaiting_validation|gate_failed_unresolved|self_uncertainty|framing_unclear) ;;
  *) echo "[lifecycle] ERROR: invalid held_reason '$HELD_REASON'" >&2
     echo "[lifecycle]        valid: rep_gate|deposit_pending|geo_block|awaiting_validation|gate_failed_unresolved|self_uncertainty|framing_unclear" >&2
     exit 1 ;;
esac

# Enforce uncertainty_source when held_reason = self_uncertainty
if [ "$HELD_REASON" = "self_uncertainty" ] && [ "$UNCERTAINTY_SOURCE" = "n/a" ]; then
  echo "[lifecycle] ERROR: self_uncertainty requires uncertainty_source argument" >&2
  echo "[lifecycle]        valid: technical_doubt|severity_doubt|scope_doubt" >&2
  exit 1
fi

# Validate uncertainty_source enum
case "$UNCERTAINTY_SOURCE" in
  technical_doubt|severity_doubt|scope_doubt|n/a) ;;
  *) echo "[lifecycle] ERROR: invalid uncertainty_source '$UNCERTAINTY_SOURCE'" >&2
     echo "[lifecycle]        valid: technical_doubt|severity_doubt|scope_doubt|n/a" >&2
     exit 1 ;;
esac

NOW="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
PROTOCOL=$(basename "$WORKSPACE" | sed 's/-audit$//; s/-recon$//')

# Build OUTCOMES entry for hold
ENTRY=$(jq -c -n \
  --arg id "$FINDING_ID" \
  --arg protocol "$PROTOCOL" \
  --arg held_at "$NOW" \
  --arg held_reason "$HELD_REASON" \
  --arg uncertainty_source "$UNCERTAINTY_SOURCE" \
  '{
    id: $id,
    protocol: $protocol,
    outcome: "held",
    held_at: $held_at,
    held_reason: $held_reason,
    uncertainty_source: $uncertainty_source,
    retroactive: false
  }')

echo "$ENTRY" >> "$WORKSPACE/OUTCOMES.jsonl"
echo "hold:$NOW:$FINDING_ID:$HELD_REASON:$UNCERTAINTY_SOURCE" >> "$WORKSPACE/.lifecycle-status"

echo "[lifecycle] on-hold: $FINDING_ID"
echo "[lifecycle]   held_reason:        $HELD_REASON"
echo "[lifecycle]   uncertainty_source: $UNCERTAINTY_SOURCE"

# Warning if signal categories
case "$HELD_REASON" in
  self_uncertainty|framing_unclear)
    echo "[lifecycle] WATCH: $HELD_REASON is a GATE-OVER-REGULATION signal category"
    echo "[lifecycle]        if rate > 25% over 30 days, gates have moved from protection to inhibition"
    ;;
esac
