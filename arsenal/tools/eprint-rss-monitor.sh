#!/usr/bin/env bash
# eprint-rss-monitor.sh — subscribe IACR eprint RSS, filter crypto/DeFi relevance
#
# Phase A skeleton. Phase B: wire LLM-based summarization + score gating.
#
# Usage:
#   ./eprint-rss-monitor.sh --scan                  # pull latest, filter, emit candidates
#   ./eprint-rss-monitor.sh --score <paper-url>     # LLM score a specific paper
#   ./eprint-rss-monitor.sh --list                  # list tracked candidates
set -euo pipefail

RSS_URL="https://eprint.iacr.org/rss/rss.xml"
CANDIDATES_LOG="$HOME/arsenal/tracking/eprint-candidates.log"
TRIAGE_DIR="$HOME/arsenal/tracking/eprint-triage"

mkdir -p "$(dirname "$CANDIDATES_LOG")" "$TRIAGE_DIR"

KEYWORDS='FROST|threshold|MPC|PLONK|halo2|Nova|bridge|oracle|MEV|sandwich|rollup|zkEVM|zkVM|folding|ZK|lookup argument|attestation|light client|DA\|data availability|restaking|slashing|paillier|schnorr|groth16|kzg|fiat.shamir|nullifier|commitment'

case "${1:-}" in
  --scan)
    echo "[scan] fetching $RSS_URL"
    tmp=$(mktemp)
    curl -s "$RSS_URL" > "$tmp"

    # Parse RSS, filter by keywords
    # Phase A: simple awk filter; Phase B: xmlstarlet + richer parse
    grep -oE '<item>.*?</item>' "$tmp" 2>/dev/null || \
      python3 -c "
import sys, re, xml.etree.ElementTree as ET
tree = ET.parse('$tmp')
root = tree.getroot()
for item in root.iter('item'):
    title = (item.find('title').text or '').strip()
    link = (item.find('link').text or '').strip()
    desc = (item.find('description').text or '').strip()
    content = f'{title} {desc}'
    if re.search(r'$KEYWORDS', content, re.IGNORECASE):
        print(f'{link} | {title}')
"
    rm -f "$tmp"
    ;;
  --score)
    shift
    URL="${1:?paper URL required}"
    echo "[stub] LLM-score paper $URL against crypto/DeFi relevance rubric (Phase B)"
    echo ""
    echo "Scoring rubric (0-10):"
    echo "  +4 attack on standardized primitive (FROST, Schnorr, BLS, PLONK, Groth16)"
    echo "  +3 names specific protocol/implementation in abstract"
    echo "  +2 applied cryptography (not pure theory)"
    echo "  +3 DeFi / blockchain specifically"
    echo "  +3 MPC / threshold / wallet related"
    echo "  +2 oracle / MEV / sandwich related"
    echo "  +3 ZK circuit bugs / soundness"
    echo "  +3 L2 / rollup / DA specific"
    echo "  +3 cross-chain bridge attack"
    echo "  +2 compiler / toolchain security"
    echo ""
    echo "Score >= 6 → read abstract + intro."
    echo "Score >= 8 → deep read + identify live targets."
    ;;
  --list)
    [ -f "$CANDIDATES_LOG" ] && cat "$CANDIDATES_LOG" || echo "no candidates yet"
    ;;
  *)
    cat <<EOF
eprint-rss-monitor.sh

Usage:
  --scan                                pull latest, filter, emit candidates
  --score <paper-url>                   LLM-score a specific paper (Phase B)
  --list                                list tracked candidates

See ~/arsenal/methodology/ACADEMIC-PAPER-HUNT.md for the full pipeline.

Additional sources to monitor (Phase B):
  - https://eprint.iacr.org/rss/rss.xml  (IACR)
  - http://export.arxiv.org/rss/cs.CR     (arXiv security)
  - ethresear.ch RSS
  - zkresear.ch RSS
  - ACM CCS, IEEE S&P, USENIX Security, NDSS proceedings
EOF
    ;;
esac
