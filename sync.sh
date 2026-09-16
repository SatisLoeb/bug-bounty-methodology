#!/usr/bin/env bash
# Sync the methodology backup repo from the live sources, scrubbed of secrets/target-data.
# Usage:  ./sync.sh            (sync + commit + push)
#         ./sync.sh --dry      (sync + show diff, NO commit/push)
set -euo pipefail

REPO="$(cd "$(dirname "$0")" && pwd)"
BUGS="/home/malix/Desktop/BUGS"
DESKTOP="/home/malix/Desktop"
ARSENAL="$HOME/arsenal"
SKILLS="$HOME/.claude/skills"
DRY="${1:-}"

cd "$REPO"

# --- wipe content dirs (keep .git, README, .gitignore, this script) ---
rm -rf claude-md methodology skills arsenal memory workflows drift-watch tools
mkdir -p claude-md methodology skills arsenal memory workflows drift-watch tools

# --- 1. CLAUDE.md + rules + agents ---
cp "$DESKTOP/CLAUDE.md" claude-md/CLAUDE-Desktop.md 2>/dev/null || true
cp "$BUGS/CLAUDE.md"    claude-md/CLAUDE-BUGS.md 2>/dev/null || true
cp "$BUGS"/CLAUDE-rules-*.md "$BUGS/AGENTS.md" "$BUGS/QWEN.md" claude-md/ 2>/dev/null || true

# --- 2. methodology whitelist (generic only, NO target-named files) ---
METHODO="CRITICAL-HUNT-CHECKLIST.md CRYPTO-LIB-HUNT-PLAYBOOK.md DEFI-FULLSTACK-CHECKLIST.md \
FINANCIAL-SYSTEMS-HUNT.md FIRM-AUDIT-PROMPT.md INFRA-ADJACENT-TO-SC-PLAYBOOK.md \
LIQUIDATION-READPATH-PLAYBOOK.md MOBILE-API-HUNT-CHECKLIST.md NEXTJS-HUNT-CHECKLIST.md \
OPEN-BANKING-HUNT-CHECKLIST.md SOLANA-HUNT-CHECKLIST.md WEB2-ON-SC-PROGRAMS-PLAYBOOK.md \
ZERO-DAY-METHODOLOGY.md CHAIN-PROOF-GATE.md CONTAINER-LAYER-ATTACK-SPEC.md DISCLOSURE-TEMPLATE.md \
KILL-GATE-TEMPLATE.md PREFLIGHT-CHECK.md REPORT-STANDARD.md SUBMISSION-TEMPLATE.md WEIGHT-CARD.md \
strix-integration.md INFRA-2026-04-24.md WIP-LIMITS.md SYNC-MACHINE2-SETUP.md \
INSTRUCTIONS-MACHINE2-RULE26-UPDATE.md"
for f in $METHODO; do [ -f "$BUGS/$f" ] && cp "$BUGS/$f" methodology/ || true; done

# --- 3. skills (whole) ---
cp -r "$SKILLS/." skills/ 2>/dev/null || true

# --- 4. arsenal: methodology-only subdirs (NO findings/morpho-audit/tracking) ---
for d in alternate-implementations audit-lifecycle checklists methodology profiles skills templates tools; do
  [ -d "$ARSENAL/$d" ] && cp -r "$ARSENAL/$d" arsenal/ || true
done
cp "$ARSENAL/README.md" "$ARSENAL/SETUP-MACHINE-2.md" "$ARSENAL/SYNC-MACHINE2.md" arsenal/ 2>/dev/null || true

# --- 4b. memories: every project memory dir, namespaced by project ---
for md in "$HOME"/.claude/projects/*/memory; do
  [ -d "$md" ] || continue
  proj="$(basename "$(dirname "$md")")"
  mkdir -p "memory/$proj"
  cp -r "$md/." "memory/$proj/" 2>/dev/null || true
done

# --- 4c. v1.6 playbook stack: gate-runner + reusable fanout template + on-chain tools ---
PBK="$DESKTOP/D-cve/playbook"
cp "$PBK/playbook-bug-bounty-v1.6.md" "$PBK/finding-acceptance-standard.md" \
   "$PBK/audit-competition-filter-results.md" "$PBK/README.md" methodology/ 2>/dev/null || true
cp "$PBK/audit-fanout-template.js" workflows/ 2>/dev/null || true
cp -r "$PBK/tools/." tools/ 2>/dev/null || true

# --- 4d. drift-watch system: scripts + watchlists + cloud-routine prompt (NO logs) ---
DW="$DESKTOP/drift-watch"
cp "$DW"/*.sh "$DW"/*.tsv "$DW"/*.md "$DW"/*.txt drift-watch/ 2>/dev/null || true
rm -f drift-watch/*.log 2>/dev/null || true

# --- 5. SCRUB: secrets, key material, nested .git, caches, large blobs ---
find claude-md methodology skills arsenal memory workflows drift-watch tools -name ".git" -type d -prune -exec rm -rf {} + 2>/dev/null || true
find claude-md methodology skills arsenal memory workflows drift-watch tools \
  \( -iname "*.key.pem" -o -iname "*.key" -o -iname "*.pem" -o -iname "id_rsa*" \
     -o -iname "*.keystore" -o -iname "*.env" -o -iname "*.p12" \) -delete 2>/dev/null || true
find claude-md methodology skills arsenal memory workflows drift-watch tools -type d \
  \( -name node_modules -o -name __pycache__ -o -name .venv -o -name target \) -prune -exec rm -rf {} + 2>/dev/null || true
find claude-md methodology skills arsenal memory workflows drift-watch tools -type f -size +3M -delete 2>/dev/null || true

# --- 6. HARD secret gate: abort if any real token/key pattern slipped through ---
HITS="$(grep -rIlE 'gh[posu]_[A-Za-z0-9]{36}|sk-[A-Za-z0-9]{20,}|AKIA[0-9A-Z]{16}|-----BEGIN [A-Z ]*PRIVATE KEY-----|xox[baprs]-[A-Za-z0-9-]{10,}' claude-md methodology skills arsenal memory workflows drift-watch tools 2>/dev/null || true)"
if [ -n "$HITS" ]; then
  echo "ABORT: real-secret pattern detected, not committing:"; echo "$HITS"; exit 1
fi

echo "scrub clean. staged file count: $(git add -A --dry-run | wc -l)"

if [ "$DRY" = "--dry" ]; then
  git add -A
  echo "=== DRY RUN diff (not committed) ==="
  git status --short
  exit 0
fi

git add -A
if git diff --cached --quiet; then
  echo "no changes to sync."
  exit 0
fi
git commit -q -m "sync methodology backup $(date -u +%Y-%m-%dT%H:%MZ)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
git push -q origin master
echo "pushed: $(git log --oneline -1)"
