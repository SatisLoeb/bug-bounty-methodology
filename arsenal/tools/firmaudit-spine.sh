#!/usr/bin/env bash
# firmaudit-spine.sh — turn firmaudit's prose-MANDATORY process phases into a MECHANICAL coverage check.
#
# F-1 fix (darkside-on-firmaudit, 2026-06-23): the load-bearing phases (Phase S seam, 4-PASS,
# Door C, COVERAGE-LEDGER, AUDIT-CONDITIONS) are called "MANDATORY / gating / illegal until" in
# prose, but preflight-mechanical.sh + on-finding.sh enforce ZERO of them — only the per-finding
# submission gates (D0/D8b/D9). So the discovery phases where firmaudit says "the wins are here"
# rely entirely on agent discipline, which the skill's own §0.5.4 proves is unreliable
# ("encoded ≠ applied; memory necessary not sufficient"). This script is the coverage-ledger
# turned on firmaudit's OWN phases: it lists which engagement artifacts exist vs missing, so a
# NO-GO/null/submission can no longer silently skip Phase S / Pass 2-4 / Door C / the ledger.
#
# It does NOT hard-block (engagement-level granularity; a Phase-T NO-GO legitimately has no 4-PASS).
# It SURFACES the coverage; firmaudit §7/NO-GO requires pasting its output and writing an
# allowed-reason for every MISSING artifact (same rule as COVERAGE-LEDGER for in-scope files).
#
# Usage: firmaudit-spine.sh [workspace-path]   (default: cwd)
set -euo pipefail
WS="${1:-$(pwd)}"
[ -d "$WS" ] || { echo "FATAL: workspace not found: $WS" >&2; exit 1; }

# phase | label | candidate paths (first that exists wins; glob ok)
ROWS=(
  "Phase 0|target intel|PHASE0-INTEL.md"
  "Phase 0|surface inventory (full surface set)|SURFACE-INVENTORY.md"
  "Phase S|seam statement (the boundary nobody owns)|recon/SEAM-STATEMENT.md SEAM-STATEMENT.md"
  "Phase S|deployed-layer read pass|recon/DEPLOYED-FINDINGS.md analysis/DEPLOYED-FINDINGS.md"
  "Phase T|triage card (GO/NO-GO + P0/P1 paths)|TRIAGE-CARD.md recon/TRIAGE-CARD.md"
  "Phase A|audit-conditions table (cast-call probes)|analysis/AUDIT-CONDITIONS.md AUDIT-CONDITIONS.md"
  "Phase R|recon probes executed + logged|analysis/RECON-PROBES.md RECON-PROBES.md"
  "Pass 1|inventory primary (seam paths dug)|analysis/INVENTORY-PASS-1.md INVENTORY-PASS-1.md"
  "Pass 2|inventory expansion (2A-2F blind spots)|analysis/INVENTORY-PASS-2.md INVENTORY-PASS-2.md"
  "Pass 3|mirror-invariant (V_in vs V_out)|findings/*/MIRROR-AUDIT.md analysis/MIRROR-AUDIT.md analysis/INVENTORY-PASS-3.md"
  "Pass 4|chain construction (primitives map)|analysis/PRIMITIVES-MAP.md analysis/CHAIN-TRIAGE-*.md findings/CHAIN-*/CHAIN-PROOF.md"
  "dedup|root-cause map (merge/split by root)|analysis/ROOT-CAUSE-MAP.md ROOT-CAUSE-MAP.md"
  "ledger|coverage ledger (every in-scope file)|analysis/COVERAGE-LEDGER.md COVERAGE-LEDGER.md analysis/coverage-ledger.md"
)

present=0; total=0; missing=()
printf "firmaudit process-artifact coverage — %s\n\n" "$WS"
printf "  %-9s %-44s %s\n" "PHASE" "ARTIFACT" "STATUS"
printf "  %-9s %-44s %s\n" "-----" "--------" "------"
for r in "${ROWS[@]}"; do
  IFS='|' read -r phase label paths <<<"$r"
  total=$((total+1))
  found=""
  for pat in $paths; do
    for f in $WS/$pat; do [ -e "$f" ] && { found="$f"; break; }; done
    [ -n "$found" ] && break
  done
  if [ -n "$found" ]; then
    present=$((present+1))
    printf "  %-9s %-44s ✓ %s\n" "$phase" "$label" "$(basename "$found")"
  else
    missing+=("$phase: $label")
    printf "  %-9s %-44s ✗ MISSING\n" "$phase" "$label"
  fi
done

echo
echo "VERDICT: $present/$total process artifacts present."
if [ ${#missing[@]} -gt 0 ]; then
  echo "⚠ ${#missing[@]} MISSING — before any NO-GO / null / submission you MUST write an allowed-reason"
  echo "  for EACH (e.g. 'Phase A N/A: no in-scope audits' / 'Pass 4 N/A: NO-GO at Phase T'). A MISSING"
  echo "  with no allowed-reason = a skipped MANDATORY phase = the discovery-skip this gate exists to catch."
  echo "  (engagement-level: not every verdict needs every artifact — but every absence needs a stated reason.)"
else
  echo "✓ all process phases have an artifact — the prose-MANDATORY phases actually ran."
fi
