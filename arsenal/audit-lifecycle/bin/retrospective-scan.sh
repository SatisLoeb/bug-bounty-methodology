#!/usr/bin/env bash
# retrospective-scan.sh
#
# Scan every existing audit/recon workspace under ~/Desktop/BUGS/, run
# auto-detect-hints.sh against it, check whether the 3 new playbooks
# (Web2-on-SC, Crypto-lib, Infra-adjacent) would fire, and cross-check
# whether a finding of that class has already been submitted. Emits a
# ranked CSV + markdown shortlist of high-opportunity targets to revisit.
#
# Usage: retrospective-scan.sh [--output <dir>] [--only <pattern>] [--min-score <n>]
#
#   --output    Output directory (default: ~/Desktop/BUGS/retrospective-scan-$(date))
#   --only      Only scan workspaces matching this substring (e.g. "polymarket")
#   --min-score Skip workspaces with opportunity score < N (default: 1)
#
# Output files:
#   results.csv      Full per-workspace data
#   shortlist.md     Ranked markdown shortlist (opportunity_score > 0)
#   summary.txt      Totals and top-10 preview

set -uo pipefail

LIFECYCLE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
AUTO_DETECT="$LIFECYCLE_DIR/lib/auto-detect-hints.sh"
ROUTER="$LIFECYCLE_DIR/lib/target-router.sh"

if [ ! -x "$AUTO_DETECT" ]; then
  echo "ERROR: auto-detect-hints.sh not found at $AUTO_DETECT" >&2
  exit 1
fi

# --- args ---
BUGS_ROOT="$HOME/Desktop/BUGS"
OUTPUT_DIR="$BUGS_ROOT/retrospective-scan-$(date -u +%Y%m%d-%H%M%S)"
FILTER=""
MIN_SCORE=1

while [ $# -gt 0 ]; do
  case "$1" in
    --output)    OUTPUT_DIR="$2"; shift 2 ;;
    --only)      FILTER="$2"; shift 2 ;;
    --min-score) MIN_SCORE="$2"; shift 2 ;;
    -h|--help)
      sed -n '/^# Usage:/,/^$/p' "$0" | sed 's/^# \?//'
      exit 0 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

mkdir -p "$OUTPUT_DIR"
CSV="$OUTPUT_DIR/results.csv"
MD="$OUTPUT_DIR/shortlist.md"
SUMMARY="$OUTPUT_DIR/summary.txt"

# CSV header
{
  printf "workspace,hints,web2_on_sc,crypto_lib,infra_adjacent,"
  printf "outcomes_count,has_web2_finding,has_crypto_finding,has_infra_finding,"
  printf "opportunity_score,notes\n"
} > "$CSV"

# --- classifiers: same regex as target-router.sh additive triggers ---
fires_web2_on_sc() {
  local h="$1"
  echo "$h" | grep -qE 'cantina|code4rena|c4|sherlock|hackenproof|bounty' && return 0
  echo "$h" | grep -qE '(smart.contract|evm|solidity|solana|anchor).*(web|api|dashboard|app|frontend|webapp|dapp|admin|nextjs)' && return 0
  echo "$h" | grep -qE '(web|api|dashboard|app|frontend|webapp|dapp|admin|nextjs).*(smart.contract|evm|solidity|solana|anchor)' && return 0
  echo "$h" | grep -qE '\b(dashboard|webapp|dapp|admin|ui|frontend)\b' && return 0
  return 1
}

fires_crypto_lib() {
  local h="$1"
  echo "$h" | grep -qE 'crypto.lib|ed25519|secp256k1|bls|frost|dkg|threshold|mpc|jwt.lib|authlib|noble|libsodium|blst|arkworks|circom|halo2' && return 0
  return 1
}

fires_infra_adjacent() {
  local h="$1"
  echo "$h" | grep -qE 'relayer|bridge|oracle|sequencer|indexer|subgraph|keeper|gelato|automation|mpc|fireblocks|meta.?tx|gasless|layerzero|axelar|wormhole|ccip|hyperlane|connext|chainlink|pyth|api3|redstone|thegraph|goldsky' && return 0
  return 1
}

# --- per-workspace outcomes analysis ---
# has_class_finding <outcomes_path> <class>
#   class ∈ {web2, crypto, infra}
#   Returns 0 if a submitted/held/awarded finding tagged with that class
#   exists (based on heuristic keyword match in id / notes / triager_comment).
has_class_finding() {
  local outcomes="$1"
  local cls="$2"
  [ ! -s "$outcomes" ] && return 1

  local pattern=""
  case "$cls" in
    web2)   pattern='web2|Web2|W-ROUTE|dashboard|frontend|IDOR|JWT|OAUTH|CORS|ATO|KYC' ;;
    crypto) pattern='ED25519|FROST|DKG|CRYPTO|SIGNATURE|MALLEAB|IDENTITY-POINT|NONCE|PANIC.*CRYPTO' ;;
    infra)  pattern='RELAYER|BRIDGE|ORACLE|SEQUENCER|RPC|INDEXER|KEEPER|CLOB|RPC-NAMESPACE|LZRECEIVE' ;;
  esac

  grep -qiE "$pattern" "$outcomes" && return 0
  return 1
}

# --- main loop ---
SCANNED=0
TOTAL_OPPORTUNITIES=0
declare -A FIRE_TOTALS=([web2]=0 [crypto]=0 [infra]=0)

echo "Scanning $BUGS_ROOT for *-audit / *-recon workspaces..."
echo ""

# Collect candidate workspaces (audit + recon suffix)
WORKSPACES=()
while IFS= read -r -d '' ws; do
  [ -n "$FILTER" ] && [[ "$ws" != *"$FILTER"* ]] && continue
  WORKSPACES+=("$ws")
done < <(find "$BUGS_ROOT" -maxdepth 1 -type d \( -name "*-audit" -o -name "*-recon" \) -print0 2>/dev/null | sort -z)

TOTAL=${#WORKSPACES[@]}
echo "Found $TOTAL workspaces to scan"
echo ""

for ws in "${WORKSPACES[@]}"; do
  SCANNED=$((SCANNED + 1))
  name=$(basename "$ws")

  # Progress indicator every 20
  if [ $((SCANNED % 20)) -eq 0 ]; then
    echo "  [$SCANNED/$TOTAL] scanning... last: $name"
  fi

  # Run auto-detect
  hints=$(bash "$AUTO_DETECT" "$ws" "" 2>/dev/null | tr -s ' ' | sed 's/^ //; s/ $//')
  hints_lower=$(echo "$hints" | tr '[:upper:]' '[:lower:]')

  # Classifier results
  W2=0; CL=0; IA=0
  fires_web2_on_sc "$hints_lower"     && W2=1 && FIRE_TOTALS[web2]=$((FIRE_TOTALS[web2] + 1))
  fires_crypto_lib "$hints_lower"     && CL=1 && FIRE_TOTALS[crypto]=$((FIRE_TOTALS[crypto] + 1))
  fires_infra_adjacent "$hints_lower" && IA=1 && FIRE_TOTALS[infra]=$((FIRE_TOTALS[infra] + 1))

  # Outcomes analysis
  outcomes="$ws/OUTCOMES.jsonl"
  outcomes_count=0
  HAS_W2=0; HAS_CL=0; HAS_IA=0
  if [ -s "$outcomes" ]; then
    outcomes_count=$(wc -l < "$outcomes")
    has_class_finding "$outcomes" web2   && HAS_W2=1
    has_class_finding "$outcomes" crypto && HAS_CL=1
    has_class_finding "$outcomes" infra  && HAS_IA=1
  fi

  # Opportunity score:
  #   +1 per fired classifier where no existing finding of that class
  #   +1 bonus if workspace has ZERO outcomes at all (virgin territory)
  SCORE=0
  [ "$W2" -eq 1 ] && [ "$HAS_W2" -eq 0 ] && SCORE=$((SCORE + 1))
  [ "$CL" -eq 1 ] && [ "$HAS_CL" -eq 0 ] && SCORE=$((SCORE + 1))
  [ "$IA" -eq 1 ] && [ "$HAS_IA" -eq 0 ] && SCORE=$((SCORE + 1))
  [ "$outcomes_count" -eq 0 ] && [ $((W2 + CL + IA)) -gt 0 ] && SCORE=$((SCORE + 1))

  # Build notes
  NOTES=""
  missing=()
  [ "$W2" -eq 1 ] && [ "$HAS_W2" -eq 0 ] && missing+=("WEB2-ON-SC")
  [ "$CL" -eq 1 ] && [ "$HAS_CL" -eq 0 ] && missing+=("CRYPTO-LIB")
  [ "$IA" -eq 1 ] && [ "$HAS_IA" -eq 0 ] && missing+=("INFRA-ADJ")
  [ ${#missing[@]} -gt 0 ] && NOTES="unaddressed: $(IFS=,; echo "${missing[*]}")"
  [ "$outcomes_count" -eq 0 ] && NOTES="${NOTES}${NOTES:+; }virgin-no-outcomes"

  # Escape commas for CSV
  hints_csv=$(echo "$hints" | tr ',' ';')
  notes_csv=$(echo "$NOTES" | tr ',' ';')

  printf '%s,%s,%d,%d,%d,%d,%d,%d,%d,%d,%s\n' \
    "$name" "$hints_csv" "$W2" "$CL" "$IA" "$outcomes_count" \
    "$HAS_W2" "$HAS_CL" "$HAS_IA" "$SCORE" "$notes_csv" >> "$CSV"

  [ "$SCORE" -ge "$MIN_SCORE" ] && TOTAL_OPPORTUNITIES=$((TOTAL_OPPORTUNITIES + 1))
done

echo ""
echo "Scan complete: $SCANNED workspaces, $TOTAL_OPPORTUNITIES opportunities (score >= $MIN_SCORE)"
echo ""

# --- build markdown shortlist ---
{
  echo "# Retrospective Scan — High-Opportunity Targets"
  echo ""
  echo "**Generated:** $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "**Scanned:** $SCANNED workspaces"
  echo "**Opportunities (score >= $MIN_SCORE):** $TOTAL_OPPORTUNITIES"
  echo ""
  echo "## Fire totals"
  echo ""
  echo "| Playbook | Workspaces where it would fire |"
  echo "|----------|--------------------------------|"
  echo "| WEB2-ON-SC-PROGRAMS | ${FIRE_TOTALS[web2]} |"
  echo "| CRYPTO-LIB-HUNT | ${FIRE_TOTALS[crypto]} |"
  echo "| INFRA-ADJACENT-TO-SC | ${FIRE_TOTALS[infra]} |"
  echo ""
  echo "## Shortlist — sorted by opportunity_score DESC"
  echo ""
  echo "Each row = a past workspace where the new playbook would fire AND no finding"
  echo "of that class has been submitted yet. Score 4 = virgin workspace with all 3"
  echo "playbooks unaddressed; Score 1 = one playbook with untouched surface."
  echo ""
  echo "| Score | Workspace | Missed playbooks | Outcomes | Detected hints |"
  echo "|-------|-----------|------------------|----------|----------------|"

  # Sort CSV by score DESC, skip header, filter by min score
  tail -n +2 "$CSV" | awk -F',' -v min="$MIN_SCORE" '$10 >= min' | sort -t',' -k10,10nr -k1,1 | while IFS=',' read -r name hints w2 cl ia out_ct has_w2 has_cl has_ia score notes; do
    missed=""
    [ "$w2" -eq 1 ] && [ "$has_w2" -eq 0 ] && missed="${missed}${missed:+ }W2"
    [ "$cl" -eq 1 ] && [ "$has_cl" -eq 0 ] && missed="${missed}${missed:+ }CRYPTO"
    [ "$ia" -eq 1 ] && [ "$has_ia" -eq 0 ] && missed="${missed}${missed:+ }INFRA"
    [ -z "$missed" ] && missed="—"
    # Truncate hints for readability
    hints_short=$(echo "$hints" | tr ';' ',' | cut -c1-80)
    [ ${#hints} -gt 80 ] && hints_short="${hints_short}..."
    printf '| %s | %s | %s | %s | %s |\n' "$score" "$name" "$missed" "$out_ct" "$hints_short"
  done
  echo ""
  echo "## How to act"
  echo ""
  echo "For each high-score workspace:"
  echo ""
  echo "1. \`cd ~/Desktop/BUGS/<workspace>\`"
  echo "2. Re-run the router with detected hints: \`~/arsenal/audit-lifecycle/bin/init-target.sh <name> \$(pwd)\`"
  echo "3. Read the updated \`ROUTING.md\` — the new additive sections are loaded"
  echo "4. Apply the checklist from the relevant playbook:"
  echo "   - \`WEB2-ON-SC-PROGRAMS-PLAYBOOK.md\` (Sections A-F mechanical checks)"
  echo "   - \`CRYPTO-LIB-HUNT-PLAYBOOK.md\` (Sections A-H)"
  echo "   - \`INFRA-ADJACENT-TO-SC-PLAYBOOK.md\` (Sections A-I)"
  echo "5. Budget: 2-4h per target. If signal → PoC immediately."
  echo ""
  echo "## Caveats"
  echo ""
  echo "- **Dismissed ≠ absent**: if a workspace has a KILL finding in that class, it's still flagged here. Check \`findings/\` before re-hunting."
  echo "- **Out-of-scope**: some workspaces may have program-level scope restrictions that exclude Web2 / infra. Re-read SCOPE.md."
  echo "- **Stale scope**: bounty programs close/open over time. Check platform before investing time."
  echo "- **Heuristic class detection**: \`has_class_finding\` uses keyword matching on OUTCOMES.jsonl. May miss renamed findings. Tune patterns in \`retrospective-scan.sh\` if false positives/negatives."
} > "$MD"

# --- summary ---
{
  echo "Retrospective Scan Summary"
  echo "=========================="
  echo "Generated:   $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "Scanned:     $SCANNED workspaces"
  echo "Output:      $OUTPUT_DIR"
  echo ""
  echo "Fire totals (playbook would fire):"
  echo "  WEB2-ON-SC:    ${FIRE_TOTALS[web2]}"
  echo "  CRYPTO-LIB:    ${FIRE_TOTALS[crypto]}"
  echo "  INFRA-ADJ:     ${FIRE_TOTALS[infra]}"
  echo ""
  echo "Opportunities (score >= $MIN_SCORE): $TOTAL_OPPORTUNITIES"
  echo ""
  echo "Top 10 by opportunity_score:"
  echo ""
  tail -n +2 "$CSV" | awk -F',' -v min="$MIN_SCORE" '$10 >= min' | sort -t',' -k10,10nr -k1,1 | head -10 | while IFS=',' read -r name hints w2 cl ia out_ct has_w2 has_cl has_ia score notes; do
    printf "  [%s] %-45s  outcomes=%d  %s\n" "$score" "$name" "$out_ct" "$notes"
  done
} | tee "$SUMMARY"

echo ""
echo "Full CSV:     $CSV"
echo "Shortlist:    $MD"
echo "Summary:      $SUMMARY"
